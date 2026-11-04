// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_placement.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$OrderPlacementCWProxy {
  OrderPlacement order(Order order);

  OrderPlacement razorpay(RazorpayCheckout? razorpay);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderPlacement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderPlacement(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderPlacement call({Order order, RazorpayCheckout? razorpay});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfOrderPlacement.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfOrderPlacement.copyWith.fieldName(...)`
class _$OrderPlacementCWProxyImpl implements _$OrderPlacementCWProxy {
  const _$OrderPlacementCWProxyImpl(this._value);

  final OrderPlacement _value;

  @override
  OrderPlacement order(Order order) => this(order: order);

  @override
  OrderPlacement razorpay(RazorpayCheckout? razorpay) =>
      this(razorpay: razorpay);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `OrderPlacement(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// OrderPlacement(...).copyWith(id: 12, name: "My name")
  /// ````
  OrderPlacement call({
    Object? order = const $CopyWithPlaceholder(),
    Object? razorpay = const $CopyWithPlaceholder(),
  }) {
    return OrderPlacement(
      order: order == const $CopyWithPlaceholder()
          ? _value.order
          // ignore: cast_nullable_to_non_nullable
          : order as Order,
      razorpay: razorpay == const $CopyWithPlaceholder()
          ? _value.razorpay
          // ignore: cast_nullable_to_non_nullable
          : razorpay as RazorpayCheckout?,
    );
  }
}

extension $OrderPlacementCopyWith on OrderPlacement {
  /// Returns a callable class that can be used as follows: `instanceOfOrderPlacement.copyWith(...)` or like so:`instanceOfOrderPlacement.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$OrderPlacementCWProxy get copyWith => _$OrderPlacementCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderPlacement _$OrderPlacementFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OrderPlacement', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['order', 'razorpay']);
      final val = OrderPlacement(
        order: $checkedConvert(
          'order',
          (v) => Order.fromJson(v as Map<String, dynamic>),
        ),
        razorpay: $checkedConvert(
          'razorpay',
          (v) => v == null
              ? null
              : RazorpayCheckout.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$OrderPlacementToJson(OrderPlacement instance) =>
    <String, dynamic>{
      'order': instance.order.toJson(),
      'razorpay': instance.razorpay?.toJson(),
    };
