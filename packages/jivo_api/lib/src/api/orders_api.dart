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
import 'package:jivo_api/src/model/order_cancel_request.dart';
import 'package:jivo_api/src/model/order_create_request.dart';
import 'package:jivo_api/src/model/order_placement.dart';
import 'package:jivo_api/src/model/paginated_order_summary_list.dart';

class OrdersApi {
  final Dio _dio;

  const OrdersApi(this._dio);

  /// Cancel my order
  /// 08 §7. **Phase 3:** only an order in PAYMENT_PENDING (T5, e.g. the customer gives up on paying or wants to pay another way): the stock and the coupon hold are released; the cart is still there. **From Phase 4:** also PLACED and ACCEPTED (T11, with a refund for paid orders). Use &#x60;can_cancel&#x60; to show the button.
  ///
  /// Parameters:
  /// * [id] - `Order.id`.
  /// * [orderCancelRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Order] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Order>> ordersCancel({
    required int id,
    required OrderCancelRequest orderCancelRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/orders/{id}/cancel/'.replaceAll(
      '{'
      r'id'
      '}',
      id.toString(),
    );
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
      _bodyData = jsonEncode(orderCancelRequest);
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

  /// Place an order from the cart
  /// Places the cart as an order at the store in &#x60;X-Store-Id&#x60; (08 T1/T2). Stock is reserved now, never earlier (08 §6.1). The server re-checks everything: the address is served by the store, the store is open, every line is available (else 409 &#x60;STOCK_UNAVAILABLE&#x60;), the minimum order, the coupon, and that its bill equals &#x60;expected_grand_total&#x60; (else 409 &#x60;PRICE_CHANGED&#x60;: reload the cart).  **COD:** the order is PLACED at once (&#x60;razorpay&#x60; is null) and the cart is emptied. COD needs the store to offer it and &#x60;grand_total&#x60; within its limit.  **ONLINE:** the order is PAYMENT_PENDING for the payment window (15 minutes); the stock and the coupon are held. Open Razorpay checkout with &#x60;razorpay&#x60;, then call &#x60;POST /payments/razorpay/verify/&#x60;. The cart is emptied only when the payment is confirmed; if it never is, the order fails, the stock is released and the cart is still there to try again.  Send the same &#x60;Idempotency-Key&#x60; when retrying a request whose response was lost: the first order is returned (200) and nothing is placed twice. Disable the button while a request is in flight.
  ///
  /// Parameters:
  /// * [idempotencyKey] - One key per attempt (a UUID v4 is recommended), 8-64 letters, digits, `-` or `_`. Send the **same** key again when retrying after a timeout or a lost response: the original result is returned and nothing is done twice. Only a successful result is remembered, so a failed attempt may be retried with the same key. The same key with a different body is a 400. Missing or malformed: 400 `VALIDATION_ERROR` with `details: {\"Idempotency-Key\": [...]}`.
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [orderCreateRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [OrderPlacement] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<OrderPlacement>> ordersCreate({
    required String idempotencyKey,
    required int xStoreId,
    required OrderCreateRequest orderCreateRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/orders/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
        r'X-Store-Id': xStoreId,
        ...?headers,
      },
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
      _bodyData = jsonEncode(orderCreateRequest);
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

    OrderPlacement? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<OrderPlacement, OrderPlacement>(
              rawData,
              'OrderPlacement',
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

    return Response<OrderPlacement>(
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

  /// My orders
  /// The caller&#39;s orders, newest first; without &#x60;status&#x60;, active orders come first. On app launch, &#x60;?status&#x3D;active&#x60; finds an order still in PAYMENT_PENDING (the app was closed during payment): show its server status and offer Retry while &#x60;can_retry_payment&#x60; is true (03 §2.9).
  ///
  /// Parameters:
  /// * [page] - Page number (1-based). Default 1.
  /// * [pageSize] - Items per page: default 20, max 100.
  /// * [status] - `active`: not finished yet, including PAYMENT_PENDING (to recover a payment after the app was closed). `past`: DELIVERED, CANCELLED, PAYMENT_FAILED, RETURNED. Omit for all orders, active first.  * `active` - Active (not finished yet) * `past` - Past (delivered, cancelled, failed or returned)
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [PaginatedOrderSummaryList] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<PaginatedOrderSummaryList>> ordersList({
    int? page,
    int? pageSize,
    String? status,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/orders/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'jwtAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (page != null) r'page': page,
      if (pageSize != null) r'page_size': pageSize,
      if (status != null) r'status': status,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    PaginatedOrderSummaryList? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<PaginatedOrderSummaryList, PaginatedOrderSummaryList>(
              rawData,
              'PaginatedOrderSummaryList',
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

    return Response<PaginatedOrderSummaryList>(
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

  /// One of my orders
  /// The order with its bill, items and state (added to Phase 3, PM decision): poll it after checkout while the payment is being confirmed (e.g. verify&#39;s response was lost), and for the success screen. Another user&#39;s order id is a 404. Phase 4 adds the status timeline and invoice to the same shape.
  ///
  /// Parameters:
  /// * [id] - `Order.id`.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Order] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Order>> ordersRetrieve({
    required int id,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/orders/{id}/'.replaceAll(
      '{'
      r'id'
      '}',
      id.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'jwtAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
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

  /// Retry the online payment
  /// For an ONLINE order in PAYMENT_PENDING before &#x60;payment_expires_at&#x60; (the &#39;Payment failed&#39; screen&#39;s Retry, 03 §2.9): creates a new Razorpay order for the same amount and returns new checkout options. The payment window is **not** extended. To pay another way, cancel the order (&#x60;POST /orders/{id}/cancel/&#x60;) and place a new one: the cart is still there.
  ///
  /// Parameters:
  /// * [idempotencyKey] - One key per attempt (a UUID v4 is recommended), 8-64 letters, digits, `-` or `_`. Send the **same** key again when retrying after a timeout or a lost response: the original result is returned and nothing is done twice. Only a successful result is remembered, so a failed attempt may be retried with the same key. The same key with a different body is a 400. Missing or malformed: 400 `VALIDATION_ERROR` with `details: {\"Idempotency-Key\": [...]}`.
  /// * [id] - `Order.id`.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [OrderPlacement] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<OrderPlacement>> ordersRetryPayment({
    required String idempotencyKey,
    required int id,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/orders/{id}/retry-payment/'.replaceAll(
      '{'
      r'id'
      '}',
      id.toString(),
    );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'jwtAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    OrderPlacement? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<OrderPlacement, OrderPlacement>(
              rawData,
              'OrderPlacement',
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

    return Response<OrderPlacement>(
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
