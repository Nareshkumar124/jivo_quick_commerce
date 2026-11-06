// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_auth_ok_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsAuthOkDataCWProxy {
  WsAuthOkData userId(int userId);

  WsAuthOkData expiresAt(DateTime? expiresAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthOkData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthOkData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthOkData call({int userId, DateTime? expiresAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsAuthOkData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsAuthOkData.copyWith.fieldName(...)`
class _$WsAuthOkDataCWProxyImpl implements _$WsAuthOkDataCWProxy {
  const _$WsAuthOkDataCWProxyImpl(this._value);

  final WsAuthOkData _value;

  @override
  WsAuthOkData userId(int userId) => this(userId: userId);

  @override
  WsAuthOkData expiresAt(DateTime? expiresAt) => this(expiresAt: expiresAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthOkData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthOkData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthOkData call({
    Object? userId = const $CopyWithPlaceholder(),
    Object? expiresAt = const $CopyWithPlaceholder(),
  }) {
    return WsAuthOkData(
      userId: userId == const $CopyWithPlaceholder()
          ? _value.userId
          // ignore: cast_nullable_to_non_nullable
          : userId as int,
      expiresAt: expiresAt == const $CopyWithPlaceholder()
          ? _value.expiresAt
          // ignore: cast_nullable_to_non_nullable
          : expiresAt as DateTime?,
    );
  }
}

extension $WsAuthOkDataCopyWith on WsAuthOkData {
  /// Returns a callable class that can be used as follows: `instanceOfWsAuthOkData.copyWith(...)` or like so:`instanceOfWsAuthOkData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsAuthOkDataCWProxy get copyWith => _$WsAuthOkDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsAuthOkData _$WsAuthOkDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsAuthOkData', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['user_id', 'expires_at']);
      final val = WsAuthOkData(
        userId: $checkedConvert('user_id', (v) => (v as num).toInt()),
        expiresAt: $checkedConvert(
          'expires_at',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'userId': 'user_id', 'expiresAt': 'expires_at'});

Map<String, dynamic> _$WsAuthOkDataToJson(WsAuthOkData instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'expires_at': instance.expiresAt?.toIso8601String(),
    };
