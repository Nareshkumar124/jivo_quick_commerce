// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_pong_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsPongMessageCWProxy {
  WsPongMessage type(String type);

  WsPongMessage sentAt(DateTime sentAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsPongMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsPongMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsPongMessage call({String type, DateTime sentAt});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsPongMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsPongMessage.copyWith.fieldName(...)`
class _$WsPongMessageCWProxyImpl implements _$WsPongMessageCWProxy {
  const _$WsPongMessageCWProxyImpl(this._value);

  final WsPongMessage _value;

  @override
  WsPongMessage type(String type) => this(type: type);

  @override
  WsPongMessage sentAt(DateTime sentAt) => this(sentAt: sentAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsPongMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsPongMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  WsPongMessage call({
    Object? type = const $CopyWithPlaceholder(),
    Object? sentAt = const $CopyWithPlaceholder(),
  }) {
    return WsPongMessage(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as String,
      sentAt: sentAt == const $CopyWithPlaceholder()
          ? _value.sentAt
          // ignore: cast_nullable_to_non_nullable
          : sentAt as DateTime,
    );
  }
}

extension $WsPongMessageCopyWith on WsPongMessage {
  /// Returns a callable class that can be used as follows: `instanceOfWsPongMessage.copyWith(...)` or like so:`instanceOfWsPongMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsPongMessageCWProxy get copyWith => _$WsPongMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsPongMessage _$WsPongMessageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsPongMessage', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'sent_at']);
      final val = WsPongMessage(
        type: $checkedConvert('type', (v) => v as String),
        sentAt: $checkedConvert('sent_at', (v) => DateTime.parse(v as String)),
      );
      return val;
    }, fieldKeyMap: const {'sentAt': 'sent_at'});

Map<String, dynamic> _$WsPongMessageToJson(WsPongMessage instance) =>
    <String, dynamic>{
      'type': instance.type,
      'sent_at': instance.sentAt.toIso8601String(),
    };
