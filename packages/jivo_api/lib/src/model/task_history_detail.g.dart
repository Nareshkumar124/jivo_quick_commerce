// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_history_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskHistoryDetailCWProxy {
  TaskHistoryDetail taskId(int taskId);

  TaskHistoryDetail orderNumber(String orderNumber);

  TaskHistoryDetail status(DeliveryTaskStatusEnum status);

  TaskHistoryDetail storeName(String storeName);

  TaskHistoryDetail dropLocality(String dropLocality);

  TaskHistoryDetail distanceKm(String? distanceKm);

  TaskHistoryDetail payout(String? payout);

  TaskHistoryDetail completedAt(DateTime completedAt);

  TaskHistoryDetail paymentType(RiderPaymentTypeEnum paymentType);

  TaskHistoryDetail codCollected(String? codCollected);

  TaskHistoryDetail items(List<TaskItem> items);

  TaskHistoryDetail itemCount(int itemCount);

  TaskHistoryDetail assignedAt(DateTime? assignedAt);

  TaskHistoryDetail pickedUpAt(DateTime? pickedUpAt);

  TaskHistoryDetail deliveredAt(DateTime? deliveredAt);

  TaskHistoryDetail failedAt(DateTime? failedAt);

  TaskHistoryDetail failReason(DeliveryFailReasonEnum? failReason);

  TaskHistoryDetail returnedAt(DateTime? returnedAt);

  TaskHistoryDetail cancelledAt(DateTime? cancelledAt);

  TaskHistoryDetail earnings(TaskEarnings? earnings);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskHistoryDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskHistoryDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskHistoryDetail call({
    int taskId,
    String orderNumber,
    DeliveryTaskStatusEnum status,
    String storeName,
    String dropLocality,
    String? distanceKm,
    String? payout,
    DateTime completedAt,
    RiderPaymentTypeEnum paymentType,
    String? codCollected,
    List<TaskItem> items,
    int itemCount,
    DateTime? assignedAt,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    DateTime? failedAt,
    DeliveryFailReasonEnum? failReason,
    DateTime? returnedAt,
    DateTime? cancelledAt,
    TaskEarnings? earnings,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskHistoryDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskHistoryDetail.copyWith.fieldName(...)`
class _$TaskHistoryDetailCWProxyImpl implements _$TaskHistoryDetailCWProxy {
  const _$TaskHistoryDetailCWProxyImpl(this._value);

  final TaskHistoryDetail _value;

  @override
  TaskHistoryDetail taskId(int taskId) => this(taskId: taskId);

  @override
  TaskHistoryDetail orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  TaskHistoryDetail status(DeliveryTaskStatusEnum status) =>
      this(status: status);

  @override
  TaskHistoryDetail storeName(String storeName) => this(storeName: storeName);

  @override
  TaskHistoryDetail dropLocality(String dropLocality) =>
      this(dropLocality: dropLocality);

  @override
  TaskHistoryDetail distanceKm(String? distanceKm) =>
      this(distanceKm: distanceKm);

  @override
  TaskHistoryDetail payout(String? payout) => this(payout: payout);

  @override
  TaskHistoryDetail completedAt(DateTime completedAt) =>
      this(completedAt: completedAt);

  @override
  TaskHistoryDetail paymentType(RiderPaymentTypeEnum paymentType) =>
      this(paymentType: paymentType);

  @override
  TaskHistoryDetail codCollected(String? codCollected) =>
      this(codCollected: codCollected);

  @override
  TaskHistoryDetail items(List<TaskItem> items) => this(items: items);

  @override
  TaskHistoryDetail itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  TaskHistoryDetail assignedAt(DateTime? assignedAt) =>
      this(assignedAt: assignedAt);

  @override
  TaskHistoryDetail pickedUpAt(DateTime? pickedUpAt) =>
      this(pickedUpAt: pickedUpAt);

  @override
  TaskHistoryDetail deliveredAt(DateTime? deliveredAt) =>
      this(deliveredAt: deliveredAt);

  @override
  TaskHistoryDetail failedAt(DateTime? failedAt) => this(failedAt: failedAt);

  @override
  TaskHistoryDetail failReason(DeliveryFailReasonEnum? failReason) =>
      this(failReason: failReason);

  @override
  TaskHistoryDetail returnedAt(DateTime? returnedAt) =>
      this(returnedAt: returnedAt);

  @override
  TaskHistoryDetail cancelledAt(DateTime? cancelledAt) =>
      this(cancelledAt: cancelledAt);

  @override
  TaskHistoryDetail earnings(TaskEarnings? earnings) =>
      this(earnings: earnings);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskHistoryDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskHistoryDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskHistoryDetail call({
    Object? taskId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? storeName = const $CopyWithPlaceholder(),
    Object? dropLocality = const $CopyWithPlaceholder(),
    Object? distanceKm = const $CopyWithPlaceholder(),
    Object? payout = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
    Object? paymentType = const $CopyWithPlaceholder(),
    Object? codCollected = const $CopyWithPlaceholder(),
    Object? items = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? assignedAt = const $CopyWithPlaceholder(),
    Object? pickedUpAt = const $CopyWithPlaceholder(),
    Object? deliveredAt = const $CopyWithPlaceholder(),
    Object? failedAt = const $CopyWithPlaceholder(),
    Object? failReason = const $CopyWithPlaceholder(),
    Object? returnedAt = const $CopyWithPlaceholder(),
    Object? cancelledAt = const $CopyWithPlaceholder(),
    Object? earnings = const $CopyWithPlaceholder(),
  }) {
    return TaskHistoryDetail(
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as DeliveryTaskStatusEnum,
      storeName: storeName == const $CopyWithPlaceholder()
          ? _value.storeName
          // ignore: cast_nullable_to_non_nullable
          : storeName as String,
      dropLocality: dropLocality == const $CopyWithPlaceholder()
          ? _value.dropLocality
          // ignore: cast_nullable_to_non_nullable
          : dropLocality as String,
      distanceKm: distanceKm == const $CopyWithPlaceholder()
          ? _value.distanceKm
          // ignore: cast_nullable_to_non_nullable
          : distanceKm as String?,
      payout: payout == const $CopyWithPlaceholder()
          ? _value.payout
          // ignore: cast_nullable_to_non_nullable
          : payout as String?,
      completedAt: completedAt == const $CopyWithPlaceholder()
          ? _value.completedAt
          // ignore: cast_nullable_to_non_nullable
          : completedAt as DateTime,
      paymentType: paymentType == const $CopyWithPlaceholder()
          ? _value.paymentType
          // ignore: cast_nullable_to_non_nullable
          : paymentType as RiderPaymentTypeEnum,
      codCollected: codCollected == const $CopyWithPlaceholder()
          ? _value.codCollected
          // ignore: cast_nullable_to_non_nullable
          : codCollected as String?,
      items: items == const $CopyWithPlaceholder()
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<TaskItem>,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      assignedAt: assignedAt == const $CopyWithPlaceholder()
          ? _value.assignedAt
          // ignore: cast_nullable_to_non_nullable
          : assignedAt as DateTime?,
      pickedUpAt: pickedUpAt == const $CopyWithPlaceholder()
          ? _value.pickedUpAt
          // ignore: cast_nullable_to_non_nullable
          : pickedUpAt as DateTime?,
      deliveredAt: deliveredAt == const $CopyWithPlaceholder()
          ? _value.deliveredAt
          // ignore: cast_nullable_to_non_nullable
          : deliveredAt as DateTime?,
      failedAt: failedAt == const $CopyWithPlaceholder()
          ? _value.failedAt
          // ignore: cast_nullable_to_non_nullable
          : failedAt as DateTime?,
      failReason: failReason == const $CopyWithPlaceholder()
          ? _value.failReason
          // ignore: cast_nullable_to_non_nullable
          : failReason as DeliveryFailReasonEnum?,
      returnedAt: returnedAt == const $CopyWithPlaceholder()
          ? _value.returnedAt
          // ignore: cast_nullable_to_non_nullable
          : returnedAt as DateTime?,
      cancelledAt: cancelledAt == const $CopyWithPlaceholder()
          ? _value.cancelledAt
          // ignore: cast_nullable_to_non_nullable
          : cancelledAt as DateTime?,
      earnings: earnings == const $CopyWithPlaceholder()
          ? _value.earnings
          // ignore: cast_nullable_to_non_nullable
          : earnings as TaskEarnings?,
    );
  }
}

extension $TaskHistoryDetailCopyWith on TaskHistoryDetail {
  /// Returns a callable class that can be used as follows: `instanceOfTaskHistoryDetail.copyWith(...)` or like so:`instanceOfTaskHistoryDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskHistoryDetailCWProxy get copyWith =>
      _$TaskHistoryDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskHistoryDetail _$TaskHistoryDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TaskHistoryDetail',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'task_id',
            'order_number',
            'status',
            'store_name',
            'drop_locality',
            'distance_km',
            'payout',
            'completed_at',
            'payment_type',
            'cod_collected',
            'items',
            'item_count',
            'assigned_at',
            'picked_up_at',
            'delivered_at',
            'failed_at',
            'fail_reason',
            'returned_at',
            'cancelled_at',
            'earnings',
          ],
        );
        final val = TaskHistoryDetail(
          taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$DeliveryTaskStatusEnumEnumMap,
              v,
              unknownValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          storeName: $checkedConvert('store_name', (v) => v as String),
          dropLocality: $checkedConvert('drop_locality', (v) => v as String),
          distanceKm: $checkedConvert('distance_km', (v) => v as String?),
          payout: $checkedConvert('payout', (v) => v as String?),
          completedAt: $checkedConvert(
            'completed_at',
            (v) => DateTime.parse(v as String),
          ),
          paymentType: $checkedConvert(
            'payment_type',
            (v) => $enumDecode(
              _$RiderPaymentTypeEnumEnumMap,
              v,
              unknownValue: RiderPaymentTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          codCollected: $checkedConvert('cod_collected', (v) => v as String?),
          items: $checkedConvert(
            'items',
            (v) => (v as List<dynamic>)
                .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
          assignedAt: $checkedConvert(
            'assigned_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          pickedUpAt: $checkedConvert(
            'picked_up_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          deliveredAt: $checkedConvert(
            'delivered_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          failedAt: $checkedConvert(
            'failed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          failReason: $checkedConvert(
            'fail_reason',
            (v) => $enumDecodeNullable(
              _$DeliveryFailReasonEnumEnumMap,
              v,
              unknownValue: DeliveryFailReasonEnum.unknownDefaultOpenApi,
            ),
          ),
          returnedAt: $checkedConvert(
            'returned_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          cancelledAt: $checkedConvert(
            'cancelled_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          earnings: $checkedConvert(
            'earnings',
            (v) => v == null
                ? null
                : TaskEarnings.fromJson(v as Map<String, dynamic>),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'taskId': 'task_id',
        'orderNumber': 'order_number',
        'storeName': 'store_name',
        'dropLocality': 'drop_locality',
        'distanceKm': 'distance_km',
        'completedAt': 'completed_at',
        'paymentType': 'payment_type',
        'codCollected': 'cod_collected',
        'itemCount': 'item_count',
        'assignedAt': 'assigned_at',
        'pickedUpAt': 'picked_up_at',
        'deliveredAt': 'delivered_at',
        'failedAt': 'failed_at',
        'failReason': 'fail_reason',
        'returnedAt': 'returned_at',
        'cancelledAt': 'cancelled_at',
      },
    );

Map<String, dynamic> _$TaskHistoryDetailToJson(TaskHistoryDetail instance) =>
    <String, dynamic>{
      'task_id': instance.taskId,
      'order_number': instance.orderNumber,
      'status': _$DeliveryTaskStatusEnumEnumMap[instance.status]!,
      'store_name': instance.storeName,
      'drop_locality': instance.dropLocality,
      'distance_km': instance.distanceKm,
      'payout': instance.payout,
      'completed_at': instance.completedAt.toIso8601String(),
      'payment_type': _$RiderPaymentTypeEnumEnumMap[instance.paymentType]!,
      'cod_collected': instance.codCollected,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'item_count': instance.itemCount,
      'assigned_at': instance.assignedAt?.toIso8601String(),
      'picked_up_at': instance.pickedUpAt?.toIso8601String(),
      'delivered_at': instance.deliveredAt?.toIso8601String(),
      'failed_at': instance.failedAt?.toIso8601String(),
      'fail_reason': _$DeliveryFailReasonEnumEnumMap[instance.failReason],
      'returned_at': instance.returnedAt?.toIso8601String(),
      'cancelled_at': instance.cancelledAt?.toIso8601String(),
      'earnings': instance.earnings?.toJson(),
    };

const _$DeliveryTaskStatusEnumEnumMap = {
  DeliveryTaskStatusEnum.SEARCHING: 'SEARCHING',
  DeliveryTaskStatusEnum.OFFERED: 'OFFERED',
  DeliveryTaskStatusEnum.ASSIGNED: 'ASSIGNED',
  DeliveryTaskStatusEnum.AT_STORE: 'AT_STORE',
  DeliveryTaskStatusEnum.PICKED_UP: 'PICKED_UP',
  DeliveryTaskStatusEnum.AT_CUSTOMER: 'AT_CUSTOMER',
  DeliveryTaskStatusEnum.DELIVERED: 'DELIVERED',
  DeliveryTaskStatusEnum.FAILED: 'FAILED',
  DeliveryTaskStatusEnum.RETURNING: 'RETURNING',
  DeliveryTaskStatusEnum.RETURNED: 'RETURNED',
  DeliveryTaskStatusEnum.UNASSIGNED: 'UNASSIGNED',
  DeliveryTaskStatusEnum.CANCELLED: 'CANCELLED',
  DeliveryTaskStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RiderPaymentTypeEnumEnumMap = {
  RiderPaymentTypeEnum.PREPAID: 'PREPAID',
  RiderPaymentTypeEnum.COD: 'COD',
  RiderPaymentTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$DeliveryFailReasonEnumEnumMap = {
  DeliveryFailReasonEnum.CUSTOMER_NOT_REACHABLE: 'CUSTOMER_NOT_REACHABLE',
  DeliveryFailReasonEnum.CUSTOMER_REFUSED: 'CUSTOMER_REFUSED',
  DeliveryFailReasonEnum.WRONG_ADDRESS: 'WRONG_ADDRESS',
  DeliveryFailReasonEnum.OTHER: 'OTHER',
  DeliveryFailReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
