// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_track.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderTrackCWProxy {
  OrderTrack orderId(int orderId);

  OrderTrack orderNumber(String orderNumber);

  OrderTrack status(OrderStatusEnum status);

  OrderTrack etaAt(DateTime? etaAt);

  OrderTrack liveEtaAt(DateTime? liveEtaAt);

  OrderTrack liveEtaMinutes(int? liveEtaMinutes);

  OrderTrack store(TrackStore store);

  OrderTrack destination(TrackPoint destination);

  OrderTrack rider(TrackRider? rider);

  OrderTrack deliveryOtp(String? deliveryOtp);

  OrderTrack taskStatus(DeliveryTaskStatusEnum? taskStatus);

  OrderTrack serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderTrack(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderTrack(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderTrack call({
    int orderId,
    String orderNumber,
    OrderStatusEnum status,
    DateTime? etaAt,
    DateTime? liveEtaAt,
    int? liveEtaMinutes,
    TrackStore store,
    TrackPoint destination,
    TrackRider? rider,
    String? deliveryOtp,
    DeliveryTaskStatusEnum? taskStatus,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderTrack.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderTrack.copyWith.fieldName(...)`
class _$OrderTrackCWProxyImpl implements _$OrderTrackCWProxy {
  const _$OrderTrackCWProxyImpl(this._value);

  final OrderTrack _value;

  @override
  OrderTrack orderId(int orderId) => this(orderId: orderId);

  @override
  OrderTrack orderNumber(String orderNumber) => this(orderNumber: orderNumber);

  @override
  OrderTrack status(OrderStatusEnum status) => this(status: status);

  @override
  OrderTrack etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  OrderTrack liveEtaAt(DateTime? liveEtaAt) => this(liveEtaAt: liveEtaAt);

  @override
  OrderTrack liveEtaMinutes(int? liveEtaMinutes) =>
      this(liveEtaMinutes: liveEtaMinutes);

  @override
  OrderTrack store(TrackStore store) => this(store: store);

  @override
  OrderTrack destination(TrackPoint destination) =>
      this(destination: destination);

  @override
  OrderTrack rider(TrackRider? rider) => this(rider: rider);

  @override
  OrderTrack deliveryOtp(String? deliveryOtp) => this(deliveryOtp: deliveryOtp);

  @override
  OrderTrack taskStatus(DeliveryTaskStatusEnum? taskStatus) =>
      this(taskStatus: taskStatus);

  @override
  OrderTrack serverTime(DateTime serverTime) => this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderTrack(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderTrack(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderTrack call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? liveEtaAt = const $CopyWithPlaceholder(),
    Object? liveEtaMinutes = const $CopyWithPlaceholder(),
    Object? store = const $CopyWithPlaceholder(),
    Object? destination = const $CopyWithPlaceholder(),
    Object? rider = const $CopyWithPlaceholder(),
    Object? deliveryOtp = const $CopyWithPlaceholder(),
    Object? taskStatus = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return OrderTrack(
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as OrderStatusEnum,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime?,
      liveEtaAt: liveEtaAt == const $CopyWithPlaceholder()
          ? _value.liveEtaAt
          // ignore: cast_nullable_to_non_nullable
          : liveEtaAt as DateTime?,
      liveEtaMinutes: liveEtaMinutes == const $CopyWithPlaceholder()
          ? _value.liveEtaMinutes
          // ignore: cast_nullable_to_non_nullable
          : liveEtaMinutes as int?,
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as TrackStore,
      destination: destination == const $CopyWithPlaceholder()
          ? _value.destination
          // ignore: cast_nullable_to_non_nullable
          : destination as TrackPoint,
      rider: rider == const $CopyWithPlaceholder()
          ? _value.rider
          // ignore: cast_nullable_to_non_nullable
          : rider as TrackRider?,
      deliveryOtp: deliveryOtp == const $CopyWithPlaceholder()
          ? _value.deliveryOtp
          // ignore: cast_nullable_to_non_nullable
          : deliveryOtp as String?,
      taskStatus: taskStatus == const $CopyWithPlaceholder()
          ? _value.taskStatus
          // ignore: cast_nullable_to_non_nullable
          : taskStatus as DeliveryTaskStatusEnum?,
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $OrderTrackCopyWith on OrderTrack {
  /// Returns a callable class that can be used as follows: `instanceOfOrderTrack.copyWith(...)` or like so:`instanceOfOrderTrack.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderTrackCWProxy get copyWith => _$OrderTrackCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderTrack _$OrderTrackFromJson(Map<String, dynamic> json) => $checkedCreate(
  'OrderTrack',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'order_id',
        'order_number',
        'status',
        'eta_at',
        'live_eta_at',
        'live_eta_minutes',
        'store',
        'destination',
        'rider',
        'delivery_otp',
        'task_status',
        'server_time',
      ],
    );
    final val = OrderTrack(
      orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
      orderNumber: $checkedConvert('order_number', (v) => v as String),
      status: $checkedConvert(
        'status',
        (v) => $enumDecode(
          _$OrderStatusEnumEnumMap,
          v,
          unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      etaAt: $checkedConvert(
        'eta_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      liveEtaAt: $checkedConvert(
        'live_eta_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      liveEtaMinutes: $checkedConvert(
        'live_eta_minutes',
        (v) => (v as num?)?.toInt(),
      ),
      store: $checkedConvert(
        'store',
        (v) => TrackStore.fromJson(v as Map<String, dynamic>),
      ),
      destination: $checkedConvert(
        'destination',
        (v) => TrackPoint.fromJson(v as Map<String, dynamic>),
      ),
      rider: $checkedConvert(
        'rider',
        (v) =>
            v == null ? null : TrackRider.fromJson(v as Map<String, dynamic>),
      ),
      deliveryOtp: $checkedConvert('delivery_otp', (v) => v as String?),
      taskStatus: $checkedConvert(
        'task_status',
        (v) => $enumDecodeNullable(
          _$DeliveryTaskStatusEnumEnumMap,
          v,
          unknownValue: DeliveryTaskStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      serverTime: $checkedConvert(
        'server_time',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderId': 'order_id',
    'orderNumber': 'order_number',
    'etaAt': 'eta_at',
    'liveEtaAt': 'live_eta_at',
    'liveEtaMinutes': 'live_eta_minutes',
    'deliveryOtp': 'delivery_otp',
    'taskStatus': 'task_status',
    'serverTime': 'server_time',
  },
);

Map<String, dynamic> _$OrderTrackToJson(OrderTrack instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'order_number': instance.orderNumber,
      'status': _$OrderStatusEnumEnumMap[instance.status]!,
      'eta_at': instance.etaAt?.toIso8601String(),
      'live_eta_at': instance.liveEtaAt?.toIso8601String(),
      'live_eta_minutes': instance.liveEtaMinutes,
      'store': instance.store.toJson(),
      'destination': instance.destination.toJson(),
      'rider': instance.rider?.toJson(),
      'delivery_otp': instance.deliveryOtp,
      'task_status': _$DeliveryTaskStatusEnumEnumMap[instance.taskStatus],
      'server_time': instance.serverTime.toIso8601String(),
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
