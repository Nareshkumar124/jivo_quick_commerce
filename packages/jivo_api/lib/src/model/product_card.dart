// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/variant_summary.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_card.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProductCard {
  /// Returns a new [ProductCard] instance.
  ProductCard({
    required this.id,

    required this.slug,

    required this.name,

    required this.brand,

    required this.isVeg,

    required this.image,

    required this.defaultVariantId,

    required this.variants,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// For product links: `GET /products/{slug}/`.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  /// e.g. \"Jivo Cold Pressed Canola Oil\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// \"Jivo\" for every product in v1.
  @JsonKey(name: r'brand', required: true, includeIfNull: false)
  final String brand;

  /// FSSAI veg mark (green dot) when true.
  @JsonKey(name: r'is_veg', required: true, includeIfNull: false)
  final bool isVeg;

  /// Image of the default variant (see `default_variant_id`). Null when none.
  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  /// The variant the tile shows and ADD adds: the one this list is about (e.g. the collection item or past purchase), else the first in-stock variant, else the first. Always one of `variants`.
  @JsonKey(name: r'default_variant_id', required: true, includeIfNull: false)
  final int defaultVariantId;

  /// Every active variant this store sells, in display order (the chips on the detail page), including out-of-stock ones. With more than one, ADD opens a variant picker. Never empty.
  @JsonKey(name: r'variants', required: true, includeIfNull: false)
  final List<VariantSummary> variants;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductCard &&
          other.id == id &&
          other.slug == slug &&
          other.name == name &&
          other.brand == brand &&
          other.isVeg == isVeg &&
          other.image == image &&
          other.defaultVariantId == defaultVariantId &&
          other.variants == variants;

  @override
  int get hashCode =>
      id.hashCode +
      slug.hashCode +
      name.hashCode +
      brand.hashCode +
      isVeg.hashCode +
      (image == null ? 0 : image.hashCode) +
      defaultVariantId.hashCode +
      variants.hashCode;

  factory ProductCard.fromJson(Map<String, dynamic> json) =>
      _$ProductCardFromJson(json);

  Map<String, dynamic> toJson() => _$ProductCardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
