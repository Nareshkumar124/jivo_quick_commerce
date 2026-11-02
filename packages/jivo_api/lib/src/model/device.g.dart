// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeviceCWProxy {
  Device id(int id);

  Device fcmToken(String fcmToken);

  Device app(AppEnum app);

  Device platform(PlatformEnum platform);

  Device appVersion(String appVersion);

  Device isActive(bool isActive);

  Device lastSeenAt(DateTime lastSeenAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Device(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Device(...).copyWith(id: 12, name: "My name")
  /// ````
  Device call({
    int id,
    String fcmToken,
    AppEnum app,
    PlatformEnum platform,
    String appVersion,
    bool isActive,
    DateTime lastSeenAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDevice.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDevice.copyWith.fieldName(...)`
class _$DeviceCWProxyImpl implements _$DeviceCWProxy {
  const _$DeviceCWProxyImpl(this._value);

  final Device _value;

  @override
  Device id(int id) => this(id: id);

  @override
  Device fcmToken(String fcmToken) => this(fcmToken: fcmToken);

  @override
  Device app(AppEnum app) => this(app: app);

  @override
  Device platform(PlatformEnum platform) => this(platform: platform);

  @override
  Device appVersion(String appVersion) => this(appVersion: appVersion);

  @override
  Device isActive(bool isActive) => this(isActive: isActive);

  @override
  Device lastSeenAt(DateTime lastSeenAt) => this(lastSeenAt: lastSeenAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Device(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Device(...).copyWith(id: 12, name: "My name")
  /// ````
  Device call({
    Object? id = const $CopyWithPlaceholder(),
    Object? fcmToken = const $CopyWithPlaceholder(),
    Object? app = const $CopyWithPlaceholder(),
    Object? platform = const $CopyWithPlaceholder(),
    Object? appVersion = const $CopyWithPlaceholder(),
    Object? isActive = const $CopyWithPlaceholder(),
    Object? lastSeenAt = const $CopyWithPlaceholder(),
  }) {
    return Device(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
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
      isActive: isActive == const $CopyWithPlaceholder()
          ? _value.isActive
          // ignore: cast_nullable_to_non_nullable
          : isActive as bool,
      lastSeenAt: lastSeenAt == const $CopyWithPlaceholder()
          ? _value.lastSeenAt
          // ignore: cast_nullable_to_non_nullable
          : lastSeenAt as DateTime,
    );
  }
}

extension $DeviceCopyWith on Device {
  /// Returns a callable class that can be used as follows: `instanceOfDevice.copyWith(...)` or like so:`instanceOfDevice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeviceCWProxy get copyWith => _$DeviceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Device',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'fcm_token',
        'app',
        'platform',
        'app_version',
        'is_active',
        'last_seen_at',
      ],
    );
    final val = Device(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
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
      isActive: $checkedConvert('is_active', (v) => v as bool),
      lastSeenAt: $checkedConvert(
        'last_seen_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'fcmToken': 'fcm_token',
    'appVersion': 'app_version',
    'isActive': 'is_active',
    'lastSeenAt': 'last_seen_at',
  },
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'id': instance.id,
  'fcm_token': instance.fcmToken,
  'app': _$AppEnumEnumMap[instance.app]!,
  'platform': _$PlatformEnumEnumMap[instance.platform]!,
  'app_version': instance.appVersion,
  'is_active': instance.isActive,
  'last_seen_at': instance.lastSeenAt.toIso8601String(),
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
