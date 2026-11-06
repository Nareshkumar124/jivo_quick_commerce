// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_error_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsErrorMessageCWProxy {
  WsErrorMessage type(String type);

  WsErrorMessage data(WsErrorData data);

  WsErrorMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsErrorMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsErrorMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsErrorMessage call({String type, WsErrorData data, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsErrorMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsErrorMessage.copyWith.fieldName(...)`
class _$WsErrorMessageCWProxyImpl implements _$WsErrorMessageCWProxy {
  const _$WsErrorMessageCWProxyImpl(this._value);

  final WsErrorMessage _value;

  @override
  WsErrorMessage type(String type) => this(type: type);

  @override
  WsErrorMessage data(WsErrorData data) => this(data: data);

  @override
  WsErrorMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsErrorMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsErrorMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsErrorMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? data = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsErrorMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      data: data == const $CopyWithPlaceholder()
          ? _value.data
          // ignore: cast_nullable_to_non_nullable
          : data as WsErrorData,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsErrorMessageCopyWith on WsErrorMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsErrorMessage.copyWith(...)` or like so:`instanceOfWsErrorMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsErrorMessageCWProxy get copyWith => _$WsErrorMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsErrorMessage _$WsErrorMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsErrorMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'data', 'sent_at']);
      final val = WsErrorMessage(
        type: $checkedConvert('type', (v) => v as String),
        data: $checkedConvert(
          'data',
          (v) => WsErrorData.fromJson(v as Map<String, dynamic>),
        ),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsErrorMessageToJson(WsErrorMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'data': instance.data.toJson(),
      'sent_at': instance.sentAt.toIso8601String(),
    };
