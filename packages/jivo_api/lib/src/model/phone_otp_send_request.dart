// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'phone_otp_send_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PhoneOtpSendRequest {
  /// Returns a new [PhoneOtpSendRequest] instance.
  PhoneOtpSendRequest({required this.phone});

  /// E.164 Indian mobile, e.g. +919876543210.
  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneOtpSendRequest && other.phone == phone;

  @override
  int get hashCode => phone.hashCode;

  factory PhoneOtpSendRequest.fromJson(Map<String, dynamic> json) =>
      _$PhoneOtpSendRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PhoneOtpSendRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
