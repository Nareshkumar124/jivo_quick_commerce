import 'package:dio/dio.dart';
// jivo_api also exports a generated `ApiError` model; jivo_core uses its own.
import 'package:jivo_api/jivo_api.dart' show JivoApi, TokenRefreshRequest;

import '../env/app_env.dart';
import '../errors/api_error.dart';
import '../network/client_info.dart';
import '../network/jivo_dio.dart';
import 'token_store.dart';

/// Exchanges a refresh token for a new pair (`POST /api/v1/auth/token/refresh/`).
abstract interface class TokenRefresher {
  /// Returns the rotated pair. Throws [ApiError]: 401 `TOKEN_INVALID` means
  /// the session is over; anything else (network, 5xx) is a transient failure.
  Future<AuthTokens> refresh(String refreshToken);
}

/// Calls the refresh endpoint through the generated client on a **dedicated**
/// Dio that has the client-info headers but no auth interceptor, so the
/// refresh request never carries `Authorization` and can't recurse into the
/// 401 handling.
class ApiTokenRefresher implements TokenRefresher {
  ApiTokenRefresher(this._api);

  /// Builds the dedicated Dio from the app's env and client info.
  /// [httpClientAdapter] replaces the network layer in tests; [logRequests]
  /// is passed to `createJivoDio`.
  factory ApiTokenRefresher.forEnv({
    required AppEnv env,
    required ClientInfo clientInfo,
    HttpClientAdapter? httpClientAdapter,
    bool? logRequests,
  }) => ApiTokenRefresher(
    JivoApi(
      dio: createJivoDio(
        env: env,
        clientInfo: clientInfo,
        httpClientAdapter: httpClientAdapter,
        logRequests: logRequests,
      ),
      interceptors: const [],
    ),
  );

  final JivoApi _api;

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await _api.getAuthApi().authTokenRefresh(
        tokenRefreshRequest: TokenRefreshRequest(refresh: refreshToken),
      );
      final pair = response.data;
      if (pair == null) {
        throw const ApiError(code: ApiErrorCode.unknown);
      }
      return AuthTokens(access: pair.access, refresh: pair.refresh);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}
