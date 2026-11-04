import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/earnings/domain/earnings.dart';
import 'package:rider_app/features/earnings/presentation/earnings_providers.dart';
import 'package:rider_app/features/earnings/presentation/earnings_screen.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  group('earnings', () {
    testWidgets('today: every amount exactly as the server sends it', (
      tester,
    ) async {
      await openFromHome(tester, h, 'home-earnings');

      expect(h.earnings.calls, ['fetchEarnings 2026-11-02..2026-11-02']);
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
      // Completed 06:10 UTC: shown in IST (intl puts a narrow no-break
      // space before AM).
      expect(find.text('Nov 2, 2026 11:40\u202FAM'), findsOneWidget);
      await scrollTo(
        tester,
        find.textContaining('Peak-hour bonus'),
        listKey: const Key('earnings-list'),
      );
      expect(find.textContaining('Late pickup'), findsOneWidget);
    });

    testWidgets('this week: Monday to today', (tester) async {
      h.now = DateTime.utc(2026, 11, 4, 6); // Wednesday
      await openFromHome(tester, h, 'home-earnings');
      await tester.tap(byKey('period-week'));
      await tester.pumpAndSettle();

      expect(h.earnings.calls.last, 'fetchEarnings 2026-11-02..2026-11-04');
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
      expect(find.text('31 orders'), findsOneWidget);
    });

    testWidgets('the date-range picker opens; saving selects "Choose dates"', (
      tester,
    ) async {
      await openFromHome(tester, h, 'home-earnings');
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
      await openFromHome(tester, h, 'home-earnings');
      ProviderScope.containerOf(tester.element(find.byType(EarningsScreen)))
          .read(earningsSelectionProvider.notifier)
          .custom(
            DateRange(DateTime.utc(2026, 10, 27), DateTime.utc(2026, 10, 30)),
          );
      await tester.pumpAndSettle();

      expect(h.earnings.calls.last, 'fetchEarnings 2026-10-27..2026-10-30');
      expect(textOf(tester, 'earnings-range'), 'Oct 27, 2026 – Oct 30, 2026');
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
    });

    testWidgets('another period fails: its error, never the previous '
        'period\'s money', (tester) async {
      h.now = DateTime.utc(2026, 11, 4, 6); // Wednesday: week ≠ today
      await openFromHome(tester, h, 'home-earnings');
      expect(textOf(tester, 'earnings-total'), '₹135.00');

      h.earnings.failNext = const ApiError(code: ApiErrorCode.network);
      await tester.tap(byKey('period-week'));
      await tester.pumpAndSettle();

      expect(byKey('earnings-retry'), findsOneWidget);
      expect(find.text('₹135.00'), findsNothing);

      await tester.tap(byKey('earnings-retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'earnings-total'), '₹1,842.50');
    });

    testWidgets('a failed load offers Retry', (tester) async {
      h.earnings.failNext = const ApiError(code: ApiErrorCode.network);
      await openFromHome(tester, h, 'home-earnings');
      expect(byKey('earnings-retry'), findsOneWidget);

      await tester.tap(byKey('earnings-retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'earnings-total'), '₹135.00');
    });
  });

  group('payouts', () {
    testWidgets('period, status, reference and the Indian paid date', (
      tester,
    ) async {
      await openFromHome(tester, h, 'home-payouts');

      expect(textOf(tester, 'payout-12-status'), 'Pending');
      expect(textOf(tester, 'payout-11-status'), 'Paid');
      expect(find.text('Reference UTR45001200'), findsOneWidget);
      expect(find.text('₹3,120.00'), findsOneWidget);
      // Paid at 19:00 UTC on 26 Oct = 00:30 IST on 27 Oct.
      expect(
        find.descendant(
          of: byKey('payout-11'),
          matching: find.text('Paid on Oct 27, 2026'),
        ),
        findsOneWidget,
      );
      expect(find.text('Paid on Oct 26, 2026'), findsNothing);
    });

    testWidgets('opened from the earnings screen too; paged', (tester) async {
      await openFromHome(tester, h, 'home-earnings');
      await tester.tap(byKey('earnings-payouts'));
      await tester.pumpAndSettle();
      expect(byKey('payout-12'), findsOneWidget);

      await scrollTo(
        tester,
        byKey('paged-more'),
        listKey: const Key('paged-list'),
      );
      await tester.tap(byKey('paged-more'));
      await tester.pumpAndSettle();
      expect(h.earnings.calls.where((c) => c.startsWith('fetchPayouts')), [
        'fetchPayouts 1',
        'fetchPayouts 2',
      ]);
      expect(byKey('paged-more'), findsNothing, reason: 'last page');
    });
  });
}
