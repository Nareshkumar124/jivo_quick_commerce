// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_rider_location_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsRiderLocationMessageCWProxy {
  WsRiderLocationMessage type(String type);

  WsRiderLocationMessage data(WsRiderLocationData data);

  WsRiderLocationMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderLocationMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderLocationMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderLocationMessage call({
    String type,
    WsRiderLocationData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsRiderLocationMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsRiderLocationMessage.copyWith.fieldName(...)`
class _$WsRiderLocationMessageCWProxyImpl
    implements _$WsRiderLocationMessageCWProxy {
  const _$WsRiderLocationMessageCWProxyImpl(this._value);

  final WsRiderLocationMessage _value;

  @override
  WsRiderLocationMessage type(String type) => this(type: type);

  @override
  WsRiderLocationMessage data(WsRiderLocationData data) => this(data: data);

  @override
  WsRiderLocationMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderLocationMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderLocationMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderLocationMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsRiderLocationMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsRiderLocationData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsRiderLocationMessageCopyWith on WsRiderLocationMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsRiderLocationMessage.copyWith(...)` or like so:`instanceOfWsRiderLocationMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsRiderLocationMessageCWProxy get copyWith =>
      _$WsRiderLocationMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsRiderLocationMessage _$WsRiderLocationMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsRiderLocationMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsRiderLocationMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsRiderLocationData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsRiderLocationMessageToJson(
  WsRiderLocationMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
