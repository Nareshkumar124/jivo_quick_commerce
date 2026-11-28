// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:jivo_api/src/model/otp_purpose_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'email_otp_send_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EmailOtpSendRequest {
  /// Returns a new [EmailOtpSendRequest] instance.
  EmailOtpSendRequest({
    required this.email,

    required this.app,

    this.purpose = OtpPurposeEnum.login,
  });

  /// The email to send the code to. Case does not matter.
  @JsonKey(name: r'email', required: true, includeIfNull: false)
  final String email;

  /// The app asking. Same value as `X-App-Name`.  * `customer` - Customer app * `rider` - Rider app
  @JsonKey(
    name: r'app',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AppEnum.unknownDefaultOpenApi,
  )
  final AppEnum app;

  /// `login` (default): for `/auth/email-otp/verify/`. `delete_account`: for `/me/delete/` by an account without a phone; it can never log anyone in.  * `login` - Log in or sign up * `delete_account` - Confirm account deletion
  @JsonKey(
    defaultValue: OtpPurposeEnum.login,
    name: r'purpose',
    required: false,
    includeIfNull: false,
    unknownEnumValue: OtpPurposeEnum.unknownDefaultOpenApi,
  )
  final OtpPurposeEnum? purpose;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailOtpSendRequest &&
          other.email == email &&
          other.app == app &&
          other.purpose == purpose;

  @override
  int get hashCode => email.hashCode + app.hashCode + purpose.hashCode;

  factory EmailOtpSendRequest.fromJson(Map<String, dynamic> json) =>
      _$EmailOtpSendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EmailOtpSendRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
