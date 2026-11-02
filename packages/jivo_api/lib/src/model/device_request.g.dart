// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeviceRequestCWProxy {
  DeviceRequest fcmToken(String fcmToken);

  DeviceRequest app(AppEnum app);

  DeviceRequest platform(PlatformEnum platform);

  DeviceRequest appVersion(String appVersion);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeviceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeviceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeviceRequest call({
    String fcmToken,
    AppEnum app,
    PlatformEnum platform,
    String appVersion,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeviceRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeviceRequest.copyWith.fieldName(...)`
class _$DeviceRequestCWProxyImpl implements _$DeviceRequestCWProxy {
  const _$DeviceRequestCWProxyImpl(this._value);

  final DeviceRequest _value;

  @override
  DeviceRequest fcmToken(String fcmToken) => this(fcmToken: fcmToken);

  @override
  DeviceRequest app(AppEnum app) => this(app: app);

  @override
  DeviceRequest platform(PlatformEnum platform) => this(platform: platform);

  @override
  DeviceRequest appVersion(String appVersion) => this(appVersion: appVersion);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeviceRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeviceRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeviceRequest call({
    Object? fcmToken = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? platform = const $CopyWithPlaceholder(),
    Object? appVersion = const $CopyWithPlaceholder(),
  }) {
    return DeviceRequest(
      fcmToken: fcmToken == const $CopyWithPlaceholder()
          ? _value.fcmToken
          // ignore: cast_nullable_to_non_nullable
          : fcmToken as String,
      app: app == const $CopyWithPlaceholder()
          ? _value.app
          // ignore: cast_nullable_to_non_nullable
          : app as AppEnum,
      platform: platform == const $CopyWithPlaceholder()
          ? _value.platform
          // ignore: cast_nullable_to_non_nullable
          : platform as PlatformEnum,
      appVersion: appVersion == const $CopyWithPlaceholder()
          ? _value.appVersion
          // ignore: cast_nullable_to_non_nullable
          : appVersion as String,
    );
  }
}

extension $DeviceRequestCopyWith on DeviceRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDeviceRequest.copyWith(...)` or like so:`instanceOfDeviceRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeviceRequestCWProxy get copyWith => _$DeviceRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceRequest _$DeviceRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'DeviceRequest',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['fcm_token', 'app', 'platform', 'app_version'],
        );
        final val = DeviceRequest(
          fcmToken: $checkedConvert('fcm_token', (v) => v as String),
          app: $checkedConvert(
            'app',
            (v) => $enumDecode(
              _$AppEnumEnumMap,
              v,
              unknownValue: AppEnum.unknownDefaultOpenApi,
            ),
          ),
          platform: $checkedConvert(
            'platform',
            (v) => $enumDecode(
              _$PlatformEnumEnumMap,
              v,
              unknownValue: PlatformEnum.unknownDefaultOpenApi,
            ),
          ),
          appVersion: $checkedConvert('app_version', (v) => v as String),
        );
        return val;
      },
      fieldKeyMap: const {'fcmToken': 'fcm_token', 'appVersion': 'app_version'},
    );

Map<String, dynamic> _$DeviceRequestToJson(DeviceRequest instance) =>
    <String, dynamic>{
      'fcm_token': instance.fcmToken,
      'app': _$AppEnumEnumMap[instance.app]!,
      'platform': _$PlatformEnumEnumMap[instance.platform]!,
      'app_version': instance.appVersion,
    };

const _$AppEnumEnumMap = {
  AppEnum.customer: 'customer',
  AppEnum.rider: 'rider',
  AppEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$PlatformEnumEnumMap = {
  PlatformEnum.android: 'android',
  PlatformEnum.ios: 'ios',
  PlatformEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
