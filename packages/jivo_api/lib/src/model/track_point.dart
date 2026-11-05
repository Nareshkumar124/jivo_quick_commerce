// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_point.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackPoint {
  /// Returns a new [TrackPoint] instance.
  TrackPoint({required this.lat, required this.lng});

  /// Latitude (WGS84).
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Longitude (WGS84).
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => lat.hashCode + lng.hashCode;

  factory TrackPoint.fromJson(Map<String, dynamic> json) =>
      _$TrackPointFromJson(json);

  Map<String, dynamic> toJson() => _$TrackPointToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
