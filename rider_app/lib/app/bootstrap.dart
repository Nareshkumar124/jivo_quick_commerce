import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/offers/data/offer_alert_notifications.dart';
import '../features/offers/presentation/offer_alert_providers.dart';
import '../features/offers/presentation/offer_controller.dart';
import '../l10n/app_localizations.dart';
import 'app.dart';
import 'env.dart';
import 'providers.dart';
import 'router.dart';
import 'routes.dart';

/// Starts the app for [flavor]. Called by `main_<flavor>.dart`.
///
/// Staging and prod need `--dart-define=API_BASE_URL=https://...` (jivo_core
/// throws `EnvConfigException` otherwise). `--dart-define=FAKE_API=true`
/// swaps in the fake repositories (never in prod).
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Receives stats from the location service isolate.
  FlutterForegroundTask.initCommunicationPort();

  final env = AppEnv.fromEnvironment(flavor);
  final clientInfo = await ClientInfo.fromPlatform(appName: riderAppName);

  // jivo_core session: restored before the first redirect, so the router
  // starts from signedIn / signedOut, never unknown.
  final session = SessionManager(
    store: SecureTokenStore(),
    refresher: ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo),
  );
  await session.restore();
  final signals = AppControlSignals();

  final l10n = lookupAppLocalizations(_supportedLocale());
  final offerAlerts = OfferAlertNotifications();
  late final ProviderContainer container;

  String? launchPayload;
  try {
    launchPayload = await offerAlerts.initialize(
      channelName: l10n.offerChannelName,
      channelDescription: l10n.offerChannelDescription,
      onOfferSelected: (payload) {
        if (payload == OfferAlertNotifications.testPayload) {
          // The Phase 0 test alert (dev only).
          if (env.showDevTools) {
            container.read(routerProvider).go(Routes.offerPreview);
          }
          return;
        }
        // A real offer: fetch it; the router opens the offer screen once it
        // is there (navigating first would race the fetch).
        unawaited(container.read(offerControllerProvider.notifier).refresh());
      },
    );
  } on Object catch (error) {
    debugPrint('bootstrap: offer alert channel setup failed: $error');
  }

  container = ProviderContainer(
    retry: noAutomaticRetry,
    overrides: [
      ...riderAppOverrides(
        env: env,
        clientInfo: clientInfo,
        session: session,
        signals: signals,
      ),
      offerAlertNotificationsProvider.overrideWithValue(offerAlerts),
      if (launchPayload == OfferAlertNotifications.testPayload &&
          env.showDevTools)
        initialLocationProvider.overrideWithValue(Routes.offerPreview),
    ],
  );

  await runWithSentry(
    dsn: env.sentryDsn,
    environment: env.environmentName,
    release: clientInfo.release,
    appRunner: () => runApp(
      UncontrolledProviderScope(container: container, child: const RiderApp()),
    ),
  );
}

/// The startup values every provider graph needs. Tests pass their own
/// (in-memory token store, fake refresher) plus fakes.
List<Override> riderAppOverrides({
  required AppEnv env,
  required ClientInfo clientInfo,
  required SessionManager session,
  required AppControlSignals signals,
}) => [
  appEnvProvider.overrideWithValue(env),
  clientInfoProvider.overrideWithValue(clientInfo),
  sessionManagerProvider.overrideWithValue(session),
  appControlSignalsProvider.overrideWithValue(signals),
];

/// The device locale if the app has strings for it, otherwise English.
Locale _supportedLocale() {
  final device = PlatformDispatcher.instance.locale;
  final supported = AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == device.languageCode,
  );
  return supported ? Locale(device.languageCode) : const Locale('en');
}
