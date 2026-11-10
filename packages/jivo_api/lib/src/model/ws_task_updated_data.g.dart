// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_task_updated_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsTaskUpdatedDataCWProxy {
  WsTaskUpdatedData taskId(int taskId);

  WsTaskUpdatedData orderId(int orderId);

  WsTaskUpdatedData status(String status);

  WsTaskUpdatedData orderStatus(OrderStatusEnum orderStatus);

  WsTaskUpdatedData change(WsTaskUpdatedDataChangeEnum change);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsTaskUpdatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsTaskUpdatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsTaskUpdatedData call({
    int taskId,
    int orderId,
    String status,
    OrderStatusEnum orderStatus,
    WsTaskUpdatedDataChangeEnum change,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsTaskUpdatedData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsTaskUpdatedData.copyWith.fieldName(...)`
class _$WsTaskUpdatedDataCWProxyImpl implements _$WsTaskUpdatedDataCWProxy {
  const _$WsTaskUpdatedDataCWProxyImpl(this._value);

  final WsTaskUpdatedData _value;

  @override
  WsTaskUpdatedData taskId(int taskId) => this(taskId: taskId);

  @override
  WsTaskUpdatedData orderId(int orderId) => this(orderId: orderId);

  @override
  WsTaskUpdatedData status(String status) => this(status: status);

  @override
  WsTaskUpdatedData orderStatus(OrderStatusEnum orderStatus) =>
      this(orderStatus: orderStatus);

  @override
  WsTaskUpdatedData change(WsTaskUpdatedDataChangeEnum change) =>
      this(change: change);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsTaskUpdatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsTaskUpdatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsTaskUpdatedData call({
    Object? taskId = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? orderStatus = const $CopyWithPlaceholder(),
    Object? change = const $CopyWithPlaceholder(),
  }) {
    return WsTaskUpdatedData(
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as String,
      orderStatus: orderStatus == const $CopyWithPlaceholder()
          ? _value.orderStatus
          // ignore: cast_nullable_to_non_nullable
          : orderStatus as OrderStatusEnum,
      change: change == const $CopyWithPlaceholder()
          ? _value.change
          // ignore: cast_nullable_to_non_nullable
          : change as WsTaskUpdatedDataChangeEnum,
    );
  }
}

extension $WsTaskUpdatedDataCopyWith on WsTaskUpdatedData {
  /// Returns a callable class that can be used as follows: `instanceOfWsTaskUpdatedData.copyWith(...)` or like so:`instanceOfWsTaskUpdatedData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsTaskUpdatedDataCWProxy get copyWith =>
      _$WsTaskUpdatedDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsTaskUpdatedData _$WsTaskUpdatedDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsTaskUpdatedData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'task_id',
            'order_id',
            'status',
            'order_status',
            'change',
          ],
        );
        final val = WsTaskUpdatedData(
          taskId: $checkedConvert('task_id', (v) => (v as num).toInt()),
          orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
          status: $checkedConvert('status', (v) => v as String),
          orderStatus: $checkedConvert(
            'order_status',
            (v) => $enumDecode(
              _$OrderStatusEnumEnumMap,
              v,
              unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          change: $checkedConvert(
            'change',
            (v) => $enumDecode(
              _$WsTaskUpdatedDataChangeEnumEnumMap,
              v,
              unknownValue: WsTaskUpdatedDataChangeEnum.unknownDefaultOpenApi,
            ),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'taskId': 'task_id',
        'orderId': 'order_id',
        'orderStatus': 'order_status',
      },
    );

Map<String, dynamic> _$WsTaskUpdatedDataToJson(WsTaskUpdatedData instance) =>
    <String, dynamic>{
      'task_id': instance.taskId,
      'order_id': instance.orderId,
      'status': instance.status,
      'order_status': _$OrderStatusEnumEnumMap[instance.orderStatus]!,
      'change': _$WsTaskUpdatedDataChangeEnumEnumMap[instance.change]!,
    };

const _$OrderStatusEnumEnumMap = {
  OrderStatusEnum.PAYMENT_PENDING: 'PAYMENT_PENDING',
  OrderStatusEnum.PLACED: 'PLACED',
  OrderStatusEnum.ACCEPTED: 'ACCEPTED',
  OrderStatusEnum.PACKING: 'PACKING',
  OrderStatusEnum.PACKED: 'PACKED',
  OrderStatusEnum.OUT_FOR_DELIVERY: 'OUT_FOR_DELIVERY',
  OrderStatusEnum.DELIVERED: 'DELIVERED',
  OrderStatusEnum.CANCELLED: 'CANCELLED',
  OrderStatusEnum.PAYMENT_FAILED: 'PAYMENT_FAILED',
  OrderStatusEnum.DELIVERY_FAILED: 'DELIVERY_FAILED',
  OrderStatusEnum.RETURNED: 'RETURNED',
  OrderStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$WsTaskUpdatedDataChangeEnumEnumMap = {
  WsTaskUpdatedDataChangeEnum.ORDER_PACKED: 'ORDER_PACKED',
  WsTaskUpdatedDataChangeEnum.ORDER_CANCELLED: 'ORDER_CANCELLED',
  WsTaskUpdatedDataChangeEnum.AMOUNT_CHANGED: 'AMOUNT_CHANGED',
  WsTaskUpdatedDataChangeEnum.REASSIGNED: 'REASSIGNED',
  WsTaskUpdatedDataChangeEnum.STATUS_CHANGED: 'STATUS_CHANGED',
  WsTaskUpdatedDataChangeEnum.ASSIGNED: 'ASSIGNED',
  WsTaskUpdatedDataChangeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
