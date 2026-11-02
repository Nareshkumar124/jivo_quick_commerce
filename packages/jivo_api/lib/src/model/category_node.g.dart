// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_node.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CategoryNodeCWProxy {
  CategoryNode id(int id);

  CategoryNode name(String name);

  CategoryNode slug(String slug);

  CategoryNode image(ImageSet? image);

  CategoryNode children(List<CategoryTile> children);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryNode(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryNode(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryNode call({
    int id,
    String name,
    String slug,
    ImageSet? image,
    List<CategoryTile> children,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCategoryNode.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCategoryNode.copyWith.fieldName(...)`
class _$CategoryNodeCWProxyImpl implements _$CategoryNodeCWProxy {
  const _$CategoryNodeCWProxyImpl(this._value);

  final CategoryNode _value;

  @override
  CategoryNode id(int id) => this(id: id);

  @override
  CategoryNode name(String name) => this(name: name);

  @override
  CategoryNode slug(String slug) => this(slug: slug);

  @override
  CategoryNode image(ImageSet? image) => this(image: image);

  @override
  CategoryNode children(List<CategoryTile> children) =>
      this(children: children);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryNode(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryNode(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryNode call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
    Object? children = const $CopyWithPlaceholder(),
  }) {
    return CategoryNode(
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
      image: image == const $CopyWithPlaceholder()
          ? _value.image
          // ignore: cast_nullable_to_non_nullable
          : image as ImageSet?,
      children: children == const $CopyWithPlaceholder()
          ? _value.children
          // ignore: cast_nullable_to_non_nullable
          : children as List<CategoryTile>,
    );
  }
}

extension $CategoryNodeCopyWith on CategoryNode {
  /// Returns a callable class that can be used as follows: `instanceOfCategoryNode.copyWith(...)` or like so:`instanceOfCategoryNode.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CategoryNodeCWProxy get copyWith => _$CategoryNodeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryNode _$CategoryNodeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CategoryNode', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'name', 'slug', 'image', 'children'],
      );
      final val = CategoryNode(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
        image: $checkedConvert(
          'image',
          (v) =>
              v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
        ),
        children: $checkedConvert(
          'children',
          (v) => (v as List<dynamic>)
              .map((e) => CategoryTile.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CategoryNodeToJson(CategoryNode instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'image': instance.image?.toJson(),
      'children': instance.children.map((e) => e.toJson()).toList(),
    };
