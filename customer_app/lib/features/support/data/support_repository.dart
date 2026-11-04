import 'package:jivo_core/jivo_core.dart';

import '../domain/support_models.dart';

/// FAQs and support tickets (`06 §2.7`, Phase 7).
///
/// TODO(api): `GET /faqs/?app=customer`, `GET/POST /support/tickets/`,
/// `GET /support/tickets/{id}/` and `POST /support/tickets/{id}/messages/`
/// are not in jivo_api yet. The screens run on [FakeSupportRepository]
/// (`FAKE_API=true`, tests); the real-API build shows only the contact
/// options from `config/app` ([UnavailableSupportRepository]).
abstract interface class SupportRepository {
  /// Active FAQs for the customer app, in display order. Throws [ApiError].
  Future<List<Faq>> faqs();

  /// The customer's tickets, newest activity first. Throws [ApiError].
  Future<TicketPage> listTickets({int page = 1});

  /// One of the customer's tickets with its messages (404 for anyone
  /// else's). Throws [ApiError].
  Future<TicketThread> ticket(int id);

  /// Opens a ticket; [message] is the first message. Throws [ApiError].
  Future<TicketThread> createTicket({
    required TicketCategory category,
    required String message,
    int? orderId,
  });

  /// Adds the customer's reply. Throws [ApiError] (`VALIDATION_ERROR` on a
  /// closed ticket).
  Future<TicketThread> reply(int ticketId, String message);
}

/// The real-API build until the P7 endpoints exist.
class UnavailableSupportRepository implements SupportRepository {
  const UnavailableSupportRepository();

  static const _error = ApiError(code: ApiErrorCode.serviceUnavailable);

  @override
  Future<List<Faq>> faqs() async => const [];

  @override
  Future<TicketPage> listTickets({int page = 1}) async =>
      const TicketPage(items: []);

  @override
  Future<TicketThread> ticket(int id) async => throw _error;

  @override
  Future<TicketThread> createTicket({
    required TicketCategory category,
    required String message,
    int? orderId,
  }) async => throw _error;

  @override
  Future<TicketThread> reply(int ticketId, String message) async =>
      throw _error;
}

/// In-memory FAQs and tickets (`FAKE_API=true` and tests). Support answers
/// a new ticket with an automatic first reply.
class FakeSupportRepository implements SupportRepository {
  FakeSupportRepository({
    DateTime Function()? clock,
    this.pageSize = 20,
    bool seed = true,
  }) : _clock = clock ?? DateTime.now {
    if (seed) _seed();
  }

  final DateTime Function() _clock;
  final int pageSize;

  final List<Faq> faqList = [
    const Faq(
      id: 1,
      category: 'Orders',
      question: 'How long does delivery take?',
      answer:
          'Most orders arrive in 10 to 30 minutes. You can follow your '
          'order live from the order screen.',
    ),
    const Faq(
      id: 2,
      category: 'Orders',
      question: 'Can I cancel my order?',
      answer:
          'Yes, until the store starts packing it. Open the order and tap '
          'Cancel order.',
    ),
    const Faq(
      id: 3,
      category: 'Payments & refunds',
      question: 'When will I get my refund?',
      answer:
          'Refunds go back to the original payment method within 5 to 7 '
          'working days.',
    ),
    const Faq(
      id: 4,
      category: 'Payments & refunds',
      question: 'Is cash on delivery available?',
      answer: 'Yes, for orders up to the limit shown at checkout.',
    ),
  ];

  final Map<int, SupportTicket> _tickets = {};
  final Map<int, List<TicketMessage>> _messages = {};
  int _nextTicket = 1;
  int _nextMessage = 1;

  /// When set, the next call throws it once.
  Object? failNext;

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  void _seed() {
    final now = _clock().toUtc();
    final thread = _open(
      category: TicketCategory.damagedItems,
      message: 'The oil bottle cap was broken when it arrived.',
      orderId: 1002,
      at: now.subtract(const Duration(days: 2)),
    );
    _addMessage(
      thread.id,
      'Sorry about that! We have started a refund for the bottle.',
      fromSupport: true,
      at: now.subtract(const Duration(days: 2, hours: -1)),
    );
    _tickets[thread.id] = _with(thread, status: TicketStatus.resolved);
  }

  SupportTicket _open({
    required TicketCategory category,
    required String message,
    required DateTime at,
    int? orderId,
  }) {
    final id = _nextTicket++;
    final ticket = SupportTicket(
      id: id,
      number: 'TK-${id.toString().padLeft(6, '0')}',
      category: category,
      status: TicketStatus.open,
      createdAt: at,
      updatedAt: at,
      orderId: orderId,
      orderNumber: orderId == null
          ? null
          : 'JV-261104-${orderId.toString().padLeft(6, '0')}',
      lastMessage: message,
    );
    _tickets[id] = ticket;
    _messages[id] = [];
    _addMessage(id, message, fromSupport: false, at: at);
    return ticket;
  }

  void _addMessage(
    int ticketId,
    String body, {
    required bool fromSupport,
    required DateTime at,
  }) {
    _messages[ticketId]!.add(
      TicketMessage(
        id: _nextMessage++,
        body: body,
        fromSupport: fromSupport,
        createdAt: at,
      ),
    );
    _tickets[ticketId] = _with(_tickets[ticketId]!, at: at, last: body);
  }

  static SupportTicket _with(
    SupportTicket t, {
    TicketStatus? status,
    DateTime? at,
    String? last,
  }) => SupportTicket(
    id: t.id,
    number: t.number,
    category: t.category,
    status: status ?? t.status,
    createdAt: t.createdAt,
    updatedAt: at ?? t.updatedAt,
    orderId: t.orderId,
    orderNumber: t.orderNumber,
    lastMessage: last ?? t.lastMessage,
  );

  /// Support closes [ticketId] (tests).
  void close(int ticketId) =>
      _tickets[ticketId] = _with(_tickets[ticketId]!, status: TicketStatus.closed);

  TicketThread _thread(int id) {
    final ticket = _tickets[id];
    if (ticket == null) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    return TicketThread(
      ticket: ticket,
      messages: List.unmodifiable(_messages[id]!),
    );
  }

  @override
  Future<List<Faq>> faqs() async {
    _maybeFail();
    return List.unmodifiable(faqList);
  }

  @override
  Future<TicketPage> listTickets({int page = 1}) async {
    _maybeFail();
    final all = _tickets.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final start = (page - 1) * pageSize;
    if (start > all.length) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    final end = (start + pageSize).clamp(0, all.length);
    return TicketPage(
      items: all.sublist(start, end),
      nextPage: end < all.length ? page + 1 : null,
    );
  }

  @override
  Future<TicketThread> ticket(int id) async {
    _maybeFail();
    return _thread(id);
  }

  @override
  Future<TicketThread> createTicket({
    required TicketCategory category,
    required String message,
    int? orderId,
  }) async {
    _maybeFail();
    final body = message.trim();
    if (body.length < ticketMessageMinLength ||
        (category.needsOrder && orderId == null)) {
      throw const ApiError(code: ApiErrorCode.validationError, statusCode: 400);
    }
    final now = _clock().toUtc();
    final ticket = _open(
      category: category,
      message: body,
      orderId: orderId,
      at: now,
    );
    _addMessage(
      ticket.id,
      'Thanks for reaching out. Our team will reply here shortly.',
      fromSupport: true,
      at: now,
    );
    return _thread(ticket.id);
  }

  @override
  Future<TicketThread> reply(int ticketId, String message) async {
    _maybeFail();
    final current = _thread(ticketId);
    final body = message.trim();
    if (!current.ticket.status.acceptsReplies || body.isEmpty) {
      throw const ApiError(code: ApiErrorCode.validationError, statusCode: 400);
    }
    _addMessage(ticketId, body, fromSupport: false, at: _clock().toUtc());
    return _thread(ticketId);
  }
}
