// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'free_variant.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FreeVariantCWProxy {
  FreeVariant id(int id);

  FreeVariant name(String name);

  FreeVariant productName(String productName);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeVariant(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeVariant(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeVariant call({int id, String name, String productName});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFreeVariant.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFreeVariant.copyWith.fieldName(...)`
class _$FreeVariantCWProxyImpl implements _$FreeVariantCWProxy {
  const _$FreeVariantCWProxyImpl(this._value);

  final FreeVariant _value;

  @override
  FreeVariant id(int id) => this(id: id);

  @override
  FreeVariant name(String name) => this(name: name);

  @override
  FreeVariant productName(String productName) => this(productName: productName);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FreeVariant(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FreeVariant(...).copyWith(id: 12, name: "My name")
  /// ````
  FreeVariant call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? productName = const $CopyWithPlaceholder(),
  }) {
    return FreeVariant(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      productName: productName == const $CopyWithPlaceholder()
          ? _value.productName
          // ignore: cast_nullable_to_non_nullable
          : productName as String,
    );
  }
}

extension $FreeVariantCopyWith on FreeVariant {
  /// Returns a callable class that can be used as follows: `instanceOfFreeVariant.copyWith(...)` or like so:`instanceOfFreeVariant.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FreeVariantCWProxy get copyWith => _$FreeVariantCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FreeVariant _$FreeVariantFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FreeVariant', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'product_name']);
      final val = FreeVariant(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        productName: $checkedConvert('product_name', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'productName': 'product_name'});

Map<String, dynamic> _$FreeVariantToJson(FreeVariant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'product_name': instance.productName,
    };
