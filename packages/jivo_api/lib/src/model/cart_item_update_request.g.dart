// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item_update_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartItemUpdateRequestCWProxy {
  CartItemUpdateRequest quantity(int quantity);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartItemUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartItemUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CartItemUpdateRequest call({int quantity});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartItemUpdateRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartItemUpdateRequest.copyWith.fieldName(...)`
class _$CartItemUpdateRequestCWProxyImpl
    implements _$CartItemUpdateRequestCWProxy {
  const _$CartItemUpdateRequestCWProxyImpl(this._value);

  final CartItemUpdateRequest _value;

  @override
  CartItemUpdateRequest quantity(int quantity) => this(quantity: quantity);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartItemUpdateRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartItemUpdateRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CartItemUpdateRequest call({
    Object? quantity = const $CopyWithPlaceholder(),
  }) {
    return CartItemUpdateRequest(
      quantity: quantity == const $CopyWithPlaceholder()
          ? _value.quantity
          // ignore: cast_nullable_to_non_nullable
          : quantity as int,
    );
  }
}

extension $CartItemUpdateRequestCopyWith on CartItemUpdateRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCartItemUpdateRequest.copyWith(...)` or like so:`instanceOfCartItemUpdateRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartItemUpdateRequestCWProxy get copyWith =>
      _$CartItemUpdateRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartItemUpdateRequest _$CartItemUpdateRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CartItemUpdateRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['quantity']);
  final val = CartItemUpdateRequest(
    quantity: $checkedConvert('quantity', (v) => (v as num).toInt()),
  );
  return val;
});

Map<String, dynamic> _$CartItemUpdateRequestToJson(
  CartItemUpdateRequest instance,
) => <String, dynamic>{'quantity': instance.quantity};
