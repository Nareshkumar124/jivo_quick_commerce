// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_table.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NutritionTableCWProxy {
  NutritionTable columns(List<String> columns);

  NutritionTable rows(List<NutritionRow> rows);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NutritionTable(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NutritionTable(...).copyWith(id: 12, name: "My name")
  /// ````
  NutritionTable call({List<String> columns, List<NutritionRow> rows});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNutritionTable.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNutritionTable.copyWith.fieldName(...)`
class _$NutritionTableCWProxyImpl implements _$NutritionTableCWProxy {
  const _$NutritionTableCWProxyImpl(this._value);

  final NutritionTable _value;

  @override
  NutritionTable columns(List<String> columns) => this(columns: columns);

  @override
  NutritionTable rows(List<NutritionRow> rows) => this(rows: rows);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NutritionTable(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NutritionTable(...).copyWith(id: 12, name: "My name")
  /// ````
  NutritionTable call({
    Object? columns = const $CopyWithPlaceholder(),
    Object? rows = const $CopyWithPlaceholder(),
  }) {
    return NutritionTable(
      columns: columns == const $CopyWithPlaceholder()
          ? _value.columns
          // ignore: cast_nullable_to_non_nullable
          : columns as List<String>,
      rows: rows == const $CopyWithPlaceholder()
          ? _value.rows
          // ignore: cast_nullable_to_non_nullable
          : rows as List<NutritionRow>,
    );
  }
}

extension $NutritionTableCopyWith on NutritionTable {
  /// Returns a callable class that can be used as follows: `instanceOfNutritionTable.copyWith(...)` or like so:`instanceOfNutritionTable.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NutritionTableCWProxy get copyWith => _$NutritionTableCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NutritionTable _$NutritionTableFromJson(Map<String, dynamic> json) =>
    $checkedCreate('NutritionTable', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['columns', 'rows']);
      final val = NutritionTable(
        columns: $checkedConvert(
          'columns',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
        rows: $checkedConvert(
          'rows',
          (v) => (v as List<dynamic>)
              .map((e) => NutritionRow.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$NutritionTableToJson(NutritionTable instance) =>
    <String, dynamic>{
      'columns': instance.columns,
      'rows': instance.rows.map((e) => e.toJson()).toList(),
    };
