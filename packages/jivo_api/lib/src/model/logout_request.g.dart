// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logout_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LogoutRequestCWProxy {
  LogoutRequest refresh(String refresh);

  LogoutRequest fcmToken(String? fcmToken);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LogoutRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LogoutRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LogoutRequest call({String refresh, String? fcmToken});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLogoutRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLogoutRequest.copyWith.fieldName(...)`
class _$LogoutRequestCWProxyImpl implements _$LogoutRequestCWProxy {
  const _$LogoutRequestCWProxyImpl(this._value);

  final LogoutRequest _value;

  @override
  LogoutRequest refresh(String refresh) => this(refresh: refresh);

  @override
  LogoutRequest fcmToken(String? fcmToken) => this(fcmToken: fcmToken);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LogoutRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LogoutRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LogoutRequest call({
    Object? refresh = const $CopyWithPlaceholder(),
    Object? fcmToken = const $CopyWithPlaceholder(),
  }) {
    return LogoutRequest(
      refresh: refresh == const $CopyWithPlaceholder()
          ? _value.refresh
          // ignore: cast_nullable_to_non_nullable
          : refresh as String,
      fcmToken: fcmToken == const $CopyWithPlaceholder()
          ? _value.fcmToken
          // ignore: cast_nullable_to_non_nullable
          : fcmToken as String?,
    );
  }
}

extension $LogoutRequestCopyWith on LogoutRequest {
  /// Returns a callable class that can be used as follows: `instanceOfLogoutRequest.copyWith(...)` or like so:`instanceOfLogoutRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LogoutRequestCWProxy get copyWith => _$LogoutRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LogoutRequest _$LogoutRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LogoutRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['refresh']);
      final val = LogoutRequest(
        refresh: $checkedConvert('refresh', (v) => v as String),
        fcmToken: $checkedConvert('fcm_token', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'fcmToken': 'fcm_token'});

Map<String, dynamic> _$LogoutRequestToJson(LogoutRequest instance) =>
    <String, dynamic>{
      'refresh': instance.refresh,
      'fcm_token': ?instance.fcmToken,
    };
