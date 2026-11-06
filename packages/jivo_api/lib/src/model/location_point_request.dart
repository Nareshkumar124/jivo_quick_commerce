// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location_point_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocationPointRequest {
  /// Returns a new [LocationPointRequest] instance.
  LocationPointRequest({
    required this.lat,

    required this.lng,

    required this.accuracy,

    this.speed,

    this.heading,

    required this.recordedAt,

    this.isMocked = false,
  });

  /// Latitude (WGS84), decimal degrees.
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Longitude (WGS84), decimal degrees.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  /// Horizontal accuracy, metres.
  // minimum: 0
  @JsonKey(name: r'accuracy', required: true, includeIfNull: false)
  final double accuracy;

  /// Metres per second.
  // minimum: 0
  @JsonKey(name: r'speed', required: false, includeIfNull: false)
  final double? speed;

  /// Degrees from north, 0-360.
  // minimum: 0
  // maximum: 360
  @JsonKey(name: r'heading', required: false, includeIfNull: false)
  final double? heading;

  /// When the fix was taken (UTC). The de-duplication key with the rider.
  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  /// True when Android reports a mock location (fraud signal, api-requests #5).
  @JsonKey(
    defaultValue: false,
    name: r'is_mocked',
    required: false,
    includeIfNull: false,
  )
  final bool? isMocked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationPointRequest &&
          other.lat == lat &&
          other.lng == lng &&
          other.accuracy == accuracy &&
          other.speed == speed &&
          other.heading == heading &&
          other.recordedAt == recordedAt &&
          other.isMocked == isMocked;

  @override
  int get hashCode =>
      lat.hashCode +
      lng.hashCode +
      accuracy.hashCode +
      (speed == null ? 0 : speed.hashCode) +
      (heading == null ? 0 : heading.hashCode) +
      recordedAt.hashCode +
      isMocked.hashCode;

  factory LocationPointRequest.fromJson(Map<String, dynamic> json) =>
      _$LocationPointRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LocationPointRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
