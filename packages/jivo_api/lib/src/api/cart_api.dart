// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';

import 'package:jivo_api/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:jivo_api/src/model/cart.dart';
import 'package:jivo_api/src/model/cart_item_add_request.dart';
import 'package:jivo_api/src/model/cart_item_update_request.dart';
import 'package:jivo_api/src/model/coupon_apply_request.dart';
import 'package:jivo_api/src/model/coupon_list.dart';
import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/patched_cart_update_request.dart';

class CartApi {
  final Dio _dio;

  const CartApi(this._dio);

  /// Empty the cart
  /// Removes every line, the coupon and the tip. The address and instructions are kept. Idempotent.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartClear({
    required int xStoreId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/';
    final _options = Options(
      method: r'DELETE',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Apply a coupon
  /// Applies &#x60;code&#x60; (case-insensitive) and replaces any coupon already applied. The discount is on the item total (or on the qualifying items for a category coupon), capped by &#x60;max_discount&#x60; and by the item total. Applying does not use the coupon up: an order does (held while its payment is pending).
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [couponApplyRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartCouponApply({
    required int xStoreId,
    required CouponApplyRequest couponApplyRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/coupon/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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
      _bodyData = jsonEncode(couponApplyRequest);
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Remove the coupon
  /// Idempotent: removing when there is none returns the cart unchanged.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartCouponRemove({
    required int xStoreId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/coupon/';
    final _options = Options(
      method: r'DELETE',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Coupons for my cart
  /// The &#39;Apply coupon&#39; sheet (03 §2.8): visible coupons valid at this store now, each with whether it applies to this cart, what it would save, and why not.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CouponList] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CouponList>> cartCouponsList({
    required int xStoreId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/coupons/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    CouponList? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CouponList, CouponList>(
              rawData,
              'CouponList',
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

    return Response<CouponList>(
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

  /// Set a variant&#39;s quantity (the ADD stepper)
  /// Sets the line for &#x60;variant_id&#x60; to &#x60;quantity&#x60;: creates it, changes it, or removes it with 0. It sets, it does not add, so a retried request never doubles a line.  An increase is checked against the store&#39;s stock and the variant&#39;s &#x60;max_qty_per_order&#x60;; a decrease is always accepted, so a customer can step down a line that has a stock issue. The cart does not reserve stock (08 §6.1).
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [cartItemAddRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartItemsAdd({
    required int xStoreId,
    required CartItemAddRequest cartItemAddRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/items/';
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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
      _bodyData = jsonEncode(cartItemAddRequest);
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Remove a line
  /// Another user&#39;s line id is a 404.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [id] - Cart line `id`.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartItemsDelete({
    required int xStoreId,
    required int id,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/items/{id}/'.replaceAll(
      '{'
      r'id'
      '}',
      id.toString(),
    );
    final _options = Options(
      method: r'DELETE',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Change a line&#39;s quantity
  /// Same rules as &#x60;cart_items_add&#x60; (increases are checked, decreases always accepted). Another user&#39;s line id is a 404.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [id] - Cart line `id`.
  /// * [cartItemUpdateRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartItemsUpdate({
    required int xStoreId,
    required int id,
    required CartItemUpdateRequest cartItemUpdateRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/items/{id}/'.replaceAll(
      '{'
      r'id'
      '}',
      id.toString(),
    );
    final _options = Options(
      method: r'PATCH',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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
      _bodyData = jsonEncode(cartItemUpdateRequest);
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// My cart with its bill
  /// The cart priced at the store in &#x60;X-Store-Id&#x60;, with stock flags on each line, the full bill (08 §6.2), how far it is from the minimum order and free delivery, which payment methods are available and what (if anything) blocks checkout.  Reload it when the cart screen opens and before checkout (03 §2.8): prices and stock are re-checked on every read. A user with no cart gets an empty one.  &#x60;?address_id&#x3D;&#x60; checks the cart against another saved address without saving it.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [addressId] - Check the cart against this saved address (not saved to the cart). Default: the cart's address. Unknown or another user's address: 400.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartRetrieve({
    required int xStoreId,
    int? addressId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'jwtAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (addressId != null) r'address_id': addressId,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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

  /// Set the tip, delivery instructions or address
  /// Partial update: send only what changes. &#x60;instructions&#x60; replaces the chips and note as a whole. &#x60;address_id&#x60; must be inside the service area of the store in &#x60;X-Store-Id&#x60; (else 422 &#x60;NOT_SERVICEABLE&#x60;, nothing saved). The tip is kept while the cart is empty but billed only with items.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [patchedCartUpdateRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [Cart] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<Cart>> cartUpdate({
    required int xStoreId,
    PatchedCartUpdateRequest? patchedCartUpdateRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/cart/';
    final _options = Options(
      method: r'PATCH',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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
      _bodyData = jsonEncode(patchedCartUpdateRequest);
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

    Cart? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<Cart, Cart>(rawData, 'Cart', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<Cart>(
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
