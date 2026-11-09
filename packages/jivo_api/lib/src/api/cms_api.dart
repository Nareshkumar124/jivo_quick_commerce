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
import 'package:jivo_api/src/model/faq.dart';
import 'package:jivo_api/src/model/page.dart';

class CmsApi {
  final Dio _dio;

  const CmsApi(this._dio);

  /// FAQs for an app&#39;s help screen
  /// Public, not paginated. Active FAQs of the app in display order, grouped by &#x60;category&#x60;: entries of one category are consecutive, so start a new heading whenever &#x60;category&#x60; changes. Answers are plain text. Cached for up to 5 minutes.
  ///
  /// Parameters:
  /// * [app] - Which app's help screen: customer or rider.  * `customer` - Customer app * `rider` - Rider app
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [List<Faq>] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<List<Faq>>> faqsList({
    required String app,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/faqs/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{r'app': app};

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    List<Faq>? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<List<Faq>, Faq>(rawData, 'List<Faq>', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<List<Faq>>(
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

  /// Static page (About, Terms, Privacy, Refund policy)
  /// Public. Slugs the apps use: &#x60;about&#x60;, &#x60;terms&#x60;, &#x60;privacy&#x60;, &#x60;refund-policy&#x60; and, in the rider app, &#x60;rider-agreement&#x60; and &#x60;rider-location-disclosure&#x60;. The HTML is sanitised server-side to a small allow-list (see &#x60;html&#x60;). An unknown or unpublished slug is 404 &#x60;NOT_FOUND&#x60;: fall back to the policy URL from &#x60;GET /config/app/&#x60;. Cached for up to 5 minutes.
  ///
  /// Parameters:
  /// * [slug] - `Page.slug`.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Page] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Page>> pagesRetrieve({
    required String slug,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/pages/{slug}/'.replaceAll(
      '{'
      r'slug'
      '}',
      slug.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    Page? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Page, Page>(rawData, 'Page', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Page>(
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
