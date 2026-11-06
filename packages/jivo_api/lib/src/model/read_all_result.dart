// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'read_all_result.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReadAllResult {
  /// Returns a new [ReadAllResult] instance.
  ReadAllResult({required this.updated});

  /// How many entries were unread and are now read.
  @JsonKey(name: r'updated', required: true, includeIfNull: false)
  final int updated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadAllResult && other.updated == updated;

  @override
  int get hashCode => updated.hashCode;

  factory ReadAllResult.fromJson(Map<String, dynamic> json) =>
      _$ReadAllResultFromJson(json);

  Map<String, dynamic> toJson() => _$ReadAllResultToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
