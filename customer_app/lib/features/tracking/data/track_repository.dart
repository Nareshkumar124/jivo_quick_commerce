import 'package:jivo_core/jivo_core.dart';

import '../../orders/domain/order.dart';
import '../domain/order_track.dart';

/// Live tracking data. Phase 5 binds `GET /orders/{id}/track/` (polling);
/// Phase 6 adds the WebSocket with polling as the fallback.
abstract interface class TrackRepository {
  Future<OrderTrack> fetch(int orderId);
}

/// TODO(api): `GET /orders/{id}/track/` is a Phase 5 endpoint, not in
/// jivo_api yet. Until then the real-API build has no tracking (the order
/// detail hides "Track order").
class UnavailableTrackRepository implements TrackRepository {
  const UnavailableTrackRepository();

  @override
  Future<OrderTrack> fetch(int orderId) async =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);
}

/// Fake tracking for the lookahead UI (`FAKE_API=true` and tests): each
/// fetch moves the order on — confirmed, packing, then the rider rides from
/// the store to the customer in [ridePings] steps, then delivered.
class FakeTrackRepository implements TrackRepository {
  FakeTrackRepository({
    this.ridePings = 6,
    DateTime Function()? clock,
    this.startStep = 0,
  }) : _clock = clock ?? DateTime.now;

  final int ridePings;
  final int startStep;
  final DateTime Function() _clock;
  final _steps = <int, int>{};

  /// When set, the next fetch throws it once.
  Object? failNext;

  static const store = TrackPoint(28.6315, 77.2167);
  static const home = TrackPoint(28.6400, 77.2300);

  @override
  Future<OrderTrack> fetch(int orderId) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    final step = _steps[orderId] ?? startStep;
    _steps[orderId] = step + 1;
    final now = _clock().toUtc();
    final riding = step - 2;
    final status = switch (step) {
      0 => OrderStatus.accepted,
      1 => OrderStatus.packing,
      _ when riding < ridePings => OrderStatus.outForDelivery,
      _ => OrderStatus.delivered,
    };
    final out = status == OrderStatus.outForDelivery;
    final fraction = out ? riding / ridePings : 0.0;
    return OrderTrack(
      orderId: orderId,
      orderNumber: 'JV-261104-${orderId.toString().padLeft(6, '0')}',
      status: status,
      storeName: 'Jivo Connaught Place',
      store: store,
      destination: home,
      etaAt: status == OrderStatus.delivered
          ? null
          : now.add(Duration(minutes: out ? (ridePings - riding) * 2 : 14)),
      rider: step == 0
          ? null
          : TrackRider(
              name: 'Ravi Kumar',
              phone: '+919000000099',
              location: out
                  ? TrackPoint(
                      store.lat + (home.lat - store.lat) * fraction,
                      store.lng + (home.lng - store.lng) * fraction,
                    )
                  : store,
              updatedAt: now,
            ),
      deliveryOtp: out ? '4821' : null,
    );
  }
}
