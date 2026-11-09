// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_ops_task_status_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOpsTaskStatusMessageCWProxy {
  WsOpsTaskStatusMessage type(String type);

  WsOpsTaskStatusMessage data(WsOpsTaskStatusData data);

  WsOpsTaskStatusMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsTaskStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsTaskStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsTaskStatusMessage call({
    String type,
    WsOpsTaskStatusData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOpsTaskStatusMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOpsTaskStatusMessage.copyWith.fieldName(...)`
class _$WsOpsTaskStatusMessageCWProxyImpl
    implements _$WsOpsTaskStatusMessageCWProxy {
  const _$WsOpsTaskStatusMessageCWProxyImpl(this._value);

  final WsOpsTaskStatusMessage _value;

  @override
  WsOpsTaskStatusMessage type(String type) => this(type: type);

  @override
  WsOpsTaskStatusMessage data(WsOpsTaskStatusData data) => this(data: data);

  @override
  WsOpsTaskStatusMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsTaskStatusMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsTaskStatusMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsTaskStatusMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsOpsTaskStatusMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsOpsTaskStatusData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsOpsTaskStatusMessageCopyWith on WsOpsTaskStatusMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsOpsTaskStatusMessage.copyWith(...)` or like so:`instanceOfWsOpsTaskStatusMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOpsTaskStatusMessageCWProxy get copyWith =>
      _$WsOpsTaskStatusMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOpsTaskStatusMessage _$WsOpsTaskStatusMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsOpsTaskStatusMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsOpsTaskStatusMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsOpsTaskStatusData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsOpsTaskStatusMessageToJson(
  WsOpsTaskStatusMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
