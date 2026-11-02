import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Error codes from the backend error envelope (`06 §6` and the OpenAPI
/// `ErrorCodeEnum`), plus client-side codes for failures that never reached
/// the server or had no envelope.
enum ApiErrorCode {
  validationError('VALIDATION_ERROR'),
  otpInvalid('OTP_INVALID'),
  otpExpired('OTP_EXPIRED'),
  otpRateLimited('OTP_RATE_LIMITED'),
  authRequired('AUTH_REQUIRED'),
  tokenInvalid('TOKEN_INVALID'),
  permissionDenied('PERMISSION_DENIED'),
  notFound('NOT_FOUND'),
  appUpdateRequired('APP_UPDATE_REQUIRED'),
  notServiceable('NOT_SERVICEABLE'),
  storeClosed('STORE_CLOSED'),
  stockUnavailable('STOCK_UNAVAILABLE'),
  maxQtyExceeded('MAX_QTY_EXCEEDED'),
  minOrderNotMet('MIN_ORDER_NOT_MET'),
  couponInvalid('COUPON_INVALID'),
  couponExpired('COUPON_EXPIRED'),
  couponNotEligible('COUPON_NOT_ELIGIBLE'),
  couponUsageExceeded('COUPON_USAGE_EXCEEDED'),
  codNotAvailable('COD_NOT_AVAILABLE'),
  priceChanged('PRICE_CHANGED'),
  paymentVerificationFailed('PAYMENT_VERIFICATION_FAILED'),
  invalidStateTransition('INVALID_STATE_TRANSITION'),
  offerExpired('OFFER_EXPIRED'),
  offerTaken('OFFER_TAKEN'),
  outsideGeofence('OUTSIDE_GEOFENCE'),
  deliveryOtpInvalid('DELIVERY_OTP_INVALID'),
  deliveryOtpLocked('DELIVERY_OTP_LOCKED'),
  cashLimitExceeded('CASH_LIMIT_EXCEEDED'),
  maintenance('MAINTENANCE'),

  // Generic HTTP-level codes. They are in the OpenAPI `ErrorCodeEnum` but not
  // (yet) in `06 §6`.
  methodNotAllowed('METHOD_NOT_ALLOWED'),
  notAcceptable('NOT_ACCEPTABLE'),
  unsupportedMediaType('UNSUPPORTED_MEDIA_TYPE'),
  rateLimited('RATE_LIMITED'),
  serviceUnavailable('SERVICE_UNAVAILABLE'),

  /// No connection, DNS failure, refused connection or TLS failure.
  network(null),

  /// Connect, send or receive timeout.
  timeout(null),

  /// The request was cancelled by the app.
  cancelled(null),

  /// `SERVER_ERROR`, or a 5xx response without an error envelope (e.g. a
  /// proxy error page).
  serverError('SERVER_ERROR'),

  /// An unrecognised server code, or any other failure.
  unknown(null);

  const ApiErrorCode(this.wireValue);

  /// The code string the backend sends, or null for client-side codes.
  final String? wireValue;

  /// Maps a backend code string to an [ApiErrorCode]; unknown strings map
  /// to [unknown].
  static ApiErrorCode fromWire(String? value) {
    if (value == null) return unknown;
    return _byWireValue[value] ?? unknown;
  }

  static final Map<String, ApiErrorCode> _byWireValue = {
    for (final code in values)
      if (code.wireValue != null) code.wireValue!: code,
  };
}

/// A failed API call, parsed from the error envelope
/// `{"error": {"code", "message", "details"}}` or from the transport failure.
///
/// Show users `apiErrorMessage(...)`, never [serverMessage] or [cause].
@immutable
class ApiError implements Exception {
  const ApiError({
    required this.code,
    this.rawCode,
    this.serverMessage,
    this.details = const {},
    this.statusCode,
    this.cause,
  });

  /// Converts any error thrown by a repository call into an [ApiError].
  factory ApiError.from(Object error) => switch (error) {
    ApiError() => error,
    DioException() => ApiError.fromDioException(error),
    _ => ApiError(code: ApiErrorCode.unknown, cause: error),
  };

  /// Converts a [DioException] into an [ApiError].
  factory ApiError.fromDioException(DioException exception) {
    final inner = exception.error;
    if (inner is ApiError) return inner;

    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiError(code: ApiErrorCode.timeout, cause: exception);
      case DioExceptionType.cancel:
        return ApiError(code: ApiErrorCode.cancelled, cause: exception);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return ApiError(code: ApiErrorCode.network, cause: exception);
      case DioExceptionType.badResponse:
        final response = exception.response;
        final status = response?.statusCode;
        return ApiError.tryParseEnvelope(
              response?.data,
              statusCode: status,
              cause: exception,
            ) ??
            ApiError(
              code: _codeForStatus(status),
              statusCode: status,
              cause: exception,
            );
      case DioExceptionType.unknown:
        final isNetwork = inner is SocketException || inner is HttpException;
        return ApiError(
          code: isNetwork ? ApiErrorCode.network : ApiErrorCode.unknown,
          cause: exception,
        );
    }
  }

  /// Parses an error envelope from a response body (a decoded JSON map or a
  /// JSON string). Returns null when [body] is not an envelope, for example
  /// an HTML error page.
  static ApiError? tryParseEnvelope(
    Object? body, {
    int? statusCode,
    Object? cause,
  }) {
    var decoded = body;
    if (decoded is String) {
      try {
        decoded = jsonDecode(decoded);
      } on FormatException {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final error = decoded['error'];
    if (error is! Map) return null;
    final rawCode = error['code'];
    if (rawCode is! String || rawCode.isEmpty) return null;

    final message = error['message'];
    final details = error['details'];
    return ApiError(
      code: ApiErrorCode.fromWire(rawCode),
      rawCode: rawCode,
      serverMessage: message is String ? message : null,
      details: details is Map
          ? {for (final e in details.entries) e.key.toString(): e.value}
          : const {},
      statusCode: statusCode,
      cause: cause,
    );
  }

  static ApiErrorCode _codeForStatus(int? status) => switch (status) {
    401 => ApiErrorCode.authRequired,
    403 => ApiErrorCode.permissionDenied,
    404 => ApiErrorCode.notFound,
    426 => ApiErrorCode.appUpdateRequired,
    429 => ApiErrorCode.rateLimited,
    final s? when s >= 500 => ApiErrorCode.serverError,
    _ => ApiErrorCode.unknown,
  };

  final ApiErrorCode code;

  /// The code string as sent by the server (useful for logs when [code] is
  /// [ApiErrorCode.unknown]). Null for client-side failures.
  final String? rawCode;

  /// The server's English message. For logs only; never shown to users.
  final String? serverMessage;

  /// `details` from the envelope, e.g. field errors for `VALIDATION_ERROR`
  /// or `items` for `STOCK_UNAVAILABLE`.
  final Map<String, Object?> details;

  final int? statusCode;

  /// The underlying exception, for logging and crash reports.
  final Object? cause;

  /// `details.attempts_remaining` (sent with `OTP_INVALID`), if present.
  int? get attemptsRemaining => _intDetail('attempts_remaining');

  /// `details.retry_after_seconds` (sent with `OTP_RATE_LIMITED` and
  /// `RATE_LIMITED`), if present.
  int? get retryAfterSeconds => _intDetail('retry_after_seconds');

  int? _intDetail(String key) {
    final value = details[key];
    return value is num ? value.toInt() : null;
  }

  /// Field errors for `VALIDATION_ERROR`, normalised to lists of strings.
  /// The backend may send either a string or a list of strings per field.
  Map<String, List<String>> get fieldErrors => {
    for (final entry in details.entries)
      if (entry.value is String)
        entry.key: [entry.value! as String]
      else if (entry.value is List)
        entry.key: [for (final v in entry.value! as List) v.toString()],
  };

  @override
  String toString() =>
      'ApiError(${rawCode ?? code.name}${statusCode == null ? '' : ', HTTP $statusCode'})';
}
