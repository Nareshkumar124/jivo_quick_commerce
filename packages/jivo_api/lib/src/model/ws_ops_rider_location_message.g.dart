// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_ops_rider_location_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOpsRiderLocationMessageCWProxy {
  WsOpsRiderLocationMessage type(String type);

  WsOpsRiderLocationMessage data(WsOpsRiderLocationData data);

  WsOpsRiderLocationMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsRiderLocationMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsRiderLocationMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsRiderLocationMessage call({
    String type,
    WsOpsRiderLocationData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOpsRiderLocationMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOpsRiderLocationMessage.copyWith.fieldName(...)`
class _$WsOpsRiderLocationMessageCWProxyImpl
    implements _$WsOpsRiderLocationMessageCWProxy {
  const _$WsOpsRiderLocationMessageCWProxyImpl(this._value);

  final WsOpsRiderLocationMessage _value;

  @override
  WsOpsRiderLocationMessage type(String type) => this(type: type);

  @override
  WsOpsRiderLocationMessage data(WsOpsRiderLocationData data) =>
      this(data: data);

  @override
  WsOpsRiderLocationMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsRiderLocationMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsRiderLocationMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsRiderLocationMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOpsRiderLocationMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOpsRiderLocationData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOpsRiderLocationMessageCopyWith on WsOpsRiderLocationMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOpsRiderLocationMessage.copyWith(...)` or like so:`instanceOfWsOpsRiderLocationMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOpsRiderLocationMessageCWProxy get copyWith =>
      _$WsOpsRiderLocationMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOpsRiderLocationMessage _$WsOpsRiderLocationMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOpsRiderLocationMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOpsRiderLocationMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOpsRiderLocationData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOpsRiderLocationMessageToJson(
  WsOpsRiderLocationMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
