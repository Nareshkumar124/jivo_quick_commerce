import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../orders/domain/order.dart';

/// Live tracking (`03 §2.10`, `06 §2.6` `GET /orders/{id}/track/`; `06 §4`
/// WebSocket messages in Phase 6). Phase 4 builds the screen on fake data
/// (lookahead); the shapes follow `06 §2.6` and are confirmed by the P5
/// contract.

@immutable
class TrackPoint {
  const TrackPoint(this.lat, this.lng);

  final double lat;
  final double lng;
}

/// The assigned rider, once there is one.
@immutable
class TrackRider {
  const TrackRider({
    required this.name,
    this.phone,
    this.photoUrl,
    this.location,
    this.updatedAt,
  });

  final String name;

  /// Masked or proxied by the server; the call button dials it.
  final String? phone;
  final String? photoUrl;
  final TrackPoint? location;

  /// When [location] was recorded (UTC).
  final DateTime? updatedAt;
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
  });

  final int orderId;
  final String orderNumber;
  final OrderStatus status;
  final String storeName;
  final TrackPoint store;
  final TrackPoint destination;

  /// The server's ETA (`08 §8`), UTC.
  final DateTime? etaAt;
  final TrackRider? rider;

  /// Sent only while `OUT_FOR_DELIVERY` (`06 §2.6`).
  final String? deliveryOtp;

  /// The delivery task's state (`08 §2`). TODO(api): `track/` does not send
  /// it yet (api-requests: `task_status` on `OrderTrack`); null until then,
  /// and [stage] falls back to the order status.
  final DeliveryTaskStatus? taskStatus;

  /// The delivery step to explain under the status, or null before pickup.
  DeliveryStage? get stage => deliveryStageFor(status, task: taskStatus);

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
