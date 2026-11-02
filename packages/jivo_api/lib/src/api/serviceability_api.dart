// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';

import 'package:jivo_api/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/notify_me.dart';
import 'package:jivo_api/src/model/notify_me_request.dart';
import 'package:jivo_api/src/model/serviceability.dart';

class ServiceabilityApi {
  final Dio _dio;

  const ServiceabilityApi(this._dio);

  /// Is this location serviceable, and by which store?
  /// Call it after the user picks a location (GPS or map pin), on app start for the selected address, and on pull-to-refresh. Save &#x60;store.id&#x60; and send it as &#x60;X-Store-Id&#x60; on catalog calls.  A valid point **always answers 200**: not serviceable is &#x60;serviceable: false&#x60; with &#x60;store: null&#x60;, and a closed store is &#x60;serviceable: true&#x60; with &#x60;store.is_open: false&#x60; (browsing allowed, checkout disabled). This endpoint never returns &#x60;NOT_SERVICEABLE&#x60; or &#x60;STORE_CLOSED&#x60;; those are 422 errors of the actions that need an open store (cart address and order placement, Phase 3).  When service areas overlap, the nearest open store is chosen (07 §2.2). &#x60;eta_minutes&#x60; follows 08 §8.
  ///
  /// Parameters:
  /// * [lat] - Latitude (WGS84, decimal degrees).
  /// * [lng] - Longitude (WGS84, decimal degrees).
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Serviceability] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Serviceability>> serviceabilityCheck({
    required double lat,
    required double lng,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/serviceability/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{r'lat': lat, r'lng': lng};

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    Serviceability? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Serviceability, Serviceability>(
              rawData,
              'Serviceability',
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

    return Response<Serviceability>(
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

  /// Notify me when you deliver here
  /// Saves interest in an unserviced location (the &#39;Notify me&#39; button on the not serviceable screen). Works signed in or anonymous: send the token when signed in, so the request is linked to the user and &#x60;phone&#x60; defaults to theirs.  Always 201 for a valid request; repeating it is harmless (the server may merge duplicates). Rate-limited per user and IP (429 &#x60;RATE_LIMITED&#x60;).
  ///
  /// Parameters:
  /// * [notifyMeRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [NotifyMe] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<NotifyMe>> serviceabilityNotifyMe({
    required NotifyMeRequest notifyMeRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/serviceability/notify-me/';
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
      _bodyData = jsonEncode(notifyMeRequest);
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

    NotifyMe? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<NotifyMe, NotifyMe>(
              rawData,
              'NotifyMe',
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

    return Response<NotifyMe>(
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
