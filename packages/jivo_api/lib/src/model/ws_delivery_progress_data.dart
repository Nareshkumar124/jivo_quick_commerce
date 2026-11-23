// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_delivery_progress_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsDeliveryProgressData {
  /// Returns a new [WsDeliveryProgressData] instance.
  WsDeliveryProgressData({
    required this.orderId,

    required this.orderNumber,

    required this.storeId,

    required this.taskId,

    required this.riderId,

    required this.orderStatus,

    required this.taskStatus,

    required this.distanceRemainingM,

    required this.liveEtaAt,

    required this.liveEtaMinutes,

    required this.isDelayed,

    required this.updatedAt,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @JsonKey(name: r'store_id', required: true, includeIfNull: false)
  final int storeId;

  @JsonKey(name: r'task_id', required: true, includeIfNull: true)
  final int? taskId;

  @JsonKey(name: r'rider_id', required: true, includeIfNull: true)
  final int? riderId;

  @JsonKey(
    name: r'order_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum orderStatus;

  @JsonKey(
    name: r'task_status',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        WsDeliveryProgressDataTaskStatusEnum.unknownDefaultOpenApi,
  )
  final WsDeliveryProgressDataTaskStatusEnum? taskStatus;

  @JsonKey(name: r'distance_remaining_m', required: true, includeIfNull: true)
  final int? distanceRemainingM;

  @JsonKey(name: r'live_eta_at', required: true, includeIfNull: true)
  final DateTime? liveEtaAt;

  @JsonKey(name: r'live_eta_minutes', required: true, includeIfNull: true)
  final int? liveEtaMinutes;

  @JsonKey(name: r'is_delayed', required: true, includeIfNull: false)
  final bool isDelayed;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsDeliveryProgressData &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.storeId == storeId &&
          other.taskId == taskId &&
          other.riderId == riderId &&
          other.orderStatus == orderStatus &&
          other.taskStatus == taskStatus &&
          other.distanceRemainingM == distanceRemainingM &&
          other.liveEtaAt == liveEtaAt &&
          other.liveEtaMinutes == liveEtaMinutes &&
          other.isDelayed == isDelayed &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      orderId.hashCode +
      orderNumber.hashCode +
      storeId.hashCode +
      (taskId == null ? 0 : taskId.hashCode) +
      (riderId == null ? 0 : riderId.hashCode) +
      orderStatus.hashCode +
      (taskStatus == null ? 0 : taskStatus.hashCode) +
      (distanceRemainingM == null ? 0 : distanceRemainingM.hashCode) +
      (liveEtaAt == null ? 0 : liveEtaAt.hashCode) +
      (liveEtaMinutes == null ? 0 : liveEtaMinutes.hashCode) +
      isDelayed.hashCode +
      updatedAt.hashCode;

  factory WsDeliveryProgressData.fromJson(Map<String, dynamic> json) =>
      _$WsDeliveryProgressDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsDeliveryProgressDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsDeliveryProgressDataTaskStatusEnum {
  @JsonValue(r'SEARCHING')
  SEARCHING(r'SEARCHING'),
  @JsonValue(r'OFFERED')
  OFFERED(r'OFFERED'),
  @JsonValue(r'ASSIGNED')
  ASSIGNED(r'ASSIGNED'),
  @JsonValue(r'AT_STORE')
  AT_STORE(r'AT_STORE'),
  @JsonValue(r'PICKED_UP')
  PICKED_UP(r'PICKED_UP'),
  @JsonValue(r'AT_CUSTOMER')
  AT_CUSTOMER(r'AT_CUSTOMER'),
  @JsonValue(r'DELIVERED')
  DELIVERED(r'DELIVERED'),
  @JsonValue(r'FAILED')
  FAILED(r'FAILED'),
  @JsonValue(r'RETURNING')
  RETURNING(r'RETURNING'),
  @JsonValue(r'RETURNED')
  RETURNED(r'RETURNED'),
  @JsonValue(r'UNASSIGNED')
  UNASSIGNED(r'UNASSIGNED'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsDeliveryProgressDataTaskStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
