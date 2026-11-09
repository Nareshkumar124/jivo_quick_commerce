// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ticket_message.dart';
import 'package:jivo_api/src/model/ticket_status_enum.dart';
import 'package:jivo_api/src/model/ticket_category_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Ticket {
  /// Returns a new [Ticket] instance.
  Ticket({
    required this.id,

    required this.number,

    required this.category,

    required this.status,

    required this.orderId,

    required this.orderNumber,

    required this.taskId,

    required this.payoutId,

    required this.lastMessage,

    required this.createdAt,

    required this.updatedAt,

    required this.canReply,

    required this.messages,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Shown to the customer and support, e.g. \"TK-000123\".
  @JsonKey(name: r'number', required: true, includeIfNull: false)
  final String number;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TicketCategoryEnum.unknownDefaultOpenApi,
  )
  final TicketCategoryEnum category;

  /// The customer can reply unless CLOSED; a reply to RESOLVED reopens it (OPEN).  * `OPEN` - Open * `IN_PROGRESS` - In progress * `RESOLVED` - Resolved * `CLOSED` - Closed
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TicketStatusEnum.unknownDefaultOpenApi,
  )
  final TicketStatusEnum status;

  @JsonKey(name: r'order_id', required: true, includeIfNull: true)
  final int? orderId;

  /// The order's number; for a rider ticket about a task, that task's order.
  @JsonKey(name: r'order_number', required: true, includeIfNull: true)
  final String? orderNumber;

  /// Rider tickets: the task it is about (Phase 7).
  @JsonKey(name: r'task_id', required: true, includeIfNull: true)
  final int? taskId;

  /// Rider tickets: the payout it is about (Phase 7).
  @JsonKey(name: r'payout_id', required: true, includeIfNull: true)
  final int? payoutId;

  /// The newest message, cut to 140 characters (plain text).
  @JsonKey(name: r'last_message', required: true, includeIfNull: true)
  final String? lastMessage;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// Last message or status change; the list is sorted by it, newest first.
  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  /// False once the ticket is CLOSED: hide the reply box and offer a new ticket.
  @JsonKey(name: r'can_reply', required: true, includeIfNull: false)
  final bool canReply;

  @JsonKey(name: r'messages', required: true, includeIfNull: false)
  final List<TicketMessage> messages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ticket &&
          other.id == id &&
          other.number == number &&
          other.category == category &&
          other.status == status &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.taskId == taskId &&
          other.payoutId == payoutId &&
          other.lastMessage == lastMessage &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt &&
          other.canReply == canReply &&
          other.messages == messages;

  @override
  int get hashCode =>
      id.hashCode +
      number.hashCode +
      category.hashCode +
      status.hashCode +
      (orderId == null ? 0 : orderId.hashCode) +
      (orderNumber == null ? 0 : orderNumber.hashCode) +
      (taskId == null ? 0 : taskId.hashCode) +
      (payoutId == null ? 0 : payoutId.hashCode) +
      (lastMessage == null ? 0 : lastMessage.hashCode) +
      createdAt.hashCode +
      updatedAt.hashCode +
      canReply.hashCode +
      messages.hashCode;

  factory Ticket.fromJson(Map<String, dynamic> json) => _$TicketFromJson(json);

  Map<String, dynamic> toJson() => _$TicketToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
