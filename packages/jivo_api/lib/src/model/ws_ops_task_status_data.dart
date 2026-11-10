// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_ops_task_status_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOpsTaskStatusData {
  /// Returns a new [WsOpsTaskStatusData] instance.
  WsOpsTaskStatusData({
    required this.taskId,

    required this.orderId,

    required this.orderNumber,

    required this.storeId,

    required this.status,

    required this.previousStatus,

    required this.riderId,

    required this.assignmentMode,

    required this.attemptCount,

    required this.updatedAt,
  });

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @JsonKey(name: r'store_id', required: true, includeIfNull: false)
  final int storeId;

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsOpsTaskStatusDataStatusEnum.unknownDefaultOpenApi,
  )
  final WsOpsTaskStatusDataStatusEnum status;

  /// null when unknown: just created, or changed twice in one transaction.
  @JsonKey(
    name: r'previous_status',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        WsOpsTaskStatusDataPreviousStatusEnum.unknownDefaultOpenApi,
  )
  final WsOpsTaskStatusDataPreviousStatusEnum? previousStatus;

  @JsonKey(name: r'rider_id', required: true, includeIfNull: true)
  final int? riderId;

  /// null before a rider is assigned.
  @JsonKey(
    name: r'assignment_mode',
    required: true,
    includeIfNull: true,
    unknownEnumValue:
        WsOpsTaskStatusDataAssignmentModeEnum.unknownDefaultOpenApi,
  )
  final WsOpsTaskStatusDataAssignmentModeEnum? assignmentMode;

  /// Offers made in the current search round.
  @JsonKey(name: r'attempt_count', required: true, includeIfNull: false)
  final int attemptCount;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOpsTaskStatusData &&
          other.taskId == taskId &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.storeId == storeId &&
          other.status == status &&
          other.previousStatus == previousStatus &&
          other.riderId == riderId &&
          other.assignmentMode == assignmentMode &&
          other.attemptCount == attemptCount &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      taskId.hashCode +
      orderId.hashCode +
      orderNumber.hashCode +
      storeId.hashCode +
      status.hashCode +
      (previousStatus == null ? 0 : previousStatus.hashCode) +
      (riderId == null ? 0 : riderId.hashCode) +
      (assignmentMode == null ? 0 : assignmentMode.hashCode) +
      attemptCount.hashCode +
      updatedAt.hashCode;

  factory WsOpsTaskStatusData.fromJson(Map<String, dynamic> json) =>
      _$WsOpsTaskStatusDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOpsTaskStatusDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsOpsTaskStatusDataStatusEnum {
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

  const WsOpsTaskStatusDataStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

/// null when unknown: just created, or changed twice in one transaction.
enum WsOpsTaskStatusDataPreviousStatusEnum {
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

  const WsOpsTaskStatusDataPreviousStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

/// null before a rider is assigned.
enum WsOpsTaskStatusDataAssignmentModeEnum {
  @JsonValue(r'AUTO')
  AUTO(r'AUTO'),
  @JsonValue(r'MANUAL')
  MANUAL(r'MANUAL'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsOpsTaskStatusDataAssignmentModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
