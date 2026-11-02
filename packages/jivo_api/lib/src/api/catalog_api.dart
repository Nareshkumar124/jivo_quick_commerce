// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';

import 'package:jivo_api/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:jivo_api/src/model/category_tree.dart';
import 'package:jivo_api/src/model/collection_detail.dart';
import 'package:jivo_api/src/model/error_envelope.dart';
import 'package:jivo_api/src/model/home_feed.dart';
import 'package:jivo_api/src/model/paginated_product_card_list.dart';
import 'package:jivo_api/src/model/product_detail.dart';
import 'package:jivo_api/src/model/search_suggestions.dart';

class CatalogApi {
  final Dio _dio;

  const CatalogApi(this._dio);

  /// Category tree for a store
  /// Top-level categories and their sub-categories that have products at this store (Categories tab, and the left rail of the product list). Two levels, not paginated.
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
  /// Returns a [Future] containing a [Response] with a [CategoryTree] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CategoryTree>> categoriesList({
    required int xStoreId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/categories/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    CategoryTree? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CategoryTree, CategoryTree>(
              rawData,
              'CategoryTree',
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

    return Response<CategoryTree>(
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

  /// Collection page
  /// A collection (&#39;See all&#39; on a home rail, or a banner link) with its products at this store. 404 &#x60;NOT_FOUND&#x60; when unknown, inactive or not shown at this store.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [slug] - Collection slug, e.g. \"bestsellers\".
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CollectionDetail] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CollectionDetail>> collectionsRetrieve({
    required int xStoreId,
    required String slug,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/collections/{slug}/'.replaceAll(
      '{'
      r'slug'
      '}',
      slug.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    CollectionDetail? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CollectionDetail, CollectionDetail>(
              rawData,
              'CollectionDetail',
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

    return Response<CollectionDetail>(
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

  /// Home feed for a store
  /// Banners, top-level categories, collection rails and, when signed in, &#39;buy again&#39; (03 §2.5), all for the store in &#x60;X-Store-Id&#x60;.  Optional authentication: send the token when signed in so &#x60;buy_again&#x60; is filled. An invalid or expired token gets 401 &#x60;TOKEN_INVALID&#x60; (refresh and retry); it is never silently treated as anonymous.  &#x60;store&#x60; is the store&#39;s current status: show the store-closed banner when &#x60;store.is_open&#x60; is false (browsing stays allowed). Pull to refresh reloads this and re-checks serviceability.
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
  /// Returns a [Future] containing a [Response] with a [HomeFeed] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<HomeFeed>> homeRetrieve({
    required int xStoreId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/home/';
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

    HomeFeed? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<HomeFeed, HomeFeed>(
              rawData,
              'HomeFeed',
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

    return Response<HomeFeed>(
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

  /// Product list (category, collection or all)
  /// Product tiles with their variants, prices and stock at this store, paginated (infinite scroll). Filter by &#x60;category&#x60; (a top-level category includes its sub-categories) and/or &#x60;collection&#x60;; with neither, all products of the store. Products the store does not sell are never listed; out-of-stock ones are listed after in-stock ones, greyed out.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [category] - Category id or slug. A top-level category includes its sub-categories. Unknown or inactive: 404 `NOT_FOUND`.
  /// * [collection] - Collection id or slug. Unknown or inactive: 404 `NOT_FOUND`.
  /// * [page] - Page number (1-based). Default 1.
  /// * [pageSize] - Items per page: default 20, max 100.
  /// * [sort] - relevance (default): admin order (collection order with `collection`). Prices use each product's default variant. In-stock products always come first.  * `relevance` - Relevance (default) * `price_asc` - Price: low to high * `price_desc` - Price: high to low * `discount` - Discount: highest first
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [PaginatedProductCardList] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<PaginatedProductCardList>> productsList({
    required int xStoreId,
    String? category,
    String? collection,
    int? page,
    int? pageSize,
    String? sort = 'relevance',
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/products/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (category != null) r'category': category,
      if (collection != null) r'collection': collection,
      if (page != null) r'page': page,
      if (pageSize != null) r'page_size': pageSize,
      if (sort != null) r'sort': sort,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    PaginatedProductCardList? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<PaginatedProductCardList, PaginatedProductCardList>(
              rawData,
              'PaginatedProductCardList',
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

    return Response<PaginatedProductCardList>(
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

  /// Product detail
  /// All variants this store sells (with price and stock), the gallery per variant, highlights, the label information required by FSSAI and Legal Metrology (09 §4) and similar products. 404 &#x60;NOT_FOUND&#x60; when the product is unknown, inactive, or not sold at this store.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [idOrSlug] - Product id (e.g. \"101\") or slug (e.g. \"jivo-cold-pressed-canola-oil\").
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [ProductDetail] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<ProductDetail>> productsRetrieve({
    required int xStoreId,
    required String idOrSlug,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/products/{id_or_slug}/'.replaceAll(
      '{'
      r'id_or_slug'
      '}',
      idOrSlug.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
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

    ProductDetail? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<ProductDetail, ProductDetail>(
              rawData,
              'ProductDetail',
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

    return Response<ProductDetail>(
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

  /// Search products
  /// Same tiles as the product list, best match first. Matches product name, variant, tags and category. No results: 200 with &#x60;count: 0&#x60;; show the empty state with trending searches from &#x60;GET /search/suggest/&#x60;.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [q] - Search text (trimmed). Matches product name, variant, tags and category.
  /// * [page] - Page number (1-based). Default 1.
  /// * [pageSize] - Items per page: default 20, max 100.
  /// * [sort] - relevance (default): best match first. In-stock products always come first.  * `relevance` - Relevance (default) * `price_asc` - Price: low to high * `price_desc` - Price: high to low * `discount` - Discount: highest first
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [PaginatedProductCardList] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<PaginatedProductCardList>> searchProducts({
    required int xStoreId,
    required String q,
    int? page,
    int? pageSize,
    String? sort = 'relevance',
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/search/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      if (page != null) r'page': page,
      if (pageSize != null) r'page_size': pageSize,
      r'q': q,
      if (sort != null) r'sort': sort,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    PaginatedProductCardList? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<PaginatedProductCardList, PaginatedProductCardList>(
              rawData,
              'PaginatedProductCardList',
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

    return Response<PaginatedProductCardList>(
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

  /// Typeahead suggestions, or trending searches
  /// Call while typing (debounced 300 ms). Up to 10 suggestions: products and categories open directly (&#x60;slug&#x60;), keywords run a search (&#x60;query&#x60;). With a blank or missing &#x60;q&#x60;, returns the trending searches (03 §2.7) as &#x60;keyword&#x60; items. Recent searches are kept on the device.
  ///
  /// Parameters:
  /// * [xStoreId] - The store id from `GET /serviceability/` (`store.id`) for the selected location. Missing or not a positive integer: 400 `VALIDATION_ERROR` with `details: {\"X-Store-Id\": [...]}`. Unknown or deactivated store: 404 `STORE_NOT_FOUND`; drop the saved store and check serviceability again. A closed store is still browsable.
  /// * [q] - Text typed so far (debounce 300 ms). Blank or missing: trending searches.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [SearchSuggestions] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<SearchSuggestions>> searchSuggest({
    required int xStoreId,
    String? q = '',
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/api/v1/search/suggest/';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{r'X-Store-Id': xStoreId, ...?headers},
      extra: <String, dynamic>{'secure': <Map<String, String>>[], ...?extra},
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{if (q != null) r'q': q};

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    SearchSuggestions? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<SearchSuggestions, SearchSuggestions>(
              rawData,
              'SearchSuggestions',
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

    return Response<SearchSuggestions>(
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
