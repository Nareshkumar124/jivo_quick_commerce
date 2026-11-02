// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/category_node.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'category_tree.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CategoryTree {
  /// Returns a new [CategoryTree] instance.
  CategoryTree({required this.results});

  /// Top-level categories with products at this store, in admin order. Two levels in v1 (top-level and sub-categories). Not paginated.
  @JsonKey(name: r'results', required: true, includeIfNull: false)
  final List<CategoryNode> results;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryTree && other.results == results;

  @override
  int get hashCode => results.hashCode;

  factory CategoryTree.fromJson(Map<String, dynamic> json) =>
      _$CategoryTreeFromJson(json);

  Map<String, dynamic> toJson() => _$CategoryTreeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
