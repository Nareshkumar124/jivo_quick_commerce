import 'package:customer_app/features/cms/data/cms_repository.dart';
import 'package:customer_app/features/support/data/api_support_repository.dart';
import 'package:customer_app/features/support/domain/support_models.dart';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../fixtures/contract_examples.dart';
import '../../helpers/fake_http.dart';
import 'photo_fixtures.dart';

/// The P7 support and CMS API (T-713) against the contract's own examples.
void main() {
  late FakeHttp http;
  late (int, Object?) Function(RequestOptions r) answer;

  (int, Object?) example(String key) =>
      (int.parse(key.split('/')[1]), contractExample(key));

  setUp(() {
    answer = (_) => (200, null);
    http = FakeHttp((r) => answer(r));
  });

  ApiSupportRepository support() => ApiSupportRepository(http.api());

  Matcher apiError(ApiErrorCode code) =>
      throwsA(isA<ApiError>().having((e) => e.code, 'code', code));

  group('FAQs', () {
    test('GET /faqs/?app=customer maps the flat list', () async {
      answer = (_) => example('faqs_list/200/CustomerApp');
      final faqs = await support().faqs();
      final sent = http.requests.single;
      expect(sent.uri.path, '/api/v1/faqs/');
      expect(sent.uri.queryParameters['app'], 'customer');
      expect(faqs.single.category, 'Orders');
      expect(faqs.single.question, 'How long does delivery take?');
      expect(faqs.single.answer, startsWith('Most orders arrive'));
    });
  });

  group('tickets', () {
    test('list: page, summaries, newest activity first as sent', () async {
      answer = (_) => example('support_tickets_list/200/Tickets');
      final page = await support().listTickets(page: 2);
      expect(http.requests.single.uri.path, '/api/v1/support/tickets/');
      expect(http.requests.single.uri.queryParameters['page'], '2');
      expect(page.nextPage, isNull);
      final first = page.items.first;
      expect(first.id, 12);
      expect(first.number, 'TK-000012');
      expect(first.category, TicketCategory.damagedItems);
      expect(first.status, TicketStatus.inProgress);
      expect(first.orderId, 1002);
      expect(first.orderNumber, 'JV-261104-001002');
      expect(first.updatedAt, DateTime.utc(2026, 11, 4, 5, 25));
      final second = page.items.last;
      expect(second.category, TicketCategory.account);
      expect(second.status, TicketStatus.resolved);
      expect(second.orderId, isNull);
    });

    test('list: empty, and a page past the end is NOT_FOUND', () async {
      answer = (_) => example('support_tickets_list/200/NoTickets');
      expect((await support().listTickets()).items, isEmpty);
      answer = (_) => example('support_tickets_list/404/PAGENOTFOUND');
      await expectLater(
        support().listTickets(page: 9),
        apiError(ApiErrorCode.notFound),
      );
    });

    test('create sends category, trimmed message and order id', () async {
      answer = (_) => example('support_tickets_create/201/Created');
      final thread = await support().createTicket(
        category: TicketCategory.damagedItems,
        message: '  The oil bottle cap was broken when it arrived.  ',
        orderId: 1002,
      );
      final sent = http.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.path, '/api/v1/support/tickets/');
      expect(http.body(0), {
        'category': 'DAMAGED_ITEMS',
        'message': 'The oil bottle cap was broken when it arrived.',
        'order_id': 1002,
      });
      expect(thread.ticket.status, TicketStatus.open);
      expect(thread.canReply, isTrue);
      expect(thread.messages.single.fromSupport, isFalse);
    });

    test('create without an order leaves order_id out', () async {
      answer = (_) => example('support_tickets_create/201/Created');
      await support().createTicket(
        category: TicketCategory.account,
        message: 'Please update my phone number',
      );
      expect(http.body(0).containsKey('order_id'), isFalse);
      expect(http.body(0)['category'], 'ACCOUNT');
    });

    test('create errors: order required, too short, rate limited', () async {
      for (final (key, code) in [
        (
          'support_tickets_create/400/OrderRequired',
          ApiErrorCode.validationError,
        ),
        ('support_tickets_create/400/NotMyOrder', ApiErrorCode.validationError),
        (
          'support_tickets_create/400/MessageTooShort',
          ApiErrorCode.validationError,
        ),
        ('support_tickets_create/429/RATELIMITED', ApiErrorCode.rateLimited),
      ]) {
        answer = (_) => example(key);
        await expectLater(
          support().createTicket(
            category: TicketCategory.missingItems,
            message: 'Something is missing',
          ),
          apiError(code),
          reason: key,
        );
      }
      answer = (_) => example('support_tickets_create/429/RATELIMITED');
      try {
        await support().createTicket(
          category: TicketCategory.other,
          message: 'Something else entirely',
        );
        fail('expected 429');
      } on ApiError catch (e) {
        expect(e.details['retry_after_seconds'], 120);
      }
    });

    test('retrieve: messages oldest first, from_support, can_reply', () async {
      answer = (_) => example('support_tickets_retrieve/200/AnsweredBySupport');
      final thread = await support().ticket(12);
      expect(http.requests.single.uri.path, '/api/v1/support/tickets/12/');
      expect(thread.messages.map((m) => m.fromSupport), [false, true]);
      expect(thread.canReply, isTrue);

      answer = (_) => example('support_tickets_retrieve/200/Closed');
      final closed = await support().ticket(12);
      expect(closed.ticket.status, TicketStatus.closed);
      expect(closed.canReply, isFalse);

      answer = (_) => example('support_tickets_retrieve/404/NOTFOUND');
      await expectLater(support().ticket(99), apiError(ApiErrorCode.notFound));
    });

    test('reply posts the message and returns the updated ticket', () async {
      // The contract example: the reply carries a photo uploaded before.
      const key = '9f1c2b7e4d5a4c3b8a7f6e5d4c3b2a19';
      answer = (_) => example('support_tickets_messages_create/201/Replied');
      final thread = await support().reply(
        12,
        ' Here is a photo of the bottle. ',
        photoKeys: [key],
      );
      final sent = http.requests.single;
      expect(sent.method, 'POST');
      expect(sent.uri.path, '/api/v1/support/tickets/12/messages/');
      expect(http.body(0), {
        'message': 'Here is a photo of the bottle.',
        'attachment_keys': [key],
      });
      expect(thread.messages, hasLength(3));
      expect(thread.messages.last.body, 'Here is a photo of the bottle.');
      expect(thread.messages.last.fromSupport, isFalse);
      final photo = thread.messages.last.photos.single;
      expect(photo.key, key);
      expect(photo.url, startsWith('https://storage.example.com/private/'));
      expect(thread.messages.first.photos, isEmpty);
      expect(thread.ticket.status, TicketStatus.open);
      expect(thread.ticket.lastMessage, 'Here is a photo of the bottle.');
      expect(thread.canReply, isTrue);
    });

    test('a reply without photos leaves attachment_keys out', () async {
      answer = (_) => example('support_tickets_messages_create/201/Replied');
      await support().reply(12, 'Thank you');
      expect(http.body(0), {'message': 'Thank you'});
    });

    test('reply errors: closed, empty, not found, rate limited', () async {
      for (final (key, code) in [
        (
          'support_tickets_messages_create/400/TicketClosed',
          ApiErrorCode.validationError,
        ),
        (
          'support_tickets_messages_create/400/EmptyMessage',
          ApiErrorCode.validationError,
        ),
        (
          'support_tickets_messages_create/400/UnknownOrExpiredPhoto',
          ApiErrorCode.validationError,
        ),
        ('support_tickets_messages_create/404/NOTFOUND', ApiErrorCode.notFound),
        (
          'support_tickets_messages_create/429/RATELIMITED',
          ApiErrorCode.rateLimited,
        ),
      ]) {
        answer = (_) => example(key);
        await expectLater(
          support().reply(12, 'x'),
          apiError(code),
          reason: key,
        );
      }
    });
  });

  group('photos', () {
    final png = TicketPhotoFile(bytes: pngBytes, filename: 'IMG_0001.png');

    test(
      'upload sends multipart `file` with its type and returns the key',
      () async {
        answer = (_) =>
            example('support_tickets_attachments_create/201/Uploaded');
        final photo = await support().uploadPhoto(12, png);
        final sent = http.requests.single;
        expect(sent.method, 'POST');
        expect(sent.uri.path, '/api/v1/support/tickets/12/attachments/');
        final form = sent.data as FormData;
        final file = form.files.single;
        expect(file.key, 'file');
        expect(file.value.contentType.toString(), 'image/png');
        // The device file name is not sent.
        expect(file.value.filename, 'photo.png');
        expect(file.value.length, pngBytes.length);
        expect(photo.key, '9f1c2b7e4d5a4c3b8a7f6e5d4c3b2a19');
        expect(photo.url, contains('X-Amz-Signature'));
      },
    );

    test('JPEG and WebP are sent with their types', () async {
      answer = (_) =>
          example('support_tickets_attachments_create/201/Uploaded');
      await support().uploadPhoto(
        12,
        TicketPhotoFile(bytes: jpegBytes, filename: 'a.jpg'),
      );
      await support().uploadPhoto(
        12,
        TicketPhotoFile(bytes: webpBytes, filename: 'a.webp'),
      );
      final types = [
        for (final r in http.requests)
          (r.data as FormData).files.single.value.contentType.toString(),
      ];
      expect(types, ['image/jpeg', 'image/webp']);
    });

    test(
      'other types and files over 5 MB are refused before any request',
      () async {
        await expectLater(
          support().uploadPhoto(
            12,
            TicketPhotoFile(
              bytes: Uint8List.fromList('GIF89a....'.codeUnits),
              filename: 'a.gif',
            ),
          ),
          throwsA(
            isA<TicketPhotoException>().having(
              (e) => e.problem,
              'problem',
              TicketPhotoProblem.unsupportedType,
            ),
          ),
        );
        final big = Uint8List(ticketPhotoMaxBytes + 1)..setAll(0, jpegBytes);
        await expectLater(
          support().uploadPhoto(12, TicketPhotoFile(bytes: big, filename: 'b')),
          throwsA(
            isA<TicketPhotoException>().having(
              (e) => e.problem,
              'problem',
              TicketPhotoProblem.tooLarge,
            ),
          ),
        );
        final exact = Uint8List(ticketPhotoMaxBytes)..setAll(0, jpegBytes);
        expect(
          checkTicketPhoto(TicketPhotoFile(bytes: exact, filename: 'c')),
          isNull,
        );
        expect(http.requests, isEmpty);
      },
    );

    test('413 from the server or a proxy is a photo-size error', () async {
      answer = (_) => (413, null);
      await expectLater(
        support().uploadPhoto(12, png),
        throwsA(
          isA<TicketPhotoException>().having(
            (e) => e.problem,
            'problem',
            TicketPhotoProblem.rejectedSize,
          ),
        ),
      );
    });

    test(
      'upload errors: not an image, closed, not found, rate limited',
      () async {
        for (final (key, code) in [
          (
            'support_tickets_attachments_create/400/NotAnImage',
            ApiErrorCode.validationError,
          ),
          (
            'support_tickets_attachments_create/400/TicketClosed',
            ApiErrorCode.validationError,
          ),
          (
            'support_tickets_attachments_create/404/NOTFOUND',
            ApiErrorCode.notFound,
          ),
          (
            'support_tickets_attachments_create/429/RATELIMITED',
            ApiErrorCode.rateLimited,
          ),
        ]) {
          answer = (_) => example(key);
          await expectLater(
            support().uploadPhoto(12, png),
            apiError(code),
            reason: key,
          );
        }
      },
    );
  });

  group('CMS pages', () {
    test('GET /pages/{slug}/ maps the page', () async {
      answer = (_) => example('pages_retrieve/200/RefundPolicy');
      final page = await ApiCmsRepository(http.api()).page(CmsSlugs.refund);
      expect(http.requests.single.uri.path, '/api/v1/pages/refund-policy/');
      expect(page.slug, 'refund-policy');
      expect(page.title, 'Refund Policy');
      expect(page.html, contains('<h1>Refund Policy</h1>'));
      expect(page.updatedAt, isNotNull);
    });

    test('an unknown or unpublished page is NOT_FOUND', () async {
      answer = (_) => example('pages_retrieve/404/NOTFOUND');
      await expectLater(
        ApiCmsRepository(http.api()).page('nope'),
        apiError(ApiErrorCode.notFound),
      );
    });
  });
}
