// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_auth_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsAuthRequestCWProxy {
  WsAuthRequest type(String type);

  WsAuthRequest token(String token);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthRequest call({String type, String token});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsAuthRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsAuthRequest.copyWith.fieldName(...)`
class _$WsAuthRequestCWProxyImpl implements _$WsAuthRequestCWProxy {
  const _$WsAuthRequestCWProxyImpl(this._value);

  final WsAuthRequest _value;

  @override
  WsAuthRequest type(String type) => this(type: type);

  @override
  WsAuthRequest token(String token) => this(token: token);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthRequest call({
    Object? type = const $CopyWithPlaceholder(),
    Object? token = const $CopyWithPlaceholder(),
  }) {
    return WsAuthRequest(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      token: token == const $CopyWithPlaceholder()
          ? _value.token
          // ignore: cast_nullable_to_non_nullable
          : token as String,
    );
  }
}

extension $WsAuthRequestCopyWith on WsAuthRequest {
  /// Returns a callable class that can be used as follows: `instanceOfWsAuthRequest.copyWith(...)` or like so:`instanceOfWsAuthRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsAuthRequestCWProxy get copyWith => _$WsAuthRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsAuthRequest _$WsAuthRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsAuthRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'token']);
      final val = WsAuthRequest(
        type: $checkedConvert('type', (v) => v as String),
        token: $checkedConvert('token', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$WsAuthRequestToJson(WsAuthRequest instance) =>
    <String, dynamic>{'type': instance.type, 'token': instance.token};
