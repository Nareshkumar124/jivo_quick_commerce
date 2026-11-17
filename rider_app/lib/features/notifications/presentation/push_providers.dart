import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../../location/domain/backoff.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../cash/presentation/cash_providers.dart';
import '../../offers/presentation/offer_controller.dart';
import '../../shift/presentation/home_providers.dart';
import '../../support/presentation/support_providers.dart';
import '../../task/domain/task_repositories.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../data/api_device_registry.dart';
import '../data/noop_push_messaging.dart';
import '../data/push_guard_store.dart';
import '../domain/device_registry.dart';
import '../domain/push_messaging.dart';
import '../domain/rider_push.dart';
import 'inbox_providers.dart';
import 'rider_links.dart';

/// The push channel: set at start-up from `initializePush()` (Firebase when
/// the flavor has its `google-services.json`, else the no-op, D-19). Offers
/// also arrive on the rider socket, with polling as the fallback. Tests use
/// `FakePushMessaging`.
final pushMessagingProvider = Provider<PushMessaging>(
  (ref) => const NoopPushMessaging(),
);

/// The flags shared with the FCM background isolate (signed in, token
/// delete pending). Tests override it with `InMemoryPushGuardStore`.
final pushGuardStoreProvider = Provider<PushGuardStore>(
  (ref) => PrefsPushGuardStore(),
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
/// (`POST /me/devices/`, `app: rider`): after login, on app start, and on
/// every token refresh. A transient failure (no network, 5xx, 429) retries
/// with backoff; a client error (4xx) is logged and not retried until the
/// next trigger. After any sign-out the local token is deleted
/// ([PushMessaging.deleteToken]); a logout unregisters it on the server
/// first ([unregisterForLogout]).
class PushRegistrationController extends Notifier<PushRegistrationState> {
  Timer? _retry;
  Backoff? _backoff;

  @override
  PushRegistrationState build() {
    final push = ref.watch(pushMessagingProvider);
    final session = ref.watch(sessionManagerProvider);
    ref.onDispose(() => _retry?.cancel());
    if (!push.isAvailable) return const PushRegistrationState();
    final guard = ref.watch(pushGuardStoreProvider);

    var wasSignedIn = session.isSignedIn;
    final status = session.statusStream.listen((status) {
      if (status == SessionStatus.signedIn) {
        wasSignedIn = true;
        unawaited(guard.setSignedIn(true));
        unawaited(registerCurrent());
      } else {
        _retry?.cancel();
        _retry = null;
        state = const PushRegistrationState();
        if (status == SessionStatus.signedOut && wasSignedIn) {
          wasSignedIn = false;
          // Every sign-out, including the DL-74 wrong-app one and an
          // expired session, where the server can't be told: a new token
          // means pushes for this rider stop reaching this phone. A logout
          // also unregistered it first (unregisterForLogout).
          unawaited(_afterSignOut());
        }
      }
    });
    final refreshes = push.tokenRefreshes.listen(
      (token) => unawaited(_register(token, force: true)),
    );
    ref.onDispose(() {
      status.cancel();
      refreshes.cancel();
    });
    // The background handler rings offers only while this is on.
    unawaited(guard.setSignedIn(session.isSignedIn));
    if (session.isSignedIn) {
      Future.microtask(registerCurrent);
    } else {
      // A sign-out that could not delete the token (offline) retries now.
      Future.microtask(_retryPendingDelete);
    }
    return const PushRegistrationState();
  }

  Future<void> _afterSignOut() async {
    final guard = ref.read(pushGuardStoreProvider);
    final push = ref.read(pushMessagingProvider);
    // First: the background handler must stop ringing for this phone.
    await guard.setSignedIn(false);
    await guard.setTokenDeletePending(true);
    if (await push.deleteToken()) await guard.setTokenDeletePending(false);
  }

  /// Deletes the token a sign-out could not delete. Returns when done (or
  /// still pending).
  Future<void> _retryPendingDelete() async {
    if (!ref.mounted) return;
    final guard = ref.read(pushGuardStoreProvider);
    if (!await guard.tokenDeletePending()) return;
    if (!ref.mounted) return;
    if (await ref.read(pushMessagingProvider).deleteToken()) {
      await guard.setTokenDeletePending(false);
    }
  }

  Future<void> registerCurrent() async {
    // A previous rider's token that could not be deleted is dropped before
    // this rider registers one.
    await _retryPendingDelete();
    if (!ref.mounted) return;
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
  // A tapped notification that started the app waits for the rider's
  // account (the screen it opens depends on it).
  ref.listen(riderAccountControllerProvider, (_, account) {
    if (account is AccountLoaded) handler._flushPending();
  });
  final subscription = push.messages.listen(handler.handle);
  ref.onDispose(subscription.cancel);
  unawaited(
    push.initialMessage().then((message) {
      if (message != null && ref.mounted) handler.handle(message);
    }),
  );
  return handler;
});

/// The message for a tapped offer alarm (`offer:<id>` payload, in-app or
/// background): the same as a tapped `offer.new` push.
PushMessage offerAlertTapMessage(String payload) {
  final id = int.tryParse(
    payload.substring(OfferAlertNotifications.payloadPrefix.length),
  );
  return PushMessage({
    RiderPush.typeKey: 'offer.new',
    if (id != null) 'offer_id': '$id',
  }, openedApp: true);
}

class PushMessageHandler {
  PushMessageHandler(this._ref);

  final Ref _ref;

  /// A tapped notification that arrived before the account was loaded.
  PushMessage? _pending;

  void _flushPending() {
    final pending = _pending;
    _pending = null;
    if (pending != null) handle(pending);
  }

  bool get _accountLoaded =>
      _ref.read(riderAccountControllerProvider) is AccountLoaded;

  void _open(String route) => _ref.read(riderLinkNavigatorProvider)(route);

  /// A tapped notification: the screen for its `link`, else for its type
  /// ([fallback]); a link the app doesn't know goes home.
  void _openTapped(PushMessage message, String? fallback) {
    final link = message.data['link'];
    if (link != null && link.isNotEmpty) {
      _open(routeForRiderLink(link) ?? Routes.home);
    } else if (fallback != null) {
      _open(fallback);
    }
  }

  /// - `offer.new`: fetch the offer from the server; the router then shows
  ///   the full-screen offer (the server's `expires_at` drives the
  ///   countdown, never the push body).
  /// - `offer.withdrawn`: end the open offer ("Order cancelled") and remove
  ///   its alert; `offer.expired` the same with "Offer expired" (P8).
  /// - `task.updated`: re-read the current task.
  /// - `cash.updated`: re-read the cash summary and ledger; tapped, open
  ///   the cash ledger.
  /// - `ticket` (every flavor): re-read that ticket and the list; tapped,
  ///   open the ticket.
  ///
  /// A tapped notification (`openedApp`) also opens its screen: the offer
  /// (or "Offer expired" when it ended meanwhile), `jivo://rider/task`,
  /// `jivo://rider/cash`, the ticket; its `link` when it has one, and home
  /// for a link or type the app doesn't know. A tap that starts the app is
  /// held until the account is loaded.
  void handle(PushMessage message) {
    if (message.openedApp && !_accountLoaded) {
      if (_ref.read(sessionManagerProvider).isSignedIn) _pending = message;
      return;
    }
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
    if (!_ref.read(riderWorkActiveProvider)) {
      // Not an active rider (yet): only the link, if any.
      if (message.openedApp) _openTapped(message, null);
      return;
    }
    switch (push) {
      case OfferPush(:final offerId) when message.openedApp:
        // Tapped: open it, or say it expired.
        unawaited(
          _ref
              .read(offerControllerProvider.notifier)
              .openFromNotification(offerId),
        );
      case OfferPush():
        // A new offer replaces an ended one still on screen ("expired").
        final offers = _ref.read(offerControllerProvider.notifier);
        if (_ref.read(offerControllerProvider).isEnded) offers.acknowledge();
        unawaited(offers.refresh());
      case OfferWithdrawnPush(:final offerId, :final expired):
        _ref
            .read(offerControllerProvider.notifier)
            .withdrawn(
              offerId,
              reason: expired
                  ? OfferEndReason.expired
                  : OfferEndReason.cancelled,
            );
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
        // The guard sends the rider home when there is no task any more.
        if (message.openedApp) _openTapped(message, Routes.task);
      case CashUpdatedPush():
        _ref
          ..invalidate(todaySummaryProvider)
          ..invalidate(cashLedgerProvider)
          ..invalidate(inboxUnreadCountProvider);
        if (message.openedApp) _openTapped(message, Routes.cash);
      case TicketPush():
        break; // handled above, in every flavor
      case UnknownPush() when message.openedApp:
        _openTapped(message, Routes.home);
      case UnknownPush():
        // Only the type: the payload may carry order details.
        debugPrint(
          'PushMessageHandler: ignored type ${message.data[RiderPush.typeKey]}',
        );
    }
  }
}
