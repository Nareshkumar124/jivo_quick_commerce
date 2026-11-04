// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BillCWProxy {
  Bill mrpTotal(String mrpTotal);

  Bill itemTotal(String itemTotal);

  Bill productDiscount(String productDiscount);

  Bill couponDiscount(String couponDiscount);

  Bill deliveryFee(String deliveryFee);

  Bill smallCartFee(String smallCartFee);

  Bill handlingFee(String handlingFee);

  Bill tip(String tip);

  Bill grandTotal(String grandTotal);

  Bill totalSavings(String totalSavings);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Bill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Bill(...).copyWith(id: 12, name: "My name")
  /// ````
  Bill call({
    String mrpTotal,
    String itemTotal,
    String productDiscount,
    String couponDiscount,
    String deliveryFee,
    String smallCartFee,
    String handlingFee,
    String tip,
    String grandTotal,
    String totalSavings,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBill.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBill.copyWith.fieldName(...)`
class _$BillCWProxyImpl implements _$BillCWProxy {
  const _$BillCWProxyImpl(this._value);

  final Bill _value;

  @override
  Bill mrpTotal(String mrpTotal) => this(mrpTotal: mrpTotal);

  @override
  Bill itemTotal(String itemTotal) => this(itemTotal: itemTotal);

  @override
  Bill productDiscount(String productDiscount) =>
      this(productDiscount: productDiscount);

  @override
  Bill couponDiscount(String couponDiscount) =>
      this(couponDiscount: couponDiscount);

  @override
  Bill deliveryFee(String deliveryFee) => this(deliveryFee: deliveryFee);

  @override
  Bill smallCartFee(String smallCartFee) => this(smallCartFee: smallCartFee);

  @override
  Bill handlingFee(String handlingFee) => this(handlingFee: handlingFee);

  @override
  Bill tip(String tip) => this(tip: tip);

  @override
  Bill grandTotal(String grandTotal) => this(grandTotal: grandTotal);

  @override
  Bill totalSavings(String totalSavings) => this(totalSavings: totalSavings);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Bill(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Bill(...).copyWith(id: 12, name: "My name")
  /// ````
  Bill call({
    Object? mrpTotal = const $CopyWithPlaceholder(),
    Object? itemTotal = const $CopyWithPlaceholder(),
    Object? productDiscount = const $CopyWithPlaceholder(),
    Object? couponDiscount = const $CopyWithPlaceholder(),
    Object? deliveryFee = const $CopyWithPlaceholder(),
    Object? smallCartFee = const $CopyWithPlaceholder(),
    Object? handlingFee = const $CopyWithPlaceholder(),
    Object? tip = const $CopyWithPlaceholder(),
    Object? grandTotal = const $CopyWithPlaceholder(),
    Object? totalSavings = const $CopyWithPlaceholder(),
  }) {
    return Bill(
      mrpTotal: mrpTotal == const $CopyWithPlaceholder()
          ? _value.mrpTotal
          // ignore: cast_nullable_to_non_nullable
          : mrpTotal as String,
      itemTotal: itemTotal == const $CopyWithPlaceholder()
          ? _value.itemTotal
          // ignore: cast_nullable_to_non_nullable
          : itemTotal as String,
      productDiscount: productDiscount == const $CopyWithPlaceholder()
          ? _value.productDiscount
          // ignore: cast_nullable_to_non_nullable
          : productDiscount as String,
      couponDiscount: couponDiscount == const $CopyWithPlaceholder()
          ? _value.couponDiscount
          // ignore: cast_nullable_to_non_nullable
          : couponDiscount as String,
      deliveryFee: deliveryFee == const $CopyWithPlaceholder()
          ? _value.deliveryFee
          // ignore: cast_nullable_to_non_nullable
          : deliveryFee as String,
      smallCartFee: smallCartFee == const $CopyWithPlaceholder()
          ? _value.smallCartFee
          // ignore: cast_nullable_to_non_nullable
          : smallCartFee as String,
      handlingFee: handlingFee == const $CopyWithPlaceholder()
          ? _value.handlingFee
          // ignore: cast_nullable_to_non_nullable
          : handlingFee as String,
      tip: tip == const $CopyWithPlaceholder()
          ? _value.tip
          // ignore: cast_nullable_to_non_nullable
          : tip as String,
      grandTotal: grandTotal == const $CopyWithPlaceholder()
          ? _value.grandTotal
          // ignore: cast_nullable_to_non_nullable
          : grandTotal as String,
      totalSavings: totalSavings == const $CopyWithPlaceholder()
          ? _value.totalSavings
          // ignore: cast_nullable_to_non_nullable
          : totalSavings as String,
    );
  }
}

extension $BillCopyWith on Bill {
  /// Returns a callable class that can be used as follows: `instanceOfBill.copyWith(...)` or like so:`instanceOfBill.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BillCWProxy get copyWith => _$BillCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Bill _$BillFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Bill',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'mrp_total',
        'item_total',
        'product_discount',
        'coupon_discount',
        'delivery_fee',
        'small_cart_fee',
        'handling_fee',
        'tip',
        'grand_total',
        'total_savings',
      ],
    );
    final val = Bill(
      mrpTotal: $checkedConvert('mrp_total', (v) => v as String),
      itemTotal: $checkedConvert('item_total', (v) => v as String),
      productDiscount: $checkedConvert('product_discount', (v) => v as String),
      couponDiscount: $checkedConvert('coupon_discount', (v) => v as String),
      deliveryFee: $checkedConvert('delivery_fee', (v) => v as String),
      smallCartFee: $checkedConvert('small_cart_fee', (v) => v as String),
      handlingFee: $checkedConvert('handling_fee', (v) => v as String),
      tip: $checkedConvert('tip', (v) => v as String),
      grandTotal: $checkedConvert('grand_total', (v) => v as String),
      totalSavings: $checkedConvert('total_savings', (v) => v as String),
    );
    return val;
  },
  fieldKeyMap: const {
    'mrpTotal': 'mrp_total',
    'itemTotal': 'item_total',
    'productDiscount': 'product_discount',
    'couponDiscount': 'coupon_discount',
    'deliveryFee': 'delivery_fee',
    'smallCartFee': 'small_cart_fee',
    'handlingFee': 'handling_fee',
    'grandTotal': 'grand_total',
    'totalSavings': 'total_savings',
  },
);

Map<String, dynamic> _$BillToJson(Bill instance) => <String, dynamic>{
  'mrp_total': instance.mrpTotal,
  'item_total': instance.itemTotal,
  'product_discount': instance.productDiscount,
  'coupon_discount': instance.couponDiscount,
  'delivery_fee': instance.deliveryFee,
  'small_cart_fee': instance.smallCartFee,
  'handling_fee': instance.handlingFee,
  'tip': instance.tip,
  'grand_total': instance.grandTotal,
  'total_savings': instance.totalSavings,
};
