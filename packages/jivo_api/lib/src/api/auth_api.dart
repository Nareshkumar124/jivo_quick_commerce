// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';

import 'package:jivo_api/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:jivo_api/src/model/auth_session.dart';
import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/logout_request.dart';
import 'package:jivo_api/src/model/otp_send_request.dart';
import 'package:jivo_api/src/model/otp_sent.dart';
import 'package:jivo_api/src/model/otp_verify_request.dart';
import 'package:jivo_api/src/model/token_pair.dart';
import 'package:jivo_api/src/model/token_refresh_request.dart';

class AuthApi {
  final Dio _dio;

  const AuthApi(this._dio);

  /// Log out this device
  /// Revokes &#x60;refresh&#x60; and, when &#x60;fcm_token&#x60; is sent, deactivates that device so it gets no more pushes. Idempotent: always 204 for a signed-in caller, even if the refresh token is already revoked, expired or not the caller&#39;s (then nothing happens).
  ///
  /// Parameters:
  /// * [logoutRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future]
  /// Throws [DioException] if API call or serialization fails
  Future<Response<void>> authLogout({
    required LogoutRequest logoutRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/auth/logout/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'jwtAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(logoutRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    return _response;
  }

  /// Send an OTP by SMS
  /// Sends a 6-digit OTP to &#x60;phone&#x60; for &#x60;app&#x60;. The response is the same whether or not the phone has an account (no account enumeration). With &#x60;purpose: delete_account&#x60; the OTP can only be used on &#x60;POST /me/delete/&#x60;; no SMS is sent if the phone has no account, but the response is identical.  Fixed-OTP test numbers exist only outside production (D-15).
  ///
  /// Parameters:
  /// * [otpSendRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [OtpSent] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<OtpSent>> authOtpRequest({
    required OtpSendRequest otpSendRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/auth/otp/request/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(otpSendRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    OtpSent? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<OtpSent, OtpSent>(rawData, 'OtpSent', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<OtpSent>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Verify the OTP and sign in
  /// Verifies a &#x60;login&#x60; OTP for &#x60;phone&#x60; + &#x60;app&#x60; and returns a token pair. Any phone can sign in on either app; a new phone creates the account (&#x60;is_new_user: true&#x60;).  - Up to 5 attempts per OTP. A wrong code returns &#x60;OTP_INVALID&#x60; with &#x60;details.attempts_remaining&#x60;; after the last attempt, or once expired (5 minutes) or used, the OTP returns &#x60;OTP_EXPIRED&#x60;: request a new one. - A &#x60;delete_account&#x60; OTP never signs anyone in. - Logging in during the 30-day deletion grace period restores the account (&#x60;deletion_cancelled: true&#x60;). - &#x60;terms_version&#x60; is recorded with the time as the user&#39;s consent (DPDP). - A deactivated account gets 403 &#x60;PERMISSION_DENIED&#x60;.
  ///
  /// Parameters:
  /// * [otpVerifyRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [AuthSession] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<AuthSession>> authOtpVerify({
    required OtpVerifyRequest otpVerifyRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/auth/otp/verify/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(otpVerifyRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    AuthSession? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<AuthSession, AuthSession>(
              rawData,
              'AuthSession',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<AuthSession>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Rotate the refresh token
  /// Returns a new access token **and a new refresh token**. The refresh token sent is revoked, so it works exactly once: run refreshes single-flight (one at a time), and replace both stored tokens.  Only 401 &#x60;TOKEN_INVALID&#x60; means the session is over (log out). This endpoint is exempt from 426 &#x60;APP_UPDATE_REQUIRED&#x60; and 503 &#x60;MAINTENANCE&#x60;, so a session survives maintenance and force updates.
  ///
  /// Parameters:
  /// * [tokenRefreshRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [TokenPair] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<TokenPair>> authTokenRefresh({
    required TokenRefreshRequest tokenRefreshRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/auth/token/refresh/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(tokenRefreshRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    TokenPair? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<TokenPair, TokenPair>(
              rawData,
              'TokenPair',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<TokenPair>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }
}
