// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_reply_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketReplyRequestCWProxy {
  TicketReplyRequest message(String message);

  TicketReplyRequest attachmentKeys(List<String>? attachmentKeys);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketReplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketReplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketReplyRequest call({String message, List<String>? attachmentKeys});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketReplyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketReplyRequest.copyWith.fieldName(...)`
class _$TicketReplyRequestCWProxyImpl implements _$TicketReplyRequestCWProxy {
  const _$TicketReplyRequestCWProxyImpl(this._value);

  final TicketReplyRequest _value;

  @override
  TicketReplyRequest message(String message) => this(message: message);

  @override
  TicketReplyRequest attachmentKeys(List<String>? attachmentKeys) =>
      this(attachmentKeys: attachmentKeys);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketReplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketReplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketReplyRequest call({
    Object? message = const $CopyWithPlaceholder(),
    Object? attachmentKeys = const $CopyWithPlaceholder(),
  }) {
    return TicketReplyRequest(
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      attachmentKeys: attachmentKeys == const $CopyWithPlaceholder()
          ? _value.attachmentKeys
          // ignore: cast_nullable_to_non_nullable
          : attachmentKeys as List<String>?,
    );
  }
}

extension $TicketReplyRequestCopyWith on TicketReplyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfTicketReplyRequest.copyWith(...)` or like so:`instanceOfTicketReplyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketReplyRequestCWProxy get copyWith =>
      _$TicketReplyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketReplyRequest _$TicketReplyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TicketReplyRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['message']);
      final val = TicketReplyRequest(
        message: $checkedConvert('message', (v) => v as String),
        attachmentKeys: $checkedConvert(
          'attachment_keys',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'attachmentKeys': 'attachment_keys'});

Map<String, dynamic> _$TicketReplyRequestToJson(TicketReplyRequest instance) =>
    <String, dynamic>{
      'message': instance.message,
      'attachment_keys': ?instance.attachmentKeys,
    };
