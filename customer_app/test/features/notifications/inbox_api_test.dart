import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/notifications/presentation/inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';

/// The inbox endpoints (`/me/notifications/*`, `06 §2.2`, P6), paging,
/// mark read / mark all read and the unread badge.
void main() {
  Map<String, Object?> entry(int id, {bool read = false, String? link}) => {
    'id': id,
    'title': 'Title $id',
    'body': 'Body $id',
    'category': 'ORDER',
    'link': link,
    'read': read,
    'created_at': '2026-11-10T09:4$id:00Z',
  };

  group('ApiNotificationRepository', () {
    test('list maps entries and pages; only jivo:// links are kept', () async {
      final http = FakeHttp(
        (_) => (
          200,
          {
            'count': 3,
            'next': 'http://x/api/v1/me/notifications/?page=2',
            'previous': null,
            'results': [
              entry(1, link: 'jivo://orders/1203'),
              entry(2, read: true, link: 'https://evil.example/'),
            ],
          },
        ),
      );
      final page = await ApiNotificationRepository(http.api()).list();
      expect(http.requests.single.path, '/api/v1/me/notifications/');
      expect(http.requests.single.queryParameters['page'], 1);
      expect(page.nextPage, 2);
      expect(page.items.first.link, Uri.parse('jivo://orders/1203'));
      expect(page.items.first.read, isFalse);
      expect(page.items.last.link, isNull);
      expect(page.items.last.read, isTrue);
    });

    test('mark one read, mark all read', () async {
      final http = FakeHttp(
        (r) => r.path.endsWith('read-all/')
            ? (200, {'updated': 4})
            : (200, entry(7, read: true)),
      );
      final repo = ApiNotificationRepository(http.api());
      await repo.markRead(7);
      expect(http.requests.last.path, '/api/v1/me/notifications/7/read/');
      expect(http.requests.last.method, 'POST');
      expect(await repo.markAllRead(), 4);
      expect(http.requests.last.path, '/api/v1/me/notifications/read-all/');
    });

    test("another user's id is NOT_FOUND", () async {
      final http = FakeHttp(
        (_) => (
          404,
          {
            'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
          },
        ),
      );
      await expectLater(
        ApiNotificationRepository(http.api()).markRead(99),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
        ),
      );
    });
  });

  group('InboxController', () {
    test('pages, marks read, marks all read; the badge follows', () async {
      final repo = FakeNotificationRepository(pageSize: 2);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(inboxProvider, (_, _) {});
      addTearDown(sub.close);
      final badge = container.listen(inboxUnreadProvider, (_, _) {});
      addTearDown(badge.close);

      var state = await container.read(inboxProvider.future);
      expect(state.items, hasLength(2));
      expect(state.hasMore, isTrue);
      expect(await container.read(inboxUnreadProvider.future), 1);

      await container.read(inboxProvider.notifier).loadMore();
      state = container.read(inboxProvider).value!;
      expect(state.items.map((n) => n.id), [3, 2, 1]);
      expect(state.hasMore, isFalse);

      await container.read(inboxProvider.notifier).markRead(3);
      expect(repo.readCalls, [3]);
      expect(await container.read(inboxUnreadProvider.future), 0);

      await container.read(inboxProvider.notifier).markAllRead();
      state = container.read(inboxProvider).value!;
      expect(state.items.every((n) => n.read), isTrue);
      expect(state.hasUnread, isFalse);
    });

    test('a failed next page keeps the list and offers retry', () async {
      final repo = FakeNotificationRepository(pageSize: 2);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(inboxProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(inboxProvider.future);
      repo.failNext = const ApiError(code: ApiErrorCode.network);
      await container.read(inboxProvider.notifier).loadMore();
      final state = container.read(inboxProvider).value!;
      expect(state.items, hasLength(2));
      expect(state.loadMoreError, isA<ApiError>());
      await container.read(inboxProvider.notifier).loadMore();
      expect(container.read(inboxProvider).value!.items, hasLength(3));
    });

    test('the badge is 0 when the inbox fails; labels cap at 9+', () async {
      final repo = FakeNotificationRepository()
        ..failNext = const ApiError(code: ApiErrorCode.network);
      final container = ProviderContainer(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(inboxUnreadProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(inboxUnreadProvider.future), 0);
      expect(unreadBadgeLabel(3), '3');
      expect(unreadBadgeLabel(12), '9+');
    });
  });

  testWidgets('account row badge; mark all read clears it', (tester) async {
    final repo = FakeNotificationRepository();
    final app = TestApp(
      tokens: signedInTokens,
      notifications: repo,
      extraOverrides: [trackingAvailableProvider.overrideWithValue(false)],
    );
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-unread-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('inbox-unread-badge')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('account-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox-mark-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-mark-all')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-unread-badge')), findsNothing);
  });

  testWidgets('mark all read failing shows a message', (tester) async {
    final repo = FakeNotificationRepository();
    await tester.pumpWidget(
      harness(
        const InboxScreen(),
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
      ),
    );
    await tester.pumpAndSettle();
    repo.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(find.byKey(const Key('inbox-mark-all')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('inbox-mark-all')), findsOneWidget);
  });
}
