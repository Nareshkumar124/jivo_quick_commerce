// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_status_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderStatusDataCWProxy {
  WsOrderStatusData orderId(int orderId);

  WsOrderStatusData orderNumber(String orderNumber);

  WsOrderStatusData storeId(int storeId);

  WsOrderStatusData status(OrderStatusEnum status);

  WsOrderStatusData paymentStatus(PaymentStatusEnum paymentStatus);

  WsOrderStatusData etaAt(DateTime? etaAt);

  WsOrderStatusData updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderStatusData call({
    int orderId,
    String orderNumber,
    int storeId,
    OrderStatusEnum status,
    PaymentStatusEnum paymentStatus,
    DateTime? etaAt,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderStatusData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderStatusData.copyWith.fieldName(...)`
class _$WsOrderStatusDataCWProxyImpl implements _$WsOrderStatusDataCWProxy {
  const _$WsOrderStatusDataCWProxyImpl(this._value);

  final WsOrderStatusData _value;

  @override
  WsOrderStatusData orderId(int orderId) => this(orderId: orderId);

  @override
  WsOrderStatusData orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  WsOrderStatusData storeId(int storeId) => this(storeId: storeId);

  @override
  WsOrderStatusData status(OrderStatusEnum status) => this(status: status);

  @override
  WsOrderStatusData paymentStatus(PaymentStatusEnum paymentStatus) =>
      this(paymentStatus: paymentStatus);

  @override
  WsOrderStatusData etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  WsOrderStatusData updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderStatusData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? paymentStatus = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderStatusData(
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
          : status as OrderStatusEnum,
      paymentStatus: paymentStatus == const $CopyWithPlaceholder()
          ? _value.paymentStatus
          // ignore: cast_nullable_to_non_nullable
          : paymentStatus as PaymentStatusEnum,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $WsOrderStatusDataCopyWith on WsOrderStatusData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderStatusData.copyWith(...)` or like so:`instanceOfWsOrderStatusData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderStatusDataCWProxy get copyWith =>
      _$WsOrderStatusDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderStatusData _$WsOrderStatusDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsOrderStatusData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'order_id',
            'order_number',
            'store_id',
            'status',
            'payment_status',
            'eta_at',
            'updated_at',
          ],
        );
        final val = WsOrderStatusData(
          orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String),
          storeId: $checkedConvert('store_id', (v) => (v as num).toInt()),
          status: $checkedConvert(
            'status',
            (v) => $enumDecode(
              _$OrderStatusEnumEnumMap,
              v,
              unknownValue: OrderStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          paymentStatus: $checkedConvert(
            'payment_status',
            (v) => $enumDecode(
              _$PaymentStatusEnumEnumMap,
              v,
              unknownValue: PaymentStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          etaAt: $checkedConvert(
            'eta_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
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
        'paymentStatus': 'payment_status',
        'etaAt': 'eta_at',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$WsOrderStatusDataToJson(WsOrderStatusData instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'order_number': instance.orderNumber,
      'store_id': instance.storeId,
      'status': _$OrderStatusEnumEnumMap[instance.status]!,
      'payment_status': _$PaymentStatusEnumEnumMap[instance.paymentStatus]!,
      'eta_at': instance.etaAt?.toIso8601String(),
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

const _$PaymentStatusEnumEnumMap = {
  PaymentStatusEnum.PENDING: 'PENDING',
  PaymentStatusEnum.PAID: 'PAID',
  PaymentStatusEnum.FAILED: 'FAILED',
  PaymentStatusEnum.REFUND_PENDING: 'REFUND_PENDING',
  PaymentStatusEnum.REFUNDED: 'REFUNDED',
  PaymentStatusEnum.PARTIALLY_REFUNDED: 'PARTIALLY_REFUNDED',
  PaymentStatusEnum.COD_PENDING: 'COD_PENDING',
  PaymentStatusEnum.COD_COLLECTED: 'COD_COLLECTED',
  PaymentStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
