import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/task/data/fake_task_backend.dart';
import 'package:rider_app/features/task/domain/rider_task.dart';
import 'package:rider_app/features/task/domain/task_status.dart';

import '../../../helpers/delivery_flow_driver.dart';
import '../../../helpers/gpx_route.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  group('GPX route', () {
    final points = parseGpx(sector18ToSector21Gpx);

    test('parses every track point in order', () {
      expect(points, hasLength(7));
      expect(points.first, const GeoPoint(28.565, 77.323));
    });

    test('the file for mock-location apps is the same track', () {
      final file = File('integration_test/routes/sector18_to_sector21.gpx');
      expect(file.readAsStringSync(), sector18ToSector21Gpx);
    });

    test('the route crosses the geofences the way the driver expects', () {
      double toStore(int i) => FakeTaskBackend.distanceMetres(
        points[i],
        FakeTaskBackend.store.location,
      );
      double toCustomer(int i) => FakeTaskBackend.distanceMetres(
        points[i],
        FakeTaskBackend.customerLocation,
      );
      const radius = FakeTaskBackend.geofenceRadiusM;

      expect(toStore(RoutePoints.start), greaterThan(radius));
      expect(toStore(RoutePoints.atStore), lessThan(radius));
      expect(toCustomer(RoutePoints.nearCustomer), greaterThan(radius));
      expect(toCustomer(RoutePoints.atCustomer), lessThan(radius));
    });
  });

  group('accept → arrived store → pickup → arrived customer → deliver, '
      'riding the GPX route against the fakes', () {
    late RiderTestHarness h;

    setUp(() async {
      h = RiderTestHarness();
      await h.signedInBefore('+919811122231');
    });

    void expectBothGeofencesChecked() {
      expect(h.tasks.calls.where((c) => c == 'arrivedAtStore'), hasLength(2));
      expect(
        h.tasks.calls.where((c) => c == 'arrivedAtCustomer'),
        hasLength(2),
      );
      expect(h.tasks.task?.status, TaskStatus.delivered);
    }

    testWidgets('prepaid', (tester) async {
      await h.pump(tester);
      await driveAcceptToDeliver(tester, h);

      expectBothGeofencesChecked();
      expect(h.tasks.calls.last, 'deliver prepaid null');
    });

    testWidgets('COD: the server amount, confirmed as cash, then deliver', (
      tester,
    ) async {
      await h.pump(tester);
      await driveAcceptToDeliver(tester, h, cod: true);

      expectBothGeofencesChecked();
      expect(h.tasks.calls.last, 'deliver cash ${FakeTaskBackend.codAmount}');
    });

    testWidgets('pickup by scanning the bag QR', (tester) async {
      await h.pump(tester);
      await driveAcceptToDeliver(tester, h, pickupByQr: true);

      expectBothGeofencesChecked();
      expect(h.tasks.calls, contains('pickup'));
    });

    testWidgets('the app is killed on the way to the customer: it resumes '
        'the same step from the server and the ride finishes', (tester) async {
      await h.pump(tester);
      await driveAcceptToDeliver(
        tester,
        h,
        cod: true,
        restartAfterPickup: true,
      );

      expectBothGeofencesChecked();
      expect(h.tasks.calls.last, 'deliver cash ${FakeTaskBackend.codAmount}');
    });

    testWidgets('customer refuses: failed delivery, ride back, the store '
        'receives the items', (tester) async {
      await h.pump(tester);
      await driveAcceptToReturn(tester, h);

      // The ended task was shown once ("Items returned") and the server
      // no longer lists it.
      expect(h.tasks.task, isNull);
      expect(h.tasks.calls, contains('fail CUSTOMER_REFUSED'));
      expect(h.tasks.calls, isNot(contains(startsWith('deliver'))));
    });
  });
}
