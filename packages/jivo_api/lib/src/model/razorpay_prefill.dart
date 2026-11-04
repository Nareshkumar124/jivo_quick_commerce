// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'razorpay_prefill.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RazorpayPrefill {
  /// Returns a new [RazorpayPrefill] instance.
  RazorpayPrefill({
    required this.name,

    required this.contact,

    required this.email,
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// The customer's phone, E.164.
  @JsonKey(name: r'contact', required: true, includeIfNull: false)
  final String contact;

  /// \"\" when the customer has none.
  @JsonKey(name: r'email', required: true, includeIfNull: false)
  final String email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RazorpayPrefill &&
          other.name == name &&
          other.contact == contact &&
          other.email == email;

  @override
  int get hashCode => name.hashCode + contact.hashCode + email.hashCode;

  factory RazorpayPrefill.fromJson(Map<String, dynamic> json) =>
      _$RazorpayPrefillFromJson(json);

  Map<String, dynamic> toJson() => _$RazorpayPrefillToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
