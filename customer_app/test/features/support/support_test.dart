import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/support/data/support_repository.dart';
import 'package:customer_app/features/support/domain/support_models.dart';
import 'package:customer_app/features/support/presentation/help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// Help & support: FAQs and tickets (`03 §2.11`, P7 lookahead on fakes).
void main() {
  group('FakeSupportRepository', () {
    test('a new ticket gets a support reply; replies append', () async {
      final repo = FakeSupportRepository(seed: false);
      final created = await repo.createTicket(
        category: TicketCategory.missingItems,
        message: '  One bottle was missing.  ',
        orderId: 5,
      );
      expect(created.ticket.status, TicketStatus.open);
      expect(created.messages.first.body, 'One bottle was missing.');
      expect(created.messages.last.fromSupport, isTrue);

      final replied = await repo.reply(created.ticket.id, 'Thanks');
      expect(replied.messages.last.body, 'Thanks');
      expect(replied.messages.last.fromSupport, isFalse);
    });

    test('order issues need an order; closed tickets refuse replies', () async {
      final repo = FakeSupportRepository(seed: false);
      expect(
        repo.createTicket(
          category: TicketCategory.damagedItems,
          message: 'Broken bottle cap',
        ),
        throwsA(isA<ApiError>()),
      );
      final t = await repo.createTicket(
        category: TicketCategory.other,
        message: 'Question about my account',
      );
      repo.close(t.ticket.id);
      expect(repo.reply(t.ticket.id, 'hello'), throwsA(isA<ApiError>()));
      expect(repo.ticket(999), throwsA(isA<ApiError>()));
    });

    test('categories offered without an order exclude order issues', () {
      final offered = TicketCategory.offered(withOrder: false);
      expect(offered.any((c) => c.needsOrder), isFalse);
      expect(
        TicketCategory.offered(withOrder: true),
        TicketCategory.values,
      );
      expect(TicketStatus.fromWire('IN_PROGRESS'), TicketStatus.inProgress);
      expect(TicketStatus.fromWire('NEW'), TicketStatus.unknown);
    });

    test('groupFaqs keeps the server order', () {
      final groups = groupFaqs(FakeSupportRepository().faqList);
      expect(groups.map((g) => g.$1), ['Orders', 'Payments & refunds']);
    });
  });

  group('screens', () {
    late FakeCommerceBackend backend;
    late FakeSupportRepository support;

    setUp(() {
      backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
      support = FakeSupportRepository();
    });

    TestApp app({bool available = true}) => TestApp(
      tokens: signedInTokens,
      commerce: backend,
      extraOverrides: [
        supportAvailableProvider.overrideWithValue(available),
        supportRepositoryProvider.overrideWithValue(support),
      ],
    );

    Finder scrollableOf(String key) => find
        .descendant(of: find.byKey(Key(key)), matching: find.byType(Scrollable))
        .first;

    Future<void> showIn(WidgetTester tester, String list, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        150,
        scrollable: scrollableOf(list),
      );
      await tester.pumpAndSettle();
    }

    Future<void> openHelp(WidgetTester tester, TestApp a) async {
      await a.pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('account-help')),
        100,
      );
      await tester.tap(find.byKey(const Key('account-help')));
      await tester.pumpAndSettle();
    }

    testWidgets('help shows FAQs; an answer expands', (tester) async {
      await openHelp(tester, app());
      expect(find.text('Frequently asked questions'), findsOneWidget);
      await showIn(tester, 'help', find.byKey(const Key('faq-3')));
      await tester.tap(find.byKey(const Key('faq-3')));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 to 7 working days'), findsOneWidget);
    });

    testWidgets('FAQ load failure offers retry', (tester) async {
      support.failNext = const ApiError(code: ApiErrorCode.network);
      await openHelp(tester, app());
      await showIn(tester, 'help', find.text('Retry'));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await showIn(tester, 'help', find.byKey(const Key('faq-1')));
      expect(find.byKey(const Key('faq-1')), findsOneWidget);
    });

    testWidgets('real-API build: only the call option, no tickets', (
      tester,
    ) async {
      await openHelp(tester, app(available: false));
      expect(find.byKey(const Key('help-tickets')), findsNothing);
      expect(find.byKey(const Key('help-new-ticket')), findsNothing);
      expect(find.text('Frequently asked questions'), findsNothing);
    });

    testWidgets('new ticket without an order: validation, then the thread', (
      tester,
    ) async {
      await openHelp(tester, app());
      await tester.tap(find.byKey(const Key('help-new-ticket')));
      await tester.pumpAndSettle();
      // Order issues need an order.
      expect(find.byKey(const Key('category-MISSING_ITEMS')), findsNothing);

      await showIn(tester, 'new-ticket', find.byKey(const Key('ticket-submit')));
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Choose an issue type.'), findsOneWidget);
      expect(find.text('Please write at least 10 characters.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('category-ACCOUNT')));
      await tester.enterText(
        find.byKey(const Key('ticket-message')),
        'I cannot change my email address',
      );
      await showIn(tester, 'new-ticket', find.byKey(const Key('ticket-submit')));
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ticket-thread')), findsOneWidget);
      expect(find.text('I cannot change my email address'), findsOneWidget);
      expect(find.text('Jivo support'), findsOneWidget);
    });

    testWidgets('get help from an order detail links the order', (
      tester,
    ) async {
      final a = app();
      await a.pump(tester);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-orders')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('order-$id')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('order-help')),
        200,
        scrollable: find.descendant(
          of: find.byKey(const Key('order-detail')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.byKey(const Key('order-help')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('category-MISSING_ITEMS')), findsOneWidget);
      await tester.tap(find.byKey(const Key('category-MISSING_ITEMS')));
      await tester.enterText(
        find.byKey(const Key('ticket-message')),
        'One bottle was missing',
      );
      await showIn(tester, 'new-ticket', find.byKey(const Key('ticket-submit')));
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();

      final page = await support.listTickets();
      final ticket = page.items.first;
      expect(ticket.orderId, id);
      expect(ticket.category, TicketCategory.missingItems);
    });

    testWidgets('ticket list → thread → reply; a closed ticket has no reply '
        'box', (tester) async {
      await openHelp(tester, app());
      await tester.tap(find.byKey(const Key('help-tickets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-1')));
      await tester.pumpAndSettle();
      expect(find.text('Resolved'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('ticket-reply')), 'Got it');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsOneWidget);
      final reply = await support.ticket(1);
      expect(reply.messages.last.body, 'Got it');

      support.close(1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-closed')), findsOneWidget);
      expect(find.byKey(const Key('ticket-reply')), findsNothing);
    });

    testWidgets('a rate-limited new ticket (429) says when to retry and '
        'keeps the form', (tester) async {
      await openHelp(tester, app());
      await tester.tap(find.byKey(const Key('help-new-ticket')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('category-ACCOUNT')));
      await tester.enterText(
        find.byKey(const Key('ticket-message')),
        'I cannot change my email address',
      );
      support.failNext = const ApiError(
        code: ApiErrorCode.rateLimited,
        statusCode: 429,
        details: {'retry_after_seconds': 120},
      );
      await showIn(tester, 'new-ticket', find.byKey(const Key('ticket-submit')));
      await tester.tap(find.byKey(const Key('ticket-submit')));
      await tester.pumpAndSettle();
      expect(
        find.text('Too many attempts. Please try again in 2 minutes.'),
        findsOneWidget,
      );
      expect(find.text('I cannot change my email address'), findsOneWidget);
      expect(find.byKey(const Key('ticket-thread')), findsNothing);
    });

    testWidgets('a reply to a resolved ticket reopens it', (tester) async {
      await openHelp(tester, app());
      await tester.tap(find.byKey(const Key('help-tickets')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-1')));
      await tester.pumpAndSettle();
      expect(find.text('Resolved'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ticket-reply')), 'Again');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('no tickets: empty state', (tester) async {
      support = FakeSupportRepository(seed: false);
      await openHelp(tester, app());
      await tester.tap(find.byKey(const Key('help-tickets')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tickets-empty')), findsOneWidget);
    });
  });
}
