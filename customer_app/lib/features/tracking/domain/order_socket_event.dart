import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:jivo_api/jivo_api.dart'
    show WsAuthOkData, WsOrderEtaData, WsOrderStatusData, WsRiderLocationData;

import '../../orders/domain/order.dart';
import 'order_track.dart';

/// What the order socket (`/ws/v1/orders/{id}/`, `06 §4`) tells the app.
/// Every message carries the current state, not a diff, so a duplicate or
/// a missed one is harmless.
@immutable
sealed class OrderSocketEvent {
  const OrderSocketEvent(this.orderId);

  final int orderId;
}

/// `order.status`: the order's status (and the server's ETA).
class OrderStatusEvent extends OrderSocketEvent {
  const OrderStatusEvent({
    required int orderId,
    required this.status,
    this.etaAt,
    this.updatedAt,
  }) : super(orderId);

  final OrderStatus status;
  final DateTime? etaAt;
  final DateTime? updatedAt;
}

/// `rider.location`: where the assigned rider is.
class RiderLocationEvent extends OrderSocketEvent {
  const RiderLocationEvent({
    required int orderId,
    required this.location,
    required this.recordedAt,
    this.heading,
  }) : super(orderId);

  final TrackPoint location;
  final DateTime recordedAt;
  final double? heading;
}

/// `order.eta`: a new server ETA.
class OrderEtaEvent extends OrderSocketEvent {
  const OrderEtaEvent({
    required int orderId,
    required this.etaAt,
    required this.etaMinutes,
  }) : super(orderId);

  final DateTime etaAt;
  final int etaMinutes;
}

/// One decoded server frame: an [OrderSocketEvent], a control message, or
/// [WsIgnored] for anything this build doesn't know (a newer server, a
/// malformed frame). Unknown messages are never an error.
@immutable
sealed class WsFrame {
  const WsFrame();
}

class WsEvent extends WsFrame {
  const WsEvent(this.event);

  final OrderSocketEvent event;
}

/// `auth.ok`: the socket is authorised until [expiresAt].
class WsAuthOk extends WsFrame {
  const WsAuthOk({this.expiresAt});

  final DateTime? expiresAt;
}

class WsPong extends WsFrame {
  const WsPong();
}

/// `error`: the server rejected a client message (the socket stays open).
class WsServerError extends WsFrame {
  const WsServerError(this.code);

  final String code;
}

class WsIgnored extends WsFrame {
  const WsIgnored(this.type);

  final String? type;
}

/// Decodes one text frame with the generated `Ws…Data` models
/// (`apps.realtime.contract`). Never throws.
WsFrame parseWsFrame(Object? raw) {
  if (raw is! String) return const WsIgnored(null);
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return const WsIgnored(null);
    final type = json['type'];
    final data = json['data'];
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    switch (type) {
      case 'order.status':
        final d = WsOrderStatusData.fromJson(map);
        return WsEvent(
          OrderStatusEvent(
            orderId: d.orderId,
            // The raw value: a status this build doesn't know is `unknown`.
            status: OrderStatus.fromWire(map['status'] as String?),
            etaAt: d.etaAt,
            updatedAt: d.updatedAt,
          ),
        );
      case 'rider.location':
        final d = WsRiderLocationData.fromJson(map);
        return WsEvent(
          RiderLocationEvent(
            orderId: d.orderId,
            location: TrackPoint(d.lat, d.lng),
            recordedAt: d.recordedAt,
            heading: d.heading,
          ),
        );
      case 'order.eta':
        final d = WsOrderEtaData.fromJson(map);
        return WsEvent(
          OrderEtaEvent(
            orderId: d.orderId,
            etaAt: d.etaAt,
            etaMinutes: d.etaMinutes,
          ),
        );
      case 'auth.ok':
        return WsAuthOk(expiresAt: WsAuthOkData.fromJson(map).expiresAt);
      case 'pong':
        return const WsPong();
      case 'error':
        return WsServerError('${map['code'] ?? ''}');
      default:
        return WsIgnored(type is String ? type : null);
    }
  } catch (_) {
    return const WsIgnored(null);
  }
}

/// Applies a socket event to the last tracking data. Returns null when the
/// event can't be applied locally and `track/` must be re-read: a new
/// status (the OTP and the rider card are only on REST, `06 §4.1`), or a
/// rider location before any rider is known.
OrderTrack? applyOrderSocketEvent(OrderTrack track, OrderSocketEvent event) {
  if (event.orderId != track.orderId) return track;
  switch (event) {
    case OrderStatusEvent(:final status, :final etaAt):
      if (status != track.status) return null;
      return etaAt == null || etaAt == track.etaAt
          ? track
          : track.copyWith(etaAt: etaAt);
    case RiderLocationEvent(:final location, :final recordedAt):
      final rider = track.rider;
      if (rider == null) return null;
      final last = rider.updatedAt;
      // Out-of-order pings: keep the newer fix.
      if (last != null && recordedAt.isBefore(last)) return track;
      return track.copyWith(
        rider: rider.copyWith(location: location, updatedAt: recordedAt),
      );
    case OrderEtaEvent(:final etaAt):
      return track.copyWith(etaAt: etaAt);
  }
}
