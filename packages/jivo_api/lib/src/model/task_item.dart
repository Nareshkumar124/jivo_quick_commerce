// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_item.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskItem {
  /// Returns a new [TaskItem] instance.
  TaskItem({required this.name, required this.variant, required this.quantity});

  /// Product name.
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// e.g. \"1 L\".
  @JsonKey(name: r'variant', required: true, includeIfNull: false)
  final String variant;

  /// Units in the bag (after any unavailable).
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskItem &&
          other.name == name &&
          other.variant == variant &&
          other.quantity == quantity;

  @override
  int get hashCode => name.hashCode + variant.hashCode + quantity.hashCode;

  factory TaskItem.fromJson(Map<String, dynamic> json) =>
      _$TaskItemFromJson(json);

  Map<String, dynamic> toJson() => _$TaskItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
