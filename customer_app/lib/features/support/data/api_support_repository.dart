import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    as api
    show
        JivoApi,
        Faq,
        Ticket,
        TicketCategoryEnum,
        TicketAttachment,
        TicketCreateRequest,
        TicketMessage,
        TicketReplyRequest,
        TicketSummary;
import 'package:jivo_core/jivo_core.dart';

import '../domain/support_models.dart';
import 'support_repository.dart';

/// FAQs and tickets on the P7 API (`faqs_list`, `support_tickets_*`).
///
/// Errors are [ApiError]s: 400 `VALIDATION_ERROR` (message length, an order
/// issue without `order_id`, someone else's order, a reply to a CLOSED
/// ticket), 404 for another user's ticket, 429 `RATE_LIMITED` with
/// `retry_after_seconds` (10 new tickets / 60 replies / 30 photos an hour).
/// The screens show them through jivo_core's messages. Photos the API won't
/// take (type, size, HTTP 413 from the server or a proxy) are
/// [TicketPhotoException]s.
class ApiSupportRepository implements SupportRepository {
  const ApiSupportRepository(this._api);

  final api.JivoApi _api;

  @override
  Future<List<Faq>> faqs() => _guard(() async {
    final list = (await _api.getCmsApi().faqsList(app: 'customer')).data!;
    return [for (final f in list) faqFromApi(f)];
  });

  @override
  Future<TicketPage> listTickets({int page = 1}) => _guard(() async {
    final result = (await _api.getSupportApi().supportTicketsList(page: page))
        .data!;
    return TicketPage(
      items: [for (final t in result.results) ticketFromSummary(t)],
      nextPage: result.next == null ? null : page + 1,
    );
  });

  @override
  Future<TicketThread> ticket(int id) => _guard(
    () async => threadFromApi(
      (await _api.getSupportApi().supportTicketsRetrieve(id: id)).data!,
    ),
  );

  @override
  Future<TicketThread> createTicket({
    required TicketCategory category,
    required String message,
    int? orderId,
  }) => _guard(() async {
    final created = (await _api.getSupportApi().supportTicketsCreate(
      ticketCreateRequest: api.TicketCreateRequest(
        category: categoryToApi(category),
        message: message.trim(),
        orderId: orderId,
      ),
    )).data!;
    return threadFromApi(created);
  });

  @override
  Future<TicketThread> reply(
    int ticketId,
    String message, {
    List<String> photoKeys = const [],
  }) => _guard(
    () async => threadFromApi(
      (await _api.getSupportApi().supportTicketsMessagesCreate(
        id: ticketId,
        ticketReplyRequest: api.TicketReplyRequest(
          message: message.trim(),
          attachmentKeys: photoKeys.isEmpty ? null : photoKeys,
        ),
      )).data!,
    ),
  );

  @override
  Future<TicketPhoto> uploadPhoto(int ticketId, TicketPhotoFile photo) async {
    final problem = checkTicketPhoto(photo);
    if (problem != null) throw TicketPhotoException(problem);
    final type = photo.type!;
    try {
      final uploaded =
          (await _api.getSupportApi().supportTicketsAttachmentsCreate(
            id: ticketId,
            file: MultipartFile.fromBytes(
              photo.bytes,
              filename: 'photo.${type.extension}',
              contentType: DioMediaType.parse(type.mimeType),
            ),
          )).data!;
      return photoFromApi(uploaded);
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        throw const TicketPhotoException(TicketPhotoProblem.rejectedSize);
      }
      throw ApiError.fromDioException(e);
    }
  }
}

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

Faq faqFromApi(api.Faq f) =>
    Faq(id: f.id, category: f.category, question: f.question, answer: f.answer);

api.TicketCategoryEnum categoryToApi(TicketCategory category) => api
    .TicketCategoryEnum
    .values
    .firstWhere((e) => e.value == category.wireValue);

SupportTicket ticketFromSummary(api.TicketSummary t) => SupportTicket(
  id: t.id,
  number: t.number,
  category: TicketCategory.fromWire(t.category.value),
  status: TicketStatus.fromWire(t.status.value),
  createdAt: t.createdAt,
  updatedAt: t.updatedAt,
  orderId: t.orderId,
  orderNumber: t.orderNumber,
  lastMessage: t.lastMessage,
);

TicketThread threadFromApi(api.Ticket t) => TicketThread(
  ticket: SupportTicket(
    id: t.id,
    number: t.number,
    category: TicketCategory.fromWire(t.category.value),
    status: TicketStatus.fromWire(t.status.value),
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    orderId: t.orderId,
    orderNumber: t.orderNumber,
    lastMessage: t.lastMessage,
  ),
  messages: [for (final m in t.messages) _message(m)],
  canReply: t.canReply,
);

TicketMessage _message(api.TicketMessage m) => TicketMessage(
  id: m.id,
  body: m.body,
  fromSupport: m.fromSupport,
  createdAt: m.createdAt,
  photos: [for (final a in m.attachments) photoFromApi(a)],
);

TicketPhoto photoFromApi(api.TicketAttachment a) =>
    TicketPhoto(key: a.key, url: a.url);
