// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_task_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_history_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskHistoryItem {
  /// Returns a new [TaskHistoryItem] instance.
  TaskHistoryItem({
    required this.taskId,

    required this.orderNumber,

    required this.status,

    required this.storeName,

    required this.dropLocality,

    required this.distanceKm,

    required this.payout,

    required this.completedAt,
  });

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  /// DELIVERED, RETURNED or CANCELLED.  * `SEARCHING` - Looking for a rider * `OFFERED` - Offered to a rider * `ASSIGNED` - Rider heading to the store * `AT_STORE` - Rider at the store * `PICKED_UP` - Picked up * `AT_CUSTOMER` - Rider at the drop location * `DELIVERED` - Delivered * `FAILED` - Delivery failed * `RETURNING` - Returning items to the store * `RETURNED` - Items returned to the store * `UNASSIGNED` - No rider found: ops to assign * `CANCELLED` - Cancelled
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
  )
  final DeliveryTaskStatusEnum status;

  @JsonKey(name: r'store_name', required: true, includeIfNull: false)
  final String storeName;

  @JsonKey(name: r'drop_locality', required: true, includeIfNull: false)
  final String dropLocality;

  /// Null for a task cancelled before pickup.
  @JsonKey(name: r'distance_km', required: true, includeIfNull: true)
  final String? distanceKm;

  /// Earned for this task (all lines); null if nothing was earned.
  @JsonKey(name: r'payout', required: true, includeIfNull: true)
  final String? payout;

  /// When it ended.
  @JsonKey(name: r'completed_at', required: true, includeIfNull: false)
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskHistoryItem &&
          other.taskId == taskId &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.storeName == storeName &&
          other.dropLocality == dropLocality &&
          other.distanceKm == distanceKm &&
          other.payout == payout &&
          other.completedAt == completedAt;

  @override
  int get hashCode =>
      taskId.hashCode +
      orderNumber.hashCode +
      status.hashCode +
      storeName.hashCode +
      dropLocality.hashCode +
      (distanceKm == null ? 0 : distanceKm.hashCode) +
      (payout == null ? 0 : payout.hashCode) +
      completedAt.hashCode;

  factory TaskHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$TaskHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$TaskHistoryItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
