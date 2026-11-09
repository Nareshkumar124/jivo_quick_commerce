import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../data/order_socket.dart';
import '../domain/order_socket_event.dart';

/// The order sockets (`/ws/v1/orders/{id}/`, `06 §4`): real wherever
/// orders are tracked on the API; off with `FAKE_API` (the fake polls).
/// Tests override it.
final orderRealtimeProvider = Provider<OrderRealtime>((ref) {
  if (!ref.watch(trackingAvailableProvider) || isFakeApi(ref)) {
    return const DisabledOrderRealtime();
  }
  return WebSocketOrderRealtime(
    apiBaseUrl: ref.watch(appEnvProvider).apiBaseUrl,
    session: ref.watch(sessionProvider),
  );
});

/// One order's socket, shared by tracking, the order detail and the order
/// list while any of them is open (the server allows 5 sockets per user).
/// Null when realtime is off.
final orderSocketProvider = Provider.autoDispose.family<OrderSocket?, int>((
  ref,
  orderId,
) {
  final socket = ref.watch(orderRealtimeProvider).open(orderId);
  if (socket != null) ref.onDispose(socket.dispose);
  return socket;
});

/// `order.status` messages for one order (the first is the snapshot sent
/// right after `auth.ok`).
final orderStatusEventsProvider = StreamProvider.autoDispose
    .family<OrderStatusEvent, int>((ref, orderId) {
      final socket = ref.watch(orderSocketProvider(orderId));
      if (socket == null) return const Stream.empty();
      return socket.events
          .where((e) => e is OrderStatusEvent)
          .cast<OrderStatusEvent>();
    });

/// How many active orders on "My orders" get a live socket (the rest
/// update on pull to refresh). Worst case 4 sockets per user: these 3 plus
/// one detail or tracking screen for an order not among them (the same
/// order shares its socket). That stays under the server's
/// `WS_MAX_SOCKETS_PER_USER` (5), leaving one spare; a 4429 close only
/// backs off and retries, and polling covers the gap.
const maxLiveOrdersInList = 3;
