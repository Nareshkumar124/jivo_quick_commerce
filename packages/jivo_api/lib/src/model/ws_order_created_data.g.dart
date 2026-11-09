// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_created_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderCreatedDataCWProxy {
  WsOrderCreatedData orderId(int orderId);

  WsOrderCreatedData orderNumber(String orderNumber);

  WsOrderCreatedData storeId(int storeId);

  WsOrderCreatedData status(OrderStatusEnum status);

  WsOrderCreatedData paymentMethod(PaymentMethodEnum paymentMethod);

  WsOrderCreatedData itemCount(int itemCount);

  WsOrderCreatedData grandTotal(String grandTotal);

  WsOrderCreatedData placedAt(DateTime? placedAt);

  WsOrderCreatedData etaAt(DateTime? etaAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderCreatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderCreatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderCreatedData call({
    int orderId,
    String orderNumber,
    int storeId,
    OrderStatusEnum status,
    PaymentMethodEnum paymentMethod,
    int itemCount,
    String grandTotal,
    DateTime? placedAt,
    DateTime? etaAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderCreatedData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderCreatedData.copyWith.fieldName(...)`
class _$WsOrderCreatedDataCWProxyImpl implements _$WsOrderCreatedDataCWProxy {
  const _$WsOrderCreatedDataCWProxyImpl(this._value);

  final WsOrderCreatedData _value;

  @override
  WsOrderCreatedData orderId(int orderId) => this(orderId: orderId);

  @override
  WsOrderCreatedData orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  WsOrderCreatedData storeId(int storeId) => this(storeId: storeId);

  @override
  WsOrderCreatedData status(OrderStatusEnum status) => this(status: status);

  @override
  WsOrderCreatedData paymentMethod(PaymentMethodEnum paymentMethod) =>
      this(paymentMethod: paymentMethod);

  @override
  WsOrderCreatedData itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  WsOrderCreatedData grandTotal(String grandTotal) =>
      this(grandTotal: grandTotal);

  @override
  WsOrderCreatedData placedAt(DateTime? placedAt) => this(placedAt: placedAt);

  @override
  WsOrderCreatedData etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderCreatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderCreatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderCreatedData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? paymentMethod = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? grandTotal = const $CopyWithPlaceholder(),
    Object? placedAt = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderCreatedData(
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
      paymentMethod: paymentMethod == const $CopyWithPlaceholder()
          ? _value.paymentMethod
          // ignore: cast_nullable_to_non_nullable
          : paymentMethod as PaymentMethodEnum,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      grandTotal: grandTotal == const $CopyWithPlaceholder()
          ? _value.grandTotal
          // ignore: cast_nullable_to_non_nullable
          : grandTotal as String,
      placedAt: placedAt == const $CopyWithPlaceholder()
          ? _value.placedAt
          // ignore: cast_nullable_to_non_nullable
          : placedAt as DateTime?,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime?,
    );
  }
}

extension $WsOrderCreatedDataCopyWith on WsOrderCreatedData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderCreatedData.copyWith(...)` or like so:`instanceOfWsOrderCreatedData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderCreatedDataCWProxy get copyWith =>
      _$WsOrderCreatedDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderCreatedData _$WsOrderCreatedDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsOrderCreatedData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'order_id',
            'order_number',
            'store_id',
            'status',
            'payment_method',
            'item_count',
            'grand_total',
            'placed_at',
            'eta_at',
          ],
        );
        final val = WsOrderCreatedData(
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
          paymentMethod: $checkedConvert(
            'payment_method',
            (v) => $enumDecode(
              _$PaymentMethodEnumEnumMap,
              v,
              unknownValue: PaymentMethodEnum.unknownDefaultOpenApi,
            ),
          ),
          itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
          grandTotal: $checkedConvert('grand_total', (v) => v as String),
          placedAt: $checkedConvert(
            'placed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          etaAt: $checkedConvert(
            'eta_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderId': 'order_id',
        'orderNumber': 'order_number',
        'storeId': 'store_id',
        'paymentMethod': 'payment_method',
        'itemCount': 'item_count',
        'grandTotal': 'grand_total',
        'placedAt': 'placed_at',
        'etaAt': 'eta_at',
      },
    );

Map<String, dynamic> _$WsOrderCreatedDataToJson(WsOrderCreatedData instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'order_number': instance.orderNumber,
      'store_id': instance.storeId,
      'status': _$OrderStatusEnumEnumMap[instance.status]!,
      'payment_method': _$PaymentMethodEnumEnumMap[instance.paymentMethod]!,
      'item_count': instance.itemCount,
      'grand_total': instance.grandTotal,
      'placed_at': instance.placedAt?.toIso8601String(),
      'eta_at': instance.etaAt?.toIso8601String(),
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

const _$PaymentMethodEnumEnumMap = {
  PaymentMethodEnum.ONLINE: 'ONLINE',
  PaymentMethodEnum.COD: 'COD',
  PaymentMethodEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
