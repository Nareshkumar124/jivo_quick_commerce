import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// The phone's clock (tests override it). Rider-fix staleness uses it with
/// the offset to the server's clock (`server_time`), so a wrong phone clock
/// never makes an old fix look live.
final trackClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// How current the tracking data is (`tracking-layout` §3): app state only.
enum TrackFreshMode { live, polling, stale }

@immutable
class TrackFreshness {
  const TrackFreshness(this.mode, this.lastUpdatedAt);

  final TrackFreshMode mode;

  /// The phone's time when track data was last received.
  final DateTime? lastUpdatedAt;
}

/// How long the socket must be down before "Live" turns into "Updated".
const trackLiveDebounce = Duration(seconds: 5);

/// One order's live tracking: `GET /orders/{id}/track/`, then the order
/// socket's `order.status`, `rider.location`, `order.eta` and (T-821)
/// `order.route` messages. Older fixes and routes are dropped.
/// While the socket is down it polls every [trackPollIntervalProvider]
/// until the order is finished; when the socket is (back) up it re-reads
/// `track/` once and stops polling. A failed refresh keeps the last data.
class TrackController extends AsyncNotifier<OrderTrack> {
  TrackController(this.orderId);

  final int orderId;
  Timer? _timer;
  OrderSocket? _socket;
  Timer? _debounce;
  bool _showLive = false;
  bool _stale = false;
  DateTime? _lastUpdatedAt;
  Duration _clockOffset = Duration.zero;
  late DateTime Function() _clock;

  /// The freshness line's state.
  final ValueNotifier<TrackFreshness> freshness = ValueNotifier(
    const TrackFreshness(TrackFreshMode.polling, null),
  );

  void _publish({bool received = false}) {
    if (received) {
      _lastUpdatedAt = _clock();
      _stale = false;
    }
    final mode = _stale
        ? TrackFreshMode.stale
        : (_showLive ? TrackFreshMode.live : TrackFreshMode.polling);
    freshness.value = TrackFreshness(mode, _lastUpdatedAt);
  }

  /// The server's clock now (the phone's clock plus the offset seen on the
  /// last `track/` read), for the rider fix's age.
  DateTime serverNow() => _clock().toUtc().add(_clockOffset);

  void _learnClock(OrderTrack track) {
    final server = track.serverTime;
    if (server != null) {
      _clockOffset = server.toUtc().difference(_clock().toUtc());
    }
  }

  /// Whether updates arrive over the socket right now (no polling).
  bool get live => _socket?.live.value ?? false;

  @override
  Future<OrderTrack> build() async {
    _clock = ref.watch(trackClockProvider);
    ref.onDispose(() {
      _timer?.cancel();
      _debounce?.cancel();
    });
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
    _learnClock(track);
    _showLive = live;
    _schedule(track);
    _publish(received: true);
    return track;
  }

  void _onLiveChanged(bool isLive) {
    if (!ref.mounted) return;
    _debounce?.cancel();
    if (isLive) {
      _showLive = true;
      _publish();
    } else if (_showLive) {
      _debounce = Timer(trackLiveDebounce, () {
        _showLive = false;
        _publish();
      });
    }
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
    _publish(received: true);
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
      final fetched = await ref.read(trackRepositoryProvider).fetch(orderId);
      if (!ref.mounted) return;
      _learnClock(fetched);
      // A fix or route the socket brought while the read was in flight is
      // newer than the read's: keep it (no marker jumping back).
      final track = mergeTrackRead(state.value, fetched);
      state = AsyncData(track);
      _publish(received: true);
      _schedule(track);
    } catch (error) {
      if (!ref.mounted) return;
      final last = state.value;
      if (last == null) {
        state = AsyncError(error, StackTrace.current);
      } else {
        _stale = true;
        _publish();
        _schedule(last);
      }
    }
  }
}

final trackProvider = AsyncNotifierProvider.autoDispose
    .family<TrackController, OrderTrack, int>(TrackController.new);
