// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'phone_verify_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PhoneVerifyRequest {
  /// Returns a new [PhoneVerifyRequest] instance.
  PhoneVerifyRequest({required this.phone, required this.otp});

  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  /// 6 digits.
  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final String otp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneVerifyRequest && other.phone == phone && other.otp == otp;

  @override
  int get hashCode => phone.hashCode + otp.hashCode;

  factory PhoneVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$PhoneVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PhoneVerifyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
