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

/// The push channel (FCM), behind an interface so the app builds and runs
/// without Firebase.
///
/// TODO(D-19): the Firebase adapter (firebase_messaging) arrives with the
/// FCM projects in P6. It also owns the background isolate that turns an
/// `offer.new` data message into the high-priority offer alert while the app
/// is not running. Until then [NoopPushMessaging] is used: no token, no
/// messages, and the app falls back to polling `GET /rider/offers/current/`.
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
}
