// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ticket_attachment.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TicketMessage {
  /// Returns a new [TicketMessage] instance.
  TicketMessage({
    required this.id,

    required this.body,

    required this.fromSupport,

    required this.createdAt,

    required this.attachments,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Plain text; show as text, never as HTML.
  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  /// Sent by Jivo support, not the customer.
  @JsonKey(name: r'from_support', required: true, includeIfNull: false)
  final bool fromSupport;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// Photos attached to this message (Phase 7); [] when none.
  @JsonKey(name: r'attachments', required: true, includeIfNull: false)
  final List<TicketAttachment> attachments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketMessage &&
          other.id == id &&
          other.body == body &&
          other.fromSupport == fromSupport &&
          other.createdAt == createdAt &&
          other.attachments == attachments;

  @override
  int get hashCode =>
      id.hashCode +
      body.hashCode +
      fromSupport.hashCode +
      createdAt.hashCode +
      attachments.hashCode;

  factory TicketMessage.fromJson(Map<String, dynamic> json) =>
      _$TicketMessageFromJson(json);

  Map<String, dynamic> toJson() => _$TicketMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
