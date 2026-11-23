import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show JivoApi, OrderTrack, TrackRoute;
import 'package:jivo_core/jivo_core.dart';

import '../../orders/domain/order.dart';
import '../domain/order_track.dart';
import '../domain/route_geometry.dart';

/// Live tracking data. Phase 5 binds `GET /orders/{id}/track/` (polling);
/// Phase 6 adds the WebSocket with polling as the fallback.
abstract interface class TrackRepository {
  Future<OrderTrack> fetch(int orderId);
}

/// `GET /orders/{id}/track/` (`orders_track`, P5 slice 5.3). Another
/// user's order is 404. `rider` is null until a rider is assigned and
/// `delivery_otp` is sent only while `OUT_FOR_DELIVERY`; both stay null
/// until the backend's slice 5.3 lands, and the cards stay hidden.
class ApiTrackRepository implements TrackRepository {
  const ApiTrackRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<OrderTrack> fetch(int orderId) async {
    try {
      final track = (await _api.getOrdersApi().ordersTrack(id: orderId)).data!;
      return orderTrackFromApi(track);
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }
}

/// Maps the generated `OrderTrack`. A rider photo is kept only when it is
/// an `https` URL (the server sends a short-lived signed link); a blank
/// OTP or phone counts as none.
OrderTrack orderTrackFromApi(api.OrderTrack t) {
  final rider = t.rider;
  final lat = rider?.lat;
  final lng = rider?.lng;
  final photo = rider?.photo;
  final photoUri = photo == null ? null : Uri.tryParse(photo);
  final otp = t.deliveryOtp?.trim();
  return OrderTrack(
    orderId: t.orderId,
    orderNumber: t.orderNumber,
    status: OrderStatus.fromWire(t.status.value),
    storeName: t.store.name,
    store: TrackPoint(t.store.lat, t.store.lng),
    destination: TrackPoint(t.destination.lat, t.destination.lng),
    // The live ETA once the server has one (T-612); the promise otherwise.
    // Null once the order is finished.
    etaAt: t.etaAt == null ? null : (t.liveEtaAt ?? t.etaAt),
    rider: rider == null
        ? null
        : TrackRider(
            name: rider.name,
            phone: _blankToNull(rider.phone),
            photoUrl:
                photoUri != null &&
                    photoUri.scheme == 'https' &&
                    photoUri.host.isNotEmpty
                ? photo
                : null,
            location: lat == null || lng == null ? null : TrackPoint(lat, lng),
            updatedAt: rider.updatedAt,
            heading: rider.heading,
            vehicle: RiderVehicle.fromWire(rider.vehicleType?.value),
            serverStale: rider.isStale,
          ),
    deliveryOtp: otp == null || otp.isEmpty ? null : otp,
    taskStatus: DeliveryTaskStatus.fromWire(t.taskStatus?.value),
    route: _route(t.route),
    distanceRemainingM: t.distanceRemainingM,
    timeline: TrackTimeline(
      current: t.progress.current?.value,
      outcome: TrackOutcome.fromWire(t.progress.outcome?.value),
      steps: [
        for (final s in t.progress.steps)
          TrackStepState(
            key: s.key.value,
            label: s.label,
            done: s.done,
            at: s.at,
          ),
      ],
    ),
    serverTime: t.serverTime,
  );
}

/// The route as sent; dropped when its leg is unknown to this build.
TrackRoute? _route(api.TrackRoute? r) {
  if (r == null) return null;
  final leg = RouteLeg.fromWire(r.leg.value);
  if (leg == null || r.polyline.isEmpty) return null;
  return TrackRoute(
    leg: leg,
    polyline: r.polyline,
    distanceM: r.distanceM,
    durationS: r.durationS,
    computedAt: r.computedAt,
    trafficAware: r.trafficAware,
  );
}

/// Null for a missing or blank value. The rider's phone is sent only while
/// OUT_FOR_DELIVERY and only to the order's owner (DL-56); without it the
/// rider card stays and the call button is hidden.
String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The build without tracking (staging/prod until orders are enabled there,
/// see `trackingAvailableProvider`).
class UnavailableTrackRepository implements TrackRepository {
  const UnavailableTrackRepository();

  @override
  Future<OrderTrack> fetch(int orderId) async =>
      throw const ApiError(code: ApiErrorCode.serviceUnavailable);
}

/// Fake tracking for the lookahead UI (`FAKE_API=true` and tests): each
/// fetch moves the order on — confirmed, packing, then the rider rides from
/// the store to the customer in [ridePings] steps (the last one at the
/// door, task `AT_CUSTOMER`), then delivered; with [failDelivery], delivery
/// failed and then returned instead.
class FakeTrackRepository implements TrackRepository {
  FakeTrackRepository({
    this.ridePings = 6,
    DateTime Function()? clock,
    this.startStep = 0,
    this.failDelivery = false,
  }) : _clock = clock ?? DateTime.now;

  final int ridePings;
  final int startStep;

  /// End in DELIVERY_FAILED, then RETURNED, instead of DELIVERED.
  final bool failDelivery;
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
      _ when !failDelivery => OrderStatus.delivered,
      _ when riding == ridePings => OrderStatus.deliveryFailed,
      _ => OrderStatus.returned,
    };
    final out = status == OrderStatus.outForDelivery;
    final ended = !status.isActive;
    final task = switch (status) {
      OrderStatus.accepted => DeliveryTaskStatus.searching,
      OrderStatus.packing => DeliveryTaskStatus.assigned,
      OrderStatus.outForDelivery when riding == ridePings - 1 =>
        DeliveryTaskStatus.atCustomer,
      OrderStatus.outForDelivery => DeliveryTaskStatus.pickedUp,
      OrderStatus.deliveryFailed => DeliveryTaskStatus.returning,
      OrderStatus.returned => DeliveryTaskStatus.returned,
      _ => DeliveryTaskStatus.delivered,
    };
    final fraction = out ? riding / ridePings : 0.0;
    final riderAt = out
        ? TrackPoint(
            store.lat + (home.lat - store.lat) * fraction,
            store.lng + (home.lng - store.lng) * fraction,
          )
        : store;
    final hasRider = step != 0 && !ended;
    final remaining = out
        ? (distanceMeters(riderAt, home)).round()
        : (hasRider ? distanceMeters(store, home).round() : null);
    return OrderTrack(
      orderId: orderId,
      orderNumber: 'JV-261104-${orderId.toString().padLeft(6, '0')}',
      status: status,
      storeName: 'Jivo Connaught Place',
      store: store,
      destination: home,
      etaAt: ended || status == OrderStatus.deliveryFailed
          ? null
          : now.add(Duration(minutes: out ? (ridePings - riding) * 2 : 14)),
      rider: !hasRider
          ? null
          : TrackRider(
              name: 'Ravi Kumar',
              phone: '+919000000099',
              location: riderAt,
              updatedAt: now,
              heading: out ? bearingDegrees(store, home) : null,
              vehicle: RiderVehicle.scooter,
            ),
      deliveryOtp: out ? '4821' : null,
      taskStatus: task,
      route: !hasRider
          ? null
          : TrackRoute(
              leg: out ? RouteLeg.toCustomer : RouteLeg.toStore,
              polyline: encodePolyline(out ? [riderAt, home] : [store, store]),
              distanceM: remaining ?? 0,
              durationS: out ? (ridePings - riding) * 120 : 0,
              computedAt: now,
            ),
      distanceRemainingM: remaining,
      timeline: fakeTimeline(status, task, now),
      serverTime: now,
    );
  }
}

/// The 8 steps the way the server reports them (`live_tracking`), for the
/// fake only: the real app never derives steps.
TrackTimeline fakeTimeline(
  OrderStatus status,
  DeliveryTaskStatus? task,
  DateTime at,
) {
  final reached = switch (status) {
    OrderStatus.placed => 0,
    OrderStatus.accepted => 1,
    OrderStatus.packing => task == DeliveryTaskStatus.assigned ? 3 : 1,
    OrderStatus.packed => 3,
    OrderStatus.outForDelivery => task == DeliveryTaskStatus.atCustomer ? 6 : 5,
    OrderStatus.delivered => 7,
    OrderStatus.deliveryFailed || OrderStatus.returned => 5,
    _ => -1,
  };
  const labels = [
    'Order confirmed',
    'Preparing your order',
    'Packed',
    'Rider assigned',
    'Picked up',
    'On the way',
    'Arriving',
    'Delivered',
  ];
  final steps = [
    for (final (i, step) in TrackStep.values.indexed)
      TrackStepState(
        key: step.wireValue,
        label: labels[i],
        done: i <= reached,
        at: i <= reached ? at : null,
      ),
  ];
  return TrackTimeline(
    steps: steps,
    current: reached < 0 ? null : TrackStep.values[reached].wireValue,
    outcome: switch (status) {
      OrderStatus.delivered => TrackOutcome.delivered,
      OrderStatus.cancelled => TrackOutcome.cancelled,
      OrderStatus.deliveryFailed => TrackOutcome.deliveryFailed,
      OrderStatus.returned => TrackOutcome.returned,
      _ => null,
    },
  );
}
