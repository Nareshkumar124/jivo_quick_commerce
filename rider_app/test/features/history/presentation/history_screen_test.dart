import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  testWidgets('order, date, store to drop, distance, payout, status; '
      'paged', (tester) async {
    await openFromHome(tester, h, 'home-history');

    expect(find.text('Order JQ-10501'), findsOneWidget);
    // Ended 11:40 IST today: shown on the same IST day (a narrow no-break
    // space before AM).
    expect(
      find.descendant(
        of: byKey('history-600'),
        matching: find.text('Nov 2, 2026 11:40 AM'),
      ),
      findsOneWidget,
    );
    expect(textOf(tester, 'history-600-status'), 'Delivered');
    expect(find.text('Jivo Sector 18 → Sector 21, Noida'), findsWidgets);
    expect(find.text('2.0 km'), findsOneWidget);
    expect(textOf(tester, 'history-598-status'), 'Returned');

    await scrollTo(
      tester,
      byKey('paged-more'),
      listKey: const Key('paged-list'),
    );
    await tester.tap(byKey('paged-more'));
    await tester.pumpAndSettle();
    expect(h.history.calls, ['fetchHistory 1', 'fetchHistory 2']);
  });

  testWidgets('a task cancelled before pickup: no distance, no payout', (
    tester,
  ) async {
    await openFromHome(tester, h, 'home-history');
    await scrollTo(
      tester,
      byKey('history-596'),
      listKey: const Key('paged-list'),
    );

    expect(textOf(tester, 'history-596-status'), 'Cancelled');
    final tile = byKey('history-596');
    expect(
      find.descendant(of: tile, matching: find.textContaining('km')),
      findsNothing,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('₹')),
      findsNothing,
    );
  });

  testWidgets('a failed first page offers Retry', (tester) async {
    h.history.failNext = const ApiError(code: ApiErrorCode.timeout);
    await openFromHome(tester, h, 'home-history');
    expect(byKey('paged-retry'), findsOneWidget);

    await tester.tap(byKey('paged-retry'));
    await tester.pumpAndSettle();
    expect(find.text('Order JQ-10501'), findsOneWidget);
  });

  testWidgets('a past task opens its details: times, items, cash collected '
      'and pay lines', (tester) async {
    await openFromHome(tester, h, 'home-history');
    await tester.tap(byKey('history-600'));
    await tester.pumpAndSettle();

    expect(byKey('history-detail'), findsOneWidget);
    expect(h.history.calls.last, 'fetchDetail 600');
    expect(textOf(tester, 'history-detail-status'), 'Delivered');
    expect(textOf(tester, 'history-detail-cod'), 'Collected ₹349');
    expect(textOf(tester, 'history-detail-earned'), '₹40');
    expect(find.text('2 × Jivo Canola Oil · 1 L'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
  });

  testWidgets('details that fail to load offer a retry', (tester) async {
    await openFromHome(tester, h, 'home-history');
    h.history.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(byKey('history-600'));
    await tester.pumpAndSettle();
    expect(byKey('history-detail-error'), findsOneWidget);

    await tester.tap(byKey('history-detail-retry'));
    await tester.pumpAndSettle();
    expect(byKey('history-detail'), findsOneWidget);
  });
}
