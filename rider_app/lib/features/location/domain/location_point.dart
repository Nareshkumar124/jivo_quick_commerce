import 'package:flutter/foundation.dart';

/// One GPS fix taken while the rider is online.
///
/// Mirrors one item of the `POST /api/v1/rider/locations/` batch in
/// `docs/06-backend-modules-and-api.md` §3:
/// `{lat, lng, accuracy, speed, heading, recorded_at}`.
///
/// TODO(api): replace [toJson] with the generated `jivo_api` model once the
/// rider contract exists (P5). [toJson]/[fromJson] are also the on-disk format
/// of the offline buffer, so keep them backwards compatible.
@immutable
class LocationPoint {
  LocationPoint({
    required this.lat,
    required this.lng,
    required DateTime recordedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.isMocked,
  }) : recordedAt = recordedAt.toUtc();

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    accuracy: (json['accuracy'] as num?)?.toDouble(),
    speed: (json['speed'] as num?)?.toDouble(),
    heading: (json['heading'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    isMocked: json['is_mocked'] as bool?,
  );

  final double lat;
  final double lng;

  /// Horizontal accuracy in metres.
  final double? accuracy;

  /// Metres per second.
  final double? speed;

  /// Degrees clockwise from north.
  final double? heading;

  /// Android reported a mock location (fraud signal for the server,
  /// api-requests #5). Null when unknown.
  final bool? isMocked;

  /// When the fix was taken on the device, always UTC. The server orders and
  /// de-duplicates points by this, not by upload time, so buffered points keep
  /// their original time.
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'recorded_at': recordedAt.toIso8601String(),
    if (isMocked != null) 'is_mocked': isMocked,
  };

  @override
  bool operator ==(Object other) =>
      other is LocationPoint &&
      other.lat == lat &&
      other.lng == lng &&
      other.accuracy == accuracy &&
      other.speed == speed &&
      other.heading == heading &&
      other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      Object.hash(lat, lng, accuracy, speed, heading, recordedAt);

  @override
  String toString() =>
      'LocationPoint($lat, $lng, ±${accuracy}m, ${recordedAt.toIso8601String()})';
}
