// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_reply_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketReplyRequestCWProxy {
  TicketReplyRequest message(String message);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketReplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketReplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketReplyRequest call({String message});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketReplyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketReplyRequest.copyWith.fieldName(...)`
class _$TicketReplyRequestCWProxyImpl implements _$TicketReplyRequestCWProxy {
  const _$TicketReplyRequestCWProxyImpl(this._value);

  final TicketReplyRequest _value;

  @override
  TicketReplyRequest message(String message) => this(message: message);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketReplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketReplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketReplyRequest call({Object? message = const $CopyWithPlaceholder()}) {
    return TicketReplyRequest(
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
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
      );
      return val;
    });

Map<String, dynamic> _$TicketReplyRequestToJson(TicketReplyRequest instance) =>
    <String, dynamic>{'message': instance.message};
