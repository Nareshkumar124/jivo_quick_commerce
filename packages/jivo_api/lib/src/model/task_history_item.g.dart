// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_history_item.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskHistoryItemCWProxy {
  TaskHistoryItem taskId(int taskId);

  TaskHistoryItem orderNumber(String orderNumber);

  TaskHistoryItem status(DeliveryTaskStatusEnum status);

  TaskHistoryItem storeName(String storeName);

  TaskHistoryItem dropLocality(String dropLocality);

  TaskHistoryItem distanceKm(String? distanceKm);

  TaskHistoryItem payout(String? payout);

  TaskHistoryItem completedAt(DateTime completedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskHistoryItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskHistoryItem(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskHistoryItem call({
    int taskId,
    String orderNumber,
    DeliveryTaskStatusEnum status,
    String storeName,
    String dropLocality,
    String? distanceKm,
    String? payout,
    DateTime completedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskHistoryItem.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskHistoryItem.copyWith.fieldName(...)`
class _$TaskHistoryItemCWProxyImpl implements _$TaskHistoryItemCWProxy {
  const _$TaskHistoryItemCWProxyImpl(this._value);

  final TaskHistoryItem _value;

  @override
  TaskHistoryItem taskId(int taskId) => this(taskId: taskId);

  @override
  TaskHistoryItem orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  TaskHistoryItem status(DeliveryTaskStatusEnum status) => this(status: status);

  @override
  TaskHistoryItem storeName(String storeName) => this(storeName: storeName);

  @override
  TaskHistoryItem dropLocality(String dropLocality) =>
      this(dropLocality: dropLocality);

  @override
  TaskHistoryItem distanceKm(String? distanceKm) =>
      this(distanceKm: distanceKm);

  @override
  TaskHistoryItem payout(String? payout) => this(payout: payout);

  @override
  TaskHistoryItem completedAt(DateTime completedAt) =>
      this(completedAt: completedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskHistoryItem(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskHistoryItem(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskHistoryItem call({
    Object? taskId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? storeName = const $CopyWithPlaceholder(),
    Object? dropLocality = const $CopyWithPlaceholder(),
    Object? distanceKm = const $CopyWithPlaceholder(),
    Object? payout = const $CopyWithPlaceholder(),
    Object? completedAt = const $CopyWithPlaceholder(),
  }) {
    return TaskHistoryItem(
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
    );
  }
}

extension $TaskHistoryItemCopyWith on TaskHistoryItem {
  /// Returns a callable class that can be used as follows: `instanceOfTaskHistoryItem.copyWith(...)` or like so:`instanceOfTaskHistoryItem.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskHistoryItemCWProxy get copyWith => _$TaskHistoryItemCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskHistoryItem _$TaskHistoryItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TaskHistoryItem',
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
          ],
        );
        final val = TaskHistoryItem(
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
      },
    );

Map<String, dynamic> _$TaskHistoryItemToJson(TaskHistoryItem instance) =>
    <String, dynamic>{
      'task_id': instance.taskId,
      'order_number': instance.orderNumber,
      'status': _$DeliveryTaskStatusEnumEnumMap[instance.status]!,
      'store_name': instance.storeName,
      'drop_locality': instance.dropLocality,
      'distance_km': instance.distanceKm,
      'payout': instance.payout,
      'completed_at': instance.completedAt.toIso8601String(),
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
