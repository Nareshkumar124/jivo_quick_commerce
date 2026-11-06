// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_eta_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderEtaMessageCWProxy {
  WsOrderEtaMessage type(String type);

  WsOrderEtaMessage data(WsOrderEtaData data);

  WsOrderEtaMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderEtaMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderEtaMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderEtaMessage call({String type, WsOrderEtaData data, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderEtaMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderEtaMessage.copyWith.fieldName(...)`
class _$WsOrderEtaMessageCWProxyImpl implements _$WsOrderEtaMessageCWProxy {
  const _$WsOrderEtaMessageCWProxyImpl(this._value);

  final WsOrderEtaMessage _value;

  @override
  WsOrderEtaMessage type(String type) => this(type: type);

  @override
  WsOrderEtaMessage data(WsOrderEtaData data) => this(data: data);

  @override
  WsOrderEtaMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderEtaMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderEtaMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderEtaMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderEtaMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOrderEtaData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOrderEtaMessageCopyWith on WsOrderEtaMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderEtaMessage.copyWith(...)` or like so:`instanceOfWsOrderEtaMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderEtaMessageCWProxy get copyWith =>
      _$WsOrderEtaMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderEtaMessage _$WsOrderEtaMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsOrderEtaMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsOrderEtaMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsOrderEtaData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOrderEtaMessageToJson(WsOrderEtaMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'sent_at': instance.sentAt.toIso8601String(),
    };
