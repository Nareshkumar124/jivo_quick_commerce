import 'dart:typed_data';

import 'package:dio/dio.dart' show FormData;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/onboarding/domain/image_picking.dart';
import 'package:rider_app/features/support/data/support_repository.dart';
import 'package:rider_app/features/support/domain/support_models.dart';
import 'package:rider_app/features/support/presentation/support_providers.dart';

import '../../helpers/canned_http.dart';
import '../../helpers/onboarding_fixtures.dart';
import '../../helpers/records_helpers.dart';
import '../../helpers/rider_app_harness.dart';

Map<String, Object?> _ticketJson({
  int id = 7,
  String category = 'TASK',
  String status = 'OPEN',
  bool canReply = true,
  int? taskId = 7001,
  String? orderNumber = 'JV-261104-000123',
  int? payoutId,
  String first = 'The bag was torn at pickup.',
  List<Map<String, Object?>> supportAttachments = const [],
}) => {
  'id': id,
  'number': 'TK-00000$id',
  'category': category,
  'status': status,
  'order_id': null,
  'order_number': orderNumber,
  'task_id': taskId,
  'payout_id': payoutId,
  'last_message': first,
  'created_at': '2026-11-06T09:00:00Z',
  'updated_at': '2026-11-06T09:05:00Z',
  'can_reply': canReply,
  'messages': [
    {
      'id': 1,
      'body': first,
      'from_support': false,
      'created_at': '2026-11-06T09:00:00Z',
      'attachments': <Object?>[],
    },
    {
      'id': 2,
      'body': 'We are checking.',
      'from_support': true,
      'created_at': '2026-11-06T09:05:00Z',
      'attachments': supportAttachments,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('domain', () {
    test('a draft sends the trimmed text, with no tag added', () {
      const draft = TicketDraft(
        topic: RiderTicketTopic.task,
        taskId: 7001,
        label: 'JV-261104-000123',
        text: '  The customer address was wrong.  ',
      );
      expect(draft.problem, isNull);
      expect(draft.message, 'The customer address was wrong.');
      expect(draft.linkedTaskId, 7001);
      expect(draft.linkedPayoutId, isNull);
      expect(draft.linkedLabel, 'JV-261104-000123');
    });

    test('a link is sent only with its own topic', () {
      const task = TicketDraft(
        topic: RiderTicketTopic.task,
        taskId: 7001,
        label: 'JV-1',
        text: 'long enough text',
      );
      final moved = task.copyWith(topic: RiderTicketTopic.cash);
      expect(moved.linkedTaskId, isNull);
      expect(moved.linkedLabel, isNull);
      // Back to TASK: the link from the past task returns.
      expect(moved.copyWith(topic: RiderTicketTopic.task).linkedTaskId, 7001);

      const payout = TicketDraft(
        topic: RiderTicketTopic.payout,
        payoutId: 41,
        label: '27 Oct – 2 Nov',
      );
      expect(payout.linkedPayoutId, 41);
      expect(payout.linkedTaskId, isNull);
      expect(
        payout.copyWith(topic: RiderTicketTopic.task).linkedPayoutId,
        isNull,
      );
    });

    test('draft problems follow the server limits (10–1000 trimmed)', () {
      expect(
        const TicketDraft(
          topic: RiderTicketTopic.other,
          text: ' short    ',
        ).problem,
        TicketDraftProblem.tooShort,
      );
      expect(
        TicketDraft(
          topic: RiderTicketTopic.other,
          text: 'x' * (ticketMessageMaxLength + 1),
        ).problem,
        TicketDraftProblem.tooLong,
      );
      final longest = TicketDraft(
        topic: RiderTicketTopic.payout,
        text: '  ${'x' * ticketMessageMaxLength}  ',
      );
      expect(longest.problem, isNull);
      expect(longest.message.length, ticketMessageMaxLength);
    });

    test('topics are the rider categories', () {
      expect(RiderTicketTopic.values.map((t) => t.code), [
        'TASK',
        'PAYOUT',
        'CASH',
        'ACCOUNT',
        'OTHER',
      ]);
      expect(RiderTicketTopic.fromCode('CASH'), RiderTicketTopic.cash);
      // A customer category is not a rider topic.
      expect(RiderTicketTopic.fromCode('MISSING_ITEMS'), isNull);
    });

    test('groupFaqs starts a section whenever the category changes', () {
      const faqs = [
        Faq(id: 1, category: 'A', question: 'q1', answer: 'a'),
        Faq(id: 2, category: 'A', question: 'q2', answer: 'a'),
        Faq(id: 3, category: 'B', question: 'q3', answer: 'a'),
      ];
      final groups = groupFaqs(faqs);
      expect(groups.map((g) => g.category), ['A', 'B']);
      expect(groups.first.entries.map((f) => f.id), [1, 2]);
      expect(TicketStatus.fromWire('IN_PROGRESS'), TicketStatus.inProgress);
      expect(TicketStatus.fromWire('NEW'), TicketStatus.unknown);
    });
  });

  group('ApiSupportRepository', () {
    late CannedAdapter http;
    late ApiSupportRepository repo;

    setUp(() {
      http = CannedAdapter();
      repo = ApiSupportRepository(cannedApi(http));
    });

    test('FAQs ask for the rider app', () async {
      http.answers['/api/v1/faqs/'] = const Canned(200, [
        {'id': 1, 'category': 'Orders', 'question': 'Q', 'answer': 'A'},
      ]);
      final faqs = await repo.faqs();
      expect(faqs.single.question, 'Q');
      expect(http.requests.last.queryParameters['app'], 'rider');
    });

    test('list, detail, create and reply map the contract', () async {
      http.answers['/api/v1/support/tickets/'] = const Canned(200, {
        'count': 21,
        'next': 'http://localhost:8001/api/v1/support/tickets/?page=2',
        'previous': null,
        'results': [
          {
            'id': 7,
            'number': 'TK-000007',
            'category': 'PAYOUT',
            'status': 'RESOLVED',
            'order_id': null,
            'order_number': null,
            'task_id': null,
            'payout_id': 41,
            'last_message': 'Done',
            'created_at': '2026-11-06T09:00:00Z',
            'updated_at': '2026-11-06T10:00:00Z',
          },
        ],
      });
      final page = await repo.tickets();
      final summary = page.items.single;
      expect(summary.status, TicketStatus.resolved);
      expect(summary.topic, RiderTicketTopic.payout);
      expect(summary.payoutId, 41);
      expect(summary.taskId, isNull);
      expect(page.nextPage, 2);
      expect(page.count, 21);

      http.answers['/api/v1/support/tickets/7/'] = Canned(
        200,
        _ticketJson(
          supportAttachments: [
            {'key': 'abc', 'url': 'https://files.example/support/7/abc.webp'},
          ],
        ),
      );
      final thread = await repo.ticket(7);
      expect(thread.topic, RiderTicketTopic.task);
      expect(thread.ticket.taskId, 7001);
      expect(thread.ticket.orderNumber, 'JV-261104-000123');
      expect(thread.messages.first.body, 'The bag was torn at pickup.');
      expect(thread.messages.last.fromSupport, isTrue);
      expect(thread.messages.last.attachments, [
        Uri.parse('https://files.example/support/7/abc.webp'),
      ]);
      expect(thread.canReply, isTrue);

      // Create posts to the same list path (canned answer replaced): the
      // real category and task_id, the text without any tag.
      http.answers['/api/v1/support/tickets/'] = Canned(201, _ticketJson());
      await repo.create(
        const TicketDraft(
          topic: RiderTicketTopic.task,
          taskId: 7001,
          label: 'JV-261104-000123',
          text: '  The bag was torn at pickup.  ',
        ),
      );
      var sent = http.jsonBody('/api/v1/support/tickets/');
      expect(sent, {
        'category': 'TASK',
        'message': 'The bag was torn at pickup.',
        'task_id': 7001,
      });

      http.answers['/api/v1/support/tickets/'] = Canned(
        201,
        _ticketJson(
          category: 'PAYOUT',
          taskId: null,
          orderNumber: null,
          payoutId: 41,
        ),
      );
      final payout = await repo.create(
        const TicketDraft(
          topic: RiderTicketTopic.payout,
          payoutId: 41,
          text: 'Payout is less than expected',
        ),
      );
      sent = http.jsonBody('/api/v1/support/tickets/');
      expect(sent, {
        'category': 'PAYOUT',
        'message': 'Payout is less than expected',
        'payout_id': 41,
      });
      expect(payout.ticket.payoutId, 41);

      http.answers['/api/v1/support/tickets/'] = Canned(
        201,
        _ticketJson(category: 'CASH', taskId: null, orderNumber: null),
      );
      await repo.create(
        const TicketDraft(
          topic: RiderTicketTopic.cash,
          // A task link from the form is not sent with another topic.
          taskId: 7001,
          text: 'Deposit not recorded yet',
        ),
      );
      sent = http.jsonBody('/api/v1/support/tickets/');
      expect(sent, {'category': 'CASH', 'message': 'Deposit not recorded yet'});

      http.answers['/api/v1/support/tickets/7/messages/'] = Canned(
        201,
        _ticketJson(),
      );
      await repo.reply(7, '  thanks  ');
      expect(http.jsonBody('/api/v1/support/tickets/7/messages/'), {
        'message': 'thanks',
      });
      await repo.reply(7, 'see photo', attachmentKeys: ['k1', 'k2']);
      expect(http.jsonBody('/api/v1/support/tickets/7/messages/'), {
        'message': 'see photo',
        'attachment_keys': ['k1', 'k2'],
      });
    });

    test('a photo uploads as multipart; 413 arrives as ApiError', () async {
      const path = '/api/v1/support/tickets/7/attachments/';
      http.answers[path] = const Canned(201, {
        'key': 'abc',
        'url': 'https://files.example/support/7/abc.webp',
      });
      final photo = await repo.uploadPhoto(7, Uint8List.fromList([1, 2, 3]));
      expect(photo.key, 'abc');
      expect(photo.url.path, '/support/7/abc.webp');
      expect(http.requests.last.method, 'POST');
      expect(http.requests.last.data, isA<FormData>());
      final file = (http.requests.last.data as FormData).files.single;
      expect(file.key, 'file');
      expect(file.value.contentType.toString(), 'image/jpeg');

      http.answers[path] = const Canned(413);
      await expectLater(
        repo.uploadPhoto(7, Uint8List.fromList([1])),
        throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 413)),
      );
    });

    test('errors arrive as ApiError', () async {
      http.answers['/api/v1/support/tickets/9/messages/'] = Canned(
        400,
        errorBody('VALIDATION_ERROR', {
          'ticket': ['closed'],
        }),
      );
      await expectLater(
        repo.reply(9, 'hello'),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.validationError,
          ),
        ),
      );
    });
  });

  group('controllers', () {
    test('a new ticket validates, sends and reports failures', () async {
      final h = RiderTestHarness();
      final container = await h.container();
      const args = (
        topic: RiderTicketTopic.task,
        taskId: 600,
        payoutId: null,
        label: 'JV-9',
      );
      final notifier = container.read(
        newTicketControllerProvider(args).notifier,
      );
      final sub = container.listen(
        newTicketControllerProvider(args),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(sub.read().draft.linkedTaskId, 600);
      expect(sub.read().draft.linkedLabel, 'JV-9');
      expect(await notifier.submit(), isNull);
      expect(sub.read().showProblems, isTrue);
      expect(h.support.calls.where((c) => c.startsWith('create')), isEmpty);

      notifier.setText('Bag was torn at pickup');
      h.support.failNext = const ApiError(
        code: ApiErrorCode.rateLimited,
        statusCode: 429,
      );
      expect(await notifier.submit(), isNull);
      expect(sub.read().error?.code, ApiErrorCode.rateLimited);
      expect(sub.read().sending, isFalse);

      notifier.setText('Bag was torn at pickup!');
      expect(sub.read().error, isNull);
      final thread = await notifier.submit();
      expect(thread, isNotNull);
      expect(thread!.messages.first.body, 'Bag was torn at pickup!');
      expect(thread.topic, RiderTicketTopic.task);
      expect(thread.ticket.orderNumber, 'JV-9');
      expect(h.support.calls.last, 'create TASK task=600');

      // Another topic drops the task link.
      notifier
        ..setTopic(RiderTicketTopic.cash)
        ..setText('Deposit not recorded yet');
      await notifier.submit();
      expect(h.support.calls.last, 'create CASH');
    });

    test(
      'the thread replies, keeps errors, and a closed ticket refuses',
      () async {
        final h = RiderTestHarness();
        final container = await h.container();
        final sub = container.listen(ticketThreadProvider(1), (_, _) {});
        addTearDown(sub.close);
        final first = await container.read(ticketThreadProvider(1).future);
        expect(first.ticket.status, TicketStatus.resolved);
        expect(first.topic, RiderTicketTopic.payout);

        final notifier = container.read(ticketThreadProvider(1).notifier);
        expect(await notifier.reply('   '), isNull);
        expect(await notifier.reply('Still short by 120'), isNull);
        // A reply reopens a resolved ticket.
        expect(sub.read().value!.ticket.status, TicketStatus.open);
        expect(sub.read().value!.messages.last.body, 'Still short by 120');

        h.support.close(1);
        await notifier.reload();
        expect(sub.read().value!.canReply, isFalse);
        final error = await notifier.reply('hello again');
        expect(error?.code, ApiErrorCode.validationError);

        await expectLater(
          container.read(supportRepositoryProvider).ticket(99),
          throwsA(isA<ApiError>()),
        );
      },
    );

    test('a photo is compressed, uploaded and sent with the reply', () async {
      final h = RiderTestHarness();
      final container = await h.container();
      final sub = container.listen(ticketThreadProvider(1), (_, _) {});
      addTearDown(sub.close);
      await container.read(ticketThreadProvider(1).future);
      final notifier = container.read(ticketThreadProvider(1).notifier);

      final result = await notifier.attachPhoto(ImagePickSource.gallery);
      expect(result.problem, isNull);
      final photo = result.photo!;
      expect(h.picker.picks.last, (ImagePickSource.gallery, false));
      // The original (with EXIF) never stays on the phone.
      expect(h.picker.discarded, hasLength(1));
      expect(h.codec.calls, isNotEmpty);
      expect(h.support.calls.last, 'upload 1');

      expect(
        await notifier.reply('Photo of the bag', attachmentKeys: [photo.key]),
        isNull,
      );
      expect(h.support.calls.last, 'reply 1 ${photo.key}');
      expect(sub.read().value!.messages.last.attachments, [photo.url]);

      // Cancelled: nothing happens.
      h.picker.cancelNext = true;
      final cancelled = await notifier.attachPhoto(ImagePickSource.camera);
      expect(cancelled.photo, isNull);
      expect(cancelled.problem, isNull);

      // Not an image.
      h.codec.unreadable = true;
      final unreadable = await notifier.attachPhoto(ImagePickSource.gallery);
      expect(unreadable.problem, isA<PhotoUnreadable>());
      h.codec.unreadable = false;

      // Too large even at the last compression step.
      h.codec.result = Uint8List(kTicketPhotoMaxBytes + 1);
      final large = await notifier.attachPhoto(ImagePickSource.gallery);
      expect(large.problem, isA<PhotoTooLarge>());
      h.codec.result = null;

      // The proxy refuses the body (413): the same clear message.
      h.support.failNext = const ApiError(
        code: ApiErrorCode.unknown,
        statusCode: 413,
      );
      final refused = await notifier.attachPhoto(ImagePickSource.gallery);
      expect(refused.problem, isA<PhotoTooLarge>());

      h.support.failNext = const ApiError(code: ApiErrorCode.network);
      final offline = await notifier.attachPhoto(ImagePickSource.gallery);
      expect(
        offline.problem,
        isA<PhotoUploadFailed>().having(
          (p) => p.error.code,
          'code',
          ApiErrorCode.network,
        ),
      );
    });

    test('staging and prod use the real support API, never the fake', () async {
      for (final flavor in [Flavor.staging, Flavor.prod]) {
        final h = RiderTestHarness(flavor: flavor);
        final container = await h.container();
        expect(
          container.read(supportRepositoryProvider),
          isA<ApiSupportRepository>(),
          reason: flavor.name,
        );
      }
      final dev = await RiderTestHarness().container();
      expect(dev.read(supportRepositoryProvider), isA<FakeSupportBackend>());
    });
  });

  group('screens', () {
    testWidgets('help: FAQs, raise a ticket, the thread and a reply', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await openFromHome(tester, h, 'home-help');
      expect(find.text('Orders'), findsOneWidget);
      await tester.tap(find.text('Where do I deposit cash?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('store manager at your home store'),
        findsOneWidget,
      );

      await tester.tap(byKey('help-raise-ticket'));
      await tester.pumpAndSettle();
      // From help, nothing is linked.
      expect(byKey('ticket-linked'), findsNothing);
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();
      expect(find.text('Write at least 10 characters.'), findsOneWidget);

      await tester.tap(byKey('ticket-topic-CASH'));
      await tester.enterText(
        byKey('ticket-text'),
        'My deposit is not in the ledger.',
      );
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();
      expect(h.support.calls.last, 'ticket 2');
      expect(h.support.calls, contains('create CASH'));

      expect(byKey('ticket-messages'), findsOneWidget);
      expect(textOf(tester, 'ticket-topic'), 'Cash deposit');
      expect(find.text('My deposit is not in the ledger.'), findsOneWidget);
      expect(find.text('Jivo support'), findsOneWidget);

      await tester.enterText(byKey('ticket-reply'), 'Deposited at 10 am');
      await tester.tap(byKey('ticket-reply-send'));
      await tester.pumpAndSettle();
      expect(find.text('Deposited at 10 am'), findsOneWidget);
    });

    testWidgets('a reply carries a photo; the photo opens from the thread', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await pushFromHome(tester, h, Routes.ticket(1));
      await tester.tap(byKey('ticket-add-photo'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('ticket-photo-gallery'));
      await tester.pumpAndSettle();
      expect(byKey('ticket-photo-1'), findsOneWidget);

      // A photo needs a message.
      await tester.tap(byKey('ticket-reply-send'));
      await tester.pumpAndSettle();
      expect(
        find.text('Write a short message to send with the photo.'),
        findsOneWidget,
      );
      // Let the message go, so it doesn't cover the reply box.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.enterText(byKey('ticket-reply'), 'Screenshot of payout');
      await tester.tap(byKey('ticket-reply-send'));
      await tester.pumpAndSettle();
      expect(h.support.calls.last, startsWith('reply 1 fake'));
      expect(byKey('ticket-photo-1'), findsNothing);

      final photoButton = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            RegExp(r'^ticket-message-\d+-photo-1$').hasMatch(key.value);
      });
      await scrollTo(
        tester,
        photoButton,
        listKey: const Key('ticket-messages'),
      );
      await tester.tap(photoButton);
      await tester.pumpAndSettle();
      expect(h.urls.opened.last.host, 'files.invalid');
    });

    testWidgets('a photo that is too large says so', (tester) async {
      final h = RiderTestHarness();
      h.codec.result = Uint8List(kTicketPhotoMaxBytes + 1);
      await pushFromHome(tester, h, Routes.ticket(1));
      await tester.tap(byKey('ticket-add-photo'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('ticket-photo-camera'));
      await tester.pumpAndSettle();
      expect(
        find.text('This photo is too large. Try another photo.'),
        findsOneWidget,
      );
      expect(byKey('ticket-photo-1'), findsNothing);
    });

    testWidgets('my tickets lists the rider tickets; closed has no reply box', (
      tester,
    ) async {
      final h = RiderTestHarness();
      h.support.close(1);
      await pushFromHome(tester, h, Routes.tickets);
      expect(byKey('ticket-1'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('A payout'), findsOneWidget);
      await tester.tap(byKey('ticket-1'));
      await tester.pumpAndSettle();
      expect(byKey('ticket-closed'), findsOneWidget);
      expect(byKey('ticket-reply'), findsNothing);
      expect(byKey('ticket-add-photo'), findsNothing);
    });

    testWidgets('a past task opens the form linked to that task', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await openFromHome(tester, h, 'home-history');
      final firstRow = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            RegExp(r'^history-\d+$').hasMatch(key.value);
      });
      final rowKey =
          (tester.widget(firstRow.first).key! as ValueKey<String>).value;
      final taskId = int.parse(rowKey.split('-').last);
      await tester.tap(firstRow.first);
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        byKey('history-detail-help'),
        listKey: const Key('history-detail'),
      );
      await tester.tap(byKey('history-detail-help'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(byKey('ticket-topic-TASK')).selected,
        isTrue,
      );
      expect(textOf(tester, 'ticket-linked'), startsWith('Order J'));

      await tester.enterText(byKey('ticket-text'), 'Customer refused OTP.');
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();
      expect(h.support.calls, contains('create TASK task=$taskId'));
      expect(
        textOf(tester, 'ticket-topic'),
        startsWith('An order · Order J'),
      );
    });

    testWidgets('a payout opens the form linked to that payout', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await openFromHome(tester, h, 'home-payouts');
      final help = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            RegExp(r'^payout-\d+-help$').hasMatch(key.value);
      });
      final key = (tester.widget(help.first).key! as ValueKey<String>).value;
      final payoutId = int.parse(key.split('-')[1]);
      await tester.tap(help.first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChoiceChip>(byKey('ticket-topic-PAYOUT')).selected,
        isTrue,
      );
      expect(textOf(tester, 'ticket-linked'), startsWith('Payout '));
      await tester.enterText(byKey('ticket-text'), 'Payout is ₹120 short.');
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();
      expect(h.support.calls, contains('create PAYOUT payout=$payoutId'));
    });

    testWidgets('help shows Call support from config and a FAQ error', (
      tester,
    ) async {
      final h = RiderTestHarness();
      h.support.failNext = const ApiError(code: ApiErrorCode.network);
      await openFromHome(tester, h, 'home-help');
      expect(byKey('help-faq-error'), findsOneWidget);
      await tester.tap(byKey('help-faq-retry'));
      await tester.pumpAndSettle();
      expect(byKey('help-faq-error'), findsNothing);
      await tester.tap(byKey('help-call-support'));
      await tester.pumpAndSettle();
      expect(h.urls.opened.last, Uri(scheme: 'tel', path: '+911800123456'));
    });

    testWidgets('staging: help and My rating are on the home and open', (
      tester,
    ) async {
      final h = RiderTestHarness(flavor: Flavor.staging);
      // The screens are under test here, not the network.
      h.extraOverrides = [
        supportRepositoryProvider.overrideWithValue(h.support),
      ];
      await pumpActiveHome(tester, h);
      expect(byKey('home-earnings'), findsNothing);
      expect(byKey('home-rating'), findsOneWidget);
      await scrollTo(
        tester,
        byKey('home-help'),
        listKey: const Key('home-list'),
      );
      await tester.tap(byKey('home-help'));
      await tester.pumpAndSettle();
      expect(byKey('help-raise-ticket'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
    });
  });
}
