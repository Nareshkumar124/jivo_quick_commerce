// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_ops_rider_location_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOpsRiderLocationData {
  /// Returns a new [WsOpsRiderLocationData] instance.
  WsOpsRiderLocationData({
    required this.riderId,

    required this.storeId,

    required this.orderId,

    required this.lat,

    required this.lng,

    required this.heading,

    required this.recordedAt,
  });

  @JsonKey(name: r'rider_id', required: true, includeIfNull: false)
  final int riderId;

  @JsonKey(name: r'store_id', required: true, includeIfNull: false)
  final int storeId;

  /// The order of the rider's active task, or null.
  @JsonKey(name: r'order_id', required: true, includeIfNull: true)
  final int? orderId;

  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @JsonKey(name: r'heading', required: true, includeIfNull: true)
  final double? heading;

  @JsonKey(name: r'recorded_at', required: true, includeIfNull: false)
  final DateTime recordedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOpsRiderLocationData &&
          other.riderId == riderId &&
          other.storeId == storeId &&
          other.orderId == orderId &&
          other.lat == lat &&
          other.lng == lng &&
          other.heading == heading &&
          other.recordedAt == recordedAt;

  @override
  int get hashCode =>
      riderId.hashCode +
      storeId.hashCode +
      (orderId == null ? 0 : orderId.hashCode) +
      lat.hashCode +
      lng.hashCode +
      (heading == null ? 0 : heading.hashCode) +
      recordedAt.hashCode;

  factory WsOpsRiderLocationData.fromJson(Map<String, dynamic> json) =>
      _$WsOpsRiderLocationDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOpsRiderLocationDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
