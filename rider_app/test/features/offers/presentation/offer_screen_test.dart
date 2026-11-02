import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/offers/presentation/offer_screen.dart';

import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// An ACTIVE rider at home; dispatch then offers an order.
  Future<int> openOffer(WidgetTester tester, {bool cod = false}) async {
    await h.signedInBefore('+919811122231');
    await h.pump(tester);
    expect(byKey('home-flavor'), findsOneWidget);
    final offer = h.tasks.simulateOffer(cod: cod);
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.byType(OfferScreen), findsOneWidget);
    return offer.id;
  }

  /// Moves the clock and lets the screen tick.
  Future<void> advance(WidgetTester tester, Duration by) async {
    h.now = h.now.add(by);
    await pumpFor(tester, const Duration(milliseconds: 1100));
  }

  testWidgets('full screen: store, locality, distance, COD amount, payout, '
      'countdown; it rings for the time left', (tester) async {
    final id = await openOffer(tester, cod: true);

    expect(find.text('New order'), findsOneWidget);
    expect(find.text('Jivo Sector 18'), findsOneWidget);
    expect(find.text('Sector 21, Noida'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('Cash on delivery: collect ₹1,249.00'), findsOneWidget);
    expect(find.text('You earn about ₹45.00'), findsOneWidget);
    expect(tester.widget<Text>(byKey('offer-countdown')).data, '30');
    expect(h.alerter.rings.single.$1, id);
    expect(h.alerter.rings.single.$2, greaterThan(const Duration(seconds: 29)));
    expect(
      tester.getSize(byKey('offer-accept')).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('the countdown follows the clock, then the offer expires', (
    tester,
  ) async {
    await openOffer(tester);
    expect(find.text('Prepaid: nothing to collect'), findsOneWidget);

    await advance(tester, const Duration(seconds: 12));
    expect(tester.widget<Text>(byKey('offer-countdown')).data, '18');

    await advance(tester, const Duration(seconds: 18));
    expect(find.text('Offer expired'), findsOneWidget);
    expect(h.alerter.stops, greaterThan(0));

    await tester.tap(byKey('offer-ok'));
    await tester.pumpAndSettle();
    expect(byKey('home-flavor'), findsOneWidget);
  });

  testWidgets('Accept opens the task: go to the store', (tester) async {
    await openOffer(tester);
    await tester.tap(byKey('offer-accept'));
    // While the route changes, the leaving offer screen never says
    // "Offer expired".
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Offer expired', skipOffstage: false), findsNothing);
    }
    await tester.pumpAndSettle();

    expect(find.text('Go to the store'), findsOneWidget);
    expect(find.text('Order JQ-10501'), findsOneWidget);
  });

  testWidgets('Reject asks for an optional reason, then back home', (
    tester,
  ) async {
    final id = await openOffer(tester);
    await tester.tap(byKey('offer-reject'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('Why are you rejecting? (optional)'), findsOneWidget);

    await tester.tap(byKey('reject-TOO_FAR'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Offer expired', skipOffstage: false), findsNothing);
    }
    await tester.pumpAndSettle();

    expect(byKey('home-flavor'), findsOneWidget);
    expect(h.tasks.calls, contains('reject $id TOO_FAR'));
  });

  testWidgets('OFFER_TAKEN: "Order taken"', (tester) async {
    await openOffer(tester);
    h.tasks.takenNext = true;
    await tester.tap(byKey('offer-accept'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.text('Order taken'), findsOneWidget);
    expect(
      find.text('Another rider accepted this order first.'),
      findsOneWidget,
    );
    await tester.tap(byKey('offer-ok'));
    await tester.pumpAndSettle();
    expect(byKey('home-flavor'), findsOneWidget);
  });

  testWidgets('offer.withdrawn: "Order cancelled"', (tester) async {
    await openOffer(tester);
    h.tasks.withdrawOffer();
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.text('Order cancelled'), findsOneWidget);
  });

  testWidgets('accept without network keeps the offer and says why', (
    tester,
  ) async {
    await openOffer(tester);
    h.tasks.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(byKey('offer-accept'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(byKey('offer-error'), findsOneWidget);
    expect(find.byType(OfferScreen), findsOneWidget);
  });

  testWidgets('CASH_LIMIT_EXCEEDED on accept: deposit cash to get COD orders', (
    tester,
  ) async {
    await openOffer(tester, cod: true);
    h.tasks.failNext = const ApiError(
      code: ApiErrorCode.cashLimitExceeded,
      statusCode: 422,
    );
    await tester.tap(byKey('offer-accept'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(
      find.text(
        'Your cash in hand has reached the limit. Deposit cash at the store '
        'to get cash orders again.',
      ),
      findsOneWidget,
    );
  });
}
