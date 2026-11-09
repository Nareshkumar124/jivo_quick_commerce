// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_alert_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsAlertMessageCWProxy {
  WsAlertMessage type(String type);

  WsAlertMessage data(WsAlertData data);

  WsAlertMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAlertMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAlertMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAlertMessage call({String type, WsAlertData data, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsAlertMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsAlertMessage.copyWith.fieldName(...)`
class _$WsAlertMessageCWProxyImpl implements _$WsAlertMessageCWProxy {
  const _$WsAlertMessageCWProxyImpl(this._value);

  final WsAlertMessage _value;

  @override
  WsAlertMessage type(String type) => this(type: type);

  @override
  WsAlertMessage data(WsAlertData data) => this(data: data);

  @override
  WsAlertMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsAlertMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsAlertMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsAlertMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsAlertMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsAlertData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsAlertMessageCopyWith on WsAlertMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsAlertMessage.copyWith(...)` or like so:`instanceOfWsAlertMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsAlertMessageCWProxy get copyWith => _$WsAlertMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsAlertMessage _$WsAlertMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsAlertMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsAlertMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsAlertData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsAlertMessageToJson(WsAlertMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'sent_at': instance.sentAt.toIso8601String(),
    };
