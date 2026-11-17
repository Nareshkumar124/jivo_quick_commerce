import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../features/notifications/data/firebase_push_messaging.dart';
import '../features/notifications/data/push_setup.dart';
import '../features/notifications/domain/push_messaging.dart';
import '../features/notifications/presentation/push_providers.dart';
import '../features/offers/data/offer_alert_notifications.dart';
import '../features/offers/presentation/offer_alert_providers.dart';
import '../l10n/app_localizations.dart';
import '../shared/session/store_synced_token_refresher.dart';
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

  // FCM when this flavor has its google-services.json, else push off
  // (D-19); runs alongside the rest of the start-up.
  final l10n = lookupAppLocalizations(_supportedLocale());
  final pushReady = initializePush(
    texts: defaultPushChannelTexts(_supportedLocale()),
  );

  final env = AppEnv.fromEnvironment(flavor);
  final clientInfo = await ClientInfo.fromPlatform(appName: riderAppName);

  // jivo_core session: restored before the first redirect, so the router
  // starts from signedIn / signedOut, never unknown.
  // The location service isolate will refresh tokens too (TODO(api): once
  // its uploader is bound): both sides go through the shared store so a
  // rotation by one never ends the other's session.
  final secureStore = SecureTokenStore();
  final tokenStore = GuardedTokenStore(secureStore);
  final session = SessionManager(
    store: tokenStore,
    refresher: StoreSyncedTokenRefresher(
      inner: ApiTokenRefresher.forEnv(env: env, clientInfo: clientInfo),
      store: secureStore,
    ),
  );
  await session.restore();
  final signals = AppControlSignals();
  final PushMessaging push = await pushReady;

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
        // is there (navigating first would race the fetch). An offer that
        // ended meanwhile shows "Offer expired".
        container
            .read(pushMessageHandlerProvider)
            .handle(offerAlertTapMessage(payload));
      },
      // A foreground push notification (FCM) was tapped.
      onOtherSelected: (payload) {
        if (push is FirebasePushMessaging) push.onLocalNotificationTap(payload);
      },
    );
  } on Object catch (error) {
    debugPrint('bootstrap: offer alert channel setup failed: $error');
  }

  // Started by a tapped foreground push notification: routed once the app
  // runs (PushMessaging.initialMessage).
  if (push is FirebasePushMessaging) push.setLocalLaunchPayload(launchPayload);
  // Started by a real offer alert (its full-screen intent or a tap): the
  // offer controller fetches the offer when the rider becomes active; this
  // also shows "Offer expired" if it ended meanwhile.
  final launchOffer =
      OfferAlertNotifications.isOfferPayload(launchPayload) &&
          launchPayload != OfferAlertNotifications.testPayload
      ? offerAlertTapMessage(launchPayload!)
      : null;

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
      pushMessagingProvider.overrideWithValue(push),
      sharedTokenStoreProvider.overrideWithValue(tokenStore),
      if (launchPayload == OfferAlertNotifications.testPayload &&
          env.showDevTools)
        initialLocationProvider.overrideWithValue(Routes.offerPreview),
    ],
  );

  if (launchOffer != null) {
    container.read(pushMessageHandlerProvider).handle(launchOffer);
  }

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
