// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartCWProxy {
  Cart store(StoreStatus store);

  Cart items(List<CartLine> items);

  Cart itemCount(int itemCount);

  Cart coupon(AppliedCoupon? coupon);

  Cart tip(String tip);

  Cart instructions(DeliveryInstructions instructions);

  Cart address(Address? address);

  Cart bill(Bill bill);

  Cart thresholds(CartThresholds thresholds);

  Cart paymentMethods(List<PaymentOption> paymentMethods);

  Cart checkout(CheckoutStatus checkout);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Cart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Cart(...).copyWith(id: 12, name: "My name")
  /// ````
  Cart call({
    StoreStatus store,
    List<CartLine> items,
    int itemCount,
    AppliedCoupon? coupon,
    String tip,
    DeliveryInstructions instructions,
    Address? address,
    Bill bill,
    CartThresholds thresholds,
    List<PaymentOption> paymentMethods,
    CheckoutStatus checkout,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCart.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCart.copyWith.fieldName(...)`
class _$CartCWProxyImpl implements _$CartCWProxy {
  const _$CartCWProxyImpl(this._value);

  final Cart _value;

  @override
  Cart store(StoreStatus store) => this(store: store);

  @override
  Cart items(List<CartLine> items) => this(items: items);

  @override
  Cart itemCount(int itemCount) => this(itemCount: itemCount);

  @override
  Cart coupon(AppliedCoupon? coupon) => this(coupon: coupon);

  @override
  Cart tip(String tip) => this(tip: tip);

  @override
  Cart instructions(DeliveryInstructions instructions) =>
      this(instructions: instructions);

  @override
  Cart address(Address? address) => this(address: address);

  @override
  Cart bill(Bill bill) => this(bill: bill);

  @override
  Cart thresholds(CartThresholds thresholds) => this(thresholds: thresholds);

  @override
  Cart paymentMethods(List<PaymentOption> paymentMethods) =>
      this(paymentMethods: paymentMethods);

  @override
  Cart checkout(CheckoutStatus checkout) => this(checkout: checkout);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Cart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Cart(...).copyWith(id: 12, name: "My name")
  /// ````
  Cart call({
    Object? store = const $CopyWithPlaceholder(),
    Object? items = const $CopyWithPlaceholder(),
    Object? itemCount = const $CopyWithPlaceholder(),
    Object? coupon = const $CopyWithPlaceholder(),
    Object? tip = const $CopyWithPlaceholder(),
    Object? instructions = const $CopyWithPlaceholder(),
    Object? address = const $CopyWithPlaceholder(),
    Object? bill = const $CopyWithPlaceholder(),
    Object? thresholds = const $CopyWithPlaceholder(),
    Object? paymentMethods = const $CopyWithPlaceholder(),
    Object? checkout = const $CopyWithPlaceholder(),
  }) {
    return Cart(
      store: store == const $CopyWithPlaceholder()
          ? _value.store
          // ignore: cast_nullable_to_non_nullable
          : store as StoreStatus,
      items: items == const $CopyWithPlaceholder()
          ? _value.items
          // ignore: cast_nullable_to_non_nullable
          : items as List<CartLine>,
      itemCount: itemCount == const $CopyWithPlaceholder()
          ? _value.itemCount
          // ignore: cast_nullable_to_non_nullable
          : itemCount as int,
      coupon: coupon == const $CopyWithPlaceholder()
          ? _value.coupon
          // ignore: cast_nullable_to_non_nullable
          : coupon as AppliedCoupon?,
      tip: tip == const $CopyWithPlaceholder()
          ? _value.tip
          // ignore: cast_nullable_to_non_nullable
          : tip as String,
      instructions: instructions == const $CopyWithPlaceholder()
          ? _value.instructions
          // ignore: cast_nullable_to_non_nullable
          : instructions as DeliveryInstructions,
      address: address == const $CopyWithPlaceholder()
          ? _value.address
          // ignore: cast_nullable_to_non_nullable
          : address as Address?,
      bill: bill == const $CopyWithPlaceholder()
          ? _value.bill
          // ignore: cast_nullable_to_non_nullable
          : bill as Bill,
      thresholds: thresholds == const $CopyWithPlaceholder()
          ? _value.thresholds
          // ignore: cast_nullable_to_non_nullable
          : thresholds as CartThresholds,
      paymentMethods: paymentMethods == const $CopyWithPlaceholder()
          ? _value.paymentMethods
          // ignore: cast_nullable_to_non_nullable
          : paymentMethods as List<PaymentOption>,
      checkout: checkout == const $CopyWithPlaceholder()
          ? _value.checkout
          // ignore: cast_nullable_to_non_nullable
          : checkout as CheckoutStatus,
    );
  }
}

extension $CartCopyWith on Cart {
  /// Returns a callable class that can be used as follows: `instanceOfCart.copyWith(...)` or like so:`instanceOfCart.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartCWProxy get copyWith => _$CartCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Cart _$CartFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Cart',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'store',
        'items',
        'item_count',
        'coupon',
        'tip',
        'instructions',
        'address',
        'bill',
        'thresholds',
        'payment_methods',
        'checkout',
      ],
    );
    final val = Cart(
      store: $checkedConvert(
        'store',
        (v) => StoreStatus.fromJson(v as Map<String, dynamic>),
      ),
      items: $checkedConvert(
        'items',
        (v) => (v as List<dynamic>)
            .map((e) => CartLine.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      itemCount: $checkedConvert('item_count', (v) => (v as num).toInt()),
      coupon: $checkedConvert(
        'coupon',
        (v) => v == null
            ? null
            : AppliedCoupon.fromJson(v as Map<String, dynamic>),
      ),
      tip: $checkedConvert('tip', (v) => v as String),
      instructions: $checkedConvert(
        'instructions',
        (v) => DeliveryInstructions.fromJson(v as Map<String, dynamic>),
      ),
      address: $checkedConvert(
        'address',
        (v) => v == null ? null : Address.fromJson(v as Map<String, dynamic>),
      ),
      bill: $checkedConvert(
        'bill',
        (v) => Bill.fromJson(v as Map<String, dynamic>),
      ),
      thresholds: $checkedConvert(
        'thresholds',
        (v) => CartThresholds.fromJson(v as Map<String, dynamic>),
      ),
      paymentMethods: $checkedConvert(
        'payment_methods',
        (v) => (v as List<dynamic>)
            .map((e) => PaymentOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
      checkout: $checkedConvert(
        'checkout',
        (v) => CheckoutStatus.fromJson(v as Map<String, dynamic>),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'itemCount': 'item_count',
    'paymentMethods': 'payment_methods',
  },
);

Map<String, dynamic> _$CartToJson(Cart instance) => <String, dynamic>{
  'store': instance.store.toJson(),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'item_count': instance.itemCount,
  'coupon': instance.coupon?.toJson(),
  'tip': instance.tip,
  'instructions': instance.instructions.toJson(),
  'address': instance.address?.toJson(),
  'bill': instance.bill.toJson(),
  'thresholds': instance.thresholds.toJson(),
  'payment_methods': instance.paymentMethods.map((e) => e.toJson()).toList(),
  'checkout': instance.checkout.toJson(),
};
