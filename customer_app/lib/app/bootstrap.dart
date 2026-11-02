import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/data/fake_token_refresher.dart';
import '../shared/formatting/formatters.dart';
import '../shared/storage/app_flags.dart';
import 'app.dart';
import 'providers.dart';

/// Starts the app for [flavor]. Called by `main_<flavor>.dart`.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment(flavor);
  final clientInfo = await ClientInfo.fromPlatform(appName: customerAppName);
  await initializeFormatting();
  final prefs = await SharedPreferences.getInstance();

  final store = SecureTokenStore();
  await clearStaleSessionOnFreshInstall(prefs, store);
  final session = createSession(env: env, clientInfo: clientInfo, store: store);
  await session.restore();

  await runWithSentry(
    dsn: env.sentryDsn,
    environment: env.environmentName,
    release: clientInfo.release,
    appRunner: () => runApp(
      customerAppRoot(
        env: env,
        clientInfo: clientInfo,
        session: session,
        signals: AppControlSignals(),
        prefs: prefs,
      ),
    ),
  );
}

/// The session: refresh through the API, or fake tokens with `FAKE_API`.
SessionManager createSession({
  required AppEnv env,
  required ClientInfo clientInfo,
  required TokenStore store,
}) => SessionManager(
  store: store,
  refresher: env.useFakeApi
      ? FakeTokenRefresher()
      : ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo),
);

/// Loads the `en_IN` date symbols and makes `en_IN` the default for `intl`.
Future<void> initializeFormatting() async {
  Intl.defaultLocale = kDisplayLocale;
  await initializeDateFormatting(kDisplayLocale);
}

/// The root widget: the provider scope with the start-up values, then the
/// app. Tests and the integration test pass extra [overrides] (fakes).
Widget customerAppRoot({
  required AppEnv env,
  required ClientInfo clientInfo,
  required SessionManager session,
  required AppControlSignals signals,
  required SharedPreferences prefs,
  List<Override> overrides = const [],
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    appEnvProvider.overrideWithValue(env),
    clientInfoProvider.overrideWithValue(clientInfo),
    sessionProvider.overrideWithValue(session),
    appControlProvider.overrideWithValue(signals),
    sharedPreferencesProvider.overrideWithValue(prefs),
    ...overrides,
  ],
  child: const JivoCustomerApp(),
);
