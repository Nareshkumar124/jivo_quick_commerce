// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_task_updated_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsTaskUpdatedData {
  /// Returns a new [WsTaskUpdatedData] instance.
  WsTaskUpdatedData({
    required this.taskId,

    required this.orderId,

    required this.status,

    required this.orderStatus,

    required this.change,
  });

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  /// The task status (08 §3).
  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final String status;

  @JsonKey(
    name: r'order_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum orderStatus;

  @JsonKey(
    name: r'change',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsTaskUpdatedDataChangeEnum.unknownDefaultOpenApi,
  )
  final WsTaskUpdatedDataChangeEnum change;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsTaskUpdatedData &&
          other.taskId == taskId &&
          other.orderId == orderId &&
          other.status == status &&
          other.orderStatus == orderStatus &&
          other.change == change;

  @override
  int get hashCode =>
      taskId.hashCode +
      orderId.hashCode +
      status.hashCode +
      orderStatus.hashCode +
      change.hashCode;

  factory WsTaskUpdatedData.fromJson(Map<String, dynamic> json) =>
      _$WsTaskUpdatedDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsTaskUpdatedDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsTaskUpdatedDataChangeEnum {
  @JsonValue(r'ORDER_PACKED')
  ORDER_PACKED(r'ORDER_PACKED'),
  @JsonValue(r'ORDER_CANCELLED')
  ORDER_CANCELLED(r'ORDER_CANCELLED'),
  @JsonValue(r'AMOUNT_CHANGED')
  AMOUNT_CHANGED(r'AMOUNT_CHANGED'),
  @JsonValue(r'REASSIGNED')
  REASSIGNED(r'REASSIGNED'),
  @JsonValue(r'STATUS_CHANGED')
  STATUS_CHANGED(r'STATUS_CHANGED'),
  @JsonValue(r'ASSIGNED')
  ASSIGNED(r'ASSIGNED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsTaskUpdatedDataChangeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
