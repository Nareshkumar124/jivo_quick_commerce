import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_fixtures.dart';
import 'rider_app_harness.dart';

/// A phone the fake auth backend reports as an ACTIVE rider.
const activeRiderPhone = '+919811122231';

Finder byKey(String key) => find.byKey(Key(key));

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(byKey(key)).data!;

/// Starts the app signed in as an ACTIVE rider, on home.
Future<void> pumpActiveHome(WidgetTester tester, RiderTestHarness h) async {
  await h.signedInBefore(activeRiderPhone);
  await h.pump(tester);
  expect(byKey('home-flavor'), findsOneWidget);
}

/// Opens one of the rider's records from the home menu ([menuKey], e.g.
/// `home-cash`).
Future<void> openFromHome(
  WidgetTester tester,
  RiderTestHarness h,
  String menuKey,
) async {
  await pumpActiveHome(tester, h);
  await scrollTo(tester, byKey(menuKey), listKey: const Key('home-list'));
  await tester.tap(byKey(menuKey));
  await tester.pumpAndSettle();
}
