import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  testWidgets('cash in hand from the server, entries by IST day, no banner '
      'below the limit', (tester) async {
    await openFromHome(tester, h, 'home-cash');

    expect(textOf(tester, 'cash-in-hand'), '₹2,149');
    expect(find.text('Limit ₹5,000'), findsOneWidget);
    expect(byKey('cash-limit-banner'), findsNothing);
    expect(byKey('cash-entry-30'), findsOneWidget);
    expect(find.text('Cash collected · Order JQ-10501'), findsOneWidget);
    // Entry times in IST (06:10 UTC; a narrow no-break space before AM).
    expect(find.text('11:40\u202FAM'), findsOneWidget);
    expect(find.text('-₹3,100'), findsOneWidget, reason: 'deposit');
    expect(find.text('Balance ₹0'), findsOneWidget);
    expect(byKey('cash-day-2026-11-02T00:00:00.000Z'), findsOneWidget);
    expect(byKey('cash-day-2026-11-01T00:00:00.000Z'), findsOneWidget);

    await scrollTo(
      tester,
      byKey('cash-entry-27'),
      listKey: const Key('paged-list'),
    );
    expect(
      find.descendant(
        of: byKey('cash-entry-27'),
        matching: find.text('Adjustment'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Short deposit corrected'), findsOneWidget);
  });

  testWidgets('at the limit (the server says so): "Deposit cash"', (
    tester,
  ) async {
    h.cash.limitReached = true;
    await openFromHome(tester, h, 'home-cash');

    expect(byKey('cash-limit-banner'), findsOneWidget);
    expect(find.text('Deposit cash'), findsOneWidget);
    expect(textOf(tester, 'cash-in-hand'), '₹5,249');
  });

  testWidgets('load more fetches the next page', (tester) async {
    await openFromHome(tester, h, 'home-cash');
    await scrollTo(
      tester,
      byKey('paged-more'),
      listKey: const Key('paged-list'),
    );
    await tester.tap(byKey('paged-more'));
    await tester.pumpAndSettle();

    expect(h.cash.calls, ['fetchLedger 1', 'fetchLedger 2']);
    expect(byKey('paged-more'), findsNothing, reason: 'last page');
  });

  testWidgets('a failed next page keeps the list and offers Load more '
      'again', (tester) async {
    await openFromHome(tester, h, 'home-cash');
    h.cash.failNext = const ApiError(code: ApiErrorCode.network);
    await scrollTo(
      tester,
      byKey('paged-more'),
      listKey: const Key('paged-list'),
    );
    await tester.tap(byKey('paged-more'));
    await tester.pumpAndSettle();

    expect(byKey('paged-error'), findsOneWidget);
    // The last row of page 1 is still listed.
    expect(byKey('cash-entry-21'), findsOneWidget);
    await scrollTo(
      tester,
      byKey('paged-more'),
      listKey: const Key('paged-list'),
    );
    await tester.tap(byKey('paged-more'));
    await tester.pumpAndSettle();
    expect(byKey('paged-error'), findsNothing);
    expect(byKey('paged-more'), findsNothing, reason: 'last page');
  });
}
