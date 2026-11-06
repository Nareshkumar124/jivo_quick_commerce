// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'shift_start_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ShiftStartRequest {
  /// Returns a new [ShiftStartRequest] instance.
  ShiftStartRequest({required this.lat, required this.lng, this.accuracy});

  /// Current position (precise location).
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Longitude (WGS84), decimal degrees.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  /// Reported accuracy in metres (optional).
  // minimum: 0
  @JsonKey(name: r'accuracy', required: false, includeIfNull: false)
  final double? accuracy;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftStartRequest &&
          other.lat == lat &&
          other.lng == lng &&
          other.accuracy == accuracy;

  @override
  int get hashCode => lat.hashCode + lng.hashCode + accuracy.hashCode;

  factory ShiftStartRequest.fromJson(Map<String, dynamic> json) =>
      _$ShiftStartRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ShiftStartRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
