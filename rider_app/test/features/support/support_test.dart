import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/support/data/support_repository.dart';
import 'package:rider_app/features/support/domain/support_models.dart';
import 'package:rider_app/features/support/presentation/support_providers.dart';

import '../../helpers/canned_http.dart';
import '../../helpers/onboarding_fixtures.dart';
import '../../helpers/records_helpers.dart';
import '../../helpers/rider_app_harness.dart';

Map<String, Object?> _ticketJson({
  int id = 7,
  String status = 'OPEN',
  bool canReply = true,
  String first = '[TASK JV-1] The bag was torn at pickup.',
}) => {
  'id': id,
  'number': 'TK-00000$id',
  'category': 'OTHER',
  'status': status,
  'order_id': null,
  'order_number': null,
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
    },
    {
      'id': 2,
      'body': 'We are checking.',
      'from_support': true,
      'created_at': '2026-11-06T09:05:00Z',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('domain', () {
    test('a draft tags the message with the topic and reference', () {
      const draft = TicketDraft(
        topic: RiderTicketTopic.task,
        reference: '  JV-261104-000123 ',
        text: '  The customer address was wrong.  ',
      );
      expect(draft.problem, isNull);
      expect(
        draft.message,
        '[TASK JV-261104-000123] The customer address was wrong.',
      );
      expect(
        const TicketDraft(
          topic: RiderTicketTopic.account,
          reference: 'ignored',
          text: 'Change my bank account please',
        ).message,
        '[ACCOUNT] Change my bank account please',
      );
      // Brackets and new lines in the reference can't break the tag.
      expect(
        const TicketDraft(
          topic: RiderTicketTopic.payout,
          reference: '27 Oct]\n[2 Nov',
          text: 'Payout is less than expected',
        ).message,
        '[PAYOUT 27 Oct 2 Nov] Payout is less than expected',
      );
    });

    test('draft problems follow the server limits', () {
      expect(
        const TicketDraft(
          topic: RiderTicketTopic.other,
          text: ' short ',
        ).problem,
        TicketDraftProblem.tooShort,
      );
      expect(
        TicketDraft(
          topic: RiderTicketTopic.other,
          text: 'x' * (riderTicketTextMaxLength + 1),
        ).problem,
        TicketDraftProblem.tooLong,
      );
      expect(
        TicketDraft(
          topic: RiderTicketTopic.task,
          reference: 'r' * (ticketReferenceMaxLength + 1),
          text: 'long enough text',
        ).problem,
        TicketDraftProblem.referenceTooLong,
      );
      // The longest allowed draft still fits the server's 1000 characters.
      final longest = TicketDraft(
        topic: RiderTicketTopic.payout,
        reference: 'r' * ticketReferenceMaxLength,
        text: 'x' * riderTicketTextMaxLength,
      );
      expect(longest.problem, isNull);
      expect(longest.message.length, lessThanOrEqualTo(ticketMessageMaxLength));
    });

    test('parseRiderMessage splits the tag; unknown tags stay text', () {
      final parsed = parseRiderMessage('[TASK JV-1] Bag torn');
      expect(parsed.topic, RiderTicketTopic.task);
      expect(parsed.reference, 'JV-1');
      expect(parsed.text, 'Bag torn');
      final plain = parseRiderMessage('[NOPE] hello');
      expect(plain.topic, isNull);
      expect(plain.text, '[NOPE] hello');
      expect(parseRiderMessage('[CASH] x').reference, isNull);
      expect(RiderTicketTopic.fromCode('APP'), RiderTicketTopic.app);
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
      http.answers['/api/v1/support/tickets/'] = Canned(200, {
        'count': 21,
        'next': 'http://localhost:8001/api/v1/support/tickets/?page=2',
        'previous': null,
        'results': [
          {
            'id': 7,
            'number': 'TK-000007',
            'category': 'OTHER',
            'status': 'RESOLVED',
            'order_id': null,
            'order_number': null,
            'last_message': 'Done',
            'created_at': '2026-11-06T09:00:00Z',
            'updated_at': '2026-11-06T10:00:00Z',
          },
        ],
      });
      final page = await repo.tickets();
      expect(page.items.single.status, TicketStatus.resolved);
      expect(page.nextPage, 2);

      http.answers['/api/v1/support/tickets/7/'] = Canned(200, _ticketJson());
      final thread = await repo.ticket(7);
      expect(thread.topic, RiderTicketTopic.task);
      expect(thread.messages.last.fromSupport, isTrue);
      expect(thread.canReply, isTrue);

      // Create posts to the same list path (canned answer replaced).
      http.answers['/api/v1/support/tickets/'] = Canned(201, _ticketJson());
      await repo.create(
        const TicketDraft(
          topic: RiderTicketTopic.account,
          text: 'Please update my phone',
        ),
      );
      final sent = http.jsonBody('/api/v1/support/tickets/');
      expect(sent['category'], 'ACCOUNT');
      expect(sent['message'], '[ACCOUNT] Please update my phone');
      expect(sent.containsKey('order_id'), isFalse);

      http.answers['/api/v1/support/tickets/7/messages/'] = Canned(
        201,
        _ticketJson(),
      );
      await repo.reply(7, '  thanks  ');
      expect(
        http.jsonBody('/api/v1/support/tickets/7/messages/')['message'],
        'thanks',
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
      const args = (topic: RiderTicketTopic.task, reference: 'JV-9');
      final notifier = container.read(
        newTicketControllerProvider(args).notifier,
      );
      final sub = container.listen(
        newTicketControllerProvider(args),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(sub.read().draft.reference, 'JV-9');
      expect(await notifier.submit(), isNull);
      expect(sub.read().showProblems, isTrue);
      expect(h.support.calls.where((c) => c.startsWith('create')), isEmpty);

      notifier
        ..setTopic(RiderTicketTopic.payout)
        ..setReference('3 Nov - 9 Nov')
        ..setText('Payout missing this week');
      h.support.failNext = const ApiError(
        code: ApiErrorCode.rateLimited,
        statusCode: 429,
      );
      expect(await notifier.submit(), isNull);
      expect(sub.read().error?.code, ApiErrorCode.rateLimited);
      expect(sub.read().sending, isFalse);

      notifier.setText('Payout missing this week!');
      expect(sub.read().error, isNull);
      final thread = await notifier.submit();
      expect(thread, isNotNull);
      expect(
        thread!.messages.first.body,
        '[PAYOUT 3 Nov - 9 Nov] Payout missing this week!',
      );
      expect(thread.topic, RiderTicketTopic.payout);
      expect(h.support.calls.last, 'create OTHER');
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

    test('staging has no support repository (every call fails)', () async {
      final h = RiderTestHarness(flavor: Flavor.staging);
      final container = await h.container();
      final repo = container.read(supportRepositoryProvider);
      await expectLater(repo.faqs(), throwsA(isA<ApiError>()));
      await expectLater(repo.tickets(), throwsA(isA<ApiError>()));
      await expectLater(repo.ticket(1), throwsA(isA<ApiError>()));
      await expectLater(
        repo.create(const TicketDraft(topic: RiderTicketTopic.other)),
        throwsA(isA<ApiError>()),
      );
      await expectLater(repo.reply(1, 'x'), throwsA(isA<ApiError>()));
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
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();
      expect(find.text('Write at least 10 characters.'), findsOneWidget);

      await tester.tap(byKey('ticket-topic-TASK'));
      await tester.enterText(byKey('ticket-reference'), 'JV-261102-001240');
      await tester.enterText(
        byKey('ticket-text'),
        'Customer gave a wrong OTP twice.',
      );
      await tester.tap(byKey('ticket-send'));
      await tester.pumpAndSettle();

      expect(byKey('ticket-messages'), findsOneWidget);
      expect(textOf(tester, 'ticket-topic'), 'An order · JV-261102-001240');
      expect(find.text('Customer gave a wrong OTP twice.'), findsOneWidget);
      expect(find.text('Jivo support'), findsOneWidget);

      await tester.enterText(byKey('ticket-reply'), 'Order is with me now');
      await tester.tap(byKey('ticket-reply-send'));
      await tester.pumpAndSettle();
      expect(find.text('Order is with me now'), findsOneWidget);
    });

    testWidgets('my tickets lists the rider tickets; closed has no reply box', (
      tester,
    ) async {
      final h = RiderTestHarness();
      h.support.close(1);
      await pushFromHome(tester, h, Routes.tickets);
      expect(byKey('ticket-1'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      // The tag is not shown in the preview.
      expect(find.textContaining('[PAYOUT'), findsNothing);
      await tester.tap(byKey('ticket-1'));
      await tester.pumpAndSettle();
      expect(byKey('ticket-closed'), findsOneWidget);
      expect(byKey('ticket-reply'), findsNothing);
    });

    testWidgets('a past task opens the form with its order number', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await openFromHome(tester, h, 'home-history');
      final firstRow = find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            RegExp(r'^history-\d+$').hasMatch(key.value);
      });
      await tester.tap(firstRow.first);
      await tester.pumpAndSettle();
      await scrollTo(
        tester,
        byKey('history-detail-help'),
        listKey: const Key('history-detail'),
      );
      await tester.tap(byKey('history-detail-help'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(byKey('ticket-reference'));
      expect(field.controller!.text, isNotEmpty);
      expect(
        tester.widget<ChoiceChip>(byKey('ticket-topic-TASK')).selected,
        isTrue,
      );
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
  });
}
