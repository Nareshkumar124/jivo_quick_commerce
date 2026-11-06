// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'arrived_customer_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ArrivedCustomerRequest {
  /// Returns a new [ArrivedCustomerRequest] instance.
  ArrivedCustomerRequest({
    required this.lat,

    required this.lng,

    this.accuracy,

    this.overrideReason,
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

  /// Metres; widens the geofence by at most 50 m.
  // minimum: 0
  @JsonKey(name: r'accuracy', required: false, includeIfNull: false)
  final double? accuracy;

  /// Outside the geofence (wrong pin, gated society...): a short reason lets the rider mark arrival anyway. Logged for ops.
  @JsonKey(name: r'override_reason', required: false, includeIfNull: false)
  final String? overrideReason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrivedCustomerRequest &&
          other.lat == lat &&
          other.lng == lng &&
          other.accuracy == accuracy &&
          other.overrideReason == overrideReason;

  @override
  int get hashCode =>
      lat.hashCode +
      lng.hashCode +
      (accuracy == null ? 0 : accuracy.hashCode) +
      overrideReason.hashCode;

  factory ArrivedCustomerRequest.fromJson(Map<String, dynamic> json) =>
      _$ArrivedCustomerRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ArrivedCustomerRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
