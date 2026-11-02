// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'account_delete_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AccountDeleteRequest {
  /// Returns a new [AccountDeleteRequest] instance.
  AccountDeleteRequest({required this.otp, this.reason});

  /// OTP from `POST /auth/otp/request/` with `purpose: delete_account` for the caller's own phone. A login OTP is rejected.
  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final String otp;

  /// Optional feedback.
  @JsonKey(name: r'reason', required: false, includeIfNull: false)
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountDeleteRequest &&
          other.otp == otp &&
          other.reason == reason;

  @override
  int get hashCode => otp.hashCode + reason.hashCode;

  factory AccountDeleteRequest.fromJson(Map<String, dynamic> json) =>
      _$AccountDeleteRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AccountDeleteRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
