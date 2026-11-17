import 'package:flutter/foundation.dart';

/// One push (FCM data message) as the app sees it: string keys and values.
@immutable
class PushMessage {
  const PushMessage(this.data, {this.openedApp = false});

  final Map<String, String> data;

  /// The rider tapped the notification (or its full-screen intent opened
  /// the app), rather than the message arriving while the app was open.
  final bool openedApp;

  @override
  String toString() => 'PushMessage(${data['type']}, openedApp: $openedApp)';
}

/// The push channel (FCM, D-19), behind an interface so the app builds and
/// runs without Firebase.
///
/// A build with the flavor's `google-services.json` uses
/// `FirebasePushMessaging` (chosen by `initializePush()` at start-up, see
/// `data/push_setup.dart`), whose background handler turns a data-only
/// `offer.new` into the full-screen offer alarm while the app is not
/// running. A build without it (CI, a fresh checkout, a flavor whose
/// Firebase project doesn't exist yet) uses `NoopPushMessaging`: no token,
/// no messages; offers still arrive on the rider socket and by polling
/// `GET /rider/offers/current/`.
///
/// Notification permission (Android 13+ `POST_NOTIFICATIONS`) is never
/// asked here: the permissions gate asks it, with its explanation, the
/// first time the rider goes online (04 §2.1).
abstract interface class PushMessaging {
  /// False when push is not configured for this build.
  bool get isAvailable;

  /// The FCM registration token, or null when not available yet.
  Future<String?> token();

  /// New tokens issued by FCM (rotation, app data cleared, restore).
  Stream<String> get tokenRefreshes;

  /// Messages received while the app runs, and notification taps.
  Stream<PushMessage> get messages;

  /// The message whose notification started the app, if any. Returns it
  /// once.
  Future<PushMessage?> initialMessage();

  /// Drops this device's token (after sign-out), so pushes meant for the
  /// signed-out rider stop arriving even when the server was not told
  /// (a DL-74 wrong-app sign-out, an expired session). The next [token]
  /// returns a new token. Never throws: returns false when the token could
  /// not be deleted (offline), so the caller can retry later.
  Future<bool> deleteToken();
}
