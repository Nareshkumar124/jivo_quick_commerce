// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderCWProxy {
  Order id(int id);

  Order orderNumber(String orderNumber);

  Order status(OrderStatusEnum status);

  Order paymentMethod(PaymentMethodEnum paymentMethod);

  Order paymentStatus(PaymentStatusEnum paymentStatus);

  Order store(OrderStore store);

  Order items(List<OrderLine> items);

  Order itemCount(int itemCount);

  Order bill(Bill bill);

  Order couponCode(String? couponCode);

  Order address(OrderAddress address);

  Order instructions(DeliveryInstructions instructions);

  Order createdAt(DateTime createdAt);

  Order placedAt(DateTime? placedAt);

  Order paymentExpiresAt(DateTime? paymentExpiresAt);

  Order etaAt(DateTime? etaAt);

  Order canCancel(bool canCancel);

  Order canRetryPayment(bool canRetryPayment);

  Order timeline(List<OrderTimelineEntry> timeline);

  Order cancellation(OrderCancellation? cancellation);

  Order amountRefunded(String amountRefunded);

  Order refunds(List<OrderRefund> refunds);

  Order canDownloadInvoice(bool canDownloadInvoice);

  Order canRate(bool canRate);

  Order rating(OrderRating? rating);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Order(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Order(...).copyWith(id: 12, name: "My name")
  /// ````
  Order call({
    int id,
    String orderNumber,
    OrderStatusEnum status,
    PaymentMethodEnum paymentMethod,
    PaymentStatusEnum paymentStatus,
    OrderStore store,
    List<OrderLine> items,
    int itemCount,
    Bill bill,
    String? couponCode,
    OrderAddress address,
    DeliveryInstructions instructions,
    DateTime createdAt,
    DateTime? placedAt,
    DateTime? paymentExpiresAt,
    DateTime? etaAt,
    bool canCancel,
    bool canRetryPayment,
    List<OrderTimelineEntry> timeline,
    OrderCancellation? cancellation,
    String amountRefunded,
    List<OrderRefund> refunds,
    bool canDownloadInvoice,
    bool canRate,
    OrderRating? rating,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrder.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrder.copyWith.fieldName(...)`
class _$OrderCWProxyImpl implements _$OrderCWProxy {
  const _$OrderCWProxyImpl(this._value);

  final Order _value;

  @override
  Order id(int id) => this(id: id);

  @override
  Order orderNumber(String orderNumber) => this(orderNumber: orderNumber);

  @override
  Order status(OrderStatusEnum status) => this(status: status);

  @override
  Order paymentMethod(PaymentMethodEnum paymentMethod) =>
      this(paymentMethod: paymentMethod);

  @override
  Order paymentStatus(PaymentStatusEnum paymentStatus) =>
      this(paymentStatus: paymentStatus);

  @override
  Order store(OrderStore store) => this(store: store);

  @override
  Order items(List<OrderLine> items) => this(items: items);

  @override
  Order itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  Order bill(Bill bill) => this(bill: bill);

  @override
  Order couponCode(String? couponCode) => this(couponCode: couponCode);

  @override
  Order address(OrderAddress address) => this(address: address);

  @override
  Order instructions(DeliveryInstructions instructions) =>
      this(instructions: instructions);

  @override
  Order createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  Order placedAt(DateTime? placedAt) => this(placedAt: placedAt);

  @override
  Order paymentExpiresAt(DateTime? paymentExpiresAt) =>
      this(paymentExpiresAt: paymentExpiresAt);

  @override
  Order etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  Order canCancel(bool canCancel) => this(canCancel: canCancel);

  @override
  Order canRetryPayment(bool canRetryPayment) =>
      this(canRetryPayment: canRetryPayment);

  @override
  Order timeline(List<OrderTimelineEntry> timeline) => this(timeline: timeline);

  @override
  Order cancellation(OrderCancellation? cancellation) =>
      this(cancellation: cancellation);

  @override
  Order amountRefunded(String amountRefunded) =>
      this(amountRefunded: amountRefunded);

  @override
  Order refunds(List<OrderRefund> refunds) => this(refunds: refunds);

  @override
  Order canDownloadInvoice(bool canDownloadInvoice) =>
      this(canDownloadInvoice: canDownloadInvoice);

  @override
  Order canRate(bool canRate) => this(canRate: canRate);

  @override
  Order rating(OrderRating? rating) => this(rating: rating);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Order(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Order(...).copyWith(id: 12, name: "My name")
  /// ````
  Order call({
    Object? id = const $CopyWithPlaceholder(),
    Object? orderNumber = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? paymentMethod = const $CopyWithPlaceholder(),
    Object? paymentStatus = const $CopyWithPlaceholder(),
    Object? store = const $CopyWithPlaceholder(),
    Object? items = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? bill = const $CopyWithPlaceholder(),
    Object? couponCode = const $CopyWithPlaceholder(),
    Object? address = const $CopyWithPlaceholder(),
    Object? instructions = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? placedAt = const $CopyWithPlaceholder(),
    Object? paymentExpiresAt = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? canCancel = const $CopyWithPlaceholder(),
    Object? canRetryPayment = const $CopyWithPlaceholder(),
    Object? timeline = const $CopyWithPlaceholder(),
    Object? cancellation = const $CopyWithPlaceholder(),
    Object? amountRefunded = const $CopyWithPlaceholder(),
    Object? refunds = const $CopyWithPlaceholder(),
    Object? canDownloadInvoice = const $CopyWithPlaceholder(),
    Object? canRate = const $CopyWithPlaceholder(),
    Object? rating = const $CopyWithPlaceholder(),
  }) {
    return Order(
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
      items: items == const $CopyWithPlaceholder()
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<OrderLine>,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      bill: bill == const $CopyWithPlaceholder()
          ? _value.bill
          // ignore: cast_nullable_to_non_nullable
          : bill as Bill,
      couponCode: couponCode == const $CopyWithPlaceholder()
          ? _value.couponCode
          // ignore: cast_nullable_to_non_nullable
          : couponCode as String?,
      address: address == const $CopyWithPlaceholder()
          ? _value.address
          // ignore: cast_nullable_to_non_nullable
          : address as OrderAddress,
      instructions: instructions == const $CopyWithPlaceholder()
          ? _value.instructions
          // ignore: cast_nullable_to_non_nullable
          : instructions as DeliveryInstructions,
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
      canCancel: canCancel == const $CopyWithPlaceholder()
          ? _value.canCancel
          // ignore: cast_nullable_to_non_nullable
          : canCancel as bool,
      canRetryPayment: canRetryPayment == const $CopyWithPlaceholder()
          ? _value.canRetryPayment
          // ignore: cast_nullable_to_non_nullable
          : canRetryPayment as bool,
      timeline: timeline == const $CopyWithPlaceholder()
          ? _value.timeline
          // ignore: cast_nullable_to_non_nullable
          : timeline as List<OrderTimelineEntry>,
      cancellation: cancellation == const $CopyWithPlaceholder()
          ? _value.cancellation
          // ignore: cast_nullable_to_non_nullable
          : cancellation as OrderCancellation?,
      amountRefunded: amountRefunded == const $CopyWithPlaceholder()
          ? _value.amountRefunded
          // ignore: cast_nullable_to_non_nullable
          : amountRefunded as String,
      refunds: refunds == const $CopyWithPlaceholder()
          ? _value.refunds
          // ignore: cast_nullable_to_non_nullable
          : refunds as List<OrderRefund>,
      canDownloadInvoice: canDownloadInvoice == const $CopyWithPlaceholder()
          ? _value.canDownloadInvoice
          // ignore: cast_nullable_to_non_nullable
          : canDownloadInvoice as bool,
      canRate: canRate == const $CopyWithPlaceholder()
          ? _value.canRate
          // ignore: cast_nullable_to_non_nullable
          : canRate as bool,
      rating: rating == const $CopyWithPlaceholder()
          ? _value.rating
          // ignore: cast_nullable_to_non_nullable
          : rating as OrderRating?,
    );
  }
}

extension $OrderCopyWith on Order {
  /// Returns a callable class that can be used as follows: `instanceOfOrder.copyWith(...)` or like so:`instanceOfOrder.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderCWProxy get copyWith => _$OrderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Order',
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
        'items',
        'item_count',
        'bill',
        'coupon_code',
        'address',
        'instructions',
        'created_at',
        'placed_at',
        'payment_expires_at',
        'eta_at',
        'can_cancel',
        'can_retry_payment',
        'timeline',
        'cancellation',
        'amount_refunded',
        'refunds',
        'can_download_invoice',
        'can_rate',
        'rating',
      ],
    );
    final val = Order(
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
      items: $checkedConvert(
        'items',
        (v) => (v as List<dynamic>)
            .map((e) => OrderLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
      bill: $checkedConvert(
        'bill',
        (v) => Bill.fromJson(v as Map<String, dynamic>),
      ),
      couponCode: $checkedConvert('coupon_code', (v) => v as String?),
      address: $checkedConvert(
        'address',
        (v) => OrderAddress.fromJson(v as Map<String, dynamic>),
      ),
      instructions: $checkedConvert(
        'instructions',
        (v) => DeliveryInstructions.fromJson(v as Map<String, dynamic>),
      ),
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
      canCancel: $checkedConvert('can_cancel', (v) => v as bool),
      canRetryPayment: $checkedConvert('can_retry_payment', (v) => v as bool),
      timeline: $checkedConvert(
        'timeline',
        (v) => (v as List<dynamic>)
            .map((e) => OrderTimelineEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      cancellation: $checkedConvert(
        'cancellation',
        (v) => v == null
            ? null
            : OrderCancellation.fromJson(v as Map<String, dynamic>),
      ),
      amountRefunded: $checkedConvert('amount_refunded', (v) => v as String),
      refunds: $checkedConvert(
        'refunds',
        (v) => (v as List<dynamic>)
            .map((e) => OrderRefund.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      canDownloadInvoice: $checkedConvert(
        'can_download_invoice',
        (v) => v as bool,
      ),
      canRate: $checkedConvert('can_rate', (v) => v as bool),
      rating: $checkedConvert(
        'rating',
        (v) =>
            v == null ? null : OrderRating.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'orderNumber': 'order_number',
    'paymentMethod': 'payment_method',
    'paymentStatus': 'payment_status',
    'itemCount': 'item_count',
    'couponCode': 'coupon_code',
    'createdAt': 'created_at',
    'placedAt': 'placed_at',
    'paymentExpiresAt': 'payment_expires_at',
    'etaAt': 'eta_at',
    'canCancel': 'can_cancel',
    'canRetryPayment': 'can_retry_payment',
    'amountRefunded': 'amount_refunded',
    'canDownloadInvoice': 'can_download_invoice',
    'canRate': 'can_rate',
  },
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'order_number': instance.orderNumber,
  'status': _$OrderStatusEnumEnumMap[instance.status]!,
  'payment_method': _$PaymentMethodEnumEnumMap[instance.paymentMethod]!,
  'payment_status': _$PaymentStatusEnumEnumMap[instance.paymentStatus]!,
  'store': instance.store.toJson(),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'item_count': instance.itemCount,
  'bill': instance.bill.toJson(),
  'coupon_code': instance.couponCode,
  'address': instance.address.toJson(),
  'instructions': instance.instructions.toJson(),
  'created_at': instance.createdAt.toIso8601String(),
  'placed_at': instance.placedAt?.toIso8601String(),
  'payment_expires_at': instance.paymentExpiresAt?.toIso8601String(),
  'eta_at': instance.etaAt?.toIso8601String(),
  'can_cancel': instance.canCancel,
  'can_retry_payment': instance.canRetryPayment,
  'timeline': instance.timeline.map((e) => e.toJson()).toList(),
  'cancellation': instance.cancellation?.toJson(),
  'amount_refunded': instance.amountRefunded,
  'refunds': instance.refunds.map((e) => e.toJson()).toList(),
  'can_download_invoice': instance.canDownloadInvoice,
  'can_rate': instance.canRate,
  'rating': instance.rating?.toJson(),
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
