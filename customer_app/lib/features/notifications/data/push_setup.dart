import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';
import 'firebase_push_messaging.dart';
import 'push_channels.dart';
import 'push_messaging.dart';

/// Chooses the push channel at start-up (D-19). Never throws.
///
/// Every flavor uses the same code; only the config differs. Firebase reads
/// its options from the flavor's `google-services.json`, which the Gradle
/// build turns into resources (`android/app/src/<flavor>/`, placed by
/// `tool/setup_firebase.sh`). Without that file (CI, a fresh checkout, a
/// flavor whose Firebase project doesn't exist yet) `Firebase.initializeApp()`
/// fails and the app runs with [NoopPushMessaging]: push off, everything
/// else unchanged.
///
/// Background and terminated: FCM notification messages (all the server
/// sends, `06 §4.3`) are shown by the system on their channel, and a tap
/// reaches the app through `getInitialMessage` / `onMessageOpenedApp`. No
/// Dart background handler is registered on purpose: the customer app gets
/// no data-only messages, and a registered handler would start a background
/// Dart isolate for every push (firebase_messaging 17.1 skips that service
/// when none is registered). Add `FirebaseMessaging.onBackgroundMessage`
/// here with a top-level `@pragma('vm:entry-point')` function if data-only
/// messages are ever sent.
///
/// iOS: TODO(ios) add `ios/Runner/GoogleService-Info.plist` per flavor and
/// the APNs key in the Firebase project (D-19). Until then initialisation
/// fails on iOS and push is off there.
Future<PushMessaging> initializePush({
  PushChannelTexts? texts,
  Future<void> Function() initializeFirebase = _initializeFirebase,
  FcmClient Function()? fcm,
  LocalNotifier Function()? local,
}) async {
  try {
    await initializeFirebase();
  } catch (error) {
    debugPrint('Push: Firebase is not configured for this build ($error).');
    return const NoopPushMessaging();
  }
  try {
    final push = FirebasePushMessaging(
      fcm: fcm == null ? FirebaseFcmClient() : fcm(),
      local: local == null ? FlutterLocalNotifier() : local(),
      texts: texts ?? defaultPushChannelTexts(),
    );
    await push.start();
    return push;
  } catch (error) {
    debugPrint('Push: could not start FCM ($error); push is off.');
    return const NoopPushMessaging();
  }
}

/// The channel names in the app's locale (`en_IN`).
PushChannelTexts defaultPushChannelTexts() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  return (
    ordersName: l10n.pushChannelOrdersName,
    ordersDescription: l10n.pushChannelOrdersDescription,
    generalName: l10n.pushChannelGeneralName,
    generalDescription: l10n.pushChannelGeneralDescription,
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb) throw UnsupportedError('No push on the web.');
  // Options come from the platform config (Android: the google-services
  // resources). Missing config throws, which means "push off".
  await Firebase.initializeApp().timeout(const Duration(seconds: 10));
}
