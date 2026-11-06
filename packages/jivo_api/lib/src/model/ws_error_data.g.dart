// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_error_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsErrorDataCWProxy {
  WsErrorData code(String code);

  WsErrorData message(String message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsErrorData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsErrorData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsErrorData call({String code, String message});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsErrorData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsErrorData.copyWith.fieldName(...)`
class _$WsErrorDataCWProxyImpl implements _$WsErrorDataCWProxy {
  const _$WsErrorDataCWProxyImpl(this._value);

  final WsErrorData _value;

  @override
  WsErrorData code(String code) => this(code: code);

  @override
  WsErrorData message(String message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsErrorData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsErrorData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsErrorData call({
    Object? code = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
  }) {
    return WsErrorData(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
    );
  }
}

extension $WsErrorDataCopyWith on WsErrorData {
  /// Returns a callable class that can be used as follows: `instanceOfWsErrorData.copyWith(...)` or like so:`instanceOfWsErrorData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsErrorDataCWProxy get copyWith => _$WsErrorDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsErrorData _$WsErrorDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsErrorData', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code', 'message']);
      final val = WsErrorData(
        code: $checkedConvert('code', (v) => v as String),
        message: $checkedConvert('message', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$WsErrorDataToJson(WsErrorData instance) =>
    <String, dynamic>{'code': instance.code, 'message': instance.message};
