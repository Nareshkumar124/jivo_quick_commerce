// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_task_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'recent_task.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RecentTask {
  /// Returns a new [RecentTask] instance.
  RecentTask({
    required this.id,

    required this.orderNumber,

    required this.status,

    required this.endedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

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

  @JsonKey(name: r'ended_at', required: true, includeIfNull: false)
  final DateTime endedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentTask &&
          other.id == id &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.endedAt == endedAt;

  @override
  int get hashCode =>
      id.hashCode + orderNumber.hashCode + status.hashCode + endedAt.hashCode;

  factory RecentTask.fromJson(Map<String, dynamic> json) =>
      _$RecentTaskFromJson(json);

  Map<String, dynamic> toJson() => _$RecentTaskToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
