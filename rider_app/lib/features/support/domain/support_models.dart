import 'package:flutter/foundation.dart';

/// Help and support for riders (04 §2.9, screen 20; P7), on the shared
/// support API (06 §2.7 `faqs_list`, `support_tickets_*`).

/// An FAQ entry (`GET /faqs/?app=rider`). Entries of one category are
/// consecutive; a new heading starts whenever [category] changes.
@immutable
class Faq {
  const Faq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  final int id;
  final String category;
  final String question;

  /// Plain text (shown as text, never as HTML).
  final String answer;
}

/// FAQs grouped for display: one section per run of the same category, in
/// the server's order.
List<({String category, List<Faq> entries})> groupFaqs(List<Faq> faqs) {
  final groups = <({String category, List<Faq> entries})>[];
  for (final faq in faqs) {
    if (groups.isEmpty || groups.last.category != faq.category) {
      groups.add((category: faq.category, entries: [faq]));
    } else {
      groups.last.entries.add(faq);
    }
  }
  return groups;
}

/// `SupportTicket.status`.
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
}

/// What the rider needs help with. The ticket API has only the customer's
/// categories and takes an `order_id` only for the caller's own order (a
/// rider never owns the order), so every rider topic is sent as `OTHER` or
/// `ACCOUNT` and the topic and reference travel in a first line of the
/// message (`[TASK JV-261104-000123] ...`).
///
/// TODO(api): rider categories (TASK, PAYOUT, CASH) and `task_id` /
/// `payout_id` on create (api-requests, P7 rider report).
enum RiderTicketTopic {
  task('TASK', wireCategory: 'OTHER', takesReference: true),
  payout('PAYOUT', wireCategory: 'OTHER', takesReference: true),
  cash('CASH', wireCategory: 'OTHER', takesReference: false),
  account('ACCOUNT', wireCategory: 'ACCOUNT', takesReference: false),
  app('APP', wireCategory: 'OTHER', takesReference: false),
  other('OTHER', wireCategory: 'OTHER', takesReference: false);

  const RiderTicketTopic(
    this.code, {
    required this.wireCategory,
    required this.takesReference,
  });

  /// The tag in the message's first line, read by support staff.
  final String code;

  /// The `category` sent to `support_tickets_create`.
  final String wireCategory;

  /// The form asks for an order number or payout reference.
  final bool takesReference;

  static RiderTicketTopic? fromCode(String? code) {
    for (final topic in values) {
      if (topic.code == code) return topic;
    }
    return null;
  }
}

/// The server's limits on a new ticket's message (`support_tickets_create`:
/// 10–1000 characters after trimming) and on a reply (1–1000).
const ticketMessageMinLength = 10;
const ticketMessageMaxLength = 1000;

/// The longest reference the form takes (an order number or payout period).
const ticketReferenceMaxLength = 40;

/// What the rider typed may be at most this long, so the tagged message
/// stays within [ticketMessageMaxLength].
const riderTicketTextMaxLength =
    ticketMessageMaxLength - ticketReferenceMaxLength - 12;

/// Why a new ticket can't be sent yet.
enum TicketDraftProblem { tooShort, tooLong, referenceTooLong }

/// A new ticket as the rider fills it in.
@immutable
class TicketDraft {
  const TicketDraft({required this.topic, this.reference = '', this.text = ''});

  final RiderTicketTopic topic;
  final String reference;
  final String text;

  TicketDraftProblem? get problem {
    final body = text.trim();
    if (body.length < ticketMessageMinLength) {
      return TicketDraftProblem.tooShort;
    }
    if (body.length > riderTicketTextMaxLength) {
      return TicketDraftProblem.tooLong;
    }
    if (reference.trim().length > ticketReferenceMaxLength) {
      return TicketDraftProblem.referenceTooLong;
    }
    return null;
  }

  /// The message sent to support: a tag line, then the rider's text.
  String get message {
    final ref = topic.takesReference ? _oneLine(reference) : '';
    final tag = ref.isEmpty ? topic.code : '${topic.code} $ref';
    return '[$tag] ${text.trim()}';
  }

  static String _oneLine(String value) =>
      value.trim().replaceAll(RegExp(r'[\s\[\]]+'), ' ');
}

/// Splits a ticket's first message into the rider's topic and text. A
/// message without a known tag comes back unchanged with no topic.
({RiderTicketTopic? topic, String? reference, String text}) parseRiderMessage(
  String message,
) {
  final match = RegExp(r'^\[([A-Z]+)(?: ([^\]]+))?\] ?').firstMatch(message);
  final topic = RiderTicketTopic.fromCode(match?.group(1));
  if (match == null || topic == null) {
    return (topic: null, reference: null, text: message);
  }
  return (
    topic: topic,
    reference: match.group(2),
    text: message.substring(match.end),
  );
}

/// One ticket in "My tickets".
@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.number,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });

  final int id;

  /// Shown to the rider and to support, e.g. `TK-000123`.
  final String number;
  final TicketStatus status;
  final DateTime createdAt;

  /// The last activity.
  final DateTime updatedAt;

  /// A preview of the newest message.
  final String? lastMessage;

  SupportTicket copyWith({
    TicketStatus? status,
    DateTime? updatedAt,
    String? lastMessage,
  }) => SupportTicket(
    id: id,
    number: number,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastMessage: lastMessage ?? this.lastMessage,
  );
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
  final String body;

  /// Sent by Jivo support, not the rider.
  final bool fromSupport;
  final DateTime createdAt;
}

/// A ticket with its messages, oldest first.
@immutable
class TicketThread {
  const TicketThread({
    required this.ticket,
    required this.messages,
    required this.canReply,
  });

  final SupportTicket ticket;
  final List<TicketMessage> messages;

  /// The server's `can_reply` (false once CLOSED; a reply to a RESOLVED
  /// ticket reopens it).
  final bool canReply;

  /// The topic of the rider's first message, if it carries one.
  RiderTicketTopic? get topic =>
      messages.isEmpty ? null : parseRiderMessage(messages.first.body).topic;
}
