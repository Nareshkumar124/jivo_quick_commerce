import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../location/domain/backoff.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../offers/presentation/offer_controller.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_device_registry.dart';
import '../data/noop_push_messaging.dart';
import '../domain/device_registry.dart';
import '../domain/push_messaging.dart';
import '../domain/rider_push.dart';

/// TODO(D-19): the Firebase adapter replaces the no-op in P6.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const NoopPushMessaging(),
);

/// `FAKE_API` builds share one fake registry (tests read it).
final fakeDeviceRegistryProvider = Provider<FakeDeviceRegistry>(
  (ref) => FakeDeviceRegistry(),
);

final deviceRegistryProvider = Provider<DeviceRegistry>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeDeviceRegistryProvider);
  }
  return ApiDeviceRegistry(
    ref.watch(jivoApiProvider),
    ref.watch(clientInfoProvider),
  );
});

/// The randomness of the registration backoff. Overridden in tests.
final pushBackoffFactoryProvider = Provider<Backoff Function()>(
  (ref) =>
      () => Backoff(
        initial: const Duration(seconds: 5),
        max: const Duration(minutes: 5),
      ),
);

@immutable
class PushRegistrationState {
  const PushRegistrationState({this.registeredToken, this.lastError});

  /// The token the server has for this session, or null.
  final String? registeredToken;
  final ApiError? lastError;
}

final pushRegistrationControllerProvider =
    NotifierProvider<PushRegistrationController, PushRegistrationState>(
      PushRegistrationController.new,
    );

/// Keeps the FCM token registered for the signed-in rider
/// (`POST /me/devices/`): after login, on app start, and on every token
/// refresh. A transient failure (no network, 5xx, 429) retries with backoff;
/// a client error (4xx) is logged and not retried until the next trigger.
///
/// TODO(api): there is no `DELETE /me/devices/` in the contract, so logout
/// cannot unregister the token. The upsert moves it to the next user who
/// signs in on this phone.
class PushRegistrationController extends Notifier<PushRegistrationState> {
  Timer? _retry;
  Backoff? _backoff;

  @override
  PushRegistrationState build() {
    final push = ref.watch(pushMessagingProvider);
    final session = ref.watch(sessionManagerProvider);
    ref.onDispose(() => _retry?.cancel());
    if (!push.isAvailable) return const PushRegistrationState();

    final status = session.statusStream.listen((status) {
      if (status == SessionStatus.signedIn) {
        unawaited(registerCurrent());
      } else {
        _retry?.cancel();
        _retry = null;
        state = const PushRegistrationState();
      }
    });
    final refreshes = push.tokenRefreshes.listen(
      (token) => unawaited(_register(token, force: true)),
    );
    ref.onDispose(() {
      status.cancel();
      refreshes.cancel();
    });
    if (session.isSignedIn) Future.microtask(registerCurrent);
    return const PushRegistrationState();
  }

  Future<void> registerCurrent() async {
    final String? token;
    try {
      token = await ref.read(pushMessagingProvider).token();
    } on Object catch (error) {
      debugPrint('PushRegistration: token unavailable: $error');
      return;
    }
    if (token != null && ref.mounted) await _register(token);
  }

  Future<void> _register(String token, {bool force = false}) async {
    if (!ref.mounted || !ref.read(sessionManagerProvider).isSignedIn) return;
    if (!force && state.registeredToken == token) return;
    _retry?.cancel();
    _retry = null;
    try {
      await ref.read(deviceRegistryProvider).register(token);
      if (!ref.mounted) return;
      _backoff?.reset();
      state = PushRegistrationState(registeredToken: token);
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!ref.mounted) return;
      state = PushRegistrationState(lastError: error);
      if (!_isTransient(error)) {
        debugPrint('PushRegistration: refused (${error.code}); not retried');
        return;
      }
      final backoff = _backoff ??= ref.read(pushBackoffFactoryProvider)();
      _retry = Timer(
        backoff.fail(serverHint: _retryAfter(error)),
        () => unawaited(_register(token, force: true)),
      );
    }
  }

  static bool _isTransient(ApiError error) {
    final status = error.statusCode;
    return status == null || status >= 500 || status == 429;
  }

  static Duration? _retryAfter(ApiError error) {
    final seconds = error.retryAfterSeconds;
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

/// Routes rider pushes to the screens (04 §2.4). Created at app start (see
/// `RiderApp`), so it also handles the message that launched the app.
final pushMessageHandlerProvider = Provider<PushMessageHandler>((ref) {
  final handler = PushMessageHandler(ref);
  final push = ref.watch(pushMessagingProvider);
  final subscription = push.messages.listen(handler.handle);
  ref.onDispose(subscription.cancel);
  unawaited(
    push.initialMessage().then((message) {
      if (message != null && ref.mounted) handler.handle(message);
    }),
  );
  return handler;
});

class PushMessageHandler {
  PushMessageHandler(this._ref);

  final Ref _ref;

  /// - `offer.new`: fetch the offer from the server; the router then shows
  ///   the full-screen offer (the server's `expires_at` drives the
  ///   countdown, never the push body).
  /// - `offer.withdrawn`: end the open offer ("Order cancelled") and remove
  ///   its alert.
  /// - `task.updated`: re-read the current task.
  void handle(PushMessage message) {
    if (!_ref.read(riderWorkActiveProvider)) return;
    switch (RiderPush.parse(message.data)) {
      case OfferPush():
        unawaited(_ref.read(offerControllerProvider.notifier).refresh());
      case OfferWithdrawnPush(:final offerId):
        _ref.read(offerControllerProvider.notifier).withdrawn(offerId);
        unawaited(
          _ref
              .read(offerAlertNotificationsProvider)
              .dismiss(id: OfferAlertNotifications.offerNotificationId)
              .catchError((Object e) => debugPrint('dismiss alert: $e')),
        );
      case TaskUpdatedPush():
        unawaited(_ref.read(taskFlowControllerProvider.notifier).load());
      case UnknownPush():
        debugPrint('PushMessageHandler: ignored $message');
    }
  }
}
