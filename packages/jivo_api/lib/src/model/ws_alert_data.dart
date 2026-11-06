// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_alert_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsAlertData {
  /// Returns a new [WsAlertData] instance.
  WsAlertData({
    required this.code,

    required this.message,

    required this.storeId,

    required this.orderId,

    required this.riderId,

    required this.at,
  });

  /// What happened. New codes may come: show `message` for unknown ones.
  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsAlertDataCodeEnum.unknownDefaultOpenApi,
  )
  final WsAlertDataCodeEnum code;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @JsonKey(name: r'store_id', required: true, includeIfNull: true)
  final int? storeId;

  @JsonKey(name: r'order_id', required: true, includeIfNull: true)
  final int? orderId;

  @JsonKey(name: r'rider_id', required: true, includeIfNull: true)
  final int? riderId;

  @JsonKey(name: r'at', required: true, includeIfNull: false)
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsAlertData &&
          other.code == code &&
          other.message == message &&
          other.storeId == storeId &&
          other.orderId == orderId &&
          other.riderId == riderId &&
          other.at == at;

  @override
  int get hashCode =>
      code.hashCode +
      message.hashCode +
      (storeId == null ? 0 : storeId.hashCode) +
      (orderId == null ? 0 : orderId.hashCode) +
      (riderId == null ? 0 : riderId.hashCode) +
      at.hashCode;

  factory WsAlertData.fromJson(Map<String, dynamic> json) =>
      _$WsAlertDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsAlertDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

/// What happened. New codes may come: show `message` for unknown ones.
enum WsAlertDataCodeEnum {
  @JsonValue(r'ACCEPTANCE_SLA_BREACHED')
  ACCEPTANCE_SLA_BREACHED(r'ACCEPTANCE_SLA_BREACHED'),
  @JsonValue(r'LATE_CAPTURE')
  LATE_CAPTURE(r'LATE_CAPTURE'),
  @JsonValue(r'REFUND_FAILED')
  REFUND_FAILED(r'REFUND_FAILED'),
  @JsonValue(r'DELIVERY_FAILED')
  DELIVERY_FAILED(r'DELIVERY_FAILED'),
  @JsonValue(r'DISPATCH_UNASSIGNED')
  DISPATCH_UNASSIGNED(r'DISPATCH_UNASSIGNED'),
  @JsonValue(r'PICKUP_CODE_LOCKED')
  PICKUP_CODE_LOCKED(r'PICKUP_CODE_LOCKED'),
  @JsonValue(r'DELIVERY_OTP_LOCKED')
  DELIVERY_OTP_LOCKED(r'DELIVERY_OTP_LOCKED'),
  @JsonValue(r'STOCK_NOT_COMMITTED')
  STOCK_NOT_COMMITTED(r'STOCK_NOT_COMMITTED'),
  @JsonValue(r'ARRIVAL_GEOFENCE_OVERRIDE')
  ARRIVAL_GEOFENCE_OVERRIDE(r'ARRIVAL_GEOFENCE_OVERRIDE'),
  @JsonValue(r'MOCKED_LOCATION')
  MOCKED_LOCATION(r'MOCKED_LOCATION'),
  @JsonValue(r'RIDER_STALE_ON_TASK')
  RIDER_STALE_ON_TASK(r'RIDER_STALE_ON_TASK'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsAlertDataCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
