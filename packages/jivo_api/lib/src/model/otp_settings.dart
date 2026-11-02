// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'otp_settings.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OtpSettings {
  /// Returns a new [OtpSettings] instance.
  OtpSettings({required this.length, required this.resendAfterSeconds});

  /// OTP digits (6).
  @JsonKey(name: r'length', required: true, includeIfNull: false)
  final int length;

  /// Resend countdown (30).
  @JsonKey(name: r'resend_after_seconds', required: true, includeIfNull: false)
  final int resendAfterSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpSettings &&
          other.length == length &&
          other.resendAfterSeconds == resendAfterSeconds;

  @override
  int get hashCode => length.hashCode + resendAfterSeconds.hashCode;

  factory OtpSettings.fromJson(Map<String, dynamic> json) =>
      _$OtpSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$OtpSettingsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
