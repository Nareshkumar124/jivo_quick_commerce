import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/offers/presentation/offer_screen.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_rules.dart';

import 'gpx_route.dart';
import 'rider_app_harness.dart';

Finder _key(String key) => find.byKey(Key(key));

/// Drives one delivery against the fakes, moving the phone along a GPX
/// route: offer → accept → arrived at store (refused while too far, then
/// accepted at the store) → pickup with the bag code → arrived at customer
/// (refused short of the drop, then accepted) → delivery OTP → delivered.
/// With [cod], the order is cash on delivery: after the OTP the rider sees
/// the server's amount and must confirm "collected exactly ₹X" before
/// `deliver` is sent (rider rule 6).
///
/// Shared by the widget test (runs in CI) and the integration test (runs on
/// the USB phone), so the harness is proven before any device is used.
Future<void> driveAcceptToDeliver(
  WidgetTester tester,
  RiderTestHarness h, {
  List<GeoPoint>? route,
  bool cod = false,
}) async {
  final points = route ?? parseGpx(sector18ToSector21Gpx);
  void moveTo(int index) => h.locationReader.fix = points[index];
  Future<void> tap(String key) async {
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  h.tasks.enforceGeofence = true;
  moveTo(RoutePoints.start);

  // Dispatch offers an order; the full-screen offer ticks every second, so
  // pump for a while instead of settling.
  h.tasks.simulateOffer(cod: cod);
  await pumpFor(tester, const Duration(milliseconds: 500));
  expect(find.byType(OfferScreen), findsOneWidget);
  await tester.tap(_key('offer-accept'));
  await pumpFor(tester, const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  expect(find.text('Go to the store'), findsOneWidget);

  // Too far from the store: the server's geofence says so.
  await tap('task-arrived-store');
  expect(find.textContaining('m away'), findsOneWidget);
  moveTo(RoutePoints.atStore);
  await tap('task-arrived-store');
  expect(find.text('Pick up the order'), findsOneWidget);

  // The store packs the order; the rider types the code from the bag.
  h.tasks.markPacked();
  await tester.enterText(_key('pickup-code'), FakeTaskBackend.pickupCode);
  await tap('task-pickup');
  expect(find.text('Deliver to the customer'), findsOneWidget);

  // Ride to the customer: short of the drop first.
  moveTo(RoutePoints.nearCustomer);
  await tap('task-arrived-customer');
  expect(find.textContaining('m away'), findsOneWidget);
  moveTo(RoutePoints.atCustomer);
  await tap('task-arrived-customer');
  expect(find.text('Enter the delivery code'), findsOneWidget);

  await tester.enterText(_key('delivery-otp'), FakeTaskBackend.deliveryOtp);
  await tester.pump();
  if (cod) {
    await tap('otp-continue');
    // The amount due comes from the server; nothing is sent until the
    // rider confirms the exact cash.
    expect(
      tester.widget<Text>(_key('cod-amount')).data,
      formatRupees(FakeTaskBackend.codAmount),
    );
    await tap('cod-cash');
    expect(h.tasks.calls, isNot(contains(startsWith('deliver'))));
    await tap('cod-cash-confirm');
  } else {
    await tap('task-deliver');
  }
  expect(find.text('Delivered!'), findsOneWidget);

  await tap('task-done');
  expect(_key('home-flavor'), findsOneWidget);
}
