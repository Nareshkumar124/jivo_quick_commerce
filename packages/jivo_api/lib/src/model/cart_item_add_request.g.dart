// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item_add_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartItemAddRequestCWProxy {
  CartItemAddRequest variantId(int variantId);

  CartItemAddRequest quantity(int quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartItemAddRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartItemAddRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CartItemAddRequest call({int variantId, int quantity});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartItemAddRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartItemAddRequest.copyWith.fieldName(...)`
class _$CartItemAddRequestCWProxyImpl implements _$CartItemAddRequestCWProxy {
  const _$CartItemAddRequestCWProxyImpl(this._value);

  final CartItemAddRequest _value;

  @override
  CartItemAddRequest variantId(int variantId) => this(variantId: variantId);

  @override
  CartItemAddRequest quantity(int quantity) => this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartItemAddRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartItemAddRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CartItemAddRequest call({
    Object? variantId = const $CopyWithPlaceholder(),
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return CartItemAddRequest(
      variantId: variantId == const $CopyWithPlaceholder()
          ? _value.variantId
          // ignore: cast_nullable_to_non_nullable
          : variantId as int,
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as int,
    );
  }
}

extension $CartItemAddRequestCopyWith on CartItemAddRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCartItemAddRequest.copyWith(...)` or like so:`instanceOfCartItemAddRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartItemAddRequestCWProxy get copyWith =>
      _$CartItemAddRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartItemAddRequest _$CartItemAddRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CartItemAddRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['variant_id', 'quantity']);
      final val = CartItemAddRequest(
        variantId: $checkedConvert('variant_id', (v) => (v as num).toInt()),
        quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
      );
      return val;
    }, fieldKeyMap: const {'variantId': 'variant_id'});

Map<String, dynamic> _$CartItemAddRequestToJson(CartItemAddRequest instance) =>
    <String, dynamic>{
      'variant_id': instance.variantId,
      'quantity': instance.quantity,
    };
