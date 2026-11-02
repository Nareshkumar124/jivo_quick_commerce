// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'otp_verify_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OtpVerifyRequest {
  /// Returns a new [OtpVerifyRequest] instance.
  OtpVerifyRequest({
    required this.phone,

    required this.otp,

    required this.app,

    required this.termsVersion,
  });

  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  /// 6 digits.
  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final String otp;

  /// Must match the `app` the OTP was requested for. Authoritative over X-App-Name.  * `customer` - Customer app * `rider` - Rider app
  @JsonKey(
    name: r'app',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AppEnum.unknownDefaultOpenApi,
  )
  final AppEnum app;

  /// The Terms & Privacy version the user accepted on the login screen: send `terms_version` from `/config/app/` (DPDP consent record).
  @JsonKey(name: r'terms_version', required: true, includeIfNull: false)
  final String termsVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpVerifyRequest &&
          other.phone == phone &&
          other.otp == otp &&
          other.app == app &&
          other.termsVersion == termsVersion;

  @override
  int get hashCode =>
      phone.hashCode + otp.hashCode + app.hashCode + termsVersion.hashCode;

  factory OtpVerifyRequest.fromJson(Map<String, dynamic> json) =>
      _$OtpVerifyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$OtpVerifyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
