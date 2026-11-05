// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/earning_line.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_earnings.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskEarnings {
  /// Returns a new [TaskEarnings] instance.
  TaskEarnings({required this.total, required this.lines});

  /// Sum of the lines.
  @JsonKey(name: r'total', required: true, includeIfNull: false)
  final String total;

  @JsonKey(name: r'lines', required: true, includeIfNull: false)
  final List<EarningLine> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskEarnings && other.total == total && other.lines == lines;

  @override
  int get hashCode => total.hashCode + lines.hashCode;

  factory TaskEarnings.fromJson(Map<String, dynamic> json) =>
      _$TaskEarningsFromJson(json);

  Map<String, dynamic> toJson() => _$TaskEarningsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
