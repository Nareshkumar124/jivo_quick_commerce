import 'dart:async';

import '../domain/push_messaging.dart';

/// FCM stand-in for `FAKE_API` builds and tests (until D-19): a token,
/// token refreshes and messages driven by the caller (dev tools, tests),
/// so token registration and push routing run end to end without Firebase.
class FakePushMessaging implements PushMessaging {
  FakePushMessaging({this.currentToken = 'fcm-token-1'});

  String? currentToken;
  final _refreshes = StreamController<String>.broadcast();
  final _messages = StreamController<PushMessage>.broadcast();

  /// The message that "launched" the app, returned once.
  PushMessage? launch;

  void refreshToken(String token) {
    currentToken = token;
    _refreshes.add(token);
  }

  /// Delivers [message] as if FCM had (foreground, or a notification tap
  /// with `openedApp`).
  void deliver(PushMessage message) => _messages.add(message);

  @override
  bool get isAvailable => true;

  @override
  Future<String?> token() async => currentToken;

  @override
  Stream<String> get tokenRefreshes => _refreshes.stream;

  @override
  Stream<PushMessage> get messages => _messages.stream;

  @override
  Future<PushMessage?> initialMessage() async {
    final message = launch;
    launch = null;
    return message;
  }
}
