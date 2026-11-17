import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/push_messaging.dart';
import 'firebase_push_messaging.dart';
import 'noop_push_messaging.dart';
import 'push_background.dart';
import 'push_channels.dart';

/// Chooses the push channel at start-up (D-19). Never throws.
///
/// Every flavor uses the same code; only the config differs. Firebase reads
/// its options from the flavor's `google-services.json`, which the Gradle
/// build turns into resources (`android/app/src/<flavor>/`, placed by
/// `tool/setup_firebase.sh`). Without that file (CI, a fresh checkout, a
/// flavor whose Firebase project doesn't exist yet) `Firebase.initializeApp()`
/// fails and the app runs with [NoopPushMessaging]: push off; offers still
/// arrive on the rider socket and by polling.
///
/// With Firebase, [riderFirebaseBackgroundHandler] is registered for
/// background and terminated messages (the data-only offer alarm). It never
/// asks for notification permission: the permissions gate does, before the
/// rider goes online (04 §2.1).
Future<PushMessaging> initializePush({
  RiderPushChannelTexts? texts,
  Future<void> Function() initializeFirebase = _initializeFirebase,
  void Function() registerBackgroundHandler = _registerBackgroundHandler,
  FcmClient Function()? fcm,
  PushNotifier Function()? notifier,
}) async {
  try {
    await initializeFirebase();
  } on Object catch (error) {
    debugPrint('Push: Firebase is not configured for this build ($error).');
    return const NoopPushMessaging();
  }
  try {
    registerBackgroundHandler();
    final push = FirebasePushMessaging(
      fcm: fcm == null ? FirebaseFcmClient() : fcm(),
      notifier: notifier == null ? FlutterLocalPushNotifier() : notifier(),
      texts: texts ?? defaultPushChannelTexts(),
    );
    await push.start();
    return push;
  } on Object catch (error) {
    debugPrint('Push: could not start FCM (${error.runtimeType}); push off.');
    return const NoopPushMessaging();
  }
}

/// The channel names in [locale] (English until Hindi strings exist).
RiderPushChannelTexts defaultPushChannelTexts([
  Locale locale = const Locale('en'),
]) {
  final l10n = lookupAppLocalizations(locale);
  return (
    offersName: l10n.pushChannelOffersName,
    offersDescription: l10n.pushChannelOffersDescription,
    ordersName: l10n.pushChannelOrdersName,
    ordersDescription: l10n.pushChannelOrdersDescription,
    generalName: l10n.pushChannelGeneralName,
    generalDescription: l10n.pushChannelGeneralDescription,
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    // Android only in v1 (D-07).
    throw UnsupportedError('Push is Android only.');
  }
  // Options come from the google-services resources. Missing config
  // throws, which means "push off".
  await Firebase.initializeApp().timeout(const Duration(seconds: 10));
}

void _registerBackgroundHandler() =>
    FirebaseMessaging.onBackgroundMessage(riderFirebaseBackgroundHandler);
