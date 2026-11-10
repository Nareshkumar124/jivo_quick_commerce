// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_ops_task_status_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOpsTaskStatusDataCWProxy {
  WsOpsTaskStatusData taskId(int taskId);

  WsOpsTaskStatusData orderId(int orderId);

  WsOpsTaskStatusData orderNumber(String orderNumber);

  WsOpsTaskStatusData storeId(int storeId);

  WsOpsTaskStatusData status(WsOpsTaskStatusDataStatusEnum status);

  WsOpsTaskStatusData previousStatus(
    WsOpsTaskStatusDataPreviousStatusEnum? previousStatus,
  );

  WsOpsTaskStatusData riderId(int? riderId);

  WsOpsTaskStatusData assignmentMode(
    WsOpsTaskStatusDataAssignmentModeEnum? assignmentMode,
  );

  WsOpsTaskStatusData attemptCount(int attemptCount);

  WsOpsTaskStatusData updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsTaskStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsTaskStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsTaskStatusData call({
    int taskId,
    int orderId,
    String orderNumber,
    int storeId,
    WsOpsTaskStatusDataStatusEnum status,
    WsOpsTaskStatusDataPreviousStatusEnum? previousStatus,
    int? riderId,
    WsOpsTaskStatusDataAssignmentModeEnum? assignmentMode,
    int attemptCount,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOpsTaskStatusData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOpsTaskStatusData.copyWith.fieldName(...)`
class _$WsOpsTaskStatusDataCWProxyImpl implements _$WsOpsTaskStatusDataCWProxy {
  const _$WsOpsTaskStatusDataCWProxyImpl(this._value);

  final WsOpsTaskStatusData _value;

  @override
  WsOpsTaskStatusData taskId(int taskId) => this(taskId: taskId);

  @override
  WsOpsTaskStatusData orderId(int orderId) => this(orderId: orderId);

  @override
  WsOpsTaskStatusData orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  WsOpsTaskStatusData storeId(int storeId) => this(storeId: storeId);

  @override
  WsOpsTaskStatusData status(WsOpsTaskStatusDataStatusEnum status) =>
      this(status: status);

  @override
  WsOpsTaskStatusData previousStatus(
    WsOpsTaskStatusDataPreviousStatusEnum? previousStatus,
  ) => this(previousStatus: previousStatus);

  @override
  WsOpsTaskStatusData riderId(int? riderId) => this(riderId: riderId);

  @override
  WsOpsTaskStatusData assignmentMode(
    WsOpsTaskStatusDataAssignmentModeEnum? assignmentMode,
  ) => this(assignmentMode: assignmentMode);

  @override
  WsOpsTaskStatusData attemptCount(int attemptCount) =>
      this(attemptCount: attemptCount);

  @override
  WsOpsTaskStatusData updatedAt(DateTime updatedAt) =>
      this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsTaskStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsTaskStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsTaskStatusData call({
    Object? taskId = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? previousStatus = const $CopyWithPlaceholder(),
    Object? riderId = const $CopyWithPlaceholder(),
    Object? assignmentMode = const $CopyWithPlaceholder(),
    Object? attemptCount = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WsOpsTaskStatusData(
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      storeId: storeId == const $CopyWithPlaceholder()
          ? _value.storeId
          // ignore: cast_nullable_to_non_nullable
          : storeId as int,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as WsOpsTaskStatusDataStatusEnum,
      previousStatus: previousStatus == const $CopyWithPlaceholder()
          ? _value.previousStatus
          // ignore: cast_nullable_to_non_nullable
          : previousStatus as WsOpsTaskStatusDataPreviousStatusEnum?,
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int?,
      assignmentMode: assignmentMode == const $CopyWithPlaceholder()
          ? _value.assignmentMode
          // ignore: cast_nullable_to_non_nullable
          : assignmentMode as WsOpsTaskStatusDataAssignmentModeEnum?,
      attemptCount: attemptCount == const $CopyWithPlaceholder()
          ? _value.attemptCount
          // ignore: cast_nullable_to_non_nullable
          : attemptCount as int,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $WsOpsTaskStatusDataCopyWith on WsOpsTaskStatusData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOpsTaskStatusData.copyWith(...)` or like so:`instanceOfWsOpsTaskStatusData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOpsTaskStatusDataCWProxy get copyWith =>
      _$WsOpsTaskStatusDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOpsTaskStatusData _$WsOpsTaskStatusDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsOpsTaskStatusData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'task_id',
            'order_id',
            'order_number',
            'store_id',
            'status',
            'previous_status',
            'rider_id',
            'assignment_mode',
            'attempt_count',
            'updated_at',
          ],
        );
        final val = WsOpsTaskStatusData(
          taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
          orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String),
          storeId: $checkedConvert('store_id', (v) => (v as num).toInt()),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$WsOpsTaskStatusDataStatusEnumEnumMap,
              v,
              unknownValue: WsOpsTaskStatusDataStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          previousStatus: $checkedConvert(
            'previous_status',
            (v) => $enumDecodeNullable(
              _$WsOpsTaskStatusDataPreviousStatusEnumEnumMap,
              v,
              unknownValue:
                  WsOpsTaskStatusDataPreviousStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          riderId: $checkedConvert('rider_id', (v) => (v as num?)?.toInt()),
          assignmentMode: $checkedConvert(
            'assignment_mode',
            (v) => $enumDecodeNullable(
              _$WsOpsTaskStatusDataAssignmentModeEnumEnumMap,
              v,
              unknownValue:
                  WsOpsTaskStatusDataAssignmentModeEnum.unknownDefaultOpenApi,
            ),
          ),
          attemptCount: $checkedConvert(
            'attempt_count',
            (v) => (v as num).toInt(),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'taskId': 'task_id',
        'orderId': 'order_id',
        'orderNumber': 'order_number',
        'storeId': 'store_id',
        'previousStatus': 'previous_status',
        'riderId': 'rider_id',
        'assignmentMode': 'assignment_mode',
        'attemptCount': 'attempt_count',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$WsOpsTaskStatusDataToJson(
  WsOpsTaskStatusData instance,
) => <String, dynamic>{
  'task_id': instance.taskId,
  'order_id': instance.orderId,
  'order_number': instance.orderNumber,
  'store_id': instance.storeId,
  'status': _$WsOpsTaskStatusDataStatusEnumEnumMap[instance.status]!,
  'previous_status':
      _$WsOpsTaskStatusDataPreviousStatusEnumEnumMap[instance.previousStatus],
  'rider_id': instance.riderId,
  'assignment_mode':
      _$WsOpsTaskStatusDataAssignmentModeEnumEnumMap[instance.assignmentMode],
  'attempt_count': instance.attemptCount,
  'updated_at': instance.updatedAt.toIso8601String(),
};

const _$WsOpsTaskStatusDataStatusEnumEnumMap = {
  WsOpsTaskStatusDataStatusEnum.SEARCHING: 'SEARCHING',
  WsOpsTaskStatusDataStatusEnum.OFFERED: 'OFFERED',
  WsOpsTaskStatusDataStatusEnum.ASSIGNED: 'ASSIGNED',
  WsOpsTaskStatusDataStatusEnum.AT_STORE: 'AT_STORE',
  WsOpsTaskStatusDataStatusEnum.PICKED_UP: 'PICKED_UP',
  WsOpsTaskStatusDataStatusEnum.AT_CUSTOMER: 'AT_CUSTOMER',
  WsOpsTaskStatusDataStatusEnum.DELIVERED: 'DELIVERED',
  WsOpsTaskStatusDataStatusEnum.FAILED: 'FAILED',
  WsOpsTaskStatusDataStatusEnum.RETURNING: 'RETURNING',
  WsOpsTaskStatusDataStatusEnum.RETURNED: 'RETURNED',
  WsOpsTaskStatusDataStatusEnum.UNASSIGNED: 'UNASSIGNED',
  WsOpsTaskStatusDataStatusEnum.CANCELLED: 'CANCELLED',
  WsOpsTaskStatusDataStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$WsOpsTaskStatusDataPreviousStatusEnumEnumMap = {
  WsOpsTaskStatusDataPreviousStatusEnum.SEARCHING: 'SEARCHING',
  WsOpsTaskStatusDataPreviousStatusEnum.OFFERED: 'OFFERED',
  WsOpsTaskStatusDataPreviousStatusEnum.ASSIGNED: 'ASSIGNED',
  WsOpsTaskStatusDataPreviousStatusEnum.AT_STORE: 'AT_STORE',
  WsOpsTaskStatusDataPreviousStatusEnum.PICKED_UP: 'PICKED_UP',
  WsOpsTaskStatusDataPreviousStatusEnum.AT_CUSTOMER: 'AT_CUSTOMER',
  WsOpsTaskStatusDataPreviousStatusEnum.DELIVERED: 'DELIVERED',
  WsOpsTaskStatusDataPreviousStatusEnum.FAILED: 'FAILED',
  WsOpsTaskStatusDataPreviousStatusEnum.RETURNING: 'RETURNING',
  WsOpsTaskStatusDataPreviousStatusEnum.RETURNED: 'RETURNED',
  WsOpsTaskStatusDataPreviousStatusEnum.UNASSIGNED: 'UNASSIGNED',
  WsOpsTaskStatusDataPreviousStatusEnum.CANCELLED: 'CANCELLED',
  WsOpsTaskStatusDataPreviousStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};

const _$WsOpsTaskStatusDataAssignmentModeEnumEnumMap = {
  WsOpsTaskStatusDataAssignmentModeEnum.AUTO: 'AUTO',
  WsOpsTaskStatusDataAssignmentModeEnum.MANUAL: 'MANUAL',
  WsOpsTaskStatusDataAssignmentModeEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
