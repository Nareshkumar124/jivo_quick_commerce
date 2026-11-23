import 'package:flutter/foundation.dart';

import 'rider_task.dart';

/// Which way the rider rides now (`RouteLegEnum`): to the store before
/// pickup, to the customer after.
enum NavigationLeg {
  toStore('TO_STORE'),
  toCustomer('TO_CUSTOMER');

  const NavigationLeg(this.wireValue);

  final String wireValue;

  /// Null for a value this build does not know (additive enum change).
  static NavigationLeg? fromWire(String? value) {
    for (final leg in values) {
      if (leg.wireValue == value) return leg;
    }
    return null;
  }
}

/// The road route the server computed for the current leg (`TrackRoute`).
@immutable
class NavigationRoute {
  const NavigationRoute({
    required this.polyline,
    required this.distanceM,
    required this.durationS,
    required this.isRoad,
    this.computedAt,
  });

  /// Google encoded polyline (precision 5) from where the route was
  /// computed to the leg's end. Drawn as is: the app never routes.
  final String polyline;
  final int distanceM;
  final int durationS;

  /// `provider == google`. A straight-line estimate (`haversine`) is a
  /// 2-point line and is labelled as an estimate.
  final bool isRoad;
  final DateTime? computedAt;

  /// The polyline's points, or an empty list when it cannot be decoded.
  List<GeoPoint> get points => decodePolyline(polyline);
}

/// `navigation` on the task body (T-821): where to ride now, and the
/// server's distance and ETA. Null outside ASSIGNED .. AT_CUSTOMER.
///
/// Display only. Geofences, the pickup code, the OTP and COD are still
/// decided by the server on the step actions (agent rule 5).
@immutable
class TaskNavigation {
  const TaskNavigation({
    required this.leg,
    required this.destination,
    this.route,
    this.distanceM,
    this.etaMinutes,
    this.etaAt,
    this.positionAt,
  });

  final NavigationLeg leg;

  /// The store, or the drop pin after pickup.
  final GeoPoint destination;

  /// Null until the server has a position from this rider.
  final NavigationRoute? route;

  /// Road metres to the destination; null without a position.
  final int? distanceM;

  /// Minutes to the destination; 0 once at the store / customer.
  final int? etaMinutes;
  final DateTime? etaAt;

  /// When the position the route starts from was recorded.
  final DateTime? positionAt;
}

/// Decodes a Google encoded polyline (precision 5). Returns what was
/// decoded up to the first malformed chunk: a bad string from the server
/// must not crash the task screen.
List<GeoPoint> decodePolyline(String encoded) {
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  final length = encoded.length;

  int? next() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= length) return null;
      final b = encoded.codeUnitAt(index++) - 63;
      if (b < 0 || b > 63 || shift > 30) return null;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) break;
    }
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < length) {
    final dLat = next();
    final dLng = next();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    final point = GeoPoint(lat / 1e5, lng / 1e5);
    if (point.lat.abs() > 90 || point.lng.abs() > 180) break;
    points.add(point);
  }
  return points;
}

/// Encodes [points] as a Google polyline (precision 5). Used by the fake
/// backend and tests; the real route always comes from the server.
String encodePolyline(List<GeoPoint> points) {
  final out = StringBuffer();
  var lastLat = 0;
  var lastLng = 0;
  void write(int value) {
    var v = value < 0 ? ~(value << 1) : value << 1;
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.lat * 1e5).round();
    final lng = (p.lng * 1e5).round();
    write(lat - lastLat);
    write(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}
