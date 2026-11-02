import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../env/app_env.dart';
import 'client_info.dart';
import 'interceptors.dart';

/// An interceptor that needs the Dio it is installed on, e.g. to retry a
/// request. [createJivoDio] calls [attach] for each one in `interceptors`;
/// with a hand-built Dio, call it yourself.
abstract interface class DioAttachable {
  void attach(Dio dio);
}

/// Creates the Dio instance an app uses for every backend call, including
/// the generated `jivo_api` client (`JivoApi(dio: dio, interceptors: const [])`).
///
/// Interceptor order:
/// 1. [ClientInfoInterceptor]: `X-App-Name`, `X-App-Version`, `X-Platform`.
/// 2. [DynamicHeadersInterceptor], when [dynamicHeaders] is given. This is the
///    hook for `X-Store-Id` (Phase 2).
/// 3. [interceptors], in order: typically `AuthInterceptor` then
///    `AppControlInterceptor`. Those implementing [DioAttachable] are
///    attached to the returned Dio.
/// 4. A request logger, when [logRequests] is true. It defaults to on for
///    debug builds of non-prod flavors and never logs headers or bodies.
///
/// [httpClientAdapter] replaces the network layer; tests use it.
Dio createJivoDio({
  required AppEnv env,
  required ClientInfo clientInfo,
  RequestHeadersBuilder? dynamicHeaders,
  List<Interceptor> interceptors = const [],
  bool? logRequests,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration receiveTimeout = const Duration(seconds: 20),
  HttpClientAdapter? httpClientAdapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl.toString(),
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );
  if (httpClientAdapter != null) {
    dio.httpClientAdapter = httpClientAdapter;
  }

  dio.interceptors.add(ClientInfoInterceptor(clientInfo));
  if (dynamicHeaders != null) {
    dio.interceptors.add(DynamicHeadersInterceptor(dynamicHeaders));
  }
  dio.interceptors.addAll(interceptors);
  for (final interceptor in interceptors) {
    if (interceptor is DioAttachable) {
      (interceptor as DioAttachable).attach(dio);
    }
  }
  if (logRequests ?? (kDebugMode && !env.isProd)) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        logPrint: (line) => debugPrint('[api] $line'),
      ),
    );
  }
  return dio;
}
