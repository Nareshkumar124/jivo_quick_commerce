// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'email_otp_for_me_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EmailOtpForMeRequest {
  /// Returns a new [EmailOtpForMeRequest] instance.
  EmailOtpForMeRequest({required this.email});

  /// The email to verify. Case does not matter.
  @JsonKey(name: r'email', required: true, includeIfNull: false)
  final String email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailOtpForMeRequest && other.email == email;

  @override
  int get hashCode => email.hashCode;

  factory EmailOtpForMeRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailOtpForMeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EmailOtpForMeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
