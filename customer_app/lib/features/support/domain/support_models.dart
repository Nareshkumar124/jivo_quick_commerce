import 'package:flutter/foundation.dart';

/// Help & support (`03 §2.11`, `06 §2.7`, `07 §2.9`; Phase 7), mapped from
/// the `support_tickets_*` contract.

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
/// issue type"); the contract's `TicketCategoryEnum` codes.
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

/// A photo on a ticket message (`TicketAttachment`): its [key] and a
/// short-lived signed [url] to show it.
@immutable
class TicketPhoto {
  const TicketPhoto({required this.key, required this.url});

  final String key;
  final String url;
}

/// A message in a ticket thread.
@immutable
class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.body,
    required this.fromSupport,
    required this.createdAt,
    this.photos = const [],
  });

  final int id;

  /// Plain text.
  final String body;

  /// Sent by Jivo support (`TicketMessage.is_staff`), not the customer.
  final bool fromSupport;
  final DateTime createdAt;

  /// The message's photos (`attachments`).
  final List<TicketPhoto> photos;
}

/// A ticket with its messages, oldest first.
@immutable
class TicketThread {
  TicketThread({required this.ticket, required this.messages, bool? canReply})
    : canReply = canReply ?? ticket.status != TicketStatus.closed;

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

/// Photos on one message: at most this many (`attachment_keys` maxItems).
const ticketPhotosPerMessage = 3;

/// The largest photo the API accepts (`support_tickets_attachments_create`).
const ticketPhotoMaxBytes = 5 * 1024 * 1024;

/// A photo the customer picked, ready to upload.
@immutable
class TicketPhotoFile {
  const TicketPhotoFile({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  /// The type read from the file's first bytes (not its name).
  TicketPhotoType? get type => TicketPhotoType.sniff(bytes);

  @override
  String toString() => 'TicketPhotoFile(${bytes.length} bytes)';
}

/// The image types the API accepts.
enum TicketPhotoType {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const TicketPhotoType(this.mimeType, this.extension);

  final String mimeType;
  final String extension;

  /// JPEG, PNG or WebP by magic bytes; null for anything else.
  static TicketPhotoType? sniff(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
      return jpeg;
    }
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return png;
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
      return webp;
    }
    return null;
  }
}

/// Why a photo can't be attached.
enum TicketPhotoProblem {
  /// Not JPEG, PNG or WebP.
  unsupportedType,

  /// Over [ticketPhotoMaxBytes].
  tooLarge,

  /// The message already has [ticketPhotosPerMessage].
  tooMany,

  /// The server or a proxy refused the size (HTTP 413).
  rejectedSize,
}

/// A photo the app refuses before (or the server refuses while) uploading.
class TicketPhotoException implements Exception {
  const TicketPhotoException(this.problem);

  final TicketPhotoProblem problem;

  @override
  String toString() => 'TicketPhotoException(${problem.name})';
}

/// Checks [photo] against the API's limits; null when it can be uploaded.
TicketPhotoProblem? checkTicketPhoto(TicketPhotoFile photo) {
  if (photo.type == null) return TicketPhotoProblem.unsupportedType;
  if (photo.bytes.length > ticketPhotoMaxBytes) {
    return TicketPhotoProblem.tooLarge;
  }
  return null;
}

/// A photo waiting to go with a message. Once uploaded it keeps its key, so
/// a retry after a failed reply doesn't upload it again.
class PendingTicketPhoto {
  PendingTicketPhoto(this.file);

  final TicketPhotoFile file;

  /// Set by a successful upload (valid for an hour on the server).
  String? uploadedKey;
}
