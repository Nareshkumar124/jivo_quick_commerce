// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_offer_expired_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOfferExpiredMessageCWProxy {
  WsOfferExpiredMessage type(String type);

  WsOfferExpiredMessage data(WsOfferWithdrawnData data);

  WsOfferExpiredMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferExpiredMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferExpiredMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferExpiredMessage call({
    String type,
    WsOfferWithdrawnData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOfferExpiredMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOfferExpiredMessage.copyWith.fieldName(...)`
class _$WsOfferExpiredMessageCWProxyImpl
    implements _$WsOfferExpiredMessageCWProxy {
  const _$WsOfferExpiredMessageCWProxyImpl(this._value);

  final WsOfferExpiredMessage _value;

  @override
  WsOfferExpiredMessage type(String type) => this(type: type);

  @override
  WsOfferExpiredMessage data(WsOfferWithdrawnData data) => this(data: data);

  @override
  WsOfferExpiredMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferExpiredMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferExpiredMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferExpiredMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOfferExpiredMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOfferWithdrawnData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOfferExpiredMessageCopyWith on WsOfferExpiredMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOfferExpiredMessage.copyWith(...)` or like so:`instanceOfWsOfferExpiredMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOfferExpiredMessageCWProxy get copyWith =>
      _$WsOfferExpiredMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOfferExpiredMessage _$WsOfferExpiredMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOfferExpiredMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOfferExpiredMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOfferWithdrawnData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOfferExpiredMessageToJson(
  WsOfferExpiredMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
