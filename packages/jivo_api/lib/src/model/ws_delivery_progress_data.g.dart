// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_delivery_progress_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsDeliveryProgressDataCWProxy {
  WsDeliveryProgressData orderId(int orderId);

  WsDeliveryProgressData orderNumber(String orderNumber);

  WsDeliveryProgressData storeId(int storeId);

  WsDeliveryProgressData taskId(int? taskId);

  WsDeliveryProgressData riderId(int? riderId);

  WsDeliveryProgressData orderStatus(OrderStatusEnum orderStatus);

  WsDeliveryProgressData taskStatus(
    WsDeliveryProgressDataTaskStatusEnum? taskStatus,
  );

  WsDeliveryProgressData distanceRemainingM(int? distanceRemainingM);

  WsDeliveryProgressData liveEtaAt(DateTime? liveEtaAt);

  WsDeliveryProgressData liveEtaMinutes(int? liveEtaMinutes);

  WsDeliveryProgressData isDelayed(bool isDelayed);

  WsDeliveryProgressData updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsDeliveryProgressData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsDeliveryProgressData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsDeliveryProgressData call({
    int orderId,
    String orderNumber,
    int storeId,
    int? taskId,
    int? riderId,
    OrderStatusEnum orderStatus,
    WsDeliveryProgressDataTaskStatusEnum? taskStatus,
    int? distanceRemainingM,
    DateTime? liveEtaAt,
    int? liveEtaMinutes,
    bool isDelayed,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsDeliveryProgressData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsDeliveryProgressData.copyWith.fieldName(...)`
class _$WsDeliveryProgressDataCWProxyImpl
    implements _$WsDeliveryProgressDataCWProxy {
  const _$WsDeliveryProgressDataCWProxyImpl(this._value);

  final WsDeliveryProgressData _value;

  @override
  WsDeliveryProgressData orderId(int orderId) => this(orderId: orderId);

  @override
  WsDeliveryProgressData orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  WsDeliveryProgressData storeId(int storeId) => this(storeId: storeId);

  @override
  WsDeliveryProgressData taskId(int? taskId) => this(taskId: taskId);

  @override
  WsDeliveryProgressData riderId(int? riderId) => this(riderId: riderId);

  @override
  WsDeliveryProgressData orderStatus(OrderStatusEnum orderStatus) =>
      this(orderStatus: orderStatus);

  @override
  WsDeliveryProgressData taskStatus(
    WsDeliveryProgressDataTaskStatusEnum? taskStatus,
  ) => this(taskStatus: taskStatus);

  @override
  WsDeliveryProgressData distanceRemainingM(int? distanceRemainingM) =>
      this(distanceRemainingM: distanceRemainingM);

  @override
  WsDeliveryProgressData liveEtaAt(DateTime? liveEtaAt) =>
      this(liveEtaAt: liveEtaAt);

  @override
  WsDeliveryProgressData liveEtaMinutes(int? liveEtaMinutes) =>
      this(liveEtaMinutes: liveEtaMinutes);

  @override
  WsDeliveryProgressData isDelayed(bool isDelayed) =>
      this(isDelayed: isDelayed);

  @override
  WsDeliveryProgressData updatedAt(DateTime updatedAt) =>
      this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsDeliveryProgressData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsDeliveryProgressData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsDeliveryProgressData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
    Object? riderId = const $CopyWithPlaceholder(),
    Object? orderStatus = const $CopyWithPlaceholder(),
    Object? taskStatus = const $CopyWithPlaceholder(),
    Object? distanceRemainingM = const $CopyWithPlaceholder(),
    Object? liveEtaAt = const $CopyWithPlaceholder(),
    Object? liveEtaMinutes = const $CopyWithPlaceholder(),
    Object? isDelayed = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WsDeliveryProgressData(
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
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int?,
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int?,
      orderStatus: orderStatus == const $CopyWithPlaceholder()
          ? _value.orderStatus
          // ignore: cast_nullable_to_non_nullable
          : orderStatus as OrderStatusEnum,
      taskStatus: taskStatus == const $CopyWithPlaceholder()
          ? _value.taskStatus
          // ignore: cast_nullable_to_non_nullable
          : taskStatus as WsDeliveryProgressDataTaskStatusEnum?,
      distanceRemainingM: distanceRemainingM == const $CopyWithPlaceholder()
          ? _value.distanceRemainingM
          // ignore: cast_nullable_to_non_nullable
          : distanceRemainingM as int?,
      liveEtaAt: liveEtaAt == const $CopyWithPlaceholder()
          ? _value.liveEtaAt
          // ignore: cast_nullable_to_non_nullable
          : liveEtaAt as DateTime?,
      liveEtaMinutes: liveEtaMinutes == const $CopyWithPlaceholder()
          ? _value.liveEtaMinutes
          // ignore: cast_nullable_to_non_nullable
          : liveEtaMinutes as int?,
      isDelayed: isDelayed == const $CopyWithPlaceholder()
          ? _value.isDelayed
          // ignore: cast_nullable_to_non_nullable
          : isDelayed as bool,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $WsDeliveryProgressDataCopyWith on WsDeliveryProgressData {
  /// Returns a callable class that can be used as follows: `instanceOfWsDeliveryProgressData.copyWith(...)` or like so:`instanceOfWsDeliveryProgressData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsDeliveryProgressDataCWProxy get copyWith =>
      _$WsDeliveryProgressDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsDeliveryProgressData _$WsDeliveryProgressDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WsDeliveryProgressData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'order_id',
        'order_number',
        'store_id',
        'task_id',
        'rider_id',
        'order_status',
        'task_status',
        'distance_remaining_m',
        'live_eta_at',
        'live_eta_minutes',
        'is_delayed',
        'updated_at',
      ],
    );
    final val = WsDeliveryProgressData(
      orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
      orderNumber: $checkedConvert('order_number', (v) => v as String),
      storeId: $checkedConvert('store_id', (v) => (v as num).toInt()),
      taskId: $checkedConvert('task_id', (v) => (v as num?)?.toInt()),
      riderId: $checkedConvert('rider_id', (v) => (v as num?)?.toInt()),
      orderStatus: $checkedConvert(
        'order_status',
        (v) => $enumDecode(
          _$OrderStatusEnumEnumMap,
          v,
          unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      taskStatus: $checkedConvert(
        'task_status',
        (v) => $enumDecodeNullable(
          _$WsDeliveryProgressDataTaskStatusEnumEnumMap,
          v,
          unknownValue:
              WsDeliveryProgressDataTaskStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      distanceRemainingM: $checkedConvert(
        'distance_remaining_m',
        (v) => (v as num?)?.toInt(),
      ),
      liveEtaAt: $checkedConvert(
        'live_eta_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      liveEtaMinutes: $checkedConvert(
        'live_eta_minutes',
        (v) => (v as num?)?.toInt(),
      ),
      isDelayed: $checkedConvert('is_delayed', (v) => v as bool),
      updatedAt: $checkedConvert(
        'updated_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderId': 'order_id',
    'orderNumber': 'order_number',
    'storeId': 'store_id',
    'taskId': 'task_id',
    'riderId': 'rider_id',
    'orderStatus': 'order_status',
    'taskStatus': 'task_status',
    'distanceRemainingM': 'distance_remaining_m',
    'liveEtaAt': 'live_eta_at',
    'liveEtaMinutes': 'live_eta_minutes',
    'isDelayed': 'is_delayed',
    'updatedAt': 'updated_at',
  },
);

Map<String, dynamic> _$WsDeliveryProgressDataToJson(
  WsDeliveryProgressData instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'order_number': instance.orderNumber,
  'store_id': instance.storeId,
  'task_id': instance.taskId,
  'rider_id': instance.riderId,
  'order_status': _$OrderStatusEnumEnumMap[instance.orderStatus]!,
  'task_status':
      _$WsDeliveryProgressDataTaskStatusEnumEnumMap[instance.taskStatus],
  'distance_remaining_m': instance.distanceRemainingM,
  'live_eta_at': instance.liveEtaAt?.toIso8601String(),
  'live_eta_minutes': instance.liveEtaMinutes,
  'is_delayed': instance.isDelayed,
  'updated_at': instance.updatedAt.toIso8601String(),
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

const _$WsDeliveryProgressDataTaskStatusEnumEnumMap = {
  WsDeliveryProgressDataTaskStatusEnum.SEARCHING: 'SEARCHING',
  WsDeliveryProgressDataTaskStatusEnum.OFFERED: 'OFFERED',
  WsDeliveryProgressDataTaskStatusEnum.ASSIGNED: 'ASSIGNED',
  WsDeliveryProgressDataTaskStatusEnum.AT_STORE: 'AT_STORE',
  WsDeliveryProgressDataTaskStatusEnum.PICKED_UP: 'PICKED_UP',
  WsDeliveryProgressDataTaskStatusEnum.AT_CUSTOMER: 'AT_CUSTOMER',
  WsDeliveryProgressDataTaskStatusEnum.DELIVERED: 'DELIVERED',
  WsDeliveryProgressDataTaskStatusEnum.FAILED: 'FAILED',
  WsDeliveryProgressDataTaskStatusEnum.RETURNING: 'RETURNING',
  WsDeliveryProgressDataTaskStatusEnum.RETURNED: 'RETURNED',
  WsDeliveryProgressDataTaskStatusEnum.UNASSIGNED: 'UNASSIGNED',
  WsDeliveryProgressDataTaskStatusEnum.CANCELLED: 'CANCELLED',
  WsDeliveryProgressDataTaskStatusEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
