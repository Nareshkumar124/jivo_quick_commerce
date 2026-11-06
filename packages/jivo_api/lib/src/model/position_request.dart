// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'position_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PositionRequest {
  /// Returns a new [PositionRequest] instance.
  PositionRequest({required this.lat, required this.lng, this.accuracy});

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

  /// Metres; widens the geofence by at most 50 m.
  // minimum: 0
  @JsonKey(name: r'accuracy', required: false, includeIfNull: false)
  final double? accuracy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositionRequest &&
          other.lat == lat &&
          other.lng == lng &&
          other.accuracy == accuracy;

  @override
  int get hashCode =>
      lat.hashCode + lng.hashCode + (accuracy == null ? 0 : accuracy.hashCode);

  factory PositionRequest.fromJson(Map<String, dynamic> json) =>
      _$PositionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PositionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
