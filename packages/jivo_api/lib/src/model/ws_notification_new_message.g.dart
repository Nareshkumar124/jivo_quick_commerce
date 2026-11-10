// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_notification_new_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsNotificationNewMessageCWProxy {
  WsNotificationNewMessage type(String type);

  WsNotificationNewMessage data(WsNotificationNewData data);

  WsNotificationNewMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsNotificationNewMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsNotificationNewMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsNotificationNewMessage call({
    String type,
    WsNotificationNewData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsNotificationNewMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsNotificationNewMessage.copyWith.fieldName(...)`
class _$WsNotificationNewMessageCWProxyImpl
    implements _$WsNotificationNewMessageCWProxy {
  const _$WsNotificationNewMessageCWProxyImpl(this._value);

  final WsNotificationNewMessage _value;

  @override
  WsNotificationNewMessage type(String type) => this(type: type);

  @override
  WsNotificationNewMessage data(WsNotificationNewData data) => this(data: data);

  @override
  WsNotificationNewMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsNotificationNewMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsNotificationNewMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsNotificationNewMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsNotificationNewMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsNotificationNewData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsNotificationNewMessageCopyWith on WsNotificationNewMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsNotificationNewMessage.copyWith(...)` or like so:`instanceOfWsNotificationNewMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsNotificationNewMessageCWProxy get copyWith =>
      _$WsNotificationNewMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsNotificationNewMessage _$WsNotificationNewMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsNotificationNewMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsNotificationNewMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsNotificationNewData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsNotificationNewMessageToJson(
  WsNotificationNewMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
