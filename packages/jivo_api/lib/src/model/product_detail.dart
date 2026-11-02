// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/variant_detail.dart';
import 'package:jivo_api/src/model/nutrition_table.dart';
import 'package:jivo_api/src/model/category_tile.dart';
import 'package:jivo_api/src/model/product_card.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProductDetail {
  /// Returns a new [ProductDetail] instance.
  ProductDetail({
    required this.id,

    required this.slug,

    required this.name,

    required this.brand,

    required this.isVeg,

    required this.category,

    required this.shortDescription,

    required this.description,

    required this.highlights,

    required this.defaultVariantId,

    required this.variants,

    required this.ingredients,

    required this.nutrition,

    required this.shelfLife,

    required this.storageInstructions,

    required this.countryOfOrigin,

    required this.manufacturer,

    required this.marketer,

    required this.importer,

    required this.consumerCare,

    required this.fssaiLicenseNo,

    required this.similarProducts,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'brand', required: true, includeIfNull: false)
  final String brand;

  /// FSSAI veg mark (green dot) when true.
  @JsonKey(name: r'is_veg', required: true, includeIfNull: false)
  final bool isVeg;

  /// The product's category (breadcrumb, links).
  @JsonKey(name: r'category', required: true, includeIfNull: false)
  final CategoryTile category;

  /// One or two lines.
  @JsonKey(name: r'short_description', required: true, includeIfNull: false)
  final String shortDescription;

  /// Plain text; paragraphs are separated by a blank line. No HTML or Markdown.
  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  /// Key highlights (bullet points).
  @JsonKey(name: r'highlights', required: true, includeIfNull: false)
  final List<String> highlights;

  /// Variant selected when the page opens (the one tapped, else first in stock).
  @JsonKey(name: r'default_variant_id', required: true, includeIfNull: false)
  final int defaultVariantId;

  /// Every active variant this store sells, in chip order (1 L / 2 L / 5 L), including out-of-stock ones. Never empty.
  @JsonKey(name: r'variants', required: true, includeIfNull: false)
  final List<VariantDetail> variants;

  @JsonKey(name: r'ingredients', required: true, includeIfNull: false)
  final String ingredients;

  /// Null when the product has no nutrition table.
  @JsonKey(name: r'nutrition', required: true, includeIfNull: true)
  final NutritionTable? nutrition;

  /// Best-before guidance, e.g. \"9 months from manufacture\".
  @JsonKey(name: r'shelf_life', required: true, includeIfNull: false)
  final String shelfLife;

  @JsonKey(name: r'storage_instructions', required: true, includeIfNull: false)
  final String storageInstructions;

  @JsonKey(name: r'country_of_origin', required: true, includeIfNull: false)
  final String countryOfOrigin;

  /// Name and address of the manufacturer or packer.
  @JsonKey(name: r'manufacturer', required: true, includeIfNull: false)
  final String manufacturer;

  /// Name and address of the marketer, when different.
  @JsonKey(name: r'marketer', required: true, includeIfNull: false)
  final String marketer;

  /// Name and address of the importer, for imported products.
  @JsonKey(name: r'importer', required: true, includeIfNull: false)
  final String importer;

  /// Consumer care details (phone, email, address).
  @JsonKey(name: r'consumer_care', required: true, includeIfNull: false)
  final String consumerCare;

  /// FSSAI licence number printed on the label (14 digits).
  @JsonKey(name: r'fssai_license_no', required: true, includeIfNull: false)
  final String fssaiLicenseNo;

  /// Up to 10 products from the same category at this store, in stock first.
  @JsonKey(name: r'similar_products', required: true, includeIfNull: false)
  final List<ProductCard> similarProducts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDetail &&
          other.id == id &&
          other.slug == slug &&
          other.name == name &&
          other.brand == brand &&
          other.isVeg == isVeg &&
          other.category == category &&
          other.shortDescription == shortDescription &&
          other.description == description &&
          other.highlights == highlights &&
          other.defaultVariantId == defaultVariantId &&
          other.variants == variants &&
          other.ingredients == ingredients &&
          other.nutrition == nutrition &&
          other.shelfLife == shelfLife &&
          other.storageInstructions == storageInstructions &&
          other.countryOfOrigin == countryOfOrigin &&
          other.manufacturer == manufacturer &&
          other.marketer == marketer &&
          other.importer == importer &&
          other.consumerCare == consumerCare &&
          other.fssaiLicenseNo == fssaiLicenseNo &&
          other.similarProducts == similarProducts;

  @override
  int get hashCode =>
      id.hashCode +
      slug.hashCode +
      name.hashCode +
      brand.hashCode +
      isVeg.hashCode +
      category.hashCode +
      shortDescription.hashCode +
      description.hashCode +
      highlights.hashCode +
      defaultVariantId.hashCode +
      variants.hashCode +
      ingredients.hashCode +
      (nutrition == null ? 0 : nutrition.hashCode) +
      shelfLife.hashCode +
      storageInstructions.hashCode +
      countryOfOrigin.hashCode +
      manufacturer.hashCode +
      marketer.hashCode +
      importer.hashCode +
      consumerCare.hashCode +
      fssaiLicenseNo.hashCode +
      similarProducts.hashCode;

  factory ProductDetail.fromJson(Map<String, dynamic> json) =>
      _$ProductDetailFromJson(json);

  Map<String, dynamic> toJson() => _$ProductDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
