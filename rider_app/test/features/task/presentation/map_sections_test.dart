import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/offers/presentation/offer_screen.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/shared/map/rider_map.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/map_fakes.dart';
import '../../../helpers/permission_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

/// User request 2026-11-23: a map on every working screen (offer, go to
/// store, pickup, go to customer, OTP, COD, return, home online), only
/// with a Maps key, small and hideable, no overflow at 320 dp and 1.3x.
void main() {
  late RiderTestHarness h;

  setUp(() {
    builtMapSpecs.clear();
    // 320 x 640 dp at DPR 2.625.
    h = RiderTestHarness()..surface = const Size(840, 1680);
    h.extraOverrides = [
      permissionsServiceProvider.overrideWithValue(
        StubbedPermissions(allGranted).service,
      ),
    ];
  });

  void scaleText(WidgetTester tester) {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// Scrolls [listKey] until [key] is built; false when it never appears.
  Future<bool> findInList(
    WidgetTester tester,
    String key, {
    String listKey = 'task-list',
  }) async {
    final scrollable = find
        .descendant(of: byKey(listKey), matching: find.byType(Scrollable))
        .first;
    for (var i = 0; i < 30; i++) {
      if (byKey(key).evaluate().isNotEmpty) {
        await tester.ensureVisible(byKey(key));
        await tester.pumpAndSettle();
        return true;
      }
      final position = tester.state<ScrollableState>(scrollable).position;
      if (position.pixels >= position.maxScrollExtent) break;
      await tester.drag(scrollable, const Offset(0, -150));
      await tester.pumpAndSettle();
    }
    return byKey(key).evaluate().isNotEmpty;
  }

  Future<void> pumpTask(
    WidgetTester tester,
    TaskStatus status, {
    required bool maps,
    bool cod = false,
  }) async {
    h
      ..maps = maps
      ..tasks.seedTask(h.tasks.newTask(cod: cod, status: status));
    await h.signedInBefore(activeRiderPhone);
    scaleText(tester);
    await h.pump(tester);
    expect(tester.takeException(), isNull);
  }

  void expectNoOverflow(WidgetTester tester) =>
      expect(tester.takeException(), isNull);

  for (final maps in [true, false]) {
    final label = maps ? 'with a Maps key' : 'without a key';

    testWidgets('go to store: navigation map $label', (tester) async {
      await pumpTask(tester, TaskStatus.assigned, maps: maps);
      expect(byKey('nav-panel'), findsOneWidget);
      expect(byKey('nav-map'), maps ? findsOneWidget : findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('pickup: small store map below the code $label', (
      tester,
    ) async {
      await pumpTask(tester, TaskStatus.atStore, maps: maps);
      expect(await findInList(tester, 'map-pickup'), maps);
      expectNoOverflow(tester);
      if (!maps) return;
      expect(
        tester.getRect(byKey('map-pickup')).top,
        greaterThan(
          tester
              .getRect(
                find.byKey(const Key('pickup-code'), skipOffstage: false),
              )
              .bottom,
        ),
      );
      expect(tester.getSize(byKey('map-pickup-view')).height, lessThan(201));
      final spec = builtMapSpecs.last;
      expect(spec.pins.single.kind, MapPinKind.store);
      expect(spec.rider, h.mapLocation.fix);
      expect(spec.showMyLocation, isTrue);
    });

    testWidgets('go to customer: navigation map $label', (tester) async {
      await pumpTask(tester, TaskStatus.pickedUp, maps: maps);
      expect(byKey('nav-map'), maps ? findsOneWidget : findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('delivery code: drop map $label', (tester) async {
      await pumpTask(tester, TaskStatus.atCustomer, maps: maps);
      expect(byKey('delivery-otp'), findsOneWidget);
      expect(await findInList(tester, 'map-otp'), maps);
      expectNoOverflow(tester);
      if (maps) {
        expect(builtMapSpecs.last.pins.single.kind, MapPinKind.customer);
      }
    });

    testWidgets('COD amount: drop map $label', (tester) async {
      await pumpTask(tester, TaskStatus.atCustomer, maps: maps, cod: true);
      await tester.enterText(
        byKey('delivery-otp'),
        FakeTaskBackend.deliveryOtp,
      );
      await tester.pump();
      await tester.tap(byKey('otp-continue'));
      await tester.pumpAndSettle();
      expect(byKey('cod-amount'), findsOneWidget);
      expect(await findInList(tester, 'map-cod'), maps);
      expectNoOverflow(tester);
    });

    testWidgets('return to store: store map, straight line $label', (
      tester,
    ) async {
      await pumpTask(tester, TaskStatus.returning, maps: maps);
      expect(find.text('Return to store'), findsOneWidget);
      expect(await findInList(tester, 'map-return'), maps);
      expectNoOverflow(tester);
      if (!maps) return;
      // No `navigation` while RETURNING: a dashed line from the rider.
      final spec = builtMapSpecs.last;
      expect(spec.pins.single.kind, MapPinKind.store);
      expect(spec.route, isEmpty);
      expect(spec.lineFromRider, isTrue);
      expect(byKey('map-return-straight'), findsOneWidget);
    });

    testWidgets('offer: store map $label', (tester) async {
      h.maps = maps;
      await h.signedInBefore(activeRiderPhone);
      scaleText(tester);
      await h.pump(tester);
      h.tasks.simulateOffer(cod: true);
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(find.byType(OfferScreen), findsOneWidget);
      final list = find
          .descendant(
            of: find.byType(OfferScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 10 && byKey('map-offer').evaluate().isEmpty; i++) {
        await tester.drag(list, const Offset(0, -150));
        await pumpFor(tester, const Duration(milliseconds: 200));
      }
      expect(byKey('map-offer'), maps ? findsOneWidget : findsNothing);
      expectNoOverflow(tester);
      // The Accept button stays on screen.
      expect(
        tester.getRect(byKey('offer-accept')).bottom,
        lessThanOrEqualTo(640.01),
      );
    });

    testWidgets('home: map only while online with no task, $label', (
      tester,
    ) async {
      h.maps = maps;
      await h.signedInBefore(activeRiderPhone);
      scaleText(tester);
      await h.pump(tester);
      expect(byKey('map-home'), findsNothing, reason: 'offline: no map');
      await tester.tap(byKey('shift-toggle'));
      await tester.pumpAndSettle();
      expect(h.shift.online, isTrue);
      expect(await findInList(tester, 'map-home', listKey: 'home-list'), maps);
      expectNoOverflow(tester);
    });
  }

  testWidgets('the rider can hide and show a map', (tester) async {
    await pumpTask(tester, TaskStatus.atStore, maps: true);
    expect(await findInList(tester, 'map-pickup'), isTrue);
    expect(byKey('map-pickup-view'), findsOneWidget);
    await tester.tap(byKey('map-pickup-toggle'));
    await tester.pumpAndSettle();
    expect(byKey('map-pickup-view'), findsNothing);
    expect(find.text('Show map'), findsOneWidget);
    await tester.tap(byKey('map-pickup-toggle'));
    await tester.pumpAndSettle();
    expect(byKey('map-pickup-view'), findsOneWidget);
  });

  testWidgets('no location permission: no blue dot, no rider position', (
    tester,
  ) async {
    h.mapLocation.allowed = false;
    await pumpTask(tester, TaskStatus.returning, maps: true);
    expect(await findInList(tester, 'map-return'), isTrue);
    final spec = builtMapSpecs.last;
    expect(spec.showMyLocation, isFalse);
    expect(spec.rider, isNull);
    expect(byKey('map-return-straight'), findsNothing);
  });

  testWidgets('a hidden map stops reading the position', (tester) async {
    await pumpTask(tester, TaskStatus.atStore, maps: true);
    expect(await findInList(tester, 'map-pickup'), isTrue);
    await tester.pump(mapPositionRefresh);
    await tester.pumpAndSettle();
    expect(h.mapLocation.reads, greaterThanOrEqualTo(2));
    await tester.tap(byKey('map-pickup-toggle'));
    await tester.pumpAndSettle();
    final before = h.mapLocation.reads;
    await tester.pump(mapPositionRefresh * 3);
    await tester.pumpAndSettle();
    expect(h.mapLocation.reads, before);
  });

  testWidgets('the screen still scrolls when a vertical drag starts on the '
      'map; a sideways drag pans the map', (tester) async {
    var mapPans = 0;
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    // The map's own recognizers, on a plain box in place of the platform
    // view (which a widget test cannot host).
    expect(
      {for (final f in riderMapGestureRecognizers) f.type},
      {PanGestureRecognizer, ScaleGestureRecognizer},
      reason: 'no eager recognizer on the map',
    );
    final pan = riderMapGestureRecognizers.firstWhere(
      (f) => f.type == PanGestureRecognizer,
    );
    final zoom = riderMapGestureRecognizers.firstWhere(
      (f) => f.type == ScaleGestureRecognizer,
    );
    final gestures = <Type, GestureRecognizerFactory>{
      PanGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
            () => pan.constructor() as PanGestureRecognizer,
            (r) => r.onUpdate = (_) => mapPans++,
          ),
      ScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => zoom.constructor() as ScaleGestureRecognizer,
            (r) => r.onUpdate = (_) => mapPans++,
          ),
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 100),
            RawGestureDetector(
              gestures: gestures,
              child: const SizedBox(
                key: Key('fake-map'),
                height: 200,
                child: ColoredBox(color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.drag(byKey('fake-map'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0), reason: 'the list scrolled');
    expect(mapPans, 0);

    final offset = scroll.offset;
    final finger = await tester.startGesture(
      tester.getCenter(byKey('fake-map')),
    );
    for (var i = 0; i < 8; i++) {
      await finger.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    await finger.up();
    await tester.pumpAndSettle();
    expect(mapPans, greaterThan(0), reason: 'the map panned');
    expect(scroll.offset, offset);
  });
}
