// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/product_card.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'collection_rail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CollectionRail {
  /// Returns a new [CollectionRail] instance.
  CollectionRail({
    required this.id,

    required this.name,

    required this.slug,

    required this.products,

    required this.hasMore,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// 'See all' opens `GET /collections/{slug}/`.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  /// Up to 10 products in the collection's order, out-of-stock last.
  @JsonKey(name: r'products', required: true, includeIfNull: false)
  final List<ProductCard> products;

  /// True when the collection has more products.
  @JsonKey(name: r'has_more', required: true, includeIfNull: false)
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionRail &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          other.products == products &&
          other.hasMore == hasMore;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      slug.hashCode +
      products.hashCode +
      hasMore.hashCode;

  factory CollectionRail.fromJson(Map<String, dynamic> json) =>
      _$CollectionRailFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionRailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
