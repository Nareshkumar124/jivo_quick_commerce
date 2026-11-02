import 'dart:async';

import 'package:dio/dio.dart';

import 'client_info.dart';

/// Builds extra headers for one request at send time.
///
/// Return an empty map to add nothing. Used for context that changes while
/// the app runs, such as `X-Store-Id` once the serviceable store is known.
typedef RequestHeadersBuilder = FutureOr<Map<String, String>> Function(
  RequestOptions options,
);

/// Adds `X-App-Name`, `X-App-Version` and `X-Platform` to every request.
class ClientInfoInterceptor extends Interceptor {
  ClientInfoInterceptor(this.clientInfo);

  final ClientInfo clientInfo;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll(clientInfo.headers);
    handler.next(options);
  }
}

/// Adds the headers returned by [builder] to every request.
///
/// A header that the request already sets (for example a generated API call
/// that takes `X-Store-Id` as a parameter) is left unchanged.
class DynamicHeadersInterceptor extends Interceptor {
  DynamicHeadersInterceptor(this.builder);

  final RequestHeadersBuilder builder;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final Map<String, String> extra;
    try {
      extra = await builder(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'Building request headers failed',
        ),
      );
      return;
    }
    final existing = options.headers.keys.map((k) => k.toLowerCase()).toSet();
    for (final entry in extra.entries) {
      if (!existing.contains(entry.key.toLowerCase())) {
        options.headers[entry.key] = entry.value;
      }
    }
    handler.next(options);
  }
}
