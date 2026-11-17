import '../domain/push_messaging.dart';

/// Push is not configured for this build: the flavor has no
/// `google-services.json` (D-19, `tool/setup_firebase.sh`). Offers still
/// arrive on the rider socket and by polling.
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

  @override
  Future<bool> deleteToken() async => true;
}
