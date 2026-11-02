// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/app_enum.dart';
import 'package:jivo_api/src/model/platform_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'device.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Device {
  /// Returns a new [Device] instance.
  Device({
    required this.id,

    required this.fcmToken,

    required this.app,

    required this.platform,

    required this.appVersion,

    required this.isActive,

    required this.lastSeenAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

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

  @JsonKey(name: r'is_active', required: true, includeIfNull: false)
  final bool isActive;

  @JsonKey(name: r'last_seen_at', required: true, includeIfNull: false)
  final DateTime lastSeenAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Device &&
          other.id == id &&
          other.fcmToken == fcmToken &&
          other.app == app &&
          other.platform == platform &&
          other.appVersion == appVersion &&
          other.isActive == isActive &&
          other.lastSeenAt == lastSeenAt;

  @override
  int get hashCode =>
      id.hashCode +
      fcmToken.hashCode +
      app.hashCode +
      platform.hashCode +
      appVersion.hashCode +
      isActive.hashCode +
      lastSeenAt.hashCode;

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
