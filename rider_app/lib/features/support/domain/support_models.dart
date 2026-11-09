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

/// What the rider needs help with: the ticket `category` the rider app
/// sends (TASK, PAYOUT and CASH are rider-only; the customer categories are
/// never offered here).
enum RiderTicketTopic {
  task('TASK'),
  payout('PAYOUT'),
  cash('CASH'),
  account('ACCOUNT'),
  other('OTHER');

  const RiderTicketTopic(this.code);

  /// The wire `category`.
  final String code;

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

/// Why a new ticket can't be sent yet.
enum TicketDraftProblem { tooShort, tooLong }

/// A new ticket as the rider fills it in. [taskId] / [payoutId] link the
/// ticket to one of the rider's tasks or payouts (sent as `task_id` /
/// `payout_id`, only with the matching topic); [label] is how the screen
/// shows that record (the order number, the payout period) and is never
/// sent.
@immutable
class TicketDraft {
  const TicketDraft({
    required this.topic,
    this.taskId,
    this.payoutId,
    this.label,
    this.text = '',
  });

  final RiderTicketTopic topic;
  final int? taskId;
  final int? payoutId;
  final String? label;
  final String text;

  /// The task sent with the ticket (TASK only).
  int? get linkedTaskId => topic == RiderTicketTopic.task ? taskId : null;

  /// The payout sent with the ticket (PAYOUT only).
  int? get linkedPayoutId => topic == RiderTicketTopic.payout ? payoutId : null;

  /// The label of the linked record, if the current topic has one.
  String? get linkedLabel =>
      linkedTaskId != null || linkedPayoutId != null ? label : null;

  TicketDraftProblem? get problem {
    final body = text.trim();
    if (body.length < ticketMessageMinLength) {
      return TicketDraftProblem.tooShort;
    }
    if (body.length > ticketMessageMaxLength) {
      return TicketDraftProblem.tooLong;
    }
    return null;
  }

  /// The message sent to support: the rider's text, trimmed.
  String get message => text.trim();

  TicketDraft copyWith({RiderTicketTopic? topic, String? text}) => TicketDraft(
    topic: topic ?? this.topic,
    taskId: taskId,
    payoutId: payoutId,
    label: label,
    text: text ?? this.text,
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
    this.topic,
    this.orderNumber,
    this.taskId,
    this.payoutId,
    this.lastMessage,
  });

  final int id;

  /// Shown to the rider and to support, e.g. `TK-000123`.
  final String number;
  final TicketStatus status;

  /// The ticket's `category`; null for a category the rider app doesn't
  /// offer.
  final RiderTicketTopic? topic;

  /// For a task ticket, that task's order number.
  final String? orderNumber;
  final int? taskId;
  final int? payoutId;
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
    topic: topic,
    orderNumber: orderNumber,
    taskId: taskId,
    payoutId: payoutId,
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
    this.attachments = const [],
  });

  final int id;
  final String body;

  /// Sent by Jivo support, not the rider.
  final bool fromSupport;
  final DateTime createdAt;

  /// Photos on the message: short-lived signed URLs.
  final List<Uri> attachments;
}

/// A photo uploaded to a ticket (`support_tickets_attachments_create`),
/// waiting to be sent with the next reply as an `attachment_keys` entry.
@immutable
class UploadedAttachment {
  const UploadedAttachment({required this.key, required this.url});

  final String key;
  final Uri url;
}

/// At most this many photos per reply (`attachment_keys`).
const maxAttachmentsPerReply = 3;

/// Photos are compressed on the phone to at most this many bytes before
/// upload. The server takes 5 MB, but the live proxy rejects bodies above
/// about 2.5 MB (413), so stay well under it.
const kTicketPhotoMaxBytes = 2000000;

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

  RiderTicketTopic? get topic => ticket.topic;
}
