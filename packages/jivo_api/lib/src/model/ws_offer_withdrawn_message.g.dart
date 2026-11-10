// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_offer_withdrawn_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOfferWithdrawnMessageCWProxy {
  WsOfferWithdrawnMessage type(String type);

  WsOfferWithdrawnMessage data(WsOfferWithdrawnData data);

  WsOfferWithdrawnMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferWithdrawnMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferWithdrawnMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferWithdrawnMessage call({
    String type,
    WsOfferWithdrawnData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOfferWithdrawnMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOfferWithdrawnMessage.copyWith.fieldName(...)`
class _$WsOfferWithdrawnMessageCWProxyImpl
    implements _$WsOfferWithdrawnMessageCWProxy {
  const _$WsOfferWithdrawnMessageCWProxyImpl(this._value);

  final WsOfferWithdrawnMessage _value;

  @override
  WsOfferWithdrawnMessage type(String type) => this(type: type);

  @override
  WsOfferWithdrawnMessage data(WsOfferWithdrawnData data) => this(data: data);

  @override
  WsOfferWithdrawnMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOfferWithdrawnMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOfferWithdrawnMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOfferWithdrawnMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOfferWithdrawnMessage(
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

extension $WsOfferWithdrawnMessageCopyWith on WsOfferWithdrawnMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOfferWithdrawnMessage.copyWith(...)` or like so:`instanceOfWsOfferWithdrawnMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOfferWithdrawnMessageCWProxy get copyWith =>
      _$WsOfferWithdrawnMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOfferWithdrawnMessage _$WsOfferWithdrawnMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOfferWithdrawnMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOfferWithdrawnMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOfferWithdrawnData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOfferWithdrawnMessageToJson(
  WsOfferWithdrawnMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
