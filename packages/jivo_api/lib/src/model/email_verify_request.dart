// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'email_verify_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EmailVerifyRequest {
  /// Returns a new [EmailVerifyRequest] instance.
  EmailVerifyRequest({required this.email, required this.otp});

  @JsonKey(name: r'email', required: true, includeIfNull: false)
  final String email;

  /// 6 digits.
  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final String otp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailVerifyRequest && other.email == email && other.otp == otp;

  @override
  int get hashCode => email.hashCode + otp.hashCode;

  factory EmailVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EmailVerifyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
