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
import 'package:jivo_api/src/model/order.dart';
import 'package:jivo_api/src/model/payment_verify_request.dart';
import 'package:jivo_api/src/model/razorpay_webhook_event_request.dart';
import 'package:jivo_api/src/model/webhook_ack.dart';

class PaymentsApi {
  final Dio _dio;

  const PaymentsApi(this._dio);

  /// Confirm an online payment
  /// Call it with the fields of Razorpay checkout&#39;s success callback. The server checks the signature (and that the Razorpay order is this order&#39;s) and moves the order from PAYMENT_PENDING to PLACED (08 T3): the stock stays reserved, the coupon is used and the cart is emptied. Then show the success screen with the returned order.  Idempotent (no &#x60;Idempotency-Key&#x60; needed): calling again, or after the webhook already confirmed the payment, returns the PLACED order. If the response is lost, call it again. On a checkout failure or dismissal do **not** call it: show &#39;Payment failed&#39; with Retry (&#x60;POST /orders/{id}/retry-payment/&#x60;).  If the order already failed or was cancelled (&#x60;INVALID_STATE_TRANSITION&#x60;), it is not revived: a payment captured anyway is refunded in full automatically (08 T3a).
  ///
  /// Parameters:
  /// * [paymentVerifyRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Order] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Order>> paymentsRazorpayVerify({
    required PaymentVerifyRequest paymentVerifyRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/payments/razorpay/verify/';
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
      _bodyData = jsonEncode(paymentVerifyRequest);
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

    Order? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Order, Order>(rawData, 'Order', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Order>(
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

  /// Razorpay webhook (server to server)
  /// Configured in the Razorpay dashboard for &#x60;payment.captured&#x60;, &#x60;payment.failed&#x60;, &#x60;refund.processed&#x60; and &#x60;refund.failed&#x60;. **Not for the apps.**  &#x60;X-Razorpay-Signature&#x60; must be the hex HMAC-SHA256 of the exact raw body bytes, keyed with the webhook secret; anything else is a 400 and nothing is stored. Events are processed once per &#x60;X-Razorpay-Event-Id&#x60; (a repeat answers &#x60;duplicate&#x60;) and in any order relative to verify (08 §4). Unhandled event types answer &#x60;ignored&#x60;. A 2xx tells Razorpay not to retry; a 503 asks it to.
  ///
  /// Parameters:
  /// * [xRazorpayEventId] - Unique per event: the idempotency key.
  /// * [xRazorpaySignature] - Hex HMAC-SHA256 of the raw body, keyed with the webhook secret.
  /// * [razorpayWebhookEventRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [WebhookAck] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<WebhookAck>> paymentsRazorpayWebhook({
    required String xRazorpayEventId,
    required String xRazorpaySignature,
    required RazorpayWebhookEventRequest razorpayWebhookEventRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/payments/razorpay/webhook/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'X-Razorpay-Event-Id': xRazorpayEventId,
        r'X-Razorpay-Signature': xRazorpaySignature,
        ...?headers,
      },
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(razorpayWebhookEventRequest);
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

    WebhookAck? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<WebhookAck, WebhookAck>(
              rawData,
              'WebhookAck',
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

    return Response<WebhookAck>(
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
