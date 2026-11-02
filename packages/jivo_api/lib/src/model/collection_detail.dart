// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/product_card.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'collection_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CollectionDetail {
  /// Returns a new [CollectionDetail] instance.
  CollectionDetail({
    required this.id,

    required this.name,

    required this.slug,

    required this.products,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  /// All products of the collection that this store sells (at most 100), in the collection's order, out-of-stock last. For sorting or paging use `GET /products/?collection={slug}`.
  @JsonKey(name: r'products', required: true, includeIfNull: false)
  final List<ProductCard> products;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionDetail &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          other.products == products;

  @override
  int get hashCode =>
      id.hashCode + name.hashCode + slug.hashCode + products.hashCode;

  factory CollectionDetail.fromJson(Map<String, dynamic> json) =>
      _$CollectionDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CollectionDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
