import 'dart:async';

/// The push channel (FCM, D-19): the device token and notification taps.
///
/// The app talks to this interface only. A build with the flavor's
/// `google-services.json` uses `FirebasePushMessaging`
/// (`firebase_push_messaging.dart`, chosen by `initializePush()` at
/// start-up). A build without it (CI, a flavor whose Firebase project
/// doesn't exist yet) uses [NoopPushMessaging]: no token, no taps, so
/// nothing is registered and nothing is routed.
abstract interface class PushMessaging {
  /// Whether this build has a push provider configured.
  bool get isConfigured;

  /// Asks the user for notification permission where the platform needs it
  /// (iOS, Android 13+). Returns whether pushes may be shown.
  Future<bool> requestPermission();

  /// This device's push token, or null when there is none (not configured,
  /// permission denied, or the provider is unreachable).
  Future<String?> getToken();

  /// New tokens after a rotation.
  Stream<String> get onTokenRefresh;

  /// Drops this device's token (after sign-out), so pushes meant for the
  /// signed-out user stop arriving even if the server was not told. The
  /// next [getToken] returns a new token.
  Future<void> deleteToken();

  /// The data payload of a notification the user tapped while the app was
  /// running or in the background (`08 §9`, api-requests #30).
  Stream<Map<String, Object?>> get onNotificationTap;

  /// The data payload of the notification that launched the app, once.
  Future<Map<String, Object?>?> takeInitialNotification();
}

/// The build without a push provider (Firebase not configured, D-19).
class NoopPushMessaging implements PushMessaging {
  const NoopPushMessaging();

  @override
  bool get isConfigured => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<Map<String, Object?>> get onNotificationTap => const Stream.empty();

  @override
  Future<Map<String, Object?>?> takeInitialNotification() async => null;
}

/// A controllable push channel for tests and the `FAKE_API` dev build.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.token, this.initialNotification});

  String? token;
  Map<String, Object?>? initialNotification;
  bool permissionGranted = true;
  int permissionRequests = 0;
  int tokenDeletions = 0;

  final _refresh = StreamController<String>.broadcast();
  final _taps = StreamController<Map<String, Object?>>.broadcast();

  /// Rotates the token (FCM `onTokenRefresh`).
  void rotate(String newToken) {
    token = newToken;
    _refresh.add(newToken);
  }

  /// The user taps a notification while the app runs.
  void tap(Map<String, Object?> data) => _taps.add(data);

  Future<void> close() async {
    await _refresh.close();
    await _taps.close();
  }

  @override
  bool get isConfigured => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async => token;

  /// Like FCM, the next [getToken] after a delete returns a new token.
  @override
  Future<void> deleteToken() async {
    tokenDeletions++;
    if (token != null) token = 'tok-new-$tokenDeletions';
  }

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<Map<String, Object?>> get onNotificationTap => _taps.stream;

  @override
  Future<Map<String, Object?>?> takeInitialNotification() async {
    final data = initialNotification;
    initialNotification = null;
    return data;
  }
}
