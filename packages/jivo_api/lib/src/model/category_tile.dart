// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_tile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CategoryTile {
  /// Returns a new [CategoryTile] instance.
  CategoryTile({
    required this.id,

    required this.name,

    required this.slug,

    required this.image,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// e.g. \"Edible Oils\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// Use as `category` on `GET /products/`.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  /// Square image. Null when none.
  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryTile &&
          other.id == id &&
          other.name == name &&
          other.slug == slug &&
          other.image == image;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      slug.hashCode +
      (image == null ? 0 : image.hashCode);

  factory CategoryTile.fromJson(Map<String, dynamic> json) =>
      _$CategoryTileFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryTileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
