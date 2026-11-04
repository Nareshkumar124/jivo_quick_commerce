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
