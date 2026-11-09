import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../cash/presentation/cash_providers.dart';
import '../../location/domain/backoff.dart';
import '../../notifications/presentation/inbox_providers.dart';
import '../../offers/data/offer_alert_notifications.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../offers/presentation/offer_controller.dart';
import '../../shift/presentation/home_providers.dart';
import '../../shift/presentation/shift_controller.dart';
import '../../task/domain/task_repositories.dart';
import '../../task/presentation/task_flow_controller.dart';
import '../../task/presentation/task_providers.dart';
import '../data/io_socket_connection.dart';
import '../data/rider_socket_client.dart';
import '../data/rider_socket_message.dart';
import '../domain/socket_connection.dart';

/// `/ws/v1/rider/` on the API host: `http` → `ws`, `https` → `wss`.
Uri riderSocketUri(Uri apiBaseUrl) => apiBaseUrl.replace(
  scheme: apiBaseUrl.scheme == 'https' ? 'wss' : 'ws',
  path: '${apiBaseUrl.path}/ws/v1/rider/'.replaceAll('//', '/'),
  query: null,
  fragment: null,
);

/// Opens sockets. Overridden in tests.
final socketConnectorProvider = Provider<SocketConnector>(
  (ref) => IoSocketConnection.connector(
    headers: ref.watch(clientInfoProvider).headers,
  ),
);

/// The reconnect backoff (2 s doubling to 1 min, with jitter). Overridden
/// in tests.
final socketBackoffFactoryProvider = Provider<Backoff Function()>(
  (ref) =>
      () => Backoff(
        initial: const Duration(seconds: 2),
        max: const Duration(minutes: 1),
      ),
);

/// Whether this build runs the rider socket at all: the API builds where
/// the rider work screens run. `FAKE_API` builds use the fake's events.
final riderSocketEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(riderWorkEnabledProvider) &&
      !ref.watch(appEnvProvider).useFakeApi,
);

final riderSocketClientProvider = Provider<RiderSocketClient>((ref) {
  final session = ref.watch(sessionManagerProvider);
  final client = RiderSocketClient(
    uri: riderSocketUri(ref.watch(appEnvProvider).apiBaseUrl),
    connect: ref.watch(socketConnectorProvider),
    accessToken: () => session.accessToken,
    refreshToken: () async {
      final outcome = await session.refreshAfterUnauthorized(
        session.tokenGeneration,
      );
      return switch (outcome) {
        RefreshSucceeded(:final tokens) => tokens.access,
        _ => null,
      };
    },
    backoff: ref.watch(socketBackoffFactoryProvider),
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() => unawaited(client.dispose()));
  return client;
});

/// Offer events from the socket, as the offer controller consumes them.
class SocketOfferEvents implements OfferEventSource {
  final _events = StreamController<OfferEvent>.broadcast();

  @override
  Stream<OfferEvent> get events => _events.stream;

  void add(OfferEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> close() => _events.close();
}

final socketOfferEventsProvider = Provider<SocketOfferEvents>((ref) {
  final events = SocketOfferEvents();
  ref.onDispose(() => unawaited(events.close()));
  return events;
});

/// The socket is up (`auth.ok`): offer polling pauses (agent brief: the 5 s
/// poll is only the fallback while the socket is down).
final riderSocketConnectedProvider = Provider<bool>(
  (ref) =>
      ref.watch(riderSocketControllerProvider) == RiderSocketStatus.connected,
);

final riderSocketControllerProvider =
    NotifierProvider<RiderSocketController, RiderSocketStatus>(
      RiderSocketController.new,
    );

/// Runs the rider socket while an ACTIVE rider is online (offers only reach
/// online riders, and a task keeps the rider online), and routes its
/// events:
/// - `offer.new` / `offer.withdrawn` / `offer.expired` → the offer
///   controller (through [SocketOfferEvents]); a withdrawn offer's alert is
///   removed.
/// - `task.updated` → re-read `GET /rider/tasks/current/` and home.
/// - `cash.updated` → re-read the cash summary (home) and the ledger.
/// - Every (re)connect → re-read the current offer and task (06 §4.1: the
///   socket does not replay what was missed).
class RiderSocketController extends Notifier<RiderSocketStatus> {
  @override
  RiderSocketStatus build() {
    if (!ref.watch(riderSocketEnabledProvider) ||
        !ref.watch(riderWorkActiveProvider)) {
      return RiderSocketStatus.disconnected;
    }
    final online = ref.watch(
      shiftControllerProvider.select((shift) => shift.isOnline),
    );
    final client = ref.watch(riderSocketClientProvider);
    if (!online) {
      unawaited(client.stop());
      return RiderSocketStatus.disconnected;
    }
    final statuses = client.statuses.listen(_onStatus);
    final messages = client.messages.listen(handle);
    // A session that ends (logout, refresh token rejected) stops the socket
    // at once, before the account state catches up.
    final session = ref.watch(sessionManagerProvider).statusStream.listen((
      status,
    ) {
      if (status == SessionStatus.signedOut) unawaited(client.stop());
    });
    ref.onDispose(() {
      statuses.cancel();
      messages.cancel();
      session.cancel();
      // Offline, signed out or no longer ACTIVE: close the socket. A
      // rebuild that stays online starts it again right away.
      unawaited(client.stop());
    });
    client.start();
    return client.status;
  }

  void _onStatus(RiderSocketStatus status) {
    if (!ref.mounted) return;
    final wasConnected = state == RiderSocketStatus.connected;
    state = status;
    if (status == RiderSocketStatus.connected && !wasConnected) {
      // Catch up on what happened while the socket was down.
      unawaited(ref.read(offerControllerProvider.notifier).refresh());
      unawaited(ref.read(taskFlowControllerProvider.notifier).load());
    }
  }

  /// Routes one server event (public for tests).
  void handle(RiderSocketMessage message) {
    if (!ref.mounted) return;
    switch (message) {
      case SocketOfferNew(:final received):
        ref.read(socketOfferEventsProvider).add(OfferArrived(received));
      case SocketOfferEnded(:final offerId, :final reason):
        ref
            .read(socketOfferEventsProvider)
            .add(
              OfferWithdrawn(offerId, reason: OfferEndReason.fromWire(reason)),
            );
        unawaited(
          ref
              .read(offerAlertNotificationsProvider)
              .dismiss(id: OfferAlertNotifications.offerNotificationId)
              .catchError(
                (Object e) => debugPrint('dismiss alert: ${e.runtimeType}'),
              ),
        );
      case SocketTaskUpdated():
        unawaited(ref.read(taskFlowControllerProvider.notifier).load());
        ref.invalidate(todaySummaryProvider);
        ref.invalidate(inboxUnreadCountProvider);
      case SocketCashUpdated():
        ref
          ..invalidate(todaySummaryProvider)
          ..invalidate(cashLedgerProvider);
      case SocketAuthOk() || SocketPong() || SocketError():
      case UnknownSocketMessage():
        break;
    }
  }
}
