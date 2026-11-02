// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_card.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProductCardCWProxy {
  ProductCard id(int id);

  ProductCard slug(String slug);

  ProductCard name(String name);

  ProductCard brand(String brand);

  ProductCard isVeg(bool isVeg);

  ProductCard image(ImageSet? image);

  ProductCard defaultVariantId(int defaultVariantId);

  ProductCard variants(List<VariantSummary> variants);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProductCard(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProductCard(...).copyWith(id: 12, name: "My name")
  /// ````
  ProductCard call({
    int id,
    String slug,
    String name,
    String brand,
    bool isVeg,
    ImageSet? image,
    int defaultVariantId,
    List<VariantSummary> variants,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProductCard.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProductCard.copyWith.fieldName(...)`
class _$ProductCardCWProxyImpl implements _$ProductCardCWProxy {
  const _$ProductCardCWProxyImpl(this._value);

  final ProductCard _value;

  @override
  ProductCard id(int id) => this(id: id);

  @override
  ProductCard slug(String slug) => this(slug: slug);

  @override
  ProductCard name(String name) => this(name: name);

  @override
  ProductCard brand(String brand) => this(brand: brand);

  @override
  ProductCard isVeg(bool isVeg) => this(isVeg: isVeg);

  @override
  ProductCard image(ImageSet? image) => this(image: image);

  @override
  ProductCard defaultVariantId(int defaultVariantId) =>
      this(defaultVariantId: defaultVariantId);

  @override
  ProductCard variants(List<VariantSummary> variants) =>
      this(variants: variants);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProductCard(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProductCard(...).copyWith(id: 12, name: "My name")
  /// ````
  ProductCard call({
    Object? id = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? brand = const $CopyWithPlaceholder(),
    Object? isVeg = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
    Object? defaultVariantId = const $CopyWithPlaceholder(),
    Object? variants = const $CopyWithPlaceholder(),
  }) {
    return ProductCard(
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
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet?,
      defaultVariantId: defaultVariantId == const $CopyWithPlaceholder()
          ? _value.defaultVariantId
          // ignore: cast_nullable_to_non_nullable
          : defaultVariantId as int,
      variants: variants == const $CopyWithPlaceholder()
          ? _value.variants
          // ignore: cast_nullable_to_non_nullable
          : variants as List<VariantSummary>,
    );
  }
}

extension $ProductCardCopyWith on ProductCard {
  /// Returns a callable class that can be used as follows: `instanceOfProductCard.copyWith(...)` or like so:`instanceOfProductCard.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProductCardCWProxy get copyWith => _$ProductCardCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductCard _$ProductCardFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ProductCard',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'slug',
        'name',
        'brand',
        'is_veg',
        'image',
        'default_variant_id',
        'variants',
      ],
    );
    final val = ProductCard(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      slug: $checkedConvert('slug', (v) => v as String),
      name: $checkedConvert('name', (v) => v as String),
      brand: $checkedConvert('brand', (v) => v as String),
      isVeg: $checkedConvert('is_veg', (v) => v as bool),
      image: $checkedConvert(
        'image',
        (v) => v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
      ),
      defaultVariantId: $checkedConvert(
        'default_variant_id',
        (v) => (v as num).toInt(),
      ),
      variants: $checkedConvert(
        'variants',
        (v) => (v as List<dynamic>)
            .map((e) => VariantSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'isVeg': 'is_veg',
    'defaultVariantId': 'default_variant_id',
  },
);

Map<String, dynamic> _$ProductCardToJson(ProductCard instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'brand': instance.brand,
      'is_veg': instance.isVeg,
      'image': instance.image?.toJson(),
      'default_variant_id': instance.defaultVariantId,
      'variants': instance.variants.map((e) => e.toJson()).toList(),
    };
