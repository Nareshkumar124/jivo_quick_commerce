// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_auth_ok_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsAuthOkMessageCWProxy {
  WsAuthOkMessage type(String type);

  WsAuthOkMessage data(WsAuthOkData data);

  WsAuthOkMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthOkMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthOkMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthOkMessage call({String type, WsAuthOkData data, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsAuthOkMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsAuthOkMessage.copyWith.fieldName(...)`
class _$WsAuthOkMessageCWProxyImpl implements _$WsAuthOkMessageCWProxy {
  const _$WsAuthOkMessageCWProxyImpl(this._value);

  final WsAuthOkMessage _value;

  @override
  WsAuthOkMessage type(String type) => this(type: type);

  @override
  WsAuthOkMessage data(WsAuthOkData data) => this(data: data);

  @override
  WsAuthOkMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAuthOkMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAuthOkMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAuthOkMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsAuthOkMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsAuthOkData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsAuthOkMessageCopyWith on WsAuthOkMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsAuthOkMessage.copyWith(...)` or like so:`instanceOfWsAuthOkMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsAuthOkMessageCWProxy get copyWith => _$WsAuthOkMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsAuthOkMessage _$WsAuthOkMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsAuthOkMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsAuthOkMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsAuthOkData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsAuthOkMessageToJson(WsAuthOkMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'sent_at': instance.sentAt.toIso8601String(),
    };
