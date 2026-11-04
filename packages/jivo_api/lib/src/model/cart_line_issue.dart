// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cart_line_issue_code_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_line_issue.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartLineIssue {
  /// Returns a new [CartLineIssue] instance.
  CartLineIssue({required this.code, required this.message});

  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CartLineIssueCodeEnum.unknownDefaultOpenApi,
  )
  final CartLineIssueCodeEnum code;

  /// Display text, e.g. 'Only 2 left'.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartLineIssue && other.code == code && other.message == message;

  @override
  int get hashCode => code.hashCode + message.hashCode;

  factory CartLineIssue.fromJson(Map<String, dynamic> json) =>
      _$CartLineIssueFromJson(json);

  Map<String, dynamic> toJson() => _$CartLineIssueToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
