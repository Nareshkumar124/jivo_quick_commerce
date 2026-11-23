// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_delivery_progress_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsDeliveryProgressMessageCWProxy {
  WsDeliveryProgressMessage type(String type);

  WsDeliveryProgressMessage data(WsDeliveryProgressData data);

  WsDeliveryProgressMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsDeliveryProgressMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsDeliveryProgressMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsDeliveryProgressMessage call({
    String type,
    WsDeliveryProgressData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsDeliveryProgressMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsDeliveryProgressMessage.copyWith.fieldName(...)`
class _$WsDeliveryProgressMessageCWProxyImpl
    implements _$WsDeliveryProgressMessageCWProxy {
  const _$WsDeliveryProgressMessageCWProxyImpl(this._value);

  final WsDeliveryProgressMessage _value;

  @override
  WsDeliveryProgressMessage type(String type) => this(type: type);

  @override
  WsDeliveryProgressMessage data(WsDeliveryProgressData data) =>
      this(data: data);

  @override
  WsDeliveryProgressMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsDeliveryProgressMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsDeliveryProgressMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsDeliveryProgressMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsDeliveryProgressMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsDeliveryProgressData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsDeliveryProgressMessageCopyWith on WsDeliveryProgressMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsDeliveryProgressMessage.copyWith(...)` or like so:`instanceOfWsDeliveryProgressMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsDeliveryProgressMessageCWProxy get copyWith =>
      _$WsDeliveryProgressMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsDeliveryProgressMessage _$WsDeliveryProgressMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsDeliveryProgressMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsDeliveryProgressMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsDeliveryProgressData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsDeliveryProgressMessageToJson(
  WsDeliveryProgressMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
