import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show
        JivoApi,
        Ticket,
        TicketCategoryEnum,
        TicketCreateRequest,
        TicketMessage,
        TicketReplyRequest,
        TicketSummary;
import 'package:jivo_core/jivo_core.dart';

import '../../../shared/fake_api_endpoint.dart';
import '../../../shared/paging.dart';
import '../domain/support_models.dart';

/// FAQs and support tickets (06 §2.7). Every method throws jivo_core's
/// [ApiError]: 400 `VALIDATION_ERROR` (message length, a reply to a CLOSED
/// ticket, a task or payout that isn't the rider's), 404 for another
/// user's ticket or a customer-app ticket (tickets are scoped to the
/// calling app), 413 for a photo the proxy refuses, 429 `RATE_LIMITED`.
abstract interface class SupportRepository {
  /// The rider app's FAQs in display order.
  Future<List<Faq>> faqs();

  /// The rider's tickets, newest activity first ([page] from 1).
  Future<Page<SupportTicket>> tickets({int? page});

  Future<TicketThread> ticket(int id);

  Future<TicketThread> create(TicketDraft draft);

  /// [attachmentKeys]: photos uploaded with [uploadPhoto] (at most
  /// [maxAttachmentsPerReply]).
  Future<TicketThread> reply(
    int ticketId,
    String message, {
    List<String> attachmentKeys = const [],
  });

  /// Uploads a JPEG photo (already compressed on the phone) to [ticketId].
  Future<UploadedAttachment> uploadPhoto(int ticketId, Uint8List jpeg);
}

/// The shared support API through the generated client.
class ApiSupportRepository implements SupportRepository {
  const ApiSupportRepository(this._api);

  final api.JivoApi _api;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiError.fromDioException(e);
    }
  }

  @override
  Future<List<Faq>> faqs() => _call(() async {
    final list = (await _api.getCmsApi().faqsList(app: 'rider')).data!;
    return [
      for (final f in list)
        Faq(
          id: f.id,
          category: f.category,
          question: f.question,
          answer: f.answer,
        ),
    ];
  });

  @override
  Future<Page<SupportTicket>> tickets({int? page}) => _call(() async {
    final body = (await _api.getSupportApi().supportTicketsList(page: page))
        .data!;
    return Page(
      items: [for (final t in body.results) ticketOfSummary(t)],
      nextPage: pageOfNext(body.next),
      count: body.count,
    );
  });

  @override
  Future<TicketThread> ticket(int id) => _call(
    () async => threadOf(
      (await _api.getSupportApi().supportTicketsRetrieve(id: id)).data!,
    ),
  );

  @override
  Future<TicketThread> create(TicketDraft draft) => _call(
    () async => threadOf(
      (await _api.getSupportApi().supportTicketsCreate(
        ticketCreateRequest: api.TicketCreateRequest(
          category: api.TicketCategoryEnum.values.firstWhere(
            (c) => c.value == draft.topic.code,
          ),
          message: draft.message,
          taskId: draft.linkedTaskId,
          payoutId: draft.linkedPayoutId,
        ),
      )).data!,
    ),
  );

  @override
  Future<TicketThread> reply(
    int ticketId,
    String message, {
    List<String> attachmentKeys = const [],
  }) => _call(
    () async => threadOf(
      (await _api.getSupportApi().supportTicketsMessagesCreate(
        id: ticketId,
        ticketReplyRequest: api.TicketReplyRequest(
          message: message.trim(),
          attachmentKeys: attachmentKeys.isEmpty ? null : attachmentKeys,
        ),
      )).data!,
    ),
  );

  @override
  Future<UploadedAttachment> uploadPhoto(int ticketId, Uint8List jpeg) => _call(
    () async {
      final body = (await _api.getSupportApi().supportTicketsAttachmentsCreate(
        id: ticketId,
        file: MultipartFile.fromBytes(
          jpeg,
          filename: 'photo.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
      )).data!;
      return UploadedAttachment(key: body.key, url: Uri.parse(body.url));
    },
  );
}

SupportTicket ticketOfSummary(api.TicketSummary t) => SupportTicket(
  id: t.id,
  number: t.number,
  status: TicketStatus.fromWire(t.status.value),
  createdAt: t.createdAt,
  updatedAt: t.updatedAt,
  topic: RiderTicketTopic.fromCode(t.category.value),
  orderNumber: t.orderNumber,
  taskId: t.taskId,
  payoutId: t.payoutId,
  lastMessage: t.lastMessage,
);

TicketThread threadOf(api.Ticket t) => TicketThread(
  ticket: SupportTicket(
    id: t.id,
    number: t.number,
    status: TicketStatus.fromWire(t.status.value),
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    topic: RiderTicketTopic.fromCode(t.category.value),
    orderNumber: t.orderNumber,
    taskId: t.taskId,
    payoutId: t.payoutId,
    lastMessage: t.lastMessage,
  ),
  messages: [for (final m in t.messages) _messageOf(m)],
  canReply: t.canReply,
);

TicketMessage _messageOf(api.TicketMessage m) => TicketMessage(
  id: m.id,
  body: m.body,
  fromSupport: m.fromSupport,
  createdAt: m.createdAt,
  attachments: [for (final a in m.attachments) ?Uri.tryParse(a.url)],
);

/// FAQs and tickets in memory (`FAKE_API` builds and tests, dev flavor
/// only). Support answers a new ticket with an automatic first reply.
class FakeSupportBackend extends FakeApiEndpoint implements SupportRepository {
  FakeSupportBackend({
    required this.clock,
    super.delay = const Duration(milliseconds: 300),
    super.pageSize = 20,
    bool seed = true,
  }) {
    if (seed) _seed();
  }

  final DateTime Function() clock;

  final List<Faq> faqList = [
    const Faq(
      id: 1,
      category: 'Orders',
      question: 'The customer is not answering. What do I do?',
      answer:
          'Call the customer twice from the order screen and wait 10 '
          'minutes at the address. Then choose "Couldn\'t deliver" and '
          '"Customer not reachable".',
    ),
    const Faq(
      id: 2,
      category: 'Orders',
      question: 'The pickup code does not work.',
      answer:
          'Check the order number on the bag. After 5 wrong codes, ask the '
          'store manager to unlock the order.',
    ),
    const Faq(
      id: 3,
      category: 'Cash and payouts',
      question: 'When do I get paid?',
      answer:
          'Payouts are sent every week to your bank account. You can see '
          'each payout and its reference under Payouts.',
    ),
    const Faq(
      id: 4,
      category: 'Cash and payouts',
      question: 'Where do I deposit cash?',
      answer:
          'Hand the cash to the store manager at your home store. It shows '
          'in your cash ledger once they record it.',
    ),
  ];

  final Map<int, SupportTicket> _tickets = {};
  final Map<int, List<TicketMessage>> _messages = {};

  /// Uploaded photos not yet sent with a reply, by key.
  final Map<String, UploadedAttachment> _uploads = {};
  int _nextTicket = 1;
  int _nextMessage = 1;
  int _nextUpload = 1;

  void _seed() {
    final at = clock().toUtc().subtract(const Duration(days: 3));
    final id = _open(
      'My payout is ₹120 less than my earnings.',
      at,
      topic: RiderTicketTopic.payout,
      payoutId: 41,
    );
    _add(
      id,
      'We checked: a ₹120 penalty for a late return was applied. It shows '
      'under Earnings.',
      fromSupport: true,
      at: at.add(const Duration(hours: 2)),
    );
    _tickets[id] = _tickets[id]!.copyWith(status: TicketStatus.resolved);
  }

  int _open(
    String message,
    DateTime at, {
    required RiderTicketTopic topic,
    int? taskId,
    String? orderNumber,
    int? payoutId,
  }) {
    final id = _nextTicket++;
    _tickets[id] = SupportTicket(
      id: id,
      number: 'TK-${id.toString().padLeft(6, '0')}',
      status: TicketStatus.open,
      createdAt: at,
      updatedAt: at,
      topic: topic,
      taskId: taskId,
      orderNumber: orderNumber,
      payoutId: payoutId,
    );
    _messages[id] = [];
    _add(id, message, fromSupport: false, at: at);
    return id;
  }

  void _add(
    int id,
    String body, {
    required bool fromSupport,
    required DateTime at,
    List<Uri> attachments = const [],
  }) {
    _messages[id]!.add(
      TicketMessage(
        id: _nextMessage++,
        body: body,
        fromSupport: fromSupport,
        createdAt: at,
        attachments: attachments,
      ),
    );
    _tickets[id] = _tickets[id]!.copyWith(updatedAt: at, lastMessage: body);
  }

  /// Support closes [id] (tests and the dev tools).
  void close(int id) =>
      _tickets[id] = _tickets[id]!.copyWith(status: TicketStatus.closed);

  TicketThread _thread(int id) {
    final ticket = _tickets[id];
    if (ticket == null) {
      throw const ApiError(code: ApiErrorCode.notFound, statusCode: 404);
    }
    return TicketThread(
      ticket: ticket,
      messages: List.unmodifiable(_messages[id]!),
      canReply: ticket.status != TicketStatus.closed,
    );
  }

  @override
  Future<List<Faq>> faqs() async {
    await recordCall('faqs');
    return List.unmodifiable(faqList);
  }

  @override
  Future<Page<SupportTicket>> tickets({int? page}) async {
    await recordCall('tickets ${page ?? 1}');
    final all = _tickets.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return pageOf(all, page ?? 1);
  }

  @override
  Future<TicketThread> ticket(int id) async {
    await recordCall('ticket $id');
    return _thread(id);
  }

  @override
  Future<TicketThread> create(TicketDraft draft) async {
    await recordCall(
      [
        'create ${draft.topic.code}',
        if (draft.linkedTaskId case final task?) 'task=$task',
        if (draft.linkedPayoutId case final payout?) 'payout=$payout',
      ].join(' '),
    );
    final message = draft.message;
    if (message.length < ticketMessageMinLength ||
        message.length > ticketMessageMaxLength) {
      throw const ApiError(code: ApiErrorCode.validationError, statusCode: 400);
    }
    final now = clock().toUtc();
    final id = _open(
      message,
      now,
      topic: draft.topic,
      taskId: draft.linkedTaskId,
      orderNumber: draft.linkedTaskId == null ? null : draft.label,
      payoutId: draft.linkedPayoutId,
    );
    _add(
      id,
      'Thanks, we got your message. Our team will reply here soon.',
      fromSupport: true,
      at: now,
    );
    return _thread(id);
  }

  @override
  Future<UploadedAttachment> uploadPhoto(int ticketId, Uint8List jpeg) async {
    await recordCall('upload $ticketId');
    if (!_thread(ticketId).canReply) {
      throw const ApiError(code: ApiErrorCode.validationError, statusCode: 400);
    }
    final key = 'fake${_nextUpload++}';
    return _uploads[key] = UploadedAttachment(
      key: key,
      url: Uri.parse('https://files.invalid/support/$ticketId/$key.webp'),
    );
  }

  @override
  Future<TicketThread> reply(
    int ticketId,
    String message, {
    List<String> attachmentKeys = const [],
  }) async {
    await recordCall(
      attachmentKeys.isEmpty
          ? 'reply $ticketId'
          : 'reply $ticketId ${attachmentKeys.join(',')}',
    );
    final current = _thread(ticketId);
    final body = message.trim();
    if (!current.canReply ||
        body.isEmpty ||
        body.length > ticketMessageMaxLength ||
        attachmentKeys.length > maxAttachmentsPerReply ||
        attachmentKeys.any((k) => !_uploads.containsKey(k))) {
      throw const ApiError(code: ApiErrorCode.validationError, statusCode: 400);
    }
    _add(
      ticketId,
      body,
      fromSupport: false,
      at: clock().toUtc(),
      attachments: [for (final k in attachmentKeys) _uploads.remove(k)!.url],
    );
    if (_tickets[ticketId]!.status == TicketStatus.resolved) {
      _tickets[ticketId] = _tickets[ticketId]!.copyWith(
        status: TicketStatus.open,
      );
    }
    return _thread(ticketId);
  }
}
