import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
// jivo_api also exports a generated `ApiError` model; the app uses jivo_core's.
import 'package:jivo_api/jivo_api.dart' show JivoApi;

import '../shared/platform/url_opener.dart';
import '../shared/session/store_synced_token_refresher.dart';

/// The `X-App-Name` this app sends.
const riderAppName = 'rider';

/// The flavor configuration. Overridden in `bootstrap()`.
final appEnvProvider = Provider<AppEnv>(
  (ref) => throw UnimplementedError('appEnvProvider is overridden at startup'),
);

/// The client-info headers (`X-App-Name: rider`, version, platform).
/// Overridden in `bootstrap()`.
final clientInfoProvider = Provider<ClientInfo>(
  (ref) =>
      throw UnimplementedError('clientInfoProvider is overridden at startup'),
);

/// The jivo_core session (secure token storage, single-flight refresh).
/// Created and restored in `bootstrap()` before the first redirect.
final sessionManagerProvider = Provider<SessionManager>(
  (ref) => throw UnimplementedError(
    'sessionManagerProvider is overridden at startup',
  ),
);

/// Force-update and maintenance signals from 426/503 responses (and from
/// `config/app`, reported by the launch controller). Created in `bootstrap()`.
final appControlSignalsProvider = Provider<AppControlSignals>(
  (ref) => throw UnimplementedError(
    'appControlSignalsProvider is overridden at startup',
  ),
);

/// The token store shared with the location service isolate (see
/// `GuardedTokenStore`). Null in tests that use an in-memory store.
final sharedTokenStoreProvider = Provider<GuardedTokenStore?>((ref) => null);

/// The Dio instance for every backend call: client-info headers, then the
/// bearer token / refresh, then 426/503 detection (jivo_core order).
final dioProvider = Provider<Dio>((ref) {
  final dio = createJivoDio(
    env: ref.watch(appEnvProvider),
    clientInfo: ref.watch(clientInfoProvider),
    interceptors: [
      AuthInterceptor(ref.watch(sessionManagerProvider)),
      AppControlInterceptor(ref.watch(appControlSignalsProvider)),
    ],
  );
  ref.onDispose(dio.close);
  return dio;
});

/// The generated API client on the shared Dio. `interceptors: const []` stops
/// it from adding its own auth interceptors (auth comes from jivo_core).
final jivoApiProvider = Provider<JivoApi>(
  (ref) => JivoApi(dio: ref.watch(dioProvider), interceptors: const []),
);

/// Analytics wrapper. TODO(D-19): back it with the chosen provider.
final analyticsProvider = Provider<AnalyticsClient>(
  (ref) => ref.watch(appEnvProvider).isProd
      ? const NoopAnalyticsClient()
      : const DebugAnalyticsClient(),
);

/// Opens links (policies, store page) outside the app.
final urlOpenerProvider = Provider<UrlOpener>(
  (ref) => const ExternalUrlOpener(),
);

/// The current time. Overridden in tests (age rule, upload times).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
