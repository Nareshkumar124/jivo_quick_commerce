// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reorder_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReorderResultCWProxy {
  ReorderResult cart(Cart cart);

  ReorderResult unavailable(List<ReorderIssue> unavailable);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReorderResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReorderResult(...).copyWith(id: 12, name: "My name")
  /// ````
  ReorderResult call({Cart cart, List<ReorderIssue> unavailable});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReorderResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReorderResult.copyWith.fieldName(...)`
class _$ReorderResultCWProxyImpl implements _$ReorderResultCWProxy {
  const _$ReorderResultCWProxyImpl(this._value);

  final ReorderResult _value;

  @override
  ReorderResult cart(Cart cart) => this(cart: cart);

  @override
  ReorderResult unavailable(List<ReorderIssue> unavailable) =>
      this(unavailable: unavailable);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReorderResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReorderResult(...).copyWith(id: 12, name: "My name")
  /// ````
  ReorderResult call({
    Object? cart = const $CopyWithPlaceholder(),
    Object? unavailable = const $CopyWithPlaceholder(),
  }) {
    return ReorderResult(
      cart: cart == const $CopyWithPlaceholder()
          ? _value.cart
          // ignore: cast_nullable_to_non_nullable
          : cart as Cart,
      unavailable: unavailable == const $CopyWithPlaceholder()
          ? _value.unavailable
          // ignore: cast_nullable_to_non_nullable
          : unavailable as List<ReorderIssue>,
    );
  }
}

extension $ReorderResultCopyWith on ReorderResult {
  /// Returns a callable class that can be used as follows: `instanceOfReorderResult.copyWith(...)` or like so:`instanceOfReorderResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReorderResultCWProxy get copyWith => _$ReorderResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReorderResult _$ReorderResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReorderResult', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['cart', 'unavailable']);
      final val = ReorderResult(
        cart: $checkedConvert(
          'cart',
          (v) => Cart.fromJson(v as Map<String, dynamic>),
        ),
        unavailable: $checkedConvert(
          'unavailable',
          (v) => (v as List<dynamic>)
              .map((e) => ReorderIssue.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$ReorderResultToJson(ReorderResult instance) =>
    <String, dynamic>{
      'cart': instance.cart.toJson(),
      'unavailable': instance.unavailable.map((e) => e.toJson()).toList(),
    };
