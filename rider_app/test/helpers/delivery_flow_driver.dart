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
///
/// - [cod]: cash on delivery. After the OTP the rider sees the server's
///   amount and must confirm "collected exactly ₹X" before `deliver` is
///   sent (rider rule 6).
/// - [pickupByQr]: the bag's QR is scanned instead of typing the code.
/// - [restartAfterPickup]: the app is killed and started again on the way
///   to the customer; it must resume at the same step from
///   `GET /rider/tasks/current/` (rider rule 7).
///
/// Shared by the widget test (runs in CI) and the integration test (runs on
/// the USB phone), so the harness is proven before any device is used.
Future<void> driveAcceptToDeliver(
  WidgetTester tester,
  RiderTestHarness h, {
  List<GeoPoint>? route,
  bool cod = false,
  bool pickupByQr = false,
  bool restartAfterPickup = false,
}) async {
  final ride = _Ride(tester, h, route ?? parseGpx(sector18ToSector21Gpx));
  await ride.toCustomer(
    cod: cod,
    pickupByQr: pickupByQr,
    restartAfterPickup: restartAfterPickup,
  );

  await tester.enterText(_key('delivery-otp'), FakeTaskBackend.deliveryOtp);
  await tester.pump();
  if (cod) {
    await ride.tap('otp-continue');
    // The amount due comes from the server; nothing is sent until the
    // rider confirms the exact cash.
    expect(
      tester.widget<Text>(_key('cod-amount')).data,
      formatRupees(FakeTaskBackend.codAmount),
    );
    await ride.tap('cod-cash');
    expect(h.tasks.calls, isNot(contains(startsWith('deliver'))));
    await ride.tap('cod-cash-confirm');
  } else {
    await ride.tap('task-deliver');
  }
  expect(find.text('Delivered!'), findsOneWidget);

  await ride.tap('task-done');
  expect(_key('home-flavor'), findsOneWidget);
}

/// The same ride, but the customer refuses the order at the door: the rider
/// reports the failed delivery, rides the route back to the store, and the
/// task ends once the store marks the items received (04 §2.6, 08 §3).
Future<void> driveAcceptToReturn(
  WidgetTester tester,
  RiderTestHarness h, {
  List<GeoPoint>? route,
}) async {
  final ride = _Ride(tester, h, route ?? parseGpx(sector18ToSector21Gpx));
  await ride.toCustomer();

  await ride.tap('task-cant-deliver');
  await tester.tap(_key('fail-CUSTOMER_REFUSED'));
  await pumpFor(tester, const Duration(milliseconds: 300));
  await ride.tap('fail-submit');
  // Confirm "Return the order to the store?" (fail-and-return.md §1.1).
  await ride.tap('fail-confirm-yes');
  expect(find.text('Return to store'), findsOneWidget);
  expect(h.tasks.calls, isNot(contains(startsWith('deliver'))));

  // Back along the route to the store; the store staff receive the items.
  ride.moveTo(RoutePoints.nearCustomer);
  ride.moveTo(RoutePoints.atStore);
  h.tasks.markReturned();
  await ride.tap('task-check');
  expect(find.text('Items returned'), findsOneWidget);

  await ride.tap('task-done');
  expect(_key('home-flavor'), findsOneWidget);
}

/// Kills the app and starts it again with the same "server" (the fakes) and
/// the same stored session, as after a crash or Android stopping it.
Future<void> restartApp(WidgetTester tester, RiderTestHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await h.pump(tester);
}

class _Ride {
  _Ride(this.tester, this.h, this.points);

  final WidgetTester tester;
  final RiderTestHarness h;
  final List<GeoPoint> points;

  /// The phone's GPS fix moves to track point [index].
  void moveTo(int index) => h.locationReader.fix = points[index];

  Future<void> tap(String key) async {
    await tester.tap(_key(key));
    await tester.pumpAndSettle();
  }

  /// Offer → accept → store (geofence) → pickup → customer (geofence), up
  /// to the delivery code.
  Future<void> toCustomer({
    bool cod = false,
    bool pickupByQr = false,
    bool restartAfterPickup = false,
  }) async {
    h.tasks.enforceGeofence = true;
    moveTo(RoutePoints.start);

    // Dispatch offers an order; the full-screen offer ticks every second,
    // so pump for a while instead of settling.
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

    // The store packs the order; the rider scans the bag or types its code.
    h.tasks.markPacked();
    if (pickupByQr) {
      await tap('pickup-scan');
      await tap('fake-scan-${FakeTaskBackend.pickupCode}');
    } else {
      await tester.enterText(_key('pickup-code'), FakeTaskBackend.pickupCode);
      await tester.pump();
      await tap('task-pickup');
    }
    expect(find.text('Deliver to the customer'), findsOneWidget);

    if (restartAfterPickup) {
      moveTo(RoutePoints.nearCustomer - 1);
      await restartApp(tester, h);
      expect(
        find.text('Deliver to the customer'),
        findsOneWidget,
        reason: 'resumed at the same step after a restart',
      );
    }

    // Ride to the customer: short of the drop first.
    moveTo(RoutePoints.nearCustomer);
    await tap('task-arrived-customer');
    expect(find.textContaining('m away'), findsOneWidget);
    moveTo(RoutePoints.atCustomer);
    await tap('task-arrived-customer');
    expect(find.text('Enter the delivery code'), findsOneWidget);
  }
}
