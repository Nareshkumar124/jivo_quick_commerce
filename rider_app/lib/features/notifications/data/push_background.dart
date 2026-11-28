import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../domain/rider_push.dart';
import 'firebase_push_messaging.dart';
import 'push_channels.dart';
import 'push_guard_store.dart';

/// FCM background / terminated handler (D-19), registered by
/// `initializePush()`. Runs in its own isolate: no providers, no session,
/// no API calls.
///
/// A message with a `notification` part is shown by the system on its
/// channel. A **data-only** `offer.new` is the server's way to ring the
/// rider (04 §2.4): it rings the offer alarm (the same
/// notification the in-app path uses, so the two replace each other instead
/// of stacking). `offer.withdrawn` / `offer.expired`, with or without text,
/// remove the alarm. Tapping the alarm starts the app, which fetches the
/// offer from the server (`GET /rider/offers/current/`): the countdown and
/// the amounts never come from the push.
///
/// It never rings while no rider is signed in on this phone
/// ([PushGuardStore.signedIn]), nor for an offer whose `expires_at` has
/// passed (a delayed push); the alarm lasts at most the time left.
@pragma('vm:entry-point')
Future<void> riderFirebaseBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    final alerts = OfferAlertNotifications();
    final texts = backgroundOfferTexts();
    await alerts.initialize(
      channelName: texts.channelName,
      channelDescription: texts.channelDescription,
      onOfferSelected: (_) {},
    );
    await handleBackgroundPush(
      incomingPush(message),
      alerts,
      texts: texts,
      signedIn: () => PrefsPushGuardStore().signedIn(),
    );
  } on Object catch (error) {
    debugPrint('Push (background): ${error.runtimeType}');
  }
}

typedef BackgroundOfferTexts = ({
  String channelName,
  String channelDescription,
  String title,
  String body,
});

BackgroundOfferTexts backgroundOfferTexts([
  Locale locale = const Locale('en'),
]) {
  final l10n = lookupAppLocalizations(locale);
  return (
    channelName: l10n.offerChannelName,
    channelDescription: l10n.offerChannelDescription,
    title: l10n.offerAlertTitle,
    body: l10n.offerAlertBodyFromPush,
  );
}

/// What the background handler does with [push]. Returns what it did, for
/// tests.
Future<BackgroundPushAction> handleBackgroundPush(
  IncomingPush push,
  OfferAlertNotifications alerts, {
  required BackgroundOfferTexts texts,
  required Future<bool> Function() signedIn,
  DateTime Function() now = DateTime.now,
}) async {
  final parsed = RiderPush.parse(push.data);
  // The offer ended: the alarm stops, whatever else the system shows.
  if (parsed is OfferWithdrawnPush) {
    await alerts.dismiss(id: OfferAlertNotifications.offerNotificationId);
    return BackgroundPushAction.dismissedOffer;
  }
  if (push.hasText) return BackgroundPushAction.shownBySystem;
  switch (parsed) {
    case OfferPush(:final offerId?):
      // Not for the next person on this phone after a sign-out whose token
      // delete failed.
      if (!await signedIn()) return BackgroundPushAction.skippedSignedOut;
      final timeout = backgroundAlarmTimeout(push.data['expires_at'], now());
      if (timeout == null) return BackgroundPushAction.skippedExpired;
      await alerts.showOffer(
        offerId: offerId,
        title: texts.title,
        body: texts.body,
        channelName: texts.channelName,
        // The offer screen counts down from the server's `expires_at`
        // (fetched); this only bounds the ringing.
        timeout: timeout,
      );
      return BackgroundPushAction.rangOffer;
    default:
      return BackgroundPushAction.none;
  }
}

enum BackgroundPushAction {
  shownBySystem,
  rangOffer,
  dismissedOffer,

  /// A data-only `offer.new` while no rider is signed in.
  skippedSignedOut,

  /// A data-only `offer.new` whose `expires_at` has passed (delayed push).
  skippedExpired,
  none,
}

/// Phone and server clocks may differ by this much.
const backgroundAlarmClockSkew = Duration(seconds: 5);

/// The shortest alarm worth ringing (an offer within the skew allowance).
const backgroundAlarmMinimum = Duration(seconds: 3);

/// How long the background alarm rings for an offer that expires at
/// [expiresAt] (the push's ISO 8601 UTC `expires_at`): the time left, at
/// most the 30 s offer window; null when it expired more than
/// [backgroundAlarmClockSkew] ago. Without a (valid) `expires_at`: 30 s.
Duration? backgroundAlarmTimeout(String? expiresAt, DateTime now) {
  const window = OfferAlertNotifications.offerTimeout;
  final expires = expiresAt == null ? null : DateTime.tryParse(expiresAt);
  if (expires == null) return window;
  final left = expires.difference(now);
  if (left < -backgroundAlarmClockSkew) return null;
  if (left > window) return window;
  return left < backgroundAlarmMinimum ? backgroundAlarmMinimum : left;
}
