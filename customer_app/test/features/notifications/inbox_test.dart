import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// The notification inbox (`/me/notifications/*`, P6).
void main() {
  Future<TestApp> openInbox(
    WidgetTester tester,
    NotificationRepository repo, {
    void Function()? onAccount,
  }) async {
    final app = TestApp(
      tokens: signedInTokens,
      notifications: repo,
      extraOverrides: [trackingAvailableProvider.overrideWithValue(false)],
    );
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    onAccount?.call();
    await tester.tap(find.byKey(const Key('account-notifications')));
    await tester.pumpAndSettle();
    return app;
  }

  testWidgets('lists notifications; a tap marks read and follows the link', (
    tester,
  ) async {
    final repo = FakeNotificationRepository();
    await openInbox(tester, repo);
    expect(find.text('Your order is on the way'), findsOneWidget);
    expect(find.text('Refund completed'), findsOneWidget);

    await tester.tap(find.text('Up to 20% off on olive oils'));
    await tester.pumpAndSettle();
    expect(repo.readCalls, [1]);
    // The collection page opened (jivo://collection/offers).
    expect(find.text('Up to 20% off on olive oils'), findsNothing);
  });

  testWidgets('empty inbox', (tester) async {
    await openInbox(tester, const UnavailableNotificationRepository());
    expect(find.byKey(const Key('inbox-empty')), findsOneWidget);
  });

  testWidgets('a failed load offers retry', (tester) async {
    final repo = FakeNotificationRepository();
    // After the account row's badge has loaded.
    await openInbox(
      tester,
      repo,
      onAccount: () =>
          repo.failNext = const ApiError(code: ApiErrorCode.network),
    );
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-list')), findsOneWidget);
  });

  test('fake pages and marks read', () async {
    final repo = FakeNotificationRepository(pageSize: 2);
    final first = await repo.list();
    expect(first.items, hasLength(2));
    expect(first.nextPage, 2);
    expect((await repo.list(page: 2)).nextPage, isNull);
    await repo.markRead(3);
    expect((await repo.list()).items.first.read, isTrue);
  });
}
