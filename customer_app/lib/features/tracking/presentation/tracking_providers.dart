import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/repositories.dart';
import '../domain/order_track.dart';

/// Re-fetch interval while the tracking screen is open (`02 §7`: polling
/// is the fallback when the socket drops). Tests set zero: no polling.
final trackPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

/// One order's live tracking, refreshed every [trackPollIntervalProvider]
/// until the order is finished. A failed refresh keeps the last data.
class TrackController extends AsyncNotifier<OrderTrack> {
  TrackController(this.orderId);

  final int orderId;
  Timer? _timer;

  @override
  Future<OrderTrack> build() async {
    ref.onDispose(() => _timer?.cancel());
    final track = await ref.read(trackRepositoryProvider).fetch(orderId);
    _schedule(track);
    return track;
  }

  void _schedule(OrderTrack track) {
    _timer?.cancel();
    final interval = ref.read(trackPollIntervalProvider);
    if (interval == Duration.zero || !track.status.isActive) return;
    _timer = Timer(interval, poll);
  }

  /// Fetches now (the timer, or pull to refresh).
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
