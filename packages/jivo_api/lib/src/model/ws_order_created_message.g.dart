// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_created_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderCreatedMessageCWProxy {
  WsOrderCreatedMessage type(String type);

  WsOrderCreatedMessage data(WsOrderCreatedData data);

  WsOrderCreatedMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderCreatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderCreatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderCreatedMessage call({
    String type,
    WsOrderCreatedData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderCreatedMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderCreatedMessage.copyWith.fieldName(...)`
class _$WsOrderCreatedMessageCWProxyImpl
    implements _$WsOrderCreatedMessageCWProxy {
  const _$WsOrderCreatedMessageCWProxyImpl(this._value);

  final WsOrderCreatedMessage _value;

  @override
  WsOrderCreatedMessage type(String type) => this(type: type);

  @override
  WsOrderCreatedMessage data(WsOrderCreatedData data) => this(data: data);

  @override
  WsOrderCreatedMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderCreatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderCreatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderCreatedMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderCreatedMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOrderCreatedData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOrderCreatedMessageCopyWith on WsOrderCreatedMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderCreatedMessage.copyWith(...)` or like so:`instanceOfWsOrderCreatedMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderCreatedMessageCWProxy get copyWith =>
      _$WsOrderCreatedMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderCreatedMessage _$WsOrderCreatedMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOrderCreatedMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOrderCreatedMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOrderCreatedData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOrderCreatedMessageToJson(
  WsOrderCreatedMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
