// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_cash_updated_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsCashUpdatedMessageCWProxy {
  WsCashUpdatedMessage type(String type);

  WsCashUpdatedMessage data(WsCashUpdatedData data);

  WsCashUpdatedMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsCashUpdatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsCashUpdatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsCashUpdatedMessage call({
    String type,
    WsCashUpdatedData data,
    DateTime sentAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsCashUpdatedMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsCashUpdatedMessage.copyWith.fieldName(...)`
class _$WsCashUpdatedMessageCWProxyImpl
    implements _$WsCashUpdatedMessageCWProxy {
  const _$WsCashUpdatedMessageCWProxyImpl(this._value);

  final WsCashUpdatedMessage _value;

  @override
  WsCashUpdatedMessage type(String type) => this(type: type);

  @override
  WsCashUpdatedMessage data(WsCashUpdatedData data) => this(data: data);

  @override
  WsCashUpdatedMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsCashUpdatedMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsCashUpdatedMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsCashUpdatedMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsCashUpdatedMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsCashUpdatedData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsCashUpdatedMessageCopyWith on WsCashUpdatedMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsCashUpdatedMessage.copyWith(...)` or like so:`instanceOfWsCashUpdatedMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsCashUpdatedMessageCWProxy get copyWith =>
      _$WsCashUpdatedMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsCashUpdatedMessage _$WsCashUpdatedMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WsCashUpdatedMessage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
  final val = WsCashUpdatedMessage(
    type: $checkedConvert('type', (v) => v as String),
    data: $checkedConvert(
      'data',
      (v) => WsCashUpdatedData.fromJson(v as Map<String, dynamic>),
    ),
    sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
  );
  return val;
}, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsCashUpdatedMessageToJson(
  WsCashUpdatedMessage instance,
) => <String, dynamic>{
  'type': instance.type,
  'data': instance.data.toJson(),
  'sent_at': instance.sentAt.toIso8601String(),
};
