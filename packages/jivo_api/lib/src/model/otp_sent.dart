// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'otp_sent.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OtpSent {
  /// Returns a new [OtpSent] instance.
  OtpSent({
    required this.otpLength,

    required this.expiresInSeconds,

    required this.resendAfterSeconds,
  });

  /// Digits in the OTP (6).
  @JsonKey(name: r'otp_length', required: true, includeIfNull: false)
  final int otpLength;

  /// The OTP is valid this long (300).
  @JsonKey(name: r'expires_in_seconds', required: true, includeIfNull: false)
  final int expiresInSeconds;

  /// Enable the Resend button after this many seconds (30).
  @JsonKey(name: r'resend_after_seconds', required: true, includeIfNull: false)
  final int resendAfterSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpSent &&
          other.otpLength == otpLength &&
          other.expiresInSeconds == expiresInSeconds &&
          other.resendAfterSeconds == resendAfterSeconds;

  @override
  int get hashCode =>
      otpLength.hashCode +
      expiresInSeconds.hashCode +
      resendAfterSeconds.hashCode;

  factory OtpSent.fromJson(Map<String, dynamic> json) =>
      _$OtpSentFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
