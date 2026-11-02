// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/otp_settings.dart';
import 'package:jivo_api/src/model/rider_location_settings.dart';
import 'package:jivo_api/src/model/policy_urls.dart';
import 'package:jivo_api/src/model/support_contacts.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AppConfig {
  /// Returns a new [AppConfig] instance.
  AppConfig({
    required this.minSupportedVersion,

    required this.latestVersion,

    required this.storeUrl,

    required this.maintenance,

    required this.maintenanceMessage,

    required this.support,

    required this.policyUrls,

    required this.termsVersion,

    required this.otp,

    required this.riderLocation,

    required this.featureFlags,
  });

  /// For the app and platform in X-App-Name / X-Platform; null when those headers are missing. Below it: blocking update screen.
  @JsonKey(name: r'min_supported_version', required: true, includeIfNull: true)
  final String? minSupportedVersion;

  /// Below it: dismissible update prompt. Null without headers.
  @JsonKey(name: r'latest_version', required: true, includeIfNull: true)
  final String? latestVersion;

  /// Store page for the update button. Null without headers.
  @JsonKey(name: r'store_url', required: true, includeIfNull: true)
  final String? storeUrl;

  /// True: show the maintenance screen.
  @JsonKey(name: r'maintenance', required: true, includeIfNull: false)
  final bool maintenance;

  /// Text for the maintenance screen.
  @JsonKey(name: r'maintenance_message', required: true, includeIfNull: false)
  final String maintenanceMessage;

  @JsonKey(name: r'support', required: true, includeIfNull: false)
  final SupportContacts support;

  @JsonKey(name: r'policy_urls', required: true, includeIfNull: false)
  final PolicyUrls policyUrls;

  /// Current Terms & Privacy version; send it as `terms_version` on OTP verify.
  @JsonKey(name: r'terms_version', required: true, includeIfNull: false)
  final String termsVersion;

  @JsonKey(name: r'otp', required: true, includeIfNull: false)
  final OtpSettings otp;

  @JsonKey(name: r'rider_location', required: true, includeIfNull: false)
  final RiderLocationSettings riderLocation;

  /// Named on/off switches. Keys are added per phase; ignore unknown keys.
  @JsonKey(name: r'feature_flags', required: true, includeIfNull: false)
  final Map<String, bool> featureFlags;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfig &&
          other.minSupportedVersion == minSupportedVersion &&
          other.latestVersion == latestVersion &&
          other.storeUrl == storeUrl &&
          other.maintenance == maintenance &&
          other.maintenanceMessage == maintenanceMessage &&
          other.support == support &&
          other.policyUrls == policyUrls &&
          other.termsVersion == termsVersion &&
          other.otp == otp &&
          other.riderLocation == riderLocation &&
          other.featureFlags == featureFlags;

  @override
  int get hashCode =>
      (minSupportedVersion == null ? 0 : minSupportedVersion.hashCode) +
      (latestVersion == null ? 0 : latestVersion.hashCode) +
      (storeUrl == null ? 0 : storeUrl.hashCode) +
      maintenance.hashCode +
      maintenanceMessage.hashCode +
      support.hashCode +
      policyUrls.hashCode +
      termsVersion.hashCode +
      otp.hashCode +
      riderLocation.hashCode +
      featureFlags.hashCode;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AppConfigToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
