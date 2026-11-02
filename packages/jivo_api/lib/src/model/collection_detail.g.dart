// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CollectionDetailCWProxy {
  CollectionDetail id(int id);

  CollectionDetail name(String name);

  CollectionDetail slug(String slug);

  CollectionDetail products(List<ProductCard> products);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionDetail call({
    int id,
    String name,
    String slug,
    List<ProductCard> products,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCollectionDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCollectionDetail.copyWith.fieldName(...)`
class _$CollectionDetailCWProxyImpl implements _$CollectionDetailCWProxy {
  const _$CollectionDetailCWProxyImpl(this._value);

  final CollectionDetail _value;

  @override
  CollectionDetail id(int id) => this(id: id);

  @override
  CollectionDetail name(String name) => this(name: name);

  @override
  CollectionDetail slug(String slug) => this(slug: slug);

  @override
  CollectionDetail products(List<ProductCard> products) =>
      this(products: products);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionDetail call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? products = const $CopyWithPlaceholder(),
  }) {
    return CollectionDetail(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      products: products == const $CopyWithPlaceholder()
          ? _value.products
          // ignore: cast_nullable_to_non_nullable
          : products as List<ProductCard>,
    );
  }
}

extension $CollectionDetailCopyWith on CollectionDetail {
  /// Returns a callable class that can be used as follows: `instanceOfCollectionDetail.copyWith(...)` or like so:`instanceOfCollectionDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CollectionDetailCWProxy get copyWith => _$CollectionDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CollectionDetail _$CollectionDetailFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CollectionDetail', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'slug', 'products']);
      final val = CollectionDetail(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
        products: $checkedConvert(
          'products',
          (v) => (v as List<dynamic>)
              .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CollectionDetailToJson(CollectionDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'products': instance.products.map((e) => e.toJson()).toList(),
    };
