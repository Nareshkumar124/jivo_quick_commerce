// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/task_item.dart';
import 'package:jivo_api/src/model/delivery_task_status_enum.dart';
import 'package:jivo_api/src/model/rider_payment_type_enum.dart';
import 'package:jivo_api/src/model/task_earnings.dart';
import 'package:jivo_api/src/model/delivery_fail_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_history_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskHistoryDetail {
  /// Returns a new [TaskHistoryDetail] instance.
  TaskHistoryDetail({
    required this.taskId,

    required this.orderNumber,

    required this.status,

    required this.storeName,

    required this.dropLocality,

    required this.distanceKm,

    required this.payout,

    required this.completedAt,

    required this.paymentType,

    required this.codCollected,

    required this.items,

    required this.itemCount,

    required this.assignedAt,

    required this.pickedUpAt,

    required this.deliveredAt,

    required this.failedAt,

    required this.failReason,

    required this.returnedAt,

    required this.cancelledAt,

    required this.earnings,
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

  @JsonKey(
    name: r'payment_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
  )
  final RiderPaymentTypeEnum paymentType;

  /// COD delivered: the amount collected (cash or UPI); else null.
  @JsonKey(name: r'cod_collected', required: true, includeIfNull: true)
  final String? codCollected;

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<TaskItem> items;

  /// Units delivered or returned.
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  @JsonKey(name: r'assigned_at', required: true, includeIfNull: true)
  final DateTime? assignedAt;

  @JsonKey(name: r'picked_up_at', required: true, includeIfNull: true)
  final DateTime? pickedUpAt;

  @JsonKey(name: r'delivered_at', required: true, includeIfNull: true)
  final DateTime? deliveredAt;

  @JsonKey(name: r'failed_at', required: true, includeIfNull: true)
  final DateTime? failedAt;

  @JsonKey(
    name: r'fail_reason',
    required: true,
    includeIfNull: true,
    unknownEnumValue: DeliveryFailReasonEnum.unknownDefaultOpenApi,
  )
  final DeliveryFailReasonEnum? failReason;

  @JsonKey(name: r'returned_at', required: true, includeIfNull: true)
  final DateTime? returnedAt;

  @JsonKey(name: r'cancelled_at', required: true, includeIfNull: true)
  final DateTime? cancelledAt;

  /// The pay lines for this task (from pickup); null if none.
  @JsonKey(name: r'earnings', required: true, includeIfNull: true)
  final TaskEarnings? earnings;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskHistoryDetail &&
          other.taskId == taskId &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.storeName == storeName &&
          other.dropLocality == dropLocality &&
          other.distanceKm == distanceKm &&
          other.payout == payout &&
          other.completedAt == completedAt &&
          other.paymentType == paymentType &&
          other.codCollected == codCollected &&
          other.items == items &&
          other.itemCount == itemCount &&
          other.assignedAt == assignedAt &&
          other.pickedUpAt == pickedUpAt &&
          other.deliveredAt == deliveredAt &&
          other.failedAt == failedAt &&
          other.failReason == failReason &&
          other.returnedAt == returnedAt &&
          other.cancelledAt == cancelledAt &&
          other.earnings == earnings;

  @override
  int get hashCode =>
      taskId.hashCode +
      orderNumber.hashCode +
      status.hashCode +
      storeName.hashCode +
      dropLocality.hashCode +
      (distanceKm == null ? 0 : distanceKm.hashCode) +
      (payout == null ? 0 : payout.hashCode) +
      completedAt.hashCode +
      paymentType.hashCode +
      (codCollected == null ? 0 : codCollected.hashCode) +
      items.hashCode +
      itemCount.hashCode +
      (assignedAt == null ? 0 : assignedAt.hashCode) +
      (pickedUpAt == null ? 0 : pickedUpAt.hashCode) +
      (deliveredAt == null ? 0 : deliveredAt.hashCode) +
      (failedAt == null ? 0 : failedAt.hashCode) +
      (failReason == null ? 0 : failReason.hashCode) +
      (returnedAt == null ? 0 : returnedAt.hashCode) +
      (cancelledAt == null ? 0 : cancelledAt.hashCode) +
      (earnings == null ? 0 : earnings.hashCode);

  factory TaskHistoryDetail.fromJson(Map<String, dynamic> json) =>
      _$TaskHistoryDetailFromJson(json);

  Map<String, dynamic> toJson() => _$TaskHistoryDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
