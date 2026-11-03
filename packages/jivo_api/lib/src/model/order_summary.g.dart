// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_summary.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderSummaryCWProxy {
  OrderSummary id(int id);

  OrderSummary orderNumber(String orderNumber);

  OrderSummary status(OrderStatusEnum status);

  OrderSummary paymentMethod(PaymentMethodEnum paymentMethod);

  OrderSummary paymentStatus(PaymentStatusEnum paymentStatus);

  OrderSummary store(OrderStore store);

  OrderSummary itemCount(int itemCount);

  OrderSummary images(List<ImageSet> images);

  OrderSummary grandTotal(String grandTotal);

  OrderSummary createdAt(DateTime createdAt);

  OrderSummary placedAt(DateTime? placedAt);

  OrderSummary paymentExpiresAt(DateTime? paymentExpiresAt);

  OrderSummary etaAt(DateTime? etaAt);

  OrderSummary canRetryPayment(bool canRetryPayment);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderSummary call({
    int id,
    String orderNumber,
    OrderStatusEnum status,
    PaymentMethodEnum paymentMethod,
    PaymentStatusEnum paymentStatus,
    OrderStore store,
    int itemCount,
    List<ImageSet> images,
    String grandTotal,
    DateTime createdAt,
    DateTime? placedAt,
    DateTime? paymentExpiresAt,
    DateTime? etaAt,
    bool canRetryPayment,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderSummary.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderSummary.copyWith.fieldName(...)`
class _$OrderSummaryCWProxyImpl implements _$OrderSummaryCWProxy {
  const _$OrderSummaryCWProxyImpl(this._value);

  final OrderSummary _value;

  @override
  OrderSummary id(int id) => this(id: id);

  @override
  OrderSummary orderNumber(String orderNumber) =>
      this(orderNumber: orderNumber);

  @override
  OrderSummary status(OrderStatusEnum status) => this(status: status);

  @override
  OrderSummary paymentMethod(PaymentMethodEnum paymentMethod) =>
      this(paymentMethod: paymentMethod);

  @override
  OrderSummary paymentStatus(PaymentStatusEnum paymentStatus) =>
      this(paymentStatus: paymentStatus);

  @override
  OrderSummary store(OrderStore store) => this(store: store);

  @override
  OrderSummary itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  OrderSummary images(List<ImageSet> images) => this(images: images);

  @override
  OrderSummary grandTotal(String grandTotal) => this(grandTotal: grandTotal);

  @override
  OrderSummary createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  OrderSummary placedAt(DateTime? placedAt) => this(placedAt: placedAt);

  @override
  OrderSummary paymentExpiresAt(DateTime? paymentExpiresAt) =>
      this(paymentExpiresAt: paymentExpiresAt);

  @override
  OrderSummary etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  OrderSummary canRetryPayment(bool canRetryPayment) =>
      this(canRetryPayment: canRetryPayment);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderSummary(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderSummary(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderSummary call({
    Object? id = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? paymentMethod = const $CopyWithPlaceholder(),
    Object? paymentStatus = const $CopyWithPlaceholder(),
    Object? store = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? images = const $CopyWithPlaceholder(),
    Object? grandTotal = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? placedAt = const $CopyWithPlaceholder(),
    Object? paymentExpiresAt = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? canRetryPayment = const $CopyWithPlaceholder(),
  }) {
    return OrderSummary(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      orderNumber: orderNumber == const $CopyWithPlaceholder()
          ? _value.orderNumber
          // ignore: cast_nullable_to_non_nullable
          : orderNumber as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as OrderStatusEnum,
      paymentMethod: paymentMethod == const $CopyWithPlaceholder()
          ? _value.paymentMethod
          // ignore: cast_nullable_to_non_nullable
          : paymentMethod as PaymentMethodEnum,
      paymentStatus: paymentStatus == const $CopyWithPlaceholder()
          ? _value.paymentStatus
          // ignore: cast_nullable_to_non_nullable
          : paymentStatus as PaymentStatusEnum,
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as OrderStore,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      images: images == const $CopyWithPlaceholder()
          ? _value.images
          // ignore: cast_nullable_to_non_nullable
          : images as List<ImageSet>,
      grandTotal: grandTotal == const $CopyWithPlaceholder()
          ? _value.grandTotal
          // ignore: cast_nullable_to_non_nullable
          : grandTotal as String,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      placedAt: placedAt == const $CopyWithPlaceholder()
          ? _value.placedAt
          // ignore: cast_nullable_to_non_nullable
          : placedAt as DateTime?,
      paymentExpiresAt: paymentExpiresAt == const $CopyWithPlaceholder()
          ? _value.paymentExpiresAt
          // ignore: cast_nullable_to_non_nullable
          : paymentExpiresAt as DateTime?,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime?,
      canRetryPayment: canRetryPayment == const $CopyWithPlaceholder()
          ? _value.canRetryPayment
          // ignore: cast_nullable_to_non_nullable
          : canRetryPayment as bool,
    );
  }
}

extension $OrderSummaryCopyWith on OrderSummary {
  /// Returns a callable class that can be used as follows: `instanceOfOrderSummary.copyWith(...)` or like so:`instanceOfOrderSummary.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderSummaryCWProxy get copyWith => _$OrderSummaryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderSummary _$OrderSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'OrderSummary',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'id',
            'order_number',
            'status',
            'payment_method',
            'payment_status',
            'store',
            'item_count',
            'images',
            'grand_total',
            'created_at',
            'placed_at',
            'payment_expires_at',
            'eta_at',
            'can_retry_payment',
          ],
        );
        final val = OrderSummary(
          id: $checkedConvert('id', (v) => (v as num).toInt()),
          orderNumber: $checkedConvert('order_number', (v) => v as String),
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
          paymentStatus: $checkedConvert(
            'payment_status',
            (v) => $enumDecode(
              _$PaymentStatusEnumEnumMap,
              v,
              unknownValue: PaymentStatusEnum.unknownDefaultOpenApi,
            ),
          ),
          store: $checkedConvert(
            'store',
            (v) => OrderStore.fromJson(v as Map<String, dynamic>),
          ),
          itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
          images: $checkedConvert(
            'images',
            (v) => (v as List<dynamic>)
                .map((e) => ImageSet.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
          grandTotal: $checkedConvert('grand_total', (v) => v as String),
          createdAt: $checkedConvert(
            'created_at',
            (v) => DateTime.parse(v as String),
          ),
          placedAt: $checkedConvert(
            'placed_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          paymentExpiresAt: $checkedConvert(
            'payment_expires_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          etaAt: $checkedConvert(
            'eta_at',
            (v) => v == null ? null : DateTime.parse(v as String),
          ),
          canRetryPayment: $checkedConvert(
            'can_retry_payment',
            (v) => v as bool,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderNumber': 'order_number',
        'paymentMethod': 'payment_method',
        'paymentStatus': 'payment_status',
        'itemCount': 'item_count',
        'grandTotal': 'grand_total',
        'createdAt': 'created_at',
        'placedAt': 'placed_at',
        'paymentExpiresAt': 'payment_expires_at',
        'etaAt': 'eta_at',
        'canRetryPayment': 'can_retry_payment',
      },
    );

Map<String, dynamic> _$OrderSummaryToJson(OrderSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': _$OrderStatusEnumEnumMap[instance.status]!,
      'payment_method': _$PaymentMethodEnumEnumMap[instance.paymentMethod]!,
      'payment_status': _$PaymentStatusEnumEnumMap[instance.paymentStatus]!,
      'store': instance.store.toJson(),
      'item_count': instance.itemCount,
      'images': instance.images.map((e) => e.toJson()).toList(),
      'grand_total': instance.grandTotal,
      'created_at': instance.createdAt.toIso8601String(),
      'placed_at': instance.placedAt?.toIso8601String(),
      'payment_expires_at': instance.paymentExpiresAt?.toIso8601String(),
      'eta_at': instance.etaAt?.toIso8601String(),
      'can_retry_payment': instance.canRetryPayment,
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
