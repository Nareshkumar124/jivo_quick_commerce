import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/app.dart';
import 'package:rider_app/app/router.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/notifications/data/fake_push_messaging.dart';
import 'package:rider_app/features/notifications/domain/inbox.dart';
import 'package:rider_app/features/notifications/domain/push_messaging.dart';
import 'package:rider_app/features/notifications/domain/rider_push.dart';
import 'package:rider_app/features/notifications/presentation/push_providers.dart';
import 'package:rider_app/features/notifications/presentation/rider_links.dart';

import '../../helpers/rider_app_harness.dart';

String _location(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(RiderApp)))
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .last
        .matchedLocation;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('routeForRiderLink (backend notification links, P7)', () {
    test('the links the backend sends', () {
      expect(
        routeForRiderLink('jivo://rider/help/tickets/42'),
        Routes.ticket(42),
      );
      expect(routeForRiderLink('jivo://rider/cash'), Routes.cash);
      expect(routeForRiderLink('jivo://rider/task'), Routes.task);
    });

    test('nearby links, and links the app does not know, are ignored', () {
      expect(routeForRiderLink('jivo://rider/help/tickets'), Routes.tickets);
      expect(routeForRiderLink('jivo://rider/help'), Routes.help);
      expect(routeForRiderLink('jivo://rider/rating'), Routes.rating);
      expect(routeForRiderLink('jivo://rider/cash/'), Routes.cash);
      for (final link in [
        null,
        '',
        'jivo://rider/help/tickets/abc',
        'jivo://rider/help/tickets/0',
        'jivo://rider/earnings',
        // The customer app's links are not the rider's.
        'jivo://support/tickets/42',
        'jivo://orders/12/detail',
        'https://jivo.in/rider/cash',
      ]) {
        expect(routeForRiderLink(link), isNull, reason: '$link');
      }
    });

    test('ticket and cash.updated pushes parse', () {
      expect(
        RiderPush.parse({'type': 'ticket', 'ticket_id': '42'}),
        isA<TicketPush>().having((p) => p.ticketId, 'ticketId', 42),
      );
      expect(RiderPush.parse({'type': 'ticket'}), isA<UnknownPush>());
      expect(RiderPush.parse({'type': 'cash.updated'}), isA<CashUpdatedPush>());
    });
  });

  group('tapped pushes open their screen', () {
    Future<(FakePushMessaging, List<String>)> setUpPush(Flavor flavor) async {
      final h = RiderTestHarness(flavor: flavor);
      final push = FakePushMessaging();
      final opened = <String>[];
      await h.signedInBefore('+919811122231');
      final c = await h.container(
        extra: [
          pushMessagingProvider.overrideWithValue(push),
          riderLinkNavigatorProvider.overrideWithValue(opened.add),
        ],
      );
      await c.read(riderAccountControllerProvider.notifier).load();
      c.listen(pushMessageHandlerProvider, (_, _) {});
      await pumpEventQueue();
      return (push, opened);
    }

    test('a support reply opens the ticket, in every flavor', () async {
      for (final flavor in Flavor.values) {
        final (push, opened) = await setUpPush(flavor);
        push.deliver(const PushMessage({'type': 'ticket', 'ticket_id': '1'}));
        await pumpEventQueue();
        expect(opened, isEmpty, reason: 'not tapped (${flavor.name})');
        push.deliver(
          const PushMessage({
            'type': 'ticket',
            'ticket_id': '1',
          }, openedApp: true),
        );
        await pumpEventQueue();
        expect(opened, [Routes.ticket(1)], reason: flavor.name);
      }
    });

    test('cash.updated opens the cash ledger when tapped', () async {
      final (push, opened) = await setUpPush(Flavor.dev);
      push.deliver(const PushMessage({'type': 'cash.updated'}));
      await pumpEventQueue();
      expect(opened, isEmpty);
      push.deliver(
        const PushMessage({'type': 'cash.updated'}, openedApp: true),
      );
      await pumpEventQueue();
      expect(opened, [Routes.cash]);
    });
  });

  group('inbox links', () {
    Future<RiderTestHarness> openInbox(
      WidgetTester tester,
      List<(int, String?)> links,
    ) async {
      final h = RiderTestHarness();
      for (final (id, link) in links) {
        h.inbox.entries.insert(
          0,
          InboxEntry(
            id: id,
            title: 'Entry $id',
            body: 'Body $id',
            category: 'support',
            read: false,
            createdAt: h.now,
            link: link,
          ),
        );
      }
      await h.signedInBefore('+919811122231');
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('home-appbar-inbox')));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('a support reply opens the ticket thread', (tester) async {
      final h = await openInbox(tester, [(9, 'jivo://rider/help/tickets/1')]);
      await tester.tap(find.byKey(const Key('inbox-9')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-messages')), findsOneWidget);
      expect(_location(tester), Routes.ticket(1));
      expect(h.inbox.calls, contains('read 9'));
      // Back returns to the inbox.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_location(tester), Routes.inbox);
    });

    testWidgets('cash opens the ledger; task without a task goes home', (
      tester,
    ) async {
      await openInbox(tester, [
        (9, 'jivo://rider/cash'),
        (10, 'jivo://rider/task'),
      ]);
      await tester.tap(find.byKey(const Key('inbox-9')));
      await tester.pumpAndSettle();
      expect(_location(tester), Routes.cash);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inbox-10')));
      await tester.pumpAndSettle();
      // No current task: the guard sends the rider home.
      expect(_location(tester), Routes.home);
    });

    testWidgets('an entry without a known link only marks it read', (
      tester,
    ) async {
      final h = await openInbox(tester, [(9, null), (10, 'jivo://nope')]);
      await tester.tap(find.byKey(const Key('inbox-9')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('inbox-10')));
      await tester.pumpAndSettle();
      expect(_location(tester), Routes.inbox);
      expect(h.inbox.calls, containsAll(['read 9', 'read 10']));
    });
  });
}
