// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_tree.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CategoryTreeCWProxy {
  CategoryTree results(List<CategoryNode> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryTree(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryTree(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryTree call({List<CategoryNode> results});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCategoryTree.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCategoryTree.copyWith.fieldName(...)`
class _$CategoryTreeCWProxyImpl implements _$CategoryTreeCWProxy {
  const _$CategoryTreeCWProxyImpl(this._value);

  final CategoryTree _value;

  @override
  CategoryTree results(List<CategoryNode> results) => this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CategoryTree(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CategoryTree(...).copyWith(id: 12, name: "My name")
  /// ````
  CategoryTree call({Object? results = const $CopyWithPlaceholder()}) {
    return CategoryTree(
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<CategoryNode>,
    );
  }
}

extension $CategoryTreeCopyWith on CategoryTree {
  /// Returns a callable class that can be used as follows: `instanceOfCategoryTree.copyWith(...)` or like so:`instanceOfCategoryTree.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CategoryTreeCWProxy get copyWith => _$CategoryTreeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CategoryTree _$CategoryTreeFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CategoryTree', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['results']);
      final val = CategoryTree(
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => CategoryNode.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CategoryTreeToJson(CategoryTree instance) =>
    <String, dynamic>{
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
