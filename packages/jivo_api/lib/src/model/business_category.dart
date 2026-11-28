// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'business_category.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BusinessCategory {
  /// Returns a new [BusinessCategory] instance.
  BusinessCategory({required this.id, required this.name, required this.slug});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Shown in the dropdown.
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// Stable key, e.g. `restaurant-cafe`.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessCategory &&
          other.id == id &&
          other.name == name &&
          other.slug == slug;

  @override
  int get hashCode => id.hashCode + name.hashCode + slug.hashCode;

  factory BusinessCategory.fromJson(Map<String, dynamic> json) =>
      _$BusinessCategoryFromJson(json);

  Map<String, dynamic> toJson() => _$BusinessCategoryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
