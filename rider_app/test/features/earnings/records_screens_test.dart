import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/earnings/domain/earnings.dart';
import 'package:rider_app/features/earnings/presentation/earnings_screen.dart';
import 'package:rider_app/features/earnings/presentation/records_providers.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

import '../../helpers/onboarding_fixtures.dart';
import '../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));
const activePhone = '+919811122231';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  Future<void> home(WidgetTester tester) async {
    await h.signedInBefore(activePhone);
    await h.pump(tester);
    expect(byKey('home-flavor'), findsOneWidget);
  }

  Future<void> open(WidgetTester tester, String menuKey) async {
    await home(tester);
    await scrollTo(tester, byKey(menuKey), listKey: const Key('home-list'));
    await tester.tap(byKey(menuKey));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(byKey(key)).data!;

  testWidgets('home lists the records, 56 dp each; not outside dev', (
    tester,
  ) async {
    await home(tester);
    for (final key in [
      'home-earnings',
      'home-cash',
      'home-history',
      'home-payouts',
      'home-profile',
    ]) {
      await scrollTo(tester, byKey(key), listKey: const Key('home-list'));
      expect(tester.getSize(byKey(key)).height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('prod flavor (even with FAKE_API): no records menu', (
    tester,
  ) async {
    h = RiderTestHarness(flavor: Flavor.prod);
    await home(tester);
    expect(byKey('home-earnings'), findsNothing);
  });

  group('earnings', () {
    testWidgets('today: every amount exactly as the server sends it', (
      tester,
    ) async {
      await open(tester, 'home-earnings');

      expect(h.records.calls, ['fetchEarnings 2026-11-02..2026-11-02']);
      // The fake's total is deliberately not the sum of what is listed.
      expect(textOf(tester, 'earnings-total'), '₹135.00');
      expect(find.text('2 orders'), findsOneWidget);
      for (final (type, amount) in [
        ('BASE', '₹60.00'),
        ('DISTANCE', '₹25.00'),
        ('TIP', '₹20.00'),
        ('INCENTIVE', '₹50.00'),
        ('PENALTY', '-₹20.00'),
      ]) {
        expect(
          find.descendant(
            of: byKey('earnings-type-$type'),
            matching: find.text(amount),
          ),
          findsOneWidget,
          reason: type,
        );
      }
      expect(
        find.descendant(
          of: byKey('earnings-order-JQ-10501'),
          matching: find.text('₹65.00'),
        ),
        findsOneWidget,
      );
      await scrollTo(
        tester,
        find.textContaining('Peak-hour bonus'),
        listKey: const Key('earnings-list'),
      );
      expect(find.textContaining('Late pickup'), findsOneWidget);
    });

    testWidgets('this week: Monday to today', (tester) async {
      h.now = DateTime.utc(2026, 11, 4, 6); // Wednesday
      await open(tester, 'home-earnings');
      await tester.tap(byKey('period-week'));
      await tester.pumpAndSettle();

      expect(h.records.calls.last, 'fetchEarnings 2026-11-02..2026-11-04');
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
      expect(find.text('31 orders'), findsOneWidget);
    });

    testWidgets('the date-range picker opens; saving selects "Choose dates"', (
      tester,
    ) async {
      await open(tester, 'home-earnings');
      await tester.tap(byKey('period-custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final chip = tester.widget<ChoiceChip>(byKey('period-custom'));
      expect(chip.selected, isTrue);
    });

    testWidgets('chosen dates: that range is fetched and labelled', (
      tester,
    ) async {
      await open(tester, 'home-earnings');
      ProviderScope.containerOf(tester.element(find.byType(EarningsScreen)))
          .read(earningsSelectionProvider.notifier)
          .custom(
            DateRange(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 10, 30)),
          );
      await tester.pumpAndSettle();

      expect(h.records.calls.last, 'fetchEarnings 2026-10-27..2026-10-30');
      expect(textOf(tester, 'earnings-range'), 'Oct 27, 2026 – Oct 30, 2026');
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
    });

    testWidgets('another period fails: its error, never the previous '
        'period\'s money', (tester) async {
      h.now = DateTime.utc(2026, 11, 4, 6); // Wednesday: week ≠ today
      await open(tester, 'home-earnings');
      expect(textOf(tester, 'earnings-total'), '₹135.00');

      h.records.failNext = const ApiError(code: ApiErrorCode.network);
      await tester.tap(byKey('period-week'));
      await tester.pumpAndSettle();

      expect(byKey('earnings-retry'), findsOneWidget);
      expect(find.text('₹135.00'), findsNothing);

      await tester.tap(byKey('earnings-retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
    });

    testWidgets('a failed load offers Retry', (tester) async {
      h.records.failNext = const ApiError(code: ApiErrorCode.network);
      await open(tester, 'home-earnings');
      expect(byKey('earnings-retry'), findsOneWidget);

      await tester.tap(byKey('earnings-retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'earnings-total'), '₹135.00');
    });

    testWidgets('payouts: period, status, reference', (tester) async {
      await open(tester, 'home-payouts');

      expect(textOf(tester, 'payout-12-status'), 'Pending');
      expect(textOf(tester, 'payout-11-status'), 'Paid');
      expect(find.text('Reference UTR45001200'), findsOneWidget);
      expect(find.text('₹3,120.00'), findsOneWidget);
    });
  });

  group('cash', () {
    testWidgets('cash in hand from the server, entries by day, no banner '
        'below the limit', (tester) async {
      await open(tester, 'home-cash');

      expect(textOf(tester, 'cash-in-hand'), '₹2,149.00');
      expect(find.text('Limit ₹5,000.00'), findsOneWidget);
      expect(byKey('cash-limit-banner'), findsNothing);
      expect(byKey('cash-entry-30'), findsOneWidget);
      expect(find.text('Cash collected · Order JQ-10501'), findsOneWidget);
      expect(find.text('-₹3,100.00'), findsOneWidget, reason: 'deposit');
      expect(byKey('cash-day-2026-11-02T00:00:00.000Z'), findsOneWidget);
    });

    testWidgets('at the limit (the server says so): "Deposit cash"', (
      tester,
    ) async {
      h.records.limitReached = true;
      await open(tester, 'home-cash');

      expect(byKey('cash-limit-banner'), findsOneWidget);
      expect(find.text('Deposit cash'), findsOneWidget);
      expect(textOf(tester, 'cash-in-hand'), '₹5,249.00');
    });

    testWidgets('load more fetches the next page', (tester) async {
      await open(tester, 'home-cash');
      await scrollTo(
        tester,
        byKey('paged-more'),
        listKey: const Key('paged-list'),
      );
      await tester.tap(byKey('paged-more'));
      await tester.pumpAndSettle();

      expect(h.records.calls, ['fetchLedger 1', 'fetchLedger 2']);
      expect(byKey('paged-more'), findsNothing, reason: 'last page');
    });
  });

  group('history', () {
    testWidgets('order, date, store to drop, distance, payout, status; '
        'paged', (tester) async {
      await open(tester, 'home-history');

      expect(find.text('Order JQ-10501'), findsOneWidget);
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
      expect(h.records.calls, ['fetchHistory 1', 'fetchHistory 2']);
    });

    testWidgets('a failed first page offers Retry', (tester) async {
      h.records.failNext = const ApiError(code: ApiErrorCode.timeout);
      await open(tester, 'home-history');
      expect(byKey('paged-retry'), findsOneWidget);

      await tester.tap(byKey('paged-retry'));
      await tester.pumpAndSettle();
      expect(find.text('Order JQ-10501'), findsOneWidget);
    });
  });

  group('profile', () {
    testWidgets('photo, name, phone, store, vehicle, KYC, rating; '
        'documents read-only', (tester) async {
      await open(tester, 'home-profile');

      expect(textOf(tester, 'profile-name'), 'Ravi Kumar');
      expect(textOf(tester, 'profile-phone'), '+91 98111 22231');
      expect(find.text('Jivo Sector 18, Noida'), findsOneWidget);
      expect(find.text('Motorbike · DL3CAB1234'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('4.8 ★'), findsOneWidget);
      expect(byKey('profile-photo'), findsOneWidget);

      await tester.tap(byKey('profile-documents'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(byKey('doc-PAN-status')).data, 'Approved');
      expect(find.text('XXXXXX234F'), findsOneWidget);
      expect(byKey('documents-continue'), findsNothing, reason: 'read-only');
      await tester.tap(byKey('doc-PAN'));
      await tester.pumpAndSettle();
      expect(byKey('capture-camera'), findsNothing);
    });
  });

  testWidgets('during a task the records are out of reach', (tester) async {
    h.tasks.seedTask(h.tasks.newTask(status: TaskStatus.pickedUp));
    await h.signedInBefore(activePhone);
    await h.pump(tester);

    expect(find.text('Deliver to the customer'), findsOneWidget);
    expect(byKey('home-earnings'), findsNothing);
  });
}
