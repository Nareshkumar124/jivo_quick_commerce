// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'nutrition_row.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NutritionRow {
  /// Returns a new [NutritionRow] instance.
  NutritionRow({
    required this.name,

    required this.values,

    required this.isSubRow,
  });

  /// Nutrient, e.g. \"Energy (kcal)\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// One value per column, as printed, e.g. [\"900\", \"135\"]. \"\" = not stated.
  @JsonKey(name: r'values', required: true, includeIfNull: false)
  final List<String> values;

  /// Indent under the previous row (e.g. \"Saturated fat\" under \"Total fat\").
  @JsonKey(name: r'is_sub_row', required: true, includeIfNull: false)
  final bool isSubRow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionRow &&
          other.name == name &&
          other.values == values &&
          other.isSubRow == isSubRow;

  @override
  int get hashCode => name.hashCode + values.hashCode + isSubRow.hashCode;

  factory NutritionRow.fromJson(Map<String, dynamic> json) =>
      _$NutritionRowFromJson(json);

  Map<String, dynamic> toJson() => _$NutritionRowToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
