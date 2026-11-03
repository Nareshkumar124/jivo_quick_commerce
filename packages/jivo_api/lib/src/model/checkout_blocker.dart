// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/checkout_blocker_code_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'checkout_blocker.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CheckoutBlocker {
  /// Returns a new [CheckoutBlocker] instance.
  CheckoutBlocker({required this.code, required this.message});

  @JsonKey(
    name: r'code',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CheckoutBlockerCodeEnum.unknownDefaultOpenApi,
  )
  final CheckoutBlockerCodeEnum code;

  /// Display text with the fix, in English.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckoutBlocker &&
          other.code == code &&
          other.message == message;

  @override
  int get hashCode => code.hashCode + message.hashCode;

  factory CheckoutBlocker.fromJson(Map<String, dynamic> json) =>
      _$CheckoutBlockerFromJson(json);

  Map<String, dynamic> toJson() => _$CheckoutBlockerToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
