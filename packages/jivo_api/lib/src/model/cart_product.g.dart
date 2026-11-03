// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_product.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CartProductCWProxy {
  CartProduct id(int id);

  CartProduct slug(String slug);

  CartProduct name(String name);

  CartProduct brand(String brand);

  CartProduct isVeg(bool isVeg);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartProduct(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartProduct(...).copyWith(id: 12, name: "My name")
  /// ````
  CartProduct call({
    int id,
    String slug,
    String name,
    String brand,
    bool isVeg,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCartProduct.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCartProduct.copyWith.fieldName(...)`
class _$CartProductCWProxyImpl implements _$CartProductCWProxy {
  const _$CartProductCWProxyImpl(this._value);

  final CartProduct _value;

  @override
  CartProduct id(int id) => this(id: id);

  @override
  CartProduct slug(String slug) => this(slug: slug);

  @override
  CartProduct name(String name) => this(name: name);

  @override
  CartProduct brand(String brand) => this(brand: brand);

  @override
  CartProduct isVeg(bool isVeg) => this(isVeg: isVeg);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CartProduct(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CartProduct(...).copyWith(id: 12, name: "My name")
  /// ````
  CartProduct call({
    Object? id = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? brand = const $CopyWithPlaceholder(),
    Object? isVeg = const $CopyWithPlaceholder(),
  }) {
    return CartProduct(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      brand: brand == const $CopyWithPlaceholder()
          ? _value.brand
          // ignore: cast_nullable_to_non_nullable
          : brand as String,
      isVeg: isVeg == const $CopyWithPlaceholder()
          ? _value.isVeg
          // ignore: cast_nullable_to_non_nullable
          : isVeg as bool,
    );
  }
}

extension $CartProductCopyWith on CartProduct {
  /// Returns a callable class that can be used as follows: `instanceOfCartProduct.copyWith(...)` or like so:`instanceOfCartProduct.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CartProductCWProxy get copyWith => _$CartProductCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CartProduct _$CartProductFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CartProduct', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'slug', 'name', 'brand', 'is_veg'],
      );
      final val = CartProduct(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        slug: $checkedConvert('slug', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        brand: $checkedConvert('brand', (v) => v as String),
        isVeg: $checkedConvert('is_veg', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'isVeg': 'is_veg'});

Map<String, dynamic> _$CartProductToJson(CartProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'brand': instance.brand,
      'is_veg': instance.isVeg,
    };
