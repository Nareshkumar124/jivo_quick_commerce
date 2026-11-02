// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/nutrition_row.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'nutrition_table.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NutritionTable {
  /// Returns a new [NutritionTable] instance.
  NutritionTable({required this.columns, required this.rows});

  /// Column headings, e.g. [\"Per 100 ml\", \"Per serving (15 ml)\"].
  @JsonKey(name: r'columns', required: true, includeIfNull: false)
  final List<String> columns;

  @JsonKey(name: r'rows', required: true, includeIfNull: false)
  final List<NutritionRow> rows;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionTable && other.columns == columns && other.rows == rows;

  @override
  int get hashCode => columns.hashCode + rows.hashCode;

  factory NutritionTable.fromJson(Map<String, dynamic> json) =>
      _$NutritionTableFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionTableToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
