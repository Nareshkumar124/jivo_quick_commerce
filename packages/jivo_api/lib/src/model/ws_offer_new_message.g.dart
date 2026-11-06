// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_offer_new_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOfferNewMessageCWProxy {
  WsOfferNewMessage type(String type);

  WsOfferNewMessage data(WsOfferData data);

  WsOfferNewMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferNewMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferNewMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferNewMessage call({String type, WsOfferData data, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOfferNewMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOfferNewMessage.copyWith.fieldName(...)`
class _$WsOfferNewMessageCWProxyImpl implements _$WsOfferNewMessageCWProxy {
  const _$WsOfferNewMessageCWProxyImpl(this._value);

  final WsOfferNewMessage _value;

  @override
  WsOfferNewMessage type(String type) => this(type: type);

  @override
  WsOfferNewMessage data(WsOfferData data) => this(data: data);

  @override
  WsOfferNewMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferNewMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferNewMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferNewMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOfferNewMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOfferData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOfferNewMessageCopyWith on WsOfferNewMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOfferNewMessage.copyWith(...)` or like so:`instanceOfWsOfferNewMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOfferNewMessageCWProxy get copyWith =>
      _$WsOfferNewMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOfferNewMessage _$WsOfferNewMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsOfferNewMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsOfferNewMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsOfferData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOfferNewMessageToJson(WsOfferNewMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'sent_at': instance.sentAt.toIso8601String(),
    };
