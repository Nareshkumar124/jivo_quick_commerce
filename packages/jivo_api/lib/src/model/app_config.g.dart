// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppConfigCWProxy {
  AppConfig minSupportedVersion(String? minSupportedVersion);

  AppConfig latestVersion(String? latestVersion);

  AppConfig storeUrl(String? storeUrl);

  AppConfig maintenance(bool maintenance);

  AppConfig maintenanceMessage(String maintenanceMessage);

  AppConfig support(SupportContacts support);

  AppConfig policyUrls(PolicyUrls policyUrls);

  AppConfig termsVersion(String termsVersion);

  AppConfig otp(OtpSettings otp);

  AppConfig riderLocation(RiderLocationSettings riderLocation);

  AppConfig featureFlags(Map<String, bool> featureFlags);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AppConfig(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AppConfig(...).copyWith(id: 12, name: "My name")
  /// ````
  AppConfig call({
    String? minSupportedVersion,
    String? latestVersion,
    String? storeUrl,
    bool maintenance,
    String maintenanceMessage,
    SupportContacts support,
    PolicyUrls policyUrls,
    String termsVersion,
    OtpSettings otp,
    RiderLocationSettings riderLocation,
    Map<String, bool> featureFlags,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAppConfig.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAppConfig.copyWith.fieldName(...)`
class _$AppConfigCWProxyImpl implements _$AppConfigCWProxy {
  const _$AppConfigCWProxyImpl(this._value);

  final AppConfig _value;

  @override
  AppConfig minSupportedVersion(String? minSupportedVersion) =>
      this(minSupportedVersion: minSupportedVersion);

  @override
  AppConfig latestVersion(String? latestVersion) =>
      this(latestVersion: latestVersion);

  @override
  AppConfig storeUrl(String? storeUrl) => this(storeUrl: storeUrl);

  @override
  AppConfig maintenance(bool maintenance) => this(maintenance: maintenance);

  @override
  AppConfig maintenanceMessage(String maintenanceMessage) =>
      this(maintenanceMessage: maintenanceMessage);

  @override
  AppConfig support(SupportContacts support) => this(support: support);

  @override
  AppConfig policyUrls(PolicyUrls policyUrls) => this(policyUrls: policyUrls);

  @override
  AppConfig termsVersion(String termsVersion) =>
      this(termsVersion: termsVersion);

  @override
  AppConfig otp(OtpSettings otp) => this(otp: otp);

  @override
  AppConfig riderLocation(RiderLocationSettings riderLocation) =>
      this(riderLocation: riderLocation);

  @override
  AppConfig featureFlags(Map<String, bool> featureFlags) =>
      this(featureFlags: featureFlags);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AppConfig(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AppConfig(...).copyWith(id: 12, name: "My name")
  /// ````
  AppConfig call({
    Object? minSupportedVersion = const $CopyWithPlaceholder(),
    Object? latestVersion = const $CopyWithPlaceholder(),
    Object? storeUrl = const $CopyWithPlaceholder(),
    Object? maintenance = const $CopyWithPlaceholder(),
    Object? maintenanceMessage = const $CopyWithPlaceholder(),
    Object? support = const $CopyWithPlaceholder(),
    Object? policyUrls = const $CopyWithPlaceholder(),
    Object? termsVersion = const $CopyWithPlaceholder(),
    Object? otp = const $CopyWithPlaceholder(),
    Object? riderLocation = const $CopyWithPlaceholder(),
    Object? featureFlags = const $CopyWithPlaceholder(),
  }) {
    return AppConfig(
      minSupportedVersion: minSupportedVersion == const $CopyWithPlaceholder()
          ? _value.minSupportedVersion
          // ignore: cast_nullable_to_non_nullable
          : minSupportedVersion as String?,
      latestVersion: latestVersion == const $CopyWithPlaceholder()
          ? _value.latestVersion
          // ignore: cast_nullable_to_non_nullable
          : latestVersion as String?,
      storeUrl: storeUrl == const $CopyWithPlaceholder()
          ? _value.storeUrl
          // ignore: cast_nullable_to_non_nullable
          : storeUrl as String?,
      maintenance: maintenance == const $CopyWithPlaceholder()
          ? _value.maintenance
          // ignore: cast_nullable_to_non_nullable
          : maintenance as bool,
      maintenanceMessage: maintenanceMessage == const $CopyWithPlaceholder()
          ? _value.maintenanceMessage
          // ignore: cast_nullable_to_non_nullable
          : maintenanceMessage as String,
      support: support == const $CopyWithPlaceholder()
          ? _value.support
          // ignore: cast_nullable_to_non_nullable
          : support as SupportContacts,
      policyUrls: policyUrls == const $CopyWithPlaceholder()
          ? _value.policyUrls
          // ignore: cast_nullable_to_non_nullable
          : policyUrls as PolicyUrls,
      termsVersion: termsVersion == const $CopyWithPlaceholder()
          ? _value.termsVersion
          // ignore: cast_nullable_to_non_nullable
          : termsVersion as String,
      otp: otp == const $CopyWithPlaceholder()
          ? _value.otp
          // ignore: cast_nullable_to_non_nullable
          : otp as OtpSettings,
      riderLocation: riderLocation == const $CopyWithPlaceholder()
          ? _value.riderLocation
          // ignore: cast_nullable_to_non_nullable
          : riderLocation as RiderLocationSettings,
      featureFlags: featureFlags == const $CopyWithPlaceholder()
          ? _value.featureFlags
          // ignore: cast_nullable_to_non_nullable
          : featureFlags as Map<String, bool>,
    );
  }
}

extension $AppConfigCopyWith on AppConfig {
  /// Returns a callable class that can be used as follows: `instanceOfAppConfig.copyWith(...)` or like so:`instanceOfAppConfig.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AppConfigCWProxy get copyWith => _$AppConfigCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AppConfig',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'min_supported_version',
        'latest_version',
        'store_url',
        'maintenance',
        'maintenance_message',
        'support',
        'policy_urls',
        'terms_version',
        'otp',
        'rider_location',
        'feature_flags',
      ],
    );
    final val = AppConfig(
      minSupportedVersion: $checkedConvert(
        'min_supported_version',
        (v) => v as String?,
      ),
      latestVersion: $checkedConvert('latest_version', (v) => v as String?),
      storeUrl: $checkedConvert('store_url', (v) => v as String?),
      maintenance: $checkedConvert('maintenance', (v) => v as bool),
      maintenanceMessage: $checkedConvert(
        'maintenance_message',
        (v) => v as String,
      ),
      support: $checkedConvert(
        'support',
        (v) => SupportContacts.fromJson(v as Map<String, dynamic>),
      ),
      policyUrls: $checkedConvert(
        'policy_urls',
        (v) => PolicyUrls.fromJson(v as Map<String, dynamic>),
      ),
      termsVersion: $checkedConvert('terms_version', (v) => v as String),
      otp: $checkedConvert(
        'otp',
        (v) => OtpSettings.fromJson(v as Map<String, dynamic>),
      ),
      riderLocation: $checkedConvert(
        'rider_location',
        (v) => RiderLocationSettings.fromJson(v as Map<String, dynamic>),
      ),
      featureFlags: $checkedConvert(
        'feature_flags',
        (v) => Map<String, bool>.from(v as Map),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'minSupportedVersion': 'min_supported_version',
    'latestVersion': 'latest_version',
    'storeUrl': 'store_url',
    'maintenanceMessage': 'maintenance_message',
    'policyUrls': 'policy_urls',
    'termsVersion': 'terms_version',
    'riderLocation': 'rider_location',
    'featureFlags': 'feature_flags',
  },
);

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
  'min_supported_version': instance.minSupportedVersion,
  'latest_version': instance.latestVersion,
  'store_url': instance.storeUrl,
  'maintenance': instance.maintenance,
  'maintenance_message': instance.maintenanceMessage,
  'support': instance.support.toJson(),
  'policy_urls': instance.policyUrls.toJson(),
  'terms_version': instance.termsVersion,
  'otp': instance.otp.toJson(),
  'rider_location': instance.riderLocation.toJson(),
  'feature_flags': instance.featureFlags,
};
