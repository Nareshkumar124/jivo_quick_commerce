import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/domain/order_socket_event.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:customer_app/features/tracking/domain/route_geometry.dart';
import 'package:customer_app/features/tracking/presentation/order_live.dart';
import 'package:customer_app/features/tracking/presentation/tracking_map.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:customer_app/features/tracking/presentation/tracking_sheet.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/fake_ws.dart';
import '../../helpers/widget_harness.dart';

/// T-821 live tracking: route geometry, socket events (route, out of
/// order, stale), the controller, and the map sheet / no-map screens.
void main() {
  final t0 = DateTime.utc(2026, 11, 23, 10);

  OrderTrack ofd({
    TrackRider? rider,
    TrackRoute? route,
    int? distance = 1840,
  }) => OrderTrack(
    orderId: 5,
    orderNumber: 'JV-5',
    status: OrderStatus.outForDelivery,
    taskStatus: DeliveryTaskStatus.pickedUp,
    store: const TrackPoint(28.6315, 77.2167),
    destination: const TrackPoint(28.64, 77.23),
    rider:
        rider ??
        TrackRider(
          name: 'Ravi K.',
          location: const TrackPoint(28.635, 77.22),
          updatedAt: t0,
          heading: 40,
        ),
    route: route,
    distanceRemainingM: distance,
    serverTime: t0,
  );

  group('route geometry', () {
    test('decodes the Google example polyline', () {
      final points = decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, const [
        TrackPoint(38.5, -120.2),
        TrackPoint(40.7, -120.95),
        TrackPoint(43.252, -126.453),
      ]);
      expect(encodePolyline(points), r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    });

    test('a malformed tail keeps the points decoded so far', () {
      expect(decodePolyline(r'_p~iF~ps|U_ulL'), hasLength(1));
      expect(decodePolyline(''), isEmpty);
      expect(decodePolyline('  '), isEmpty);
    });

    test('headings turn the short way; bearings point east', () {
      expect(lerpHeading(350, 10, 0.5), closeTo(0, 1e-9));
      expect(lerpHeading(10, 350, 0.5), closeTo(0, 1e-9));
      expect(lerpHeading(90, 180, 0.5), closeTo(135, 1e-9));
      expect(
        bearingDegrees(const TrackPoint(0, 0), const TrackPoint(0, 1)),
        closeTo(90, 0.01),
      );
      expect(
        markerHeading(
          previous: const TrackPoint(0, 0),
          current: const TrackPoint(0, 0),
          fallback: 12,
        ),
        12,
      );
      expect(
        markerHeading(
          previous: null,
          current: const TrackPoint(0, 0),
          serverHeading: 370,
        ),
        10,
      );
    });

    test('the route ahead starts at the rider, past the points behind', () {
      const route = [
        TrackPoint(28.60, 77.20),
        TrackPoint(28.61, 77.20),
        TrackPoint(28.62, 77.20),
        TrackPoint(28.63, 77.20),
      ];
      const rider = TrackPoint(28.615, 77.2001);
      final ahead = routeAhead(route, rider);
      expect(ahead.first, rider);
      expect(ahead.skip(1), const [
        TrackPoint(28.62, 77.20),
        TrackPoint(28.63, 77.20),
      ]);
      expect(routeAhead(route, null), route);
    });
  });

  group('socket events', () {
    test('order.route parses and applies; an older route is dropped', () {
      final frame = parseWsFrame(
        '{"type":"order.route","data":{"order_id":5,"leg":"TO_CUSTOMER",'
        '"polyline":"abc","distance_m":900,"duration_s":200,'
        '"provider":"google","traffic_aware":true,'
        '"computed_at":"2026-11-23T10:00:05Z"}}',
      );
      final event = (frame as WsEvent).event as OrderRouteEvent;
      expect(event.route.leg, RouteLeg.toCustomer);
      expect(event.route.distanceM, 900);

      final track = applyOrderSocketEvent(ofd(), event)!;
      expect(track.route!.polyline, 'abc');

      final older = OrderRouteEvent(
        orderId: 5,
        route: TrackRoute(
          leg: RouteLeg.toCustomer,
          polyline: 'old',
          distanceM: 1500,
          durationS: 300,
          computedAt: t0,
        ),
      );
      expect(identical(applyOrderSocketEvent(track, older), track), isTrue);
    });

    test('an unknown leg is ignored, never an error', () {
      final frame = parseWsFrame(
        '{"type":"order.route","data":{"order_id":5,"leg":"TO_MOON",'
        '"polyline":"abc","distance_m":1,"duration_s":1,'
        '"provider":"google","traffic_aware":false,'
        '"computed_at":"2026-11-23T10:00:05Z"}}',
      );
      expect(frame, isA<WsIgnored>());
    });

    test('rider.location: newer moves the rider, sets heading and distance, '
        'clears the server stale flag; older or equal is dropped', () {
      final track = ofd(
        rider: TrackRider(
          name: 'Ravi K.',
          location: const TrackPoint(28.635, 77.22),
          updatedAt: t0,
          serverStale: true,
        ),
      );
      final newer = applyOrderSocketEvent(
        track,
        RiderLocationEvent(
          orderId: 5,
          location: const TrackPoint(28.636, 77.221),
          recordedAt: t0.add(const Duration(seconds: 5)),
          heading: 75,
          distanceRemainingM: 1700,
        ),
      )!;
      expect(newer.rider!.location, const TrackPoint(28.636, 77.221));
      expect(newer.rider!.heading, 75);
      expect(newer.rider!.serverStale, isFalse);
      expect(newer.distanceRemainingM, 1700);

      for (final at in [t0, t0.subtract(const Duration(seconds: 1))]) {
        final same = applyOrderSocketEvent(
          newer,
          RiderLocationEvent(
            orderId: 5,
            location: const TrackPoint(1, 1),
            recordedAt: at,
          ),
        );
        expect(identical(same, newer), isTrue);
      }
    });

    test('a newer fix without a heading clears the old heading, so the '
        'marker turns by the direction of travel', () {
      final track = ofd(
        rider: TrackRider(
          name: 'Ravi K.',
          location: const TrackPoint(28.635, 77.22),
          updatedAt: t0,
          heading: 75,
        ),
      );
      const next = TrackPoint(28.635, 77.23); // due east, about 1 km
      final newer = applyOrderSocketEvent(
        track,
        RiderLocationEvent(
          orderId: 5,
          location: next,
          recordedAt: t0.add(const Duration(seconds: 5)),
        ),
      )!;
      expect(newer.rider!.heading, isNull);
      final shown = markerHeading(
        previous: track.rider!.location,
        current: next,
        serverHeading: newer.rider!.heading,
        fallback: 75,
      );
      expect(shown, closeTo(90, 1));
      // copyWith without a heading keeps it.
      expect(track.rider!.copyWith(serverStale: false).heading, 75);
    });

    test('a rider.location without distance_remaining_m (older server) '
        'still parses', () {
      final frame = parseWsFrame(
        '{"type":"rider.location","data":{"order_id":5,"lat":28.6,'
        '"lng":77.2,"heading":null,"recorded_at":"2026-11-23T10:00:00Z"}}',
      );
      final event = (frame as WsEvent).event as RiderLocationEvent;
      expect(event.distanceRemainingM, isNull);
    });

    test('a track/ read never moves the rider back to an older fix', () {
      final shown = ofd(
        rider: TrackRider(
          name: 'Ravi K.',
          location: const TrackPoint(28.637, 77.225),
          updatedAt: t0.add(const Duration(seconds: 20)),
        ),
        distance: 900,
      );
      final fetched = ofd(distance: 1840);
      final merged = mergeTrackRead(shown, fetched);
      expect(merged.rider!.location, const TrackPoint(28.637, 77.225));
      expect(merged.distanceRemainingM, 900);

      final fresher = ofd(
        rider: TrackRider(
          name: 'Ravi K.',
          location: const TrackPoint(28.639, 77.229),
          updatedAt: t0.add(const Duration(seconds: 30)),
        ),
        distance: 200,
      );
      expect(mergeTrackRead(shown, fresher), fresher);
    });

    test('a fix older than 60 s (server clock) is stale', () {
      final rider = TrackRider(
        name: 'R',
        location: const TrackPoint(1, 1),
        updatedAt: t0,
      );
      expect(rider.isStaleAt(t0.add(const Duration(seconds: 60))), isFalse);
      expect(rider.isStaleAt(t0.add(const Duration(seconds: 61))), isTrue);
      expect(rider.copyWith(serverStale: true).isStaleAt(t0), isTrue);
      expect(const TrackRider(name: 'R').isStaleAt(t0), isTrue);
    });

    test('settled drops the per-ping fields only', () {
      final a = ofd();
      final b = applyOrderSocketEvent(
        a,
        RiderLocationEvent(
          orderId: 5,
          location: const TrackPoint(28.7, 77.3),
          recordedAt: t0.add(const Duration(seconds: 3)),
          distanceRemainingM: 10,
        ),
      )!;
      expect(a == b, isFalse);
      expect(a.settled, b.settled);
    });
  });

  group('TrackController (T-821)', () {
    late DateTime phoneNow;

    ({ProviderContainer container, FakeOrderRealtime rt}) setUp0({
      Duration phoneSkew = Duration.zero,
    }) {
      phoneNow = t0.add(phoneSkew);
      final rt = FakeOrderRealtime();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          trackRepositoryProvider.overrideWithValue(
            FakeTrackRepository(startStep: 2, clock: () => t0),
          ),
          trackPollIntervalProvider.overrideWithValue(Duration.zero),
          orderRealtimeProvider.overrideWithValue(rt),
          trackClockProvider.overrideWithValue(() => phoneNow),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(trackProvider(5), (_, _) {});
      addTearDown(sub.close);
      return (container: container, rt: rt);
    }

    test('rider.location and order.route over the socket update the state; '
        'an out-of-order fix is ignored', () async {
      final (:container, :rt) = setUp0();
      await container.read(trackProvider(5).future);
      rt.server.last.authOk();
      await pumpEventQueue();

      rt.server.last
        ..push('rider.location', {
          'order_id': 5,
          'lat': 28.636,
          'lng': 77.224,
          'heading': 60.0,
          'recorded_at': '2026-11-23T10:00:10Z',
          'distance_remaining_m': 1200,
        })
        ..push('rider.location', {
          'order_id': 5,
          'lat': 1.0,
          'lng': 1.0,
          'heading': 0.0,
          'recorded_at': '2026-11-23T10:00:05Z',
          'distance_remaining_m': 9999,
        })
        ..push('order.route', {
          'order_id': 5,
          'leg': 'TO_CUSTOMER',
          'polyline': encodePolyline(const [
            TrackPoint(28.636, 77.224),
            TrackPoint(28.64, 77.23),
          ]),
          'distance_m': 1200,
          'duration_s': 240,
          'provider': 'google',
          'traffic_aware': true,
          'computed_at': '2026-11-23T10:00:11Z',
        });
      await pumpEventQueue();
      final t = container.read(trackProvider(5)).value!;
      expect(t.rider!.location, const TrackPoint(28.636, 77.224));
      expect(t.rider!.heading, 60);
      expect(t.distanceRemainingM, 1200);
      expect(t.route!.durationS, 240);
      expect(t.route!.trafficAware, isTrue);
    });

    test(
      'staleness runs on the server clock, even with a wrong phone clock',
      () async {
        // The phone is 10 minutes fast: without the server offset every fix
        // would look stale.
        final (:container, rt: _) = setUp0(
          phoneSkew: const Duration(minutes: 10),
        );
        await container.read(trackProvider(5).future);
        final ctrl = container.read(trackProvider(5).notifier);
        expect(ctrl.serverNow(), t0);
        final rider = container.read(trackProvider(5)).value!.rider!;
        expect(rider.isStaleAt(ctrl.serverNow()), isFalse);

        phoneNow = phoneNow.add(const Duration(seconds: 61));
        expect(rider.isStaleAt(ctrl.serverNow()), isTrue);
      },
    );
  });

  group('screens', () {
    late DateTime now;

    List<Override> overrides({bool maps = false}) => [
      trackRepositoryProvider.overrideWithValue(
        FakeTrackRepository(startStep: 2, clock: () => t0),
      ),
      trackPollIntervalProvider.overrideWithValue(Duration.zero),
      trackClockProvider.overrideWithValue(() => now),
      supportAvailableProvider.overrideWithValue(true),
      mapsAvailabilityProvider.overrideWithValue(
        FakeMapsAvailability(available: maps),
      ),
      trackMapBuilderProvider.overrideWithValue(
        (orderId, inset) => ColoredBox(
          key: const Key('fake-map'),
          color: Colors.blueGrey,
          child: Text('map $orderId'),
        ),
      ),
    ];

    setUp(() => now = t0);

    testWidgets('no-map mode: sheet content, 8 steps from the server, '
        'distance, vehicle, help; no crash', (tester) async {
      tester.view.physicalSize = const Size(400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(const TrackingScreen(orderId: 3), overrides: overrides()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake-map')), findsNothing);
      expect(find.byKey(const Key('route-sketch')), findsOneWidget);
      expect(find.byKey(const Key('track-progress')), findsOneWidget);
      for (final step in TrackStep.values) {
        expect(find.byKey(Key('track-step-${step.wireValue}')), findsOneWidget);
      }
      // Out for delivery, picked up: 6 steps done in the fake.
      expect(find.byKey(const Key('track-step-ON_THE_WAY-done')), findsOne);
      expect(find.byKey(const Key('track-step-ARRIVING-done')), findsNothing);
      expect(find.byKey(const Key('tracking-distance')), findsOneWidget);
      expect(find.textContaining('km away'), findsOneWidget);
      expect(find.text('Your delivery partner · Scooter'), findsOneWidget);
      expect(find.byKey(const Key('tracking-help')), findsOneWidget);
      expect(find.text('Order JV-261104-000003'), findsOneWidget);
    });

    testWidgets('map mode: full map with the floating sheet', (tester) async {
      await tester.pumpWidget(
        harness(
          const TrackingScreen(orderId: 3),
          overrides: overrides(maps: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tracking-map')), findsOneWidget);
      expect(find.text('map 3'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byKey(const Key('route-sketch')), findsNothing);
      expect(find.byKey(const Key('tracking-status')), findsOneWidget);
      expect(find.byKey(const Key('tracking-map-not-live')), findsNothing);
      // The map is behind the sheet and fills the body.
      final map = tester.getSize(find.byKey(const Key('tracking-map')));
      expect(map.height, greaterThan(400));
    });

    testWidgets('a rider fix older than 60 s is never shown as live', (
      tester,
    ) async {
      final rt = FakeOrderRealtime();
      await tester.pumpWidget(
        harness(
          const TrackingScreen(orderId: 3),
          realtime: rt,
          overrides: overrides(maps: true),
        ),
      );
      await tester.pumpAndSettle();
      rt.server.last.authOk();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('tracking-fresh-live')), findsOneWidget);

      now = t0.add(const Duration(seconds: 90));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('tracking-fresh-live')), findsNothing);
      expect(
        find.byKey(const Key('tracking-fresh-rider-stale')),
        findsOneWidget,
      );
      expect(find.textContaining("Rider's location last updated"), findsOne);
      expect(find.byKey(const Key('tracking-map-not-live')), findsOneWidget);

      // A fresh fix makes it live again.
      rt.server.last.push('rider.location', {
        'order_id': 3,
        'lat': 28.636,
        'lng': 77.224,
        'heading': 60.0,
        'recorded_at': t0.add(const Duration(seconds: 89)).toIso8601String(),
        'distance_remaining_m': 400,
      });
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('tracking-fresh-live')), findsOneWidget);
      expect(find.byKey(const Key('tracking-map-not-live')), findsNothing);
      expect(find.text('400 m away'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    });

    for (final maps in [true, false]) {
      testWidgets('2.0x text on 320 x 568 (maps: $maps): no overflow', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          harness(
            const TrackingScreen(orderId: 3),
            textScaler: const TextScaler.linear(2),
            overrides: overrides(maps: maps),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Scroll the sheet to the end: still no overflow.
        await tester.drag(
          find.byKey(const Key('tracking')),
          const Offset(0, -3000),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the 8-step timeline: unknown step keys show the server '
        'label; screen-reader states', (tester) async {
      const timeline = TrackTimeline(
        current: 'PACKED',
        steps: [
          TrackStepState(key: 'CONFIRMED', label: 'x', done: true),
          TrackStepState(key: 'PACKED', label: 'x', done: true),
          TrackStepState(key: 'TELEPORTED', label: 'Teleported', done: false),
        ],
      );
      await tester.pumpWidget(
        harness(const TrackProgressTimeline(timeline: timeline)),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TrackProgressTimeline)),
      );
      expect(find.text(l10n.trackStepConfirmed), findsOneWidget);
      expect(find.text('Teleported'), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.trackStepCurrentSemantics('Packed')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.trackStepPendingSemantics('Teleported')),
        findsOneWidget,
      );
    });

    testWidgets('Help opens a new ticket with the order attached', (
      tester,
    ) async {
      final pushed = <String>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(body: TrackHelpButton(orderId: 7)),
          ),
          GoRoute(
            path: '/account/help/new',
            builder: (_, state) {
              pushed.add(state.uri.toString());
              return const Scaffold(body: Text('new ticket'));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [supportAvailableProvider.overrideWithValue(true)],
          child: MaterialApp.router(
            routerConfig: router,
            theme: JivoTheme.light(),
            locale: const Locale('en', 'IN'),
            supportedLocales: const [Locale('en', 'IN')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              JivoCoreLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('tracking-help')));
      await tester.pumpAndSettle();
      expect(pushed.single, Routes.newTicket(orderId: 7));
    });

    test('distance text: metres to 10 m under 1 km, else km', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(distanceText(l10n, 0), '10 m away');
      expect(distanceText(l10n, 456), '460 m away');
      expect(distanceText(l10n, 1840), '1.8 km away');
    });
  });
}
