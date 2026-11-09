import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../data/order_socket.dart';
import '../domain/order_socket_event.dart';
import '../domain/order_track.dart';
import 'order_live.dart';

/// Re-fetch interval while the tracking screen is open and the socket is
/// down (`02 §7`, `06 §4.1`: polling is the fallback). Tests set zero: no
/// polling.
final trackPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

/// One order's live tracking: `GET /orders/{id}/track/`, then the order
/// socket's `order.status`, `rider.location` and `order.eta` messages.
/// While the socket is down it polls every [trackPollIntervalProvider]
/// until the order is finished; when the socket is (back) up it re-reads
/// `track/` once and stops polling. A failed refresh keeps the last data.
class TrackController extends AsyncNotifier<OrderTrack> {
  TrackController(this.orderId);

  final int orderId;
  Timer? _timer;
  OrderSocket? _socket;

  /// Whether updates arrive over the socket right now (no polling).
  bool get live => _socket?.live.value ?? false;

  @override
  Future<OrderTrack> build() async {
    ref.onDispose(() => _timer?.cancel());
    final socket = ref.watch(orderSocketProvider(orderId));
    _socket = socket;
    if (socket != null) {
      final sub = socket.events.listen(_onEvent);
      void onLive() => _onLiveChanged(socket.live.value);
      socket.live.addListener(onLive);
      ref.onDispose(() {
        unawaited(sub.cancel());
        socket.live.removeListener(onLive);
      });
    }
    final track = await ref.read(trackRepositoryProvider).fetch(orderId);
    _schedule(track);
    return track;
  }

  void _onLiveChanged(bool isLive) {
    if (!ref.mounted) return;
    if (isLive) {
      _timer?.cancel();
      // Messages may have been missed while down: re-read once (`06 §4.1`).
      if (state.hasValue) unawaited(poll());
    } else {
      final last = state.value;
      if (last != null) _schedule(last);
    }
  }

  void _onEvent(OrderSocketEvent event) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return; // The first fetch is still running.
    final next = applyOrderSocketEvent(current, event);
    if (next == null) {
      unawaited(poll());
    } else if (!identical(next, current)) {
      state = AsyncData(next);
    }
  }

  void _schedule(OrderTrack track) {
    _timer?.cancel();
    if (live) return;
    final interval = ref.read(trackPollIntervalProvider);
    if (interval == Duration.zero || !track.status.isActive) return;
    _timer = Timer(interval, poll);
  }

  /// Fetches now (the timer, a socket event, or pull to refresh).
  Future<void> poll() async {
    try {
      final track = await ref.read(trackRepositoryProvider).fetch(orderId);
      if (!ref.mounted) return;
      state = AsyncData(track);
      _schedule(track);
    } catch (error) {
      if (!ref.mounted) return;
      final last = state.value;
      if (last == null) {
        state = AsyncError(error, StackTrace.current);
      } else {
        _schedule(last);
      }
    }
  }
}

final trackProvider = AsyncNotifierProvider.autoDispose
    .family<TrackController, OrderTrack, int>(TrackController.new);
