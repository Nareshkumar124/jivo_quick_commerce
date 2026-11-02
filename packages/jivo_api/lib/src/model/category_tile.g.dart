// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_tile.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CategoryTileCWProxy {
  CategoryTile id(int id);

  CategoryTile name(String name);

  CategoryTile slug(String slug);

  CategoryTile image(ImageSet? image);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryTile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryTile(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryTile call({int id, String name, String slug, ImageSet? image});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCategoryTile.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCategoryTile.copyWith.fieldName(...)`
class _$CategoryTileCWProxyImpl implements _$CategoryTileCWProxy {
  const _$CategoryTileCWProxyImpl(this._value);

  final CategoryTile _value;

  @override
  CategoryTile id(int id) => this(id: id);

  @override
  CategoryTile name(String name) => this(name: name);

  @override
  CategoryTile slug(String slug) => this(slug: slug);

  @override
  CategoryTile image(ImageSet? image) => this(image: image);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryTile(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryTile(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryTile call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? image = const $CopyWithPlaceholder(),
  }) {
    return CategoryTile(
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
    );
  }
}

extension $CategoryTileCopyWith on CategoryTile {
  /// Returns a callable class that can be used as follows: `instanceOfCategoryTile.copyWith(...)` or like so:`instanceOfCategoryTile.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CategoryTileCWProxy get copyWith => _$CategoryTileCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryTile _$CategoryTileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CategoryTile', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'slug', 'image']);
      final val = CategoryTile(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
        image: $checkedConvert(
          'image',
          (v) =>
              v == null ? null : ImageSet.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CategoryTileToJson(CategoryTile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'image': instance.image?.toJson(),
    };
