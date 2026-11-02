// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_rail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CollectionRailCWProxy {
  CollectionRail id(int id);

  CollectionRail name(String name);

  CollectionRail slug(String slug);

  CollectionRail products(List<ProductCard> products);

  CollectionRail hasMore(bool hasMore);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionRail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionRail(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionRail call({
    int id,
    String name,
    String slug,
    List<ProductCard> products,
    bool hasMore,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCollectionRail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCollectionRail.copyWith.fieldName(...)`
class _$CollectionRailCWProxyImpl implements _$CollectionRailCWProxy {
  const _$CollectionRailCWProxyImpl(this._value);

  final CollectionRail _value;

  @override
  CollectionRail id(int id) => this(id: id);

  @override
  CollectionRail name(String name) => this(name: name);

  @override
  CollectionRail slug(String slug) => this(slug: slug);

  @override
  CollectionRail products(List<ProductCard> products) =>
      this(products: products);

  @override
  CollectionRail hasMore(bool hasMore) => this(hasMore: hasMore);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CollectionRail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CollectionRail(...).copyWith(id: 12, name: "My name")
  /// ````
  CollectionRail call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? products = const $CopyWithPlaceholder(),
    Object? hasMore = const $CopyWithPlaceholder(),
  }) {
    return CollectionRail(
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
      hasMore: hasMore == const $CopyWithPlaceholder()
          ? _value.hasMore
          // ignore: cast_nullable_to_non_nullable
          : hasMore as bool,
    );
  }
}

extension $CollectionRailCopyWith on CollectionRail {
  /// Returns a callable class that can be used as follows: `instanceOfCollectionRail.copyWith(...)` or like so:`instanceOfCollectionRail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CollectionRailCWProxy get copyWith => _$CollectionRailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CollectionRail _$CollectionRailFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CollectionRail', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'name', 'slug', 'products', 'has_more'],
      );
      final val = CollectionRail(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
        products: $checkedConvert(
          'products',
          (v) => (v as List<dynamic>)
              .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        hasMore: $checkedConvert('has_more', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'hasMore': 'has_more'});

Map<String, dynamic> _$CollectionRailToJson(CollectionRail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'products': instance.products.map((e) => e.toJson()).toList(),
      'has_more': instance.hasMore,
    };
