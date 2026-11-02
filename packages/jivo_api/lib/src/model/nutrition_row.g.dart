// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_row.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NutritionRowCWProxy {
  NutritionRow name(String name);

  NutritionRow values(List<String> values);

  NutritionRow isSubRow(bool isSubRow);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NutritionRow(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NutritionRow(...).copyWith(id: 12, name: "My name")
  /// ````
  NutritionRow call({String name, List<String> values, bool isSubRow});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNutritionRow.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNutritionRow.copyWith.fieldName(...)`
class _$NutritionRowCWProxyImpl implements _$NutritionRowCWProxy {
  const _$NutritionRowCWProxyImpl(this._value);

  final NutritionRow _value;

  @override
  NutritionRow name(String name) => this(name: name);

  @override
  NutritionRow values(List<String> values) => this(values: values);

  @override
  NutritionRow isSubRow(bool isSubRow) => this(isSubRow: isSubRow);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NutritionRow(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NutritionRow(...).copyWith(id: 12, name: "My name")
  /// ````
  NutritionRow call({
    Object? name = const $CopyWithPlaceholder(),
    Object? values = const $CopyWithPlaceholder(),
    Object? isSubRow = const $CopyWithPlaceholder(),
  }) {
    return NutritionRow(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      values: values == const $CopyWithPlaceholder()
          ? _value.values
          // ignore: cast_nullable_to_non_nullable
          : values as List<String>,
      isSubRow: isSubRow == const $CopyWithPlaceholder()
          ? _value.isSubRow
          // ignore: cast_nullable_to_non_nullable
          : isSubRow as bool,
    );
  }
}

extension $NutritionRowCopyWith on NutritionRow {
  /// Returns a callable class that can be used as follows: `instanceOfNutritionRow.copyWith(...)` or like so:`instanceOfNutritionRow.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NutritionRowCWProxy get copyWith => _$NutritionRowCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NutritionRow _$NutritionRowFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NutritionRow', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'values', 'is_sub_row']);
      final val = NutritionRow(
        name: $checkedConvert('name', (v) => v as String),
        values: $checkedConvert(
          'values',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        isSubRow: $checkedConvert('is_sub_row', (v) => v as bool),
      );
      return val;
    }, fieldKeyMap: const {'isSubRow': 'is_sub_row'});

Map<String, dynamic> _$NutritionRowToJson(NutritionRow instance) =>
    <String, dynamic>{
      'name': instance.name,
      'values': instance.values,
      'is_sub_row': instance.isSubRow,
    };
