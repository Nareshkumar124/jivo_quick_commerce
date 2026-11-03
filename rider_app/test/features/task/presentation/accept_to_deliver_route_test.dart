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

    test('the route crosses the geofences the way the driver expects', () {
      double toStore(int i) => FakeTaskBackend.distanceMetres(
        points[i],
        FakeTaskBackend.store.location,
      );
      const customer = GeoPoint(28.5832, 77.3412);
      double toCustomer(int i) =>
          FakeTaskBackend.distanceMetres(points[i], customer);

      expect(toStore(RoutePoints.start), greaterThan(200));
      expect(toStore(RoutePoints.atStore), lessThan(200));
      expect(toCustomer(RoutePoints.nearCustomer), greaterThan(200));
      expect(toCustomer(RoutePoints.atCustomer), lessThan(200));
    });
  });

  testWidgets('accept → arrived store → pickup → arrived customer → deliver, '
      'riding the GPX route against the fakes', (tester) async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    await h.pump(tester);

    await driveAcceptToDeliver(tester, h);

    expect(h.tasks.calls.where((c) => c == 'arrivedAtStore'), hasLength(2));
    expect(h.tasks.calls.where((c) => c == 'arrivedAtCustomer'), hasLength(2));
    expect(h.tasks.calls.last, 'deliver prepaid null');
    expect(h.tasks.task?.status, TaskStatus.delivered);
  });
}
