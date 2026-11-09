// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_attachment.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketAttachmentCWProxy {
  TicketAttachment key(String key);

  TicketAttachment url(String url);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketAttachment(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketAttachment(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketAttachment call({String key, String url});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketAttachment.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketAttachment.copyWith.fieldName(...)`
class _$TicketAttachmentCWProxyImpl implements _$TicketAttachmentCWProxy {
  const _$TicketAttachmentCWProxyImpl(this._value);

  final TicketAttachment _value;

  @override
  TicketAttachment key(String key) => this(key: key);

  @override
  TicketAttachment url(String url) => this(url: url);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketAttachment(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketAttachment(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketAttachment call({
    Object? key = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
  }) {
    return TicketAttachment(
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      url: url == const $CopyWithPlaceholder()
          ? _value.url
          // ignore: cast_nullable_to_non_nullable
          : url as String,
    );
  }
}

extension $TicketAttachmentCopyWith on TicketAttachment {
  /// Returns a callable class that can be used as follows: `instanceOfTicketAttachment.copyWith(...)` or like so:`instanceOfTicketAttachment.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketAttachmentCWProxy get copyWith => _$TicketAttachmentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketAttachment _$TicketAttachmentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TicketAttachment', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key', 'url']);
      final val = TicketAttachment(
        key: $checkedConvert('key', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$TicketAttachmentToJson(TicketAttachment instance) =>
    <String, dynamic>{'key': instance.key, 'url': instance.url};
