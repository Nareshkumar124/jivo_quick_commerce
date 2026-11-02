import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show JivoApi;
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/location/presentation/delivery_controller.dart';
import '../shared/links/url_opener.dart';
import '../shared/network/store_header.dart';
import '../shared/storage/app_flags.dart';

/// The `X-App-Name` this app sends.
const customerAppName = 'customer';

Never _overriddenAtStartup(String name) => throw UnimplementedError(
  '$name is overridden at startup (customerAppRoot)',
);

/// The flavor configuration.
final appEnvProvider = Provider<AppEnv>(
  (ref) => _overriddenAtStartup('appEnvProvider'),
);

/// The client-info headers.
final clientInfoProvider = Provider<ClientInfo>(
  (ref) => _overriddenAtStartup('clientInfoProvider'),
);

/// The session, restored before the first frame.
final sessionProvider = Provider<SessionManager>(
  (ref) => _overriddenAtStartup('sessionProvider'),
);

/// Force-update and maintenance state.
final appControlProvider = Provider<AppControlSignals>(
  (ref) => _overriddenAtStartup('appControlProvider'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => _overriddenAtStartup('sharedPreferencesProvider'),
);

final appFlagsProvider = Provider<AppFlags>(
  (ref) => AppFlags(ref.watch(sharedPreferencesProvider)),
);

/// The Dio instance for every backend call: client-info headers,
/// `X-Store-Id` on catalog and cart calls, the auth interceptor (token,
/// refresh once on 401) and the app-control interceptor (426/503).
final dioProvider = Provider<Dio>((ref) {
  final dio = createJivoDio(
    env: ref.watch(appEnvProvider),
    clientInfo: ref.watch(clientInfoProvider),
    dynamicHeaders: (options) =>
        storeHeaders(options.path, ref.read(currentStoreIdProvider)),
    interceptors: [
      AuthInterceptor(ref.watch(sessionProvider)),
      AppControlInterceptor(ref.watch(appControlProvider)),
    ],
  );
  ref.onDispose(dio.close);
  return dio;
});

/// The generated API client, on the shared Dio.
///
/// `interceptors: const []` stops the generated constructor from adding its
/// own auth interceptors to the shared Dio (auth comes from jivo_core).
final jivoApiProvider = Provider<JivoApi>(
  (ref) => JivoApi(dio: ref.watch(dioProvider), interceptors: const []),
);

/// The analytics wrapper (`03 §4`).
///
/// TODO(D-19): back it with the chosen provider (Firebase Analytics
/// recommended). Until then events go to the debug log, and nowhere in prod.
final analyticsProvider = Provider<AnalyticsClient>(
  (ref) => ref.watch(appEnvProvider).isProd
      ? const NoopAnalyticsClient()
      : const DebugAnalyticsClient(),
);

final urlOpenerProvider = Provider<UrlOpener>((ref) => const LaunchUrlOpener());
