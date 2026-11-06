// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_task_updated_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsTaskUpdatedMessageCWProxy {
  WsTaskUpdatedMessage type(String type);

  WsTaskUpdatedMessage data(WsTaskUpdatedData data);

  WsTaskUpdatedMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsTaskUpdatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsTaskUpdatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsTaskUpdatedMessage call({
    String type,
    WsTaskUpdatedData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsTaskUpdatedMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsTaskUpdatedMessage.copyWith.fieldName(...)`
class _$WsTaskUpdatedMessageCWProxyImpl
    implements _$WsTaskUpdatedMessageCWProxy {
  const _$WsTaskUpdatedMessageCWProxyImpl(this._value);

  final WsTaskUpdatedMessage _value;

  @override
  WsTaskUpdatedMessage type(String type) => this(type: type);

  @override
  WsTaskUpdatedMessage data(WsTaskUpdatedData data) => this(data: data);

  @override
  WsTaskUpdatedMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsTaskUpdatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsTaskUpdatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsTaskUpdatedMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsTaskUpdatedMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsTaskUpdatedData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsTaskUpdatedMessageCopyWith on WsTaskUpdatedMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsTaskUpdatedMessage.copyWith(...)` or like so:`instanceOfWsTaskUpdatedMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsTaskUpdatedMessageCWProxy get copyWith =>
      _$WsTaskUpdatedMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsTaskUpdatedMessage _$WsTaskUpdatedMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsTaskUpdatedMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsTaskUpdatedMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsTaskUpdatedData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsTaskUpdatedMessageToJson(
  WsTaskUpdatedMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
