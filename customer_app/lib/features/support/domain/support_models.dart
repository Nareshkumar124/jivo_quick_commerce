import 'package:flutter/foundation.dart';

/// Help & support (`03 §2.11`, `06 §2.7`, `07 §2.9`; Phase 7, built ahead
/// on fakes). TODO(api): the shapes are the app's proposal until the P7
/// contract.

/// An FAQ entry (`GET /faqs/?app=customer`).
@immutable
class Faq {
  const Faq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final int id;

  /// A display heading from the server ("Orders", "Payments & refunds").
  final String category;
  final String question;

  /// Plain text (shown as text, never as HTML).
  final String answer;
}

/// `SupportTicket.status` (`07 §2.9`).
enum TicketStatus {
  open('OPEN'),
  inProgress('IN_PROGRESS'),
  resolved('RESOLVED'),
  closed('CLOSED'),
  unknown(null);

  const TicketStatus(this.wireValue);

  final String? wireValue;

  static TicketStatus fromWire(String? value) {
    for (final status in values) {
      if (status.wireValue != null && status.wireValue == value) return status;
    }
    return unknown;
  }

  /// The customer can still reply.
  bool get acceptsReplies => this != closed;
}

/// The issue type the customer picks (`03 §2.11` "choose an order, then an
/// issue type"). TODO(api): codes proposed for `SupportTicket.category`.
enum TicketCategory {
  missingItems('MISSING_ITEMS', needsOrder: true),
  damagedItems('DAMAGED_ITEMS', needsOrder: true),
  wrongItems('WRONG_ITEMS', needsOrder: true),
  lateDelivery('LATE_DELIVERY', needsOrder: true),
  paymentRefund('PAYMENT_REFUND', needsOrder: false),
  account('ACCOUNT', needsOrder: false),
  other('OTHER', needsOrder: false);

  const TicketCategory(this.wireValue, {required this.needsOrder});

  final String wireValue;

  /// Only offered when an order is chosen.
  final bool needsOrder;

  static TicketCategory fromWire(String? value) {
    for (final category in values) {
      if (category.wireValue == value) return category;
    }
    return other;
  }

  /// The categories offered with or without an order.
  static List<TicketCategory> offered({required bool withOrder}) => [
    for (final category in values)
      if (withOrder || !category.needsOrder) category,
  ];
}

/// The longest message the app sends.
const ticketMessageMaxLength = 1000;

/// The shortest new-ticket description the app accepts (the server's
/// limit, `support_tickets_create`). A reply needs one character.
const ticketMessageMinLength = 10;

/// One ticket in "My tickets".
@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.orderNumber,
    this.lastMessage,
  });

  final int id;

  /// Shown to the customer and to support, e.g. `TK-000123`.
  final String number;
  final TicketCategory category;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? orderId;
  final String? orderNumber;

  /// A preview of the newest message.
  final String? lastMessage;
}

/// A message in a ticket thread.
@immutable
class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.body,
    required this.fromSupport,
    required this.createdAt,
  });

  final int id;

  /// Plain text.
  final String body;

  /// Sent by Jivo support (`TicketMessage.is_staff`), not the customer.
  final bool fromSupport;
  final DateTime createdAt;
}

/// A ticket with its messages, oldest first.
@immutable
class TicketThread {
  TicketThread({
    required this.ticket,
    required this.messages,
    bool? canReply,
  }) : canReply = canReply ?? ticket.status != TicketStatus.closed;

  final SupportTicket ticket;
  final List<TicketMessage> messages;

  /// The server's `can_reply` (false once CLOSED; a reply to a RESOLVED
  /// ticket reopens it).
  final bool canReply;
}

@immutable
class TicketPage {
  const TicketPage({required this.items, this.nextPage});

  final List<SupportTicket> items;
  final int? nextPage;
}
