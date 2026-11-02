// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:jivo_api/src/model/otp_purpose_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'otp_send_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OtpSendRequest {
  /// Returns a new [OtpSendRequest] instance.
  OtpSendRequest({
    required this.phone,

    required this.app,

    this.purpose = OtpPurposeEnum.login,
  });

  /// E.164 Indian mobile, e.g. +919876543210.
  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  /// The app asking. Same value as `X-App-Name`.  * `customer` - Customer app * `rider` - Rider app
  @JsonKey(
    name: r'app',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AppEnum.unknownDefaultOpenApi,
  )
  final AppEnum app;

  /// `login` (default): for `/auth/otp/verify/`. `delete_account`: for `/me/delete/` only; it can never log anyone in.  * `login` - Log in or sign up * `delete_account` - Confirm account deletion
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
      other is OtpSendRequest &&
          other.phone == phone &&
          other.app == app &&
          other.purpose == purpose;

  @override
  int get hashCode => phone.hashCode + app.hashCode + purpose.hashCode;

  factory OtpSendRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpSendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSendRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
