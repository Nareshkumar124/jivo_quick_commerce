import '../domain/push_messaging.dart';

/// Push is not configured for this build (no Firebase project yet, D-19).
/// Offers still arrive by polling and, in P6, the rider WebSocket.
class NoopPushMessaging implements PushMessaging {
  const NoopPushMessaging();

  @override
  bool get isAvailable => false;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Stream<PushMessage> get messages => const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async => null;
}
