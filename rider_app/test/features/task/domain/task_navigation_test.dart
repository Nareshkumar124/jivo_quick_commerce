import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' as api show RiderTask;
import 'package:rider_app/features/task/data/api_task_repository.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_navigation.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

import '../../../fixtures/rider_contract_examples.dart';

Map<String, Object?> get _task =>
    currentTaskAtStoreExample['task']! as Map<String, Object?>;

RiderTask _mapped(Map<String, Object?> changes) =>
    riderTaskOf(api.RiderTask.fromJson({..._task, ...changes}));

void main() {
  group('polyline', () {
    test('decodes the Google reference example', () {
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(points, const [
        GeoPoint(38.5, -120.2),
        GeoPoint(40.7, -120.95),
        GeoPoint(43.252, -126.453),
      ]);
    });

    test('encode and decode round-trip', () {
      const route = [
        GeoPoint(28.5651, 77.3199),
        GeoPoint(28.5706, 77.3261),
        GeoPoint(28.5832, 77.3412),
      ];
      expect(decodePolyline(encodePolyline(route)), route);
    });

    test('a malformed string keeps what decoded and never throws', () {
      expect(decodePolyline(''), isEmpty);
      final good = encodePolyline(const [GeoPoint(28.5, 77.2)]);
      // Cut in the middle of the next point.
      final points = decodePolyline('${good}_p~');
      expect(points, const [GeoPoint(28.5, 77.2)]);
      expect(decodePolyline(' \n!!'), isEmpty);
    });
  });

  group('navigation from the task body (T-821)', () {
    test('before pickup: to the store, with the road route', () {
      final task = _mapped({
        'status': 'ASSIGNED',
        'navigation': navToStoreExample,
      });
      final nav = task.navigation!;
      expect(nav.leg, NavigationLeg.toStore);
      expect(nav.destination, const GeoPoint(28.4718, 77.0436));
      expect(nav.distanceM, 820);
      expect(nav.etaMinutes, 4);
      expect(nav.etaAt, DateTime.utc(2026, 11, 10, 9, 35, 0, 120));
      expect(nav.positionAt, DateTime.utc(2026, 11, 10, 9, 31));
      final route = nav.route!;
      expect(route.isRoad, isTrue);
      expect(route.distanceM, 820);
      expect(route.durationS, 190);
      expect(route.points, hasLength(3));
    });

    test('after pickup: to the customer; a straight-line estimate', () {
      final task = _mapped({
        'status': 'PICKED_UP',
        'navigation': navToCustomerExample,
      });
      final nav = task.navigation!;
      expect(nav.leg, NavigationLeg.toCustomer);
      expect(nav.destination, const GeoPoint(28.5012, 77.0688));
      expect(nav.distanceM, 2400);
      expect(nav.etaMinutes, 9);
      expect(nav.route!.isRoad, isFalse);
    });

    test('no position yet: no route, no distance', () {
      final task = _mapped({
        'status': 'ASSIGNED',
        'navigation': {
          ...navToStoreExample,
          'route': null,
          'distance_m': null,
          'eta_minutes': null,
          'eta_at': null,
          'position_at': null,
        },
      });
      final nav = task.navigation!;
      expect(nav.route, isNull);
      expect(nav.distanceM, isNull);
      expect(nav.etaMinutes, isNull);
    });

    test('null outside the riding states', () {
      final task = _mapped({'status': 'DELIVERED', 'navigation': null});
      expect(task.navigation, isNull);
    });

    test('an unknown leg (newer server) is no navigation, not a crash', () {
      final task = _mapped({
        'navigation': {...navToStoreExample, 'leg': 'TO_DEPOT'},
      });
      expect(task.navigation, isNull);
    });
  });

  test('the fake backend sends navigation per leg (dev flavor)', () {
    expect(
      FakeTaskBackend.fakeNavigation(TaskStatus.assigned)!.leg,
      NavigationLeg.toStore,
    );
    expect(
      FakeTaskBackend.fakeNavigation(TaskStatus.pickedUp)!.destination,
      FakeTaskBackend.customerLocation,
    );
    expect(FakeTaskBackend.fakeNavigation(TaskStatus.delivered), isNull);
  });
}
