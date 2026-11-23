import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_navigation.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/navigation_panel.dart';
import 'package:rider_app/l10n/app_localizations.dart';
import 'package:rider_app/shared/map/rider_map.dart';

import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

final _now = DateTime.utc(2026, 11, 10, 9, 32);

TaskNavigation _nav({
  NavigationLeg leg = NavigationLeg.toStore,
  bool road = true,
  bool withRoute = true,
  int? metres = 1250,
  int? minutes = 6,
  DateTime? positionAt,
}) => TaskNavigation(
  leg: leg,
  destination: const GeoPoint(28.5706, 77.3261),
  route: withRoute
      ? NavigationRoute(
          polyline: encodePolyline(const [
            GeoPoint(28.5651, 77.3199),
            GeoPoint(28.5706, 77.3261),
          ]),
          distanceM: metres ?? 0,
          durationS: (minutes ?? 0) * 60,
          isRoad: road,
        )
      : null,
  distanceM: metres,
  etaMinutes: minutes,
  etaAt: DateTime.utc(2026, 11, 10, 9, 38),
  positionAt: positionAt ?? _now.subtract(const Duration(seconds: 20)),
);

RiderTask _task(TaskNavigation? navigation, {TaskStatus? status}) =>
    FakeTaskBackend(delay: Duration.zero)
        .newTask(status: status)
        .copyWith(navigation: navigation, clearNavigation: navigation == null);

Future<void> _pumpPanel(
  WidgetTester tester,
  RiderTask task, {
  bool maps = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        mapsAvailableProvider.overrideWith((ref) async => maps),
        taskMapBuilderProvider.overrideWithValue(
          (navigation, destination) => Text(
            'map ${navigation.leg.wireValue} '
            '${navigation.route?.points.length ?? 0} points',
            key: const Key('stub-map'),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(children: [NavigationPanel(task: task)]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group(
    'map spec from `navigation` (camera follow, user request 2026-11-23)',
    () {
      test('the camera follows a new route and a new leg', () {
        final a = navigationMapSpec(_nav());
        final b = navigationMapSpec(_nav(metres: 900));
        expect(a.followKey, b.followKey, reason: 'same route: no refit');
        final rerouted = navigationMapSpec(
          TaskNavigation(
            leg: NavigationLeg.toStore,
            destination: const GeoPoint(28.5706, 77.3261),
            route: NavigationRoute(
              polyline: encodePolyline(const [
                GeoPoint(28.5600, 77.3100),
                GeoPoint(28.5706, 77.3261),
              ]),
              distanceM: 2000,
              durationS: 600,
              isRoad: true,
            ),
          ),
        );
        expect(rerouted.followKey, isNot(a.followKey));
        final toCustomer = navigationMapSpec(
          _nav(leg: NavigationLeg.toCustomer),
        );
        expect(toCustomer.followKey, isNot(a.followKey));
        expect(toCustomer.pins.single.kind, MapPinKind.customer);
        expect(a.pins.single.kind, MapPinKind.store);
        expect(a.route, hasLength(2));
      });

      test('a straight-line estimate is labelled; no route draws from the '
          'rider', () {
        expect(navigationMapSpec(_nav(road: false)).showsStraightLine, isTrue);
        expect(navigationMapSpec(_nav()).showsStraightLine, isFalse);
        final noRoute = navigationMapSpec(_nav(withRoute: false));
        expect(noRoute.showsStraightLine, isFalse, reason: 'no rider yet');
        expect(
          noRoute
              .withRider(
                const MapRiderFix(permitted: true, at: GeoPoint(28.56, 77.31)),
              )
              .showsStraightLine,
          isTrue,
        );
      });
    },
  );

  group('navigation card from `navigation`', () {
    testWidgets('to the store: leg, ETA, distance and arrival time', (
      tester,
    ) async {
      await _pumpPanel(tester, _task(_nav()));
      expect(find.text('To the store'), findsOneWidget);
      expect(find.text('6 min'), findsOneWidget);
      expect(find.text('1.3 km'), findsOneWidget);
      // 09:38 UTC is 3:08 PM IST.
      final etaAt = tester.widget<Text>(byKey('nav-eta-at')).data!;
      expect(etaAt, startsWith('Reach by 3:08'));
      expect(etaAt, endsWith('PM'));
      expect(byKey('nav-straight-line'), findsNothing);
      expect(byKey('nav-stale'), findsNothing);
    });

    testWidgets('to the customer: metres under 1 km; straight-line label', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        _task(
          _nav(leg: NavigationLeg.toCustomer, road: false, metres: 850),
          status: TaskStatus.pickedUp,
        ),
      );
      expect(find.text('To the customer'), findsOneWidget);
      expect(find.text('850 m'), findsOneWidget);
      expect(find.text('Straight-line estimate'), findsOneWidget);
    });

    testWidgets('null navigation shows nothing', (tester) async {
      await _pumpPanel(tester, _task(null));
      expect(byKey('nav-panel'), findsNothing);
    });

    testWidgets('no position yet: waiting text, no numbers', (tester) async {
      await _pumpPanel(
        tester,
        _task(_nav(withRoute: false, metres: null, minutes: null)),
      );
      expect(byKey('nav-waiting'), findsOneWidget);
      expect(byKey('nav-eta'), findsNothing);
      expect(byKey('nav-distance'), findsNothing);
    });

    testWidgets('an old server position says to check GPS and network', (
      tester,
    ) async {
      await _pumpPanel(
        tester,
        _task(_nav(positionAt: _now.subtract(const Duration(minutes: 3)))),
      );
      expect(
        find.text('Location not updated for 3 min. Check GPS and network.'),
        findsOneWidget,
      );
    });

    testWidgets('ETA 0: "You\'re here"', (tester) async {
      await _pumpPanel(tester, _task(_nav(metres: 0, minutes: 0)));
      expect(byKey('nav-arrived'), findsOneWidget);
      expect(byKey('nav-eta-at'), findsNothing);
    });
  });

  group('map', () {
    testWidgets('no Maps key: the card alone (no-map fallback)', (
      tester,
    ) async {
      await _pumpPanel(tester, _task(_nav()));
      expect(byKey('nav-map'), findsNothing);
      expect(byKey('nav-eta'), findsOneWidget);
    });

    testWidgets('with a key: the map gets the decoded route, then the card', (
      tester,
    ) async {
      await _pumpPanel(tester, _task(_nav()), maps: true);
      expect(byKey('nav-map'), findsOneWidget);
      expect(find.text('map TO_STORE 2 points'), findsOneWidget);
      expect(byKey('nav-eta'), findsOneWidget);
      // Small screens: the map stays within a quarter of the height.
      expect(tester.getSize(byKey('nav-map')).height, lessThanOrEqualTo(240));
    });
  });

  group('on the task screens (fake backend)', () {
    late RiderTestHarness h;
    setUp(() => h = RiderTestHarness());

    Future<void> resume(WidgetTester tester, TaskStatus status) async {
      h.tasks.seedTask(h.tasks.newTask(status: status));
      await h.signedInBefore('+919811122231');
      await h.pump(tester);
    }

    testWidgets('go to the store: the card above the store', (tester) async {
      await resume(tester, TaskStatus.assigned);
      expect(find.text('To the store'), findsOneWidget);
      expect(find.text('4 min'), findsOneWidget);
      expect(find.text('1.1 km'), findsOneWidget);
      expect(byKey('nav-map'), findsNothing, reason: 'no key in tests');
    });

    testWidgets('go to the customer: card, customer, call and navigate', (
      tester,
    ) async {
      await resume(tester, TaskStatus.pickedUp);
      expect(find.text('To the customer'), findsOneWidget);
      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('Flat 302, Tower B, Sector 21, Noida'), findsOneWidget);

      await tester.tap(byKey('navigate-customer'));
      await tester.pumpAndSettle();
      final opened = h.urls.opened.single;
      expect(opened.scheme, 'google.navigation');
      expect(opened.toString(), contains('28.5832,77.3412'));

      await tester.tap(byKey('call-customer'));
      await tester.pumpAndSettle();
      expect(h.urls.opened.last, Uri(scheme: 'tel', path: '+919876512345'));
    });

    testWidgets('no maps app: falls back to geo:, then the browser', (
      tester,
    ) async {
      await resume(tester, TaskStatus.assigned);
      h.urls.result = false;
      await tester.tap(byKey('navigate-store'));
      await tester.pumpAndSettle();
      expect(h.urls.opened.map((u) => u.scheme), [
        'google.navigation',
        'geo',
        'https',
      ]);
      expect(
        find.text(
          'No maps app found. Install Google Maps or another maps app.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('action guard: a double tap on Arrived sends one call', (
      tester,
    ) async {
      await resume(tester, TaskStatus.assigned);
      final hold = h.locationReader.hold = Completer<void>();
      await tester.tap(byKey('task-arrived-store'));
      await tester.pump();
      await tester.tap(byKey('task-arrived-store'), warnIfMissed: false);
      await tester.pump();
      hold.complete();
      await tester.pumpAndSettle();

      expect(h.locationReader.reads, 1);
      expect(
        h.tasks.calls.where((c) => c.startsWith('arrivedAtStore')),
        hasLength(1),
      );
      expect(find.text('Pick up the order'), findsOneWidget);
    });
  });
}
