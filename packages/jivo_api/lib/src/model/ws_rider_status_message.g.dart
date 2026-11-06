// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_rider_status_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsRiderStatusMessageCWProxy {
  WsRiderStatusMessage type(String type);

  WsRiderStatusMessage data(WsRiderStatusData data);

  WsRiderStatusMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderStatusMessage call({
    String type,
    WsRiderStatusData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsRiderStatusMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsRiderStatusMessage.copyWith.fieldName(...)`
class _$WsRiderStatusMessageCWProxyImpl
    implements _$WsRiderStatusMessageCWProxy {
  const _$WsRiderStatusMessageCWProxyImpl(this._value);

  final WsRiderStatusMessage _value;

  @override
  WsRiderStatusMessage type(String type) => this(type: type);

  @override
  WsRiderStatusMessage data(WsRiderStatusData data) => this(data: data);

  @override
  WsRiderStatusMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderStatusMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsRiderStatusMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsRiderStatusData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsRiderStatusMessageCopyWith on WsRiderStatusMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsRiderStatusMessage.copyWith(...)` or like so:`instanceOfWsRiderStatusMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsRiderStatusMessageCWProxy get copyWith =>
      _$WsRiderStatusMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsRiderStatusMessage _$WsRiderStatusMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsRiderStatusMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsRiderStatusMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsRiderStatusData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsRiderStatusMessageToJson(
  WsRiderStatusMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
