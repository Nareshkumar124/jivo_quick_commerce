import 'package:dio/dio.dart';

import '../network/jivo_dio.dart';
import 'session_manager.dart';

/// Adds `Authorization: Bearer <access>` and recovers from expired access
/// tokens. Pass it in `createJivoDio(interceptors: [...])`, which attaches it
/// to the Dio it retries on.
///
/// Which requests get the token:
/// - Generated `jivo_api` calls follow the contract: operations whose
///   `security` lists the bearer scheme get it; public ones (OTP, token
///   refresh, `config/app`, health) never do.
/// - Hand-written calls get it only when they opt in with
///   `Options(extra: {AuthInterceptor.requiresAuthKey: true})`.
///
/// On a 401 for a request that carried a token, it asks the [SessionManager]
/// for a refresh (single-flight) and retries the request **once** with the
/// new token. If the refresh token is rejected, the session ends and the
/// original 401 is returned. If the refresh fails for another reason
/// (network, 5xx), the session is kept and the request fails with that error.
class AuthInterceptor extends Interceptor implements DioAttachable {
  AuthInterceptor(this.session);

  final SessionManager session;

  /// Opt-in flag for hand-written requests that need the token.
  static const requiresAuthKey = 'jivo.requiresAuth';

  // Stores the token generation, never the token: Dio's LogInterceptor
  // prints `extra`.
  static const _sentGenerationKey = 'jivo.auth.generation';
  static const _retriedKey = 'jivo.auth.retried';

  Dio? _dio;

  @override
  void attach(Dio dio) => _dio = dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (requiresAuth(options) && session.accessToken != null) {
      // Don't send a token that is being replaced right now.
      await session.refreshDone;
      final token = session.accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_sentGenerationKey] = session.tokenGeneration;
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sentGeneration = options.extra[_sentGenerationKey];
    final dio = _dio;
    if (err.response?.statusCode != 401 ||
        sentGeneration is! int ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    assert(
      dio != null,
      'AuthInterceptor is not attached to a Dio: create the Dio with '
      'createJivoDio(interceptors: [...]) or call attach(dio).',
    );
    if (dio == null) {
      handler.next(err);
      return;
    }

    switch (await session.refreshAfterUnauthorized(sentGeneration)) {
      case RefreshSucceeded():
        try {
          final data = options.data;
          final retry = options.copyWith(
            // A FormData body is consumed by the first send.
            data: data is FormData ? data.clone() : data,
            extra: {...options.extra, _retriedKey: true},
          );
          handler.resolve(await dio.fetch<dynamic>(retry));
        } on DioException catch (retryError) {
          handler.reject(retryError);
        }
      case SessionEnded():
        handler.next(err);
      case RefreshFailed(:final error):
        handler.reject(
          DioException(
            requestOptions: options,
            error: error,
            type: error.cause is DioException
                ? (error.cause! as DioException).type
                : DioExceptionType.unknown,
            message: 'Token refresh failed',
          ),
        );
    }
  }

  /// Whether [options] should carry the access token.
  static bool requiresAuth(RequestOptions options) {
    if (options.extra[requiresAuthKey] == true) return true;
    final secure = options.extra['secure'];
    if (secure is! List) return false;
    return secure.any(
      (entry) =>
          entry is Map &&
          entry['type'] == 'http' &&
          '${entry['scheme']}'.toLowerCase() == 'bearer',
    );
  }
}
