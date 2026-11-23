// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_route_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderRouteMessageCWProxy {
  WsOrderRouteMessage type(String type);

  WsOrderRouteMessage data(WsOrderRouteData data);

  WsOrderRouteMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderRouteMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderRouteMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderRouteMessage call({
    String type,
    WsOrderRouteData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderRouteMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderRouteMessage.copyWith.fieldName(...)`
class _$WsOrderRouteMessageCWProxyImpl implements _$WsOrderRouteMessageCWProxy {
  const _$WsOrderRouteMessageCWProxyImpl(this._value);

  final WsOrderRouteMessage _value;

  @override
  WsOrderRouteMessage type(String type) => this(type: type);

  @override
  WsOrderRouteMessage data(WsOrderRouteData data) => this(data: data);

  @override
  WsOrderRouteMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderRouteMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderRouteMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderRouteMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderRouteMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOrderRouteData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOrderRouteMessageCopyWith on WsOrderRouteMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderRouteMessage.copyWith(...)` or like so:`instanceOfWsOrderRouteMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderRouteMessageCWProxy get copyWith =>
      _$WsOrderRouteMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderRouteMessage _$WsOrderRouteMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsOrderRouteMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsOrderRouteMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsOrderRouteData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOrderRouteMessageToJson(
  WsOrderRouteMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
