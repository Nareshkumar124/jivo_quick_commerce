// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ticket_message.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TicketMessageCWProxy {
  TicketMessage id(int id);

  TicketMessage body(String body);

  TicketMessage fromSupport(bool fromSupport);

  TicketMessage createdAt(DateTime createdAt);

  TicketMessage attachments(List<TicketAttachment> attachments);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketMessage call({
    int id,
    String body,
    bool fromSupport,
    DateTime createdAt,
    List<TicketAttachment> attachments,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTicketMessage.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTicketMessage.copyWith.fieldName(...)`
class _$TicketMessageCWProxyImpl implements _$TicketMessageCWProxy {
  const _$TicketMessageCWProxyImpl(this._value);

  final TicketMessage _value;

  @override
  TicketMessage id(int id) => this(id: id);

  @override
  TicketMessage body(String body) => this(body: body);

  @override
  TicketMessage fromSupport(bool fromSupport) => this(fromSupport: fromSupport);

  @override
  TicketMessage createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  TicketMessage attachments(List<TicketAttachment> attachments) =>
      this(attachments: attachments);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TicketMessage(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TicketMessage(...).copyWith(id: 12, name: "My name")
  /// ````
  TicketMessage call({
    Object? id = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? fromSupport = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? attachments = const $CopyWithPlaceholder(),
  }) {
    return TicketMessage(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      fromSupport: fromSupport == const $CopyWithPlaceholder()
          ? _value.fromSupport
          // ignore: cast_nullable_to_non_nullable
          : fromSupport as bool,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      attachments: attachments == const $CopyWithPlaceholder()
          ? _value.attachments
          // ignore: cast_nullable_to_non_nullable
          : attachments as List<TicketAttachment>,
    );
  }
}

extension $TicketMessageCopyWith on TicketMessage {
  /// Returns a callable class that can be used as follows: `instanceOfTicketMessage.copyWith(...)` or like so:`instanceOfTicketMessage.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TicketMessageCWProxy get copyWith => _$TicketMessageCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TicketMessage _$TicketMessageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'TicketMessage',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'body',
        'from_support',
        'created_at',
        'attachments',
      ],
    );
    final val = TicketMessage(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      body: $checkedConvert('body', (v) => v as String),
      fromSupport: $checkedConvert('from_support', (v) => v as bool),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      attachments: $checkedConvert(
        'attachments',
        (v) => (v as List<dynamic>)
            .map((e) => TicketAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {'fromSupport': 'from_support', 'createdAt': 'created_at'},
);

Map<String, dynamic> _$TicketMessageToJson(TicketMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'body': instance.body,
      'from_support': instance.fromSupport,
      'created_at': instance.createdAt.toIso8601String(),
      'attachments': instance.attachments.map((e) => e.toJson()).toList(),
    };
