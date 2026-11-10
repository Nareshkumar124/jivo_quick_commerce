import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/notifications/data/api_inbox_repository.dart';
import 'package:rider_app/features/notifications/domain/inbox.dart';
import 'package:rider_app/features/notifications/presentation/inbox_providers.dart';
import 'package:rider_app/shared/paging.dart';

import '../../helpers/canned_http.dart';
import '../../helpers/rider_app_harness.dart';

const _list = '/api/v1/me/notifications/';

Map<String, Object?> _entry(int id, {bool read = false}) => {
  'id': id,
  'title': 'Order ready for pickup',
  'body': 'JV-261110-001203 is packed.',
  'category': 'order',
  'link': null,
  'read': read,
  'created_at': '2026-11-10T09:41:05Z',
};

InboxEntry _e(int id, {bool read = false}) => InboxEntry(
  id: id,
  title: 'Entry $id',
  body: 'Body $id',
  category: 'system',
  read: read,
  createdAt: DateTime.utc(2026, 11, 2, 6),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiInboxRepository (me_notifications_*)', () {
    late CannedAdapter http;

    setUp(() => http = CannedAdapter());

    test('the list maps entries and the next page', () async {
      http.answers[_list] = Canned(200, {
        'count': 30,
        'next': 'http://localhost:8001/api/v1/me/notifications/?page=2',
        'previous': null,
        'results': [_entry(2), _entry(1, read: true)],
        'unread_count': 1,
      });
      final page = await ApiInboxRepository(cannedApi(http)).fetchPage();
      expect(page.items.map((e) => e.id), [2, 1]);
      expect(page.items.first.read, isFalse);
      expect(page.items.first.category, 'order');
      expect(page.items.first.createdAt, DateTime.utc(2026, 11, 10, 9, 41, 5));
      expect(page.nextPage, 2);
    });

    test('mark one read, mark all read, errors as ApiError', () async {
      http.answers['/api/v1/me/notifications/2/read/'] = Canned(
        200,
        _entry(2, read: true),
      );
      http.answers['/api/v1/me/notifications/read-all/'] = const Canned(200, {
        'updated': 4,
      });
      final repo = ApiInboxRepository(cannedApi(http));
      expect((await repo.markRead(2)).read, isTrue);
      expect(await repo.markAllRead(), 4);
      expect(http.requests.last.method, 'POST');

      http.answers['/api/v1/me/notifications/9/read/'] = Canned(
        404,
        errorBody('NOT_FOUND'),
      );
      await expectLater(
        repo.markRead(9),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
        ),
      );
    });
  });

  group('InboxBadge', () {
    test('counts the unread entries of the first page', () {
      final badge = InboxBadge.of(
        Page(items: [_e(3), _e(2), _e(1, read: true)]),
      );
      expect(badge.unread, 2);
      expect(badge.label, '2');
      expect(InboxBadge.of(const Page(items: [])).isEmpty, isTrue);
    });

    test('a whole unread page with more pages is "N+"; over 9 is "9+"', () {
      expect(
        InboxBadge.of(Page(items: [_e(2), _e(1)], nextPage: 2)).label,
        '2+',
      );
      expect(
        InboxBadge.of(Page(items: [for (var i = 0; i < 12; i++) _e(i)])).label,
        '9+',
      );
    });
  });

  group('InboxController', () {
    late RiderTestHarness h;
    late ProviderContainer c;

    Future<void> start() async {
      h = RiderTestHarness();
      await h.signedInBefore('+919811122231'); // ACTIVE
      c = await h.container();
      await c.read(riderAccountControllerProvider.notifier).load();
      c
        ..listen(inboxControllerProvider, (_, _) {})
        ..listen(inboxUnreadCountProvider, (_, _) {});
      await pumpEventQueue();
    }

    test('loads the list and the badge', () async {
      await start();
      final state = c.read(inboxControllerProvider);
      expect(state.loaded, isTrue);
      expect(state.items.map((e) => e.id), [3, 2, 1]);
      expect((await c.read(inboxUnreadCountProvider.future)).unread, 2);
    });

    test('a tap marks one read; the badge follows', () async {
      await start();
      await c.read(inboxControllerProvider.notifier).markRead(3);
      expect(c.read(inboxControllerProvider).items.first.read, isTrue);
      expect(h.inbox.calls, contains('read 3'));
      expect((await c.read(inboxUnreadCountProvider.future)).unread, 1);

      // Already read: no call.
      final calls = h.inbox.calls.length;
      await c.read(inboxControllerProvider.notifier).markRead(3);
      expect(h.inbox.calls.length, calls);
    });

    test('a failed mark-read puts the entry back as unread', () async {
      await start();
      h.inbox.failNext = const ApiError(code: ApiErrorCode.network);
      await c.read(inboxControllerProvider.notifier).markRead(2);
      final entry = c
          .read(inboxControllerProvider)
          .items
          .firstWhere((e) => e.id == 2);
      expect(entry.read, isFalse);
    });

    test('mark all read clears the badge; a failure restores', () async {
      await start();
      h.inbox.failNext = const ApiError(code: ApiErrorCode.network);
      expect(
        await c.read(inboxControllerProvider.notifier).markAllRead(),
        isFalse,
      );
      expect(
        c.read(inboxControllerProvider).items.where((e) => !e.read),
        hasLength(2),
      );

      expect(
        await c.read(inboxControllerProvider.notifier).markAllRead(),
        isTrue,
      );
      expect(
        c.read(inboxControllerProvider).items.every((e) => e.read),
        isTrue,
      );
      expect((await c.read(inboxUnreadCountProvider.future)).isEmpty, isTrue);
    });
  });

  group('screens', () {
    testWidgets('home bell shows the badge and opens the inbox', (
      tester,
    ) async {
      final h = RiderTestHarness();
      await h.signedInBefore('+919811122231');
      await h.pump(tester);
      expect(find.byKey(const Key('home-appbar-inbox')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-inbox-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('home-appbar-inbox')));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byKey(const Key('inbox-3-unread')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbox-3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inbox-3-unread')), findsNothing);

      await tester.tap(find.byKey(const Key('inbox-mark-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inbox-2-unread')), findsNothing);
      expect(find.byKey(const Key('inbox-mark-all')), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('home-inbox-badge')),
          matching: find.text('2'),
        ),
        findsNothing,
      );
    });
  });
}
