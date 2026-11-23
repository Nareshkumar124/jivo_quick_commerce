import 'dart:math' as math;

import 'order_track.dart';

/// Map drawing helpers for live tracking (T-821). Display only: distances
/// and ETAs shown to the customer always come from the server.

/// Decodes a Google encoded polyline (precision 5). A malformed tail is
/// dropped: the points decoded so far are returned, never an exception.
List<TrackPoint> decodePolyline(String encoded) {
  final points = <TrackPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  int? next() {
    var result = 0;
    var shift = 0;
    while (index < encoded.length) {
      final b = encoded.codeUnitAt(index++) - 63;
      if (b < 0 || b > 63) return null;
      result |= (b & 0x1f) << shift;
      shift += 5;
      if (b < 0x20) {
        return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      }
    }
    return null;
  }

  while (index < encoded.length) {
    final dLat = next();
    final dLng = next();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    points.add(TrackPoint(lat / 1e5, lng / 1e5));
  }
  return points;
}

/// Encodes [points] as a Google polyline (precision 5): fakes and tests.
String encodePolyline(List<TrackPoint> points) {
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

/// Great-circle distance in metres.
double distanceMeters(TrackPoint a, TrackPoint b) {
  const r = 6371000.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// The compass bearing from [a] to [b], 0–360 degrees from north.
double bearingDegrees(TrackPoint a, TrackPoint b) {
  final lat1 = _rad(a.lat);
  final lat2 = _rad(b.lat);
  final dLng = _rad(b.lng - a.lng);
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// The point [t] (0–1) of the way from [a] to [b].
TrackPoint lerpPoint(TrackPoint a, TrackPoint b, double t) =>
    TrackPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);

/// The heading [t] of the way from [a] to [b] the short way round
/// (350° → 10° passes north), 0–360.
double lerpHeading(double a, double b, double t) {
  final delta = ((b - a + 540) % 360) - 180;
  return (a + delta * t + 360) % 360;
}

/// The part of the server's route still ahead of the rider: from [rider]
/// to the end, starting after the route point nearest to the rider. The
/// whole route when there is no rider position.
List<TrackPoint> routeAhead(List<TrackPoint> route, TrackPoint? rider) {
  if (rider == null || route.length < 2) return route;
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final d = distanceMeters(route[i], rider);
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  // Past the nearest point when the rider is already beyond it.
  if (best < route.length - 1) {
    final toNext = distanceMeters(rider, route[best + 1]);
    final segment = distanceMeters(route[best], route[best + 1]);
    if (toNext < segment) best++;
  }
  return [rider, ...route.skip(best)];
}

/// The rider's heading for the marker: the server's when sent, else the
/// direction of travel from [previous] when it moved over 5 m, else
/// [fallback].
double? markerHeading({
  required TrackPoint? previous,
  required TrackPoint current,
  double? serverHeading,
  double? fallback,
}) {
  if (serverHeading != null) return serverHeading % 360;
  if (previous != null && distanceMeters(previous, current) > 5) {
    return bearingDegrees(previous, current);
  }
  return fallback;
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;
