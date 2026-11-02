// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/image_set.dart';
import 'package:jivo_api/src/model/category_tile.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_node.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CategoryNode {
  /// Returns a new [CategoryNode] instance.
  CategoryNode({
    required this.id,

    required this.name,

    required this.slug,

    required this.image,

    required this.children,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  /// Sub-categories with products at this store (the left rail of the product list). Empty when the category has none: list it directly.
  @JsonKey(name: r'children', required: true, includeIfNull: false)
  final List<CategoryTile> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryNode &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          other.image == image &&
          other.children == children;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      slug.hashCode +
      (image == null ? 0 : image.hashCode) +
      children.hashCode;

  factory CategoryNode.fromJson(Map<String, dynamic> json) =>
      _$CategoryNodeFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryNodeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
