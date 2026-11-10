import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../location/domain/backoff.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../cash/presentation/cash_providers.dart';
import '../../offers/presentation/offer_controller.dart';
import '../../shift/presentation/home_providers.dart';
import '../../support/presentation/support_providers.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/api_device_registry.dart';
import '../data/noop_push_messaging.dart';
import '../domain/device_registry.dart';
import '../domain/push_messaging.dart';
import '../domain/rider_push.dart';
import 'inbox_providers.dart';
import 'rider_links.dart';

/// The push channel. TODO(D-19): the Firebase adapter (firebase_messaging,
/// with its background isolate that turns an `offer.new` data message into
/// the full-screen offer alert) replaces the no-op once Jivo's FCM projects
/// exist. Until then offers arrive on the rider socket, with polling as the
/// fallback. Tests (and a future dev tool) use `FakePushMessaging`.
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
      debugPrint('PushRegistration: token unavailable: ${error.runtimeType}');
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

  /// Logout, before the session ends (while the request still carries the
  /// token): `DELETE /me/devices/`, best effort, so the next rider on this
  /// phone gets no pushes meant for this one. Returns the token (also sent
  /// with `POST /auth/logout/`), or null when push is not set up.
  Future<String?> unregisterForLogout() async {
    _retry?.cancel();
    _retry = null;
    final push = ref.read(pushMessagingProvider);
    if (!push.isAvailable) return null;
    String? token = state.registeredToken;
    if (token == null) {
      try {
        token = await push.token();
      } on Object catch (error) {
        debugPrint('PushRegistration: token unavailable: ${error.runtimeType}');
      }
    }
    if (token == null || !ref.mounted) return token;
    try {
      await ref.read(deviceRegistryProvider).unregister(token);
    } on Object catch (e) {
      // Best effort: logout goes on; `auth/logout` carries the token too.
      debugPrint(
        'PushRegistration: unregister failed (${ApiError.from(e).code})',
      );
    }
    if (ref.mounted) state = const PushRegistrationState();
    return token;
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
  /// - `cash.updated`: re-read the cash summary and ledger; tapped, open
  ///   the cash ledger.
  /// - `ticket` (every flavor): re-read that ticket and the list; tapped,
  ///   open the ticket.
  void handle(PushMessage message) {
    final push = RiderPush.parse(message.data);
    if (push case TicketPush(:final ticketId)) {
      _ref
        ..invalidate(ticketThreadProvider(ticketId))
        ..invalidate(ticketsProvider)
        ..invalidate(inboxUnreadCountProvider);
      if (message.openedApp) {
        _ref.read(riderLinkNavigatorProvider)(Routes.ticket(ticketId));
      }
      return;
    }
    if (!_ref.read(riderWorkActiveProvider)) return;
    switch (push) {
      case OfferPush():
        // A new offer replaces an ended one still on screen ("expired").
        final offers = _ref.read(offerControllerProvider.notifier);
        if (_ref.read(offerControllerProvider).isEnded) offers.acknowledge();
        unawaited(offers.refresh());
      case OfferWithdrawnPush(:final offerId):
        _ref.read(offerControllerProvider.notifier).withdrawn(offerId);
        unawaited(
          _ref
              .read(offerAlertNotificationsProvider)
              .dismiss(id: OfferAlertNotifications.offerNotificationId)
              .catchError(
                (Object e) => debugPrint('dismiss alert: ${e.runtimeType}'),
              ),
        );
      case TaskUpdatedPush():
        unawaited(_ref.read(taskFlowControllerProvider.notifier).load());
        _ref.invalidate(inboxUnreadCountProvider);
      case CashUpdatedPush():
        _ref
          ..invalidate(todaySummaryProvider)
          ..invalidate(cashLedgerProvider)
          ..invalidate(inboxUnreadCountProvider);
        if (message.openedApp) {
          _ref.read(riderLinkNavigatorProvider)(Routes.cash);
        }
      case TicketPush():
        break; // handled above, in every flavor
      case UnknownPush():
        // Only the type: the payload may carry order details.
        debugPrint(
          'PushMessageHandler: ignored type ${message.data[RiderPush.typeKey]}',
        );
    }
  }
}
