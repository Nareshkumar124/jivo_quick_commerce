// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_rider_location_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsRiderLocationData {
  /// Returns a new [WsRiderLocationData] instance.
  WsRiderLocationData({
    required this.orderId,

    required this.lat,

    required this.lng,

    required this.heading,

    required this.recordedAt,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  /// Degrees from north, or null.
  @JsonKey(name: r'heading', required: true, includeIfNull: true)
  final double? heading;

  /// When the phone recorded the fix (UTC).
  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsRiderLocationData &&
          other.orderId == orderId &&
          other.lat == lat &&
          other.lng == lng &&
          other.heading == heading &&
          other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      orderId.hashCode +
      lat.hashCode +
      lng.hashCode +
      (heading == null ? 0 : heading.hashCode) +
      recordedAt.hashCode;

  factory WsRiderLocationData.fromJson(Map<String, dynamic> json) =>
      _$WsRiderLocationDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsRiderLocationDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
