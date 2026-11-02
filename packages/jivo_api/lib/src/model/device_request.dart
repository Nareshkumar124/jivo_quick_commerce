// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:jivo_api/src/model/platform_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeviceRequest {
  /// Returns a new [DeviceRequest] instance.
  DeviceRequest({
    required this.fcmToken,

    required this.app,

    required this.platform,

    required this.appVersion,
  });

  /// Firebase Cloud Messaging token.
  @JsonKey(name: r'fcm_token', required: true, includeIfNull: false)
  final String fcmToken;

  @JsonKey(
    name: r'app',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AppEnum.unknownDefaultOpenApi,
  )
  final AppEnum app;

  @JsonKey(
    name: r'platform',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PlatformEnum.unknownDefaultOpenApi,
  )
  final PlatformEnum platform;

  /// Installed app version, e.g. \"1.4.2\" or \"1.4.2+37\".
  @JsonKey(name: r'app_version', required: true, includeIfNull: false)
  final String appVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceRequest &&
          other.fcmToken == fcmToken &&
          other.app == app &&
          other.platform == platform &&
          other.appVersion == appVersion;

  @override
  int get hashCode =>
      fcmToken.hashCode +
      app.hashCode +
      platform.hashCode +
      appVersion.hashCode;

  factory DeviceRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
