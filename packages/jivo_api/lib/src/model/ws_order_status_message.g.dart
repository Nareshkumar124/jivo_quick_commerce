// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_status_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderStatusMessageCWProxy {
  WsOrderStatusMessage type(String type);

  WsOrderStatusMessage data(WsOrderStatusData data);

  WsOrderStatusMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderStatusMessage call({
    String type,
    WsOrderStatusData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderStatusMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderStatusMessage.copyWith.fieldName(...)`
class _$WsOrderStatusMessageCWProxyImpl
    implements _$WsOrderStatusMessageCWProxy {
  const _$WsOrderStatusMessageCWProxyImpl(this._value);

  final WsOrderStatusMessage _value;

  @override
  WsOrderStatusMessage type(String type) => this(type: type);

  @override
  WsOrderStatusMessage data(WsOrderStatusData data) => this(data: data);

  @override
  WsOrderStatusMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderStatusMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderStatusMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOrderStatusData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOrderStatusMessageCopyWith on WsOrderStatusMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderStatusMessage.copyWith(...)` or like so:`instanceOfWsOrderStatusMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderStatusMessageCWProxy get copyWith =>
      _$WsOrderStatusMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderStatusMessage _$WsOrderStatusMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOrderStatusMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOrderStatusMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOrderStatusData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOrderStatusMessageToJson(
  WsOrderStatusMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
