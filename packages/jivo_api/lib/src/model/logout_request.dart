// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'logout_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LogoutRequest {
  /// Returns a new [LogoutRequest] instance.
  LogoutRequest({required this.refresh, this.fcmToken});

  /// The refresh token to revoke.
  @JsonKey(name: r'refresh', required: true, includeIfNull: false)
  final String refresh;

  /// This device's FCM token, to stop its pushes.
  @JsonKey(name: r'fcm_token', required: false, includeIfNull: false)
  final String? fcmToken;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogoutRequest &&
          other.refresh == refresh &&
          other.fcmToken == fcmToken;

  @override
  int get hashCode => refresh.hashCode + fcmToken.hashCode;

  factory LogoutRequest.fromJson(Map<String, dynamic> json) =>
      _$LogoutRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LogoutRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
