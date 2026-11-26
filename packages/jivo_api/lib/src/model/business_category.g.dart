// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_category.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BusinessCategoryCWProxy {
  BusinessCategory id(int id);

  BusinessCategory name(String name);

  BusinessCategory slug(String slug);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BusinessCategory(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BusinessCategory(...).copyWith(id: 12, name: "My name")
  /// ````
  BusinessCategory call({int id, String name, String slug});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBusinessCategory.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBusinessCategory.copyWith.fieldName(...)`
class _$BusinessCategoryCWProxyImpl implements _$BusinessCategoryCWProxy {
  const _$BusinessCategoryCWProxyImpl(this._value);

  final BusinessCategory _value;

  @override
  BusinessCategory id(int id) => this(id: id);

  @override
  BusinessCategory name(String name) => this(name: name);

  @override
  BusinessCategory slug(String slug) => this(slug: slug);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BusinessCategory(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BusinessCategory(...).copyWith(id: 12, name: "My name")
  /// ````
  BusinessCategory call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
  }) {
    return BusinessCategory(
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
    );
  }
}

extension $BusinessCategoryCopyWith on BusinessCategory {
  /// Returns a callable class that can be used as follows: `instanceOfBusinessCategory.copyWith(...)` or like so:`instanceOfBusinessCategory.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BusinessCategoryCWProxy get copyWith => _$BusinessCategoryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BusinessCategory _$BusinessCategoryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BusinessCategory', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'slug']);
      final val = BusinessCategory(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$BusinessCategoryToJson(BusinessCategory instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
    };
