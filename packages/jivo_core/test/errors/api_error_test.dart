import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../support/capture_adapter.dart';

/// Every code in `06 §6` and the backend's OpenAPI `ErrorCodeEnum`.
const backendCodes = [
  'VALIDATION_ERROR',
  'OTP_INVALID',
  'OTP_EXPIRED',
  'OTP_RATE_LIMITED',
  'AUTH_REQUIRED',
  'TOKEN_INVALID',
  'PERMISSION_DENIED',
  'NOT_FOUND',
  'APP_UPDATE_REQUIRED',
  'NOT_SERVICEABLE',
  'STORE_CLOSED',
  'STOCK_UNAVAILABLE',
  'MAX_QTY_EXCEEDED',
  'MIN_ORDER_NOT_MET',
  'COUPON_INVALID',
  'COUPON_EXPIRED',
  'COUPON_NOT_ELIGIBLE',
  'COUPON_USAGE_EXCEEDED',
  'COD_NOT_AVAILABLE',
  'PRICE_CHANGED',
  'PAYMENT_VERIFICATION_FAILED',
  'INVALID_STATE_TRANSITION',
  'OFFER_EXPIRED',
  'OFFER_TAKEN',
  'OUTSIDE_GEOFENCE',
  'DELIVERY_OTP_INVALID',
  'DELIVERY_OTP_LOCKED',
  'CASH_LIMIT_EXCEEDED',
  'MAINTENANCE',
  // In the OpenAPI ErrorCodeEnum, not in 06 §6.
  'METHOD_NOT_ALLOWED',
  'NOT_ACCEPTABLE',
  'UNSUPPORTED_MEDIA_TYPE',
  'RATE_LIMITED',
  'SERVER_ERROR',
  'SERVICE_UNAVAILABLE',
];

Future<ApiError> errorFor(CaptureAdapter adapter) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))
    ..httpClientAdapter = adapter;
  try {
    await dio.get<Object?>('/x');
  } on DioException catch (e) {
    return ApiError.fromDioException(e);
  }
  fail('expected the request to fail');
}

void main() {
  test('every backend code in 06 §6 maps to its own ApiErrorCode', () {
    final mapped = {for (final c in backendCodes) ApiErrorCode.fromWire(c)};

    expect(mapped, hasLength(backendCodes.length));
    expect(mapped, isNot(contains(ApiErrorCode.unknown)));
    for (final c in backendCodes) {
      expect(ApiErrorCode.fromWire(c).wireValue, c);
    }
  });

  test('unknown and missing codes map to unknown', () {
    expect(ApiErrorCode.fromWire('SOMETHING_NEW'), ApiErrorCode.unknown);
    expect(ApiErrorCode.fromWire(null), ApiErrorCode.unknown);
  });

  group('envelope parsing from a response', () {
    test('reads code, message, details and status', () async {
      final error = await errorFor(
        CaptureAdapter(
          status: 409,
          body: {
            'error': {
              'code': 'STOCK_UNAVAILABLE',
              'message': 'Some items are unavailable',
              'details': {
                'items': [
                  {'variant_id': 7, 'available_qty': 1},
                ],
              },
            },
          },
        ),
      );

      expect(error.code, ApiErrorCode.stockUnavailable);
      expect(error.rawCode, 'STOCK_UNAVAILABLE');
      expect(error.serverMessage, 'Some items are unavailable');
      expect(error.statusCode, 409);
      expect(error.details['items'], isA<List<Object?>>());
    });

    test('keeps an unrecognised code for logging', () async {
      final error = await errorFor(
        CaptureAdapter(
          status: 422,
          body: {
            'error': {'code': 'BRAND_NEW_CODE', 'message': 'x'},
          },
        ),
      );

      expect(error.code, ApiErrorCode.unknown);
      expect(error.rawCode, 'BRAND_NEW_CODE');
      expect(error.details, isEmpty);
    });

    test('validation details may hold strings or lists', () {
      final error = ApiError.tryParseEnvelope({
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'Invalid input',
          'details': {
            'phone': ['Enter a valid phone number.'],
            'pincode': 'Required.',
          },
        },
      })!;

      expect(error.fieldErrors, {
        'phone': ['Enter a valid phone number.'],
        'pincode': ['Required.'],
      });
    });

    test('accepts a JSON string body', () {
      final error = ApiError.tryParseEnvelope(
        '{"error": {"code": "NOT_FOUND", "message": "Not found."}}',
        statusCode: 404,
      );

      expect(error?.code, ApiErrorCode.notFound);
    });

    test('returns null for bodies that are not envelopes', () {
      expect(ApiError.tryParseEnvelope('<html>502 Bad Gateway</html>'), isNull);
      expect(ApiError.tryParseEnvelope({'detail': 'Not found.'}), isNull);
      expect(ApiError.tryParseEnvelope({'error': 'oops'}), isNull);
      expect(ApiError.tryParseEnvelope(null), isNull);
    });
  });

  group('responses without an envelope', () {
    test('an HTML 502 from a proxy is a server error', () async {
      final error = await errorFor(
        CaptureAdapter(status: 502, body: '<html>Bad Gateway</html>'),
      );

      expect(error.code, ApiErrorCode.serverError);
      expect(error.statusCode, 502);
    });

    test('426 without an envelope is still app-update-required', () async {
      final error = await errorFor(CaptureAdapter(status: 426, body: ''));

      expect(error.code, ApiErrorCode.appUpdateRequired);
    });

    test('other statuses fall back by HTTP status', () async {
      expect(
        (await errorFor(CaptureAdapter(status: 401, body: ''))).code,
        ApiErrorCode.authRequired,
      );
      expect(
        (await errorFor(CaptureAdapter(status: 403, body: ''))).code,
        ApiErrorCode.permissionDenied,
      );
      expect(
        (await errorFor(CaptureAdapter(status: 404, body: ''))).code,
        ApiErrorCode.notFound,
      );
      expect(
        (await errorFor(CaptureAdapter(status: 429, body: ''))).code,
        ApiErrorCode.rateLimited,
      );
      expect(
        (await errorFor(CaptureAdapter(status: 418, body: ''))).code,
        ApiErrorCode.unknown,
      );
    });
  });

  group('transport failures', () {
    RequestOptions options() => RequestOptions(path: '/x');

    test('timeouts', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          ApiError.fromDioException(
            DioException(requestOptions: options(), type: type),
          ).code,
          ApiErrorCode.timeout,
        );
      }
    });

    test('connection errors and socket failures are network errors', () async {
      expect(
        ApiError.fromDioException(
          DioException.connectionError(
            requestOptions: options(),
            reason: 'refused',
          ),
        ).code,
        ApiErrorCode.network,
      );
      final viaAdapter = await errorFor(
        CaptureAdapter(error: const SocketException('Failed host lookup')),
      );
      expect(viaAdapter.code, ApiErrorCode.network);
    });

    test('cancellation', () {
      expect(
        ApiError.fromDioException(
          DioException(
            requestOptions: options(),
            type: DioExceptionType.cancel,
          ),
        ).code,
        ApiErrorCode.cancelled,
      );
    });
  });

  group('ApiError.from', () {
    test('passes an ApiError through and wraps anything else', () {
      const original = ApiError(code: ApiErrorCode.priceChanged);

      expect(ApiError.from(original), same(original));
      expect(ApiError.from(StateError('boom')).code, ApiErrorCode.unknown);
    });

    test('unwraps an ApiError carried inside a DioException', () {
      const inner = ApiError(code: ApiErrorCode.tokenInvalid);
      final wrapped = DioException(
        requestOptions: RequestOptions(path: '/x'),
        error: inner,
      );

      expect(ApiError.from(wrapped), same(inner));
    });
  });
}
