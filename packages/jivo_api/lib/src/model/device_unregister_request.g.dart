// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_unregister_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeviceUnregisterRequestCWProxy {
  DeviceUnregisterRequest fcmToken(String fcmToken);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeviceUnregisterRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeviceUnregisterRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeviceUnregisterRequest call({String fcmToken});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeviceUnregisterRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeviceUnregisterRequest.copyWith.fieldName(...)`
class _$DeviceUnregisterRequestCWProxyImpl
    implements _$DeviceUnregisterRequestCWProxy {
  const _$DeviceUnregisterRequestCWProxyImpl(this._value);

  final DeviceUnregisterRequest _value;

  @override
  DeviceUnregisterRequest fcmToken(String fcmToken) => this(fcmToken: fcmToken);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeviceUnregisterRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeviceUnregisterRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeviceUnregisterRequest call({
    Object? fcmToken = const $CopyWithPlaceholder(),
  }) {
    return DeviceUnregisterRequest(
      fcmToken: fcmToken == const $CopyWithPlaceholder()
          ? _value.fcmToken
          // ignore: cast_nullable_to_non_nullable
          : fcmToken as String,
    );
  }
}

extension $DeviceUnregisterRequestCopyWith on DeviceUnregisterRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDeviceUnregisterRequest.copyWith(...)` or like so:`instanceOfDeviceUnregisterRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeviceUnregisterRequestCWProxy get copyWith =>
      _$DeviceUnregisterRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceUnregisterRequest _$DeviceUnregisterRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeviceUnregisterRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['fcm_token']);
  final val = DeviceUnregisterRequest(
    fcmToken: $checkedConvert('fcm_token', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'fcmToken': 'fcm_token'});

Map<String, dynamic> _$DeviceUnregisterRequestToJson(
  DeviceUnregisterRequest instance,
) => <String, dynamic>{'fcm_token': instance.fcmToken};
