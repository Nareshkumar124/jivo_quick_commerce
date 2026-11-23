import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../orders/domain/order.dart';

/// Live tracking (`03 §2.10`, `06 §2.6` `GET /orders/{id}/track/`; `06 §4`
/// WebSocket messages). T-821 adds the rider's heading and vehicle, the
/// server's road route, the distance left and the 8 tracking steps.

@immutable
class TrackPoint {
  const TrackPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is TrackPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'TrackPoint($lat, $lng)';
}

/// The rider's vehicle (`VehicleTypeEnum`, T-821). The number plate is
/// never sent.
enum RiderVehicle {
  bicycle('BICYCLE'),
  eBike('E_BIKE'),
  motorbike('MOTORBIKE'),
  scooter('SCOOTER');

  const RiderVehicle(this.wireValue);

  final String wireValue;

  /// Null for a missing value or one this build doesn't know.
  static RiderVehicle? fromWire(String? value) =>
      values.where((v) => v.wireValue == value).firstOrNull;
}

/// How long a rider fix counts as live (`TRACKING_STALE_SECONDS`, 60 s,
/// T-821).
const riderFixStaleAfter = Duration(seconds: 60);

/// "Not passed" for copyWith parameters where null is a real value.
const Object _keep = Object();

/// The assigned rider, once there is one.
@immutable
class TrackRider {
  const TrackRider({
    required this.name,
    this.phone,
    this.photoUrl,
    this.location,
    this.updatedAt,
    this.heading,
    this.vehicle,
    this.serverStale = false,
  });

  final String name;

  /// Masked or proxied by the server; the call button dials it.
  final String? phone;
  final String? photoUrl;
  final TrackPoint? location;

  /// When [location] was recorded (UTC).
  final DateTime? updatedAt;

  /// Degrees from north (T-821); null when unknown.
  final double? heading;
  final RiderVehicle? vehicle;

  /// The server's `is_stale` when [location] came from `track/`. A newer
  /// socket fix clears it.
  final bool serverStale;

  /// Whether the fix is too old to show as live at [serverNow] (the
  /// server's clock, `TrackController.serverNow`). No fix counts as stale.
  bool isStaleAt(DateTime serverNow) {
    final at = updatedAt;
    if (location == null || at == null || serverStale) return true;
    return serverNow.toUtc().difference(at.toUtc()) > riderFixStaleAfter;
  }

  /// [heading] is replaced even with null (pass nothing to keep it): a
  /// newer fix without a heading must not keep the old one, so the marker
  /// turns by the direction of travel instead (03 §2.8, T-821).
  TrackRider copyWith({
    TrackPoint? location,
    DateTime? updatedAt,
    Object? heading = _keep,
    bool? serverStale,
  }) => TrackRider(
    name: name,
    phone: phone,
    photoUrl: photoUrl,
    location: location ?? this.location,
    updatedAt: updatedAt ?? this.updatedAt,
    heading: identical(heading, _keep) ? this.heading : heading as double?,
    vehicle: vehicle,
    serverStale: serverStale ?? this.serverStale,
  );

  /// The rider without the per-ping fields (position, heading, time).
  TrackRider get withoutFix => TrackRider(
    name: name,
    phone: phone,
    photoUrl: photoUrl,
    vehicle: vehicle,
  );

  @override
  bool operator ==(Object other) =>
      other is TrackRider &&
      other.name == name &&
      other.phone == phone &&
      other.photoUrl == photoUrl &&
      other.location == location &&
      other.updatedAt == updatedAt &&
      other.heading == heading &&
      other.vehicle == vehicle &&
      other.serverStale == serverStale;

  @override
  int get hashCode => Object.hash(
    name,
    phone,
    photoUrl,
    location,
    updatedAt,
    heading,
    vehicle,
    serverStale,
  );
}

/// Which leg the rider is on (`RouteLegEnum`, T-821).
enum RouteLeg {
  toStore('TO_STORE'),
  toCustomer('TO_CUSTOMER');

  const RouteLeg(this.wireValue);

  final String wireValue;

  static RouteLeg? fromWire(String? value) =>
      values.where((l) => l.wireValue == value).firstOrNull;
}

/// The rider's current leg as the server computed it (`route` in `track/`,
/// `order.route` on the socket; T-821). Drawn as sent, never recomputed.
@immutable
class TrackRoute {
  const TrackRoute({
    required this.leg,
    required this.polyline,
    required this.distanceM,
    required this.durationS,
    required this.computedAt,
    this.trafficAware = false,
  });

  final RouteLeg leg;

  /// Google encoded polyline, precision 5.
  final String polyline;
  final int distanceM;
  final int durationS;
  final DateTime computedAt;
  final bool trafficAware;

  @override
  bool operator ==(Object other) =>
      other is TrackRoute &&
      other.leg == leg &&
      other.polyline == polyline &&
      other.distanceM == distanceM &&
      other.durationS == durationS &&
      other.computedAt == computedAt &&
      other.trafficAware == trafficAware;

  @override
  int get hashCode => Object.hash(
    leg,
    polyline,
    distanceM,
    durationS,
    computedAt,
    trafficAware,
  );
}

/// The customer's 8 tracking steps (`TrackingStepEnum`, T-821), in order.
enum TrackStep {
  confirmed('CONFIRMED'),
  preparing('PREPARING'),
  packed('PACKED'),
  riderAssigned('RIDER_ASSIGNED'),
  pickedUp('PICKED_UP'),
  onTheWay('ON_THE_WAY'),
  arriving('ARRIVING'),
  delivered('DELIVERED');

  const TrackStep(this.wireValue);

  final String wireValue;

  /// Null for a missing value or one this build doesn't know.
  static TrackStep? fromWire(String? value) =>
      values.where((s) => s.wireValue == value).firstOrNull;
}

/// How a finished order ended (`TrackingOutcomeEnum`); null while active.
enum TrackOutcome {
  delivered('DELIVERED'),
  cancelled('CANCELLED'),
  deliveryFailed('DELIVERY_FAILED'),
  returned('RETURNED');

  const TrackOutcome(this.wireValue);

  final String wireValue;

  static TrackOutcome? fromWire(String? value) =>
      values.where((s) => s.wireValue == value).firstOrNull;
}

/// One step as the server reports it. [step] is null for a key this build
/// doesn't know; the server's English [label] is shown then.
@immutable
class TrackStepState {
  const TrackStepState({
    required this.key,
    required this.label,
    required this.done,
    this.at,
  });

  /// The wire key (`CONFIRMED`, ...).
  final String key;
  final String label;
  final bool done;

  /// When it happened (UTC); null for derived steps or not yet.
  final DateTime? at;

  TrackStep? get step => TrackStep.fromWire(key);

  @override
  bool operator ==(Object other) =>
      other is TrackStepState &&
      other.key == key &&
      other.label == label &&
      other.done == done &&
      other.at == at;

  @override
  int get hashCode => Object.hash(key, label, done, at);
}

/// `progress` in `track/` (T-821): the server's steps, from real order and
/// task states. The app never derives a step itself.
@immutable
class TrackTimeline {
  const TrackTimeline({required this.steps, this.current, this.outcome});

  final List<TrackStepState> steps;

  /// The wire key of the last step reached, or null.
  final String? current;
  final TrackOutcome? outcome;

  @override
  bool operator ==(Object other) =>
      other is TrackTimeline &&
      other.current == current &&
      other.outcome == outcome &&
      listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hash(current, outcome, Object.hashAll(steps));
}

@immutable
class OrderTrack {
  const OrderTrack({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.store,
    required this.destination,
    this.storeName = '',
    this.etaAt,
    this.rider,
    this.deliveryOtp,
    this.taskStatus,
    this.route,
    this.distanceRemainingM,
    this.timeline,
    this.serverTime,
  });

  final int orderId;
  final String orderNumber;
  final OrderStatus status;
  final String storeName;
  final TrackPoint store;
  final TrackPoint destination;

  /// The server's ETA (`08 §8`), UTC: the live one when the server has it.
  final DateTime? etaAt;
  final TrackRider? rider;

  /// Sent only while `OUT_FOR_DELIVERY` (`06 §2.6`).
  final String? deliveryOtp;

  /// The delivery task's state (`08 §2`, `track/` `task_status`); null
  /// before there is a task, and [stage] falls back to the order status.
  final DeliveryTaskStatus? taskStatus;

  /// The rider's current leg (T-821); null without a rider position.
  final TrackRoute? route;

  /// Road metres the rider still rides to the customer (T-821), or null.
  final int? distanceRemainingM;

  /// The 8 steps (T-821); null from a server without them.
  final TrackTimeline? timeline;

  /// The server's clock when this was read (`server_time`).
  final DateTime? serverTime;

  /// DL-56: the delivery OTP and the rider's phone are for
  /// `OUT_FOR_DELIVERY` only. The server sends null otherwise; the screens
  /// also hide them on any other status (P5-TC-124).
  bool get outForDelivery => status == OrderStatus.outForDelivery;

  /// [deliveryOtp] while [outForDelivery], else null.
  String? get visibleDeliveryOtp => outForDelivery ? deliveryOtp : null;

  /// A copy with live socket data applied (`06 §4`).
  OrderTrack copyWith({
    DateTime? etaAt,
    TrackRider? rider,
    TrackRoute? route,
    int? distanceRemainingM,
  }) => OrderTrack(
    orderId: orderId,
    orderNumber: orderNumber,
    status: status,
    store: store,
    destination: destination,
    storeName: storeName,
    etaAt: etaAt ?? this.etaAt,
    rider: rider ?? this.rider,
    deliveryOtp: deliveryOtp,
    taskStatus: taskStatus,
    route: route ?? this.route,
    distanceRemainingM: distanceRemainingM ?? this.distanceRemainingM,
    timeline: timeline,
    serverTime: serverTime,
  );

  /// This track without the per-ping fields (rider fix, route, distance,
  /// server time): widgets that don't show them `select` it, so a location
  /// ping does not rebuild them.
  OrderTrack get settled => OrderTrack(
    orderId: orderId,
    orderNumber: orderNumber,
    status: status,
    store: store,
    destination: destination,
    storeName: storeName,
    etaAt: etaAt,
    rider: rider?.withoutFix,
    deliveryOtp: deliveryOtp,
    taskStatus: taskStatus,
    timeline: timeline,
  );

  /// The delivery step to explain under the status, or null before pickup.
  DeliveryStage? get stage => deliveryStageFor(status, task: taskStatus);

  /// Whether the server tracks the rider now (its tracking gate, `06 §4`:
  /// task ASSIGNED, AT_STORE, PICKED_UP or AT_CUSTOMER).
  bool get riderTracked =>
      status.isActive &&
      const {
        DeliveryTaskStatus.assigned,
        DeliveryTaskStatus.atStore,
        DeliveryTaskStatus.pickedUp,
        DeliveryTaskStatus.atCustomer,
      }.contains(taskStatus);

  /// How far the rider is from the store towards the customer, 0–1, for
  /// the route sketch (display only; the ETA is the server's).
  double get progress {
    final at = rider?.location;
    if (at == null || status != OrderStatus.outForDelivery) {
      return status == OrderStatus.delivered ? 1 : 0;
    }
    final total = _distance(store, destination);
    if (total == 0) return 1;
    return (_distance(store, at) / total).clamp(0, 1).toDouble();
  }

  static double _distance(TrackPoint a, TrackPoint b) {
    final dLat = a.lat - b.lat;
    final dLng = a.lng - b.lng;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  @override
  bool operator ==(Object other) =>
      other is OrderTrack &&
      other.orderId == orderId &&
      other.orderNumber == orderNumber &&
      other.status == status &&
      other.storeName == storeName &&
      other.store == store &&
      other.destination == destination &&
      other.etaAt == etaAt &&
      other.rider == rider &&
      other.deliveryOtp == deliveryOtp &&
      other.taskStatus == taskStatus &&
      other.route == route &&
      other.distanceRemainingM == distanceRemainingM &&
      other.timeline == timeline &&
      other.serverTime == serverTime;

  @override
  int get hashCode => Object.hash(
    orderId,
    orderNumber,
    status,
    storeName,
    store,
    destination,
    etaAt,
    rider,
    deliveryOtp,
    taskStatus,
    route,
    distanceRemainingM,
    timeline,
    serverTime,
  );
}

/// The delivery task's states (`DeliveryTaskStatusEnum`, `08 §2`).
enum DeliveryTaskStatus {
  searching('SEARCHING'),
  offered('OFFERED'),
  assigned('ASSIGNED'),
  atStore('AT_STORE'),
  pickedUp('PICKED_UP'),
  atCustomer('AT_CUSTOMER'),
  delivered('DELIVERED'),
  failed('FAILED'),
  returning('RETURNING'),
  returned('RETURNED'),
  unassigned('UNASSIGNED'),
  cancelled('CANCELLED'),

  /// A state this build doesn't know (a newer server).
  unknown(null);

  const DeliveryTaskStatus(this.wireValue);

  final String? wireValue;

  /// Null for a missing value; [unknown] for one this build doesn't know.
  static DeliveryTaskStatus? fromWire(String? value) => value == null
      ? null
      : values.firstWhere(
          (s) => s.wireValue != null && s.wireValue == value,
          orElse: () => unknown,
        );
}

/// The customer-facing delivery steps after packing (`03 §2.10`,
/// `08 §1`/`§2`): picked up, the rider arriving at the door, delivery
/// failed (items going back) and returned to the store.
enum DeliveryStage { pickedUp, arriving, failed, returned }

/// The stage for an order [status], refined by the task state when the
/// server sends it: `AT_CUSTOMER` while out for delivery is "arriving".
/// Null before pickup and once delivered or cancelled.
DeliveryStage? deliveryStageFor(
  OrderStatus status, {
  DeliveryTaskStatus? task,
}) => switch (status) {
  OrderStatus.outForDelivery when task == DeliveryTaskStatus.atCustomer =>
    DeliveryStage.arriving,
  OrderStatus.outForDelivery => DeliveryStage.pickedUp,
  OrderStatus.deliveryFailed => DeliveryStage.failed,
  OrderStatus.returned => DeliveryStage.returned,
  _ => null,
};
