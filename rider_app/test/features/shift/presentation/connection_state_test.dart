import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/domain/backoff.dart';
import 'package:rider_app/features/location/domain/location_service_client.dart';
import 'package:rider_app/features/location/domain/tracker_stats.dart';
import 'package:rider_app/features/location/domain/tracking_config.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/realtime/presentation/rider_socket_providers.dart';
import 'package:rider_app/features/shift/presentation/connection_providers.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';

import '../../../helpers/fake_permissions_service.dart';
import '../../../helpers/permission_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';
import '../../realtime/socket_fakes.dart';

const _text = OnlineNotificationText(
  title: "You're online",
  body: 'Jivo Rider is using your location for deliveries.',
  channelName: 'Online status',
  channelDescription: 'Shown while you are online.',
);

TrackerStats _upload(UploadStatus status, {String? error}) => TrackerStats(
  running: true,
  mode: TrackingMode.idle,
  intervals: const TrackingIntervals(
    sample: Duration(seconds: 30),
    upload: Duration(seconds: 30),
  ),
  buffered: 3,
  uploaded: 0,
  rejected: 0,
  droppedOverflow: 0,
  lastUploadStatus: status,
  lastError: error,
);

/// UX audit RA-10: home said "You're online. Waiting for orders" with no
/// internet, so riders waited for offers that could not arrive.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a location upload failing for lack of network: the status '
      'card and the strip say so; an accepted upload clears it', (
    tester,
  ) async {
    final h = RiderTestHarness();
    h.extraOverrides = [
      permissionsServiceProvider.overrideWithValue(
        StubbedPermissions(allGranted).service,
      ),
    ];
    await h.signedInBefore('+919811122231'); // ACTIVE
    await h.pump(tester);
    await tester.tap(find.byKey(const Key('shift-toggle')));
    await tester.pumpAndSettle();
    expect(find.text("You're online"), findsWidgets);
    expect(find.byKey(const Key('home-offline-banner')), findsNothing);

    h.location.emitStats(_upload(UploadStatus.retryLater, error: 'network'));
    await tester.pumpAndSettle();
    expect(
      find.text("You're online, but there's no internet"),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-offline-banner')), findsOneWidget);

    h.location.emitStats(_upload(UploadStatus.accepted));
    await tester.pumpAndSettle();
    expect(find.text("You're online, but there's no internet"), findsNothing);
    expect(find.byKey(const Key('home-offline-banner')), findsNothing);
  });

  test('a server error (not the network) is not "no internet"', () async {
    final h = RiderTestHarness();
    await h.signedInBefore('+919811122231');
    final c = await h.container(
      extra: [
        permissionsServiceProvider.overrideWithValue(
          StubbedPermissions(allGranted).service,
        ),
      ],
    );
    await c.read(riderAccountControllerProvider.notifier).load();
    c
      ..listen(shiftControllerProvider, (_, _) {})
      ..listen(riderConnectionLostProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(shiftControllerProvider.notifier).goOnline(_text);
    h.location.emitStats(_upload(UploadStatus.retryLater, error: 'serverError'));
    await pumpEventQueue();
    expect(c.read(riderConnectionLostProvider), isFalse);
  });

  group('the rider socket (API builds)', () {
    late RiderTestHarness h;
    late ProviderContainer c;
    late FakeConnector connector;

    setUp(() async {
      h = RiderTestHarness();
      connector = FakeConnector();
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [
          permissionsServiceProvider.overrideWithValue(
            StubbedPermissions(allGranted).service,
          ),
          riderSocketEnabledProvider.overrideWithValue(true),
          socketConnectorProvider.overrideWithValue(connector.call),
          socketBackoffFactoryProvider.overrideWithValue(
            () => Backoff(
              initial: const Duration(milliseconds: 10),
              max: const Duration(milliseconds: 10),
              jitter: 0,
            ),
          ),
          socketDownGraceProvider.overrideWithValue(
            const Duration(milliseconds: 40),
          ),
          taskPollingEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(() => c.read(riderSocketClientProvider).stop());
      await c.read(riderAccountControllerProvider.notifier).load();
      c
        ..listen(shiftControllerProvider, (_, _) {})
        ..listen(riderSocketControllerProvider, (_, _) {})
        ..listen(riderConnectionLostProvider, (_, _) {});
      await pumpEventQueue();
      await c.read(shiftControllerProvider.notifier).goOnline(_text);
      await pumpEventQueue();
    });

    test('down past the grace: lost; back up: cleared at once', () async {
      // Connected but never authenticated: not up.
      expect(c.read(riderConnectionLostProvider), isFalse, reason: 'grace');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.read(riderConnectionLostProvider), isTrue);

      connector.last.authOk(expiresAt: '2030-01-01T00:00:00Z');
      await pumpEventQueue();
      expect(c.read(riderConnectionLostProvider), isFalse);
    });

    test('a short drop inside the grace is not shown', () async {
      connector.last.authOk(expiresAt: '2030-01-01T00:00:00Z');
      await pumpEventQueue();
      connector.last.serverClose(1006);
      await pumpEventQueue();
      expect(c.read(riderConnectionLostProvider), isFalse);
    });

    test('offline: never "no internet"', () async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.read(riderConnectionLostProvider), isTrue);
      await c.read(shiftControllerProvider.notifier).goOffline();
      await pumpEventQueue();
      expect(c.read(riderConnectionLostProvider), isFalse);
    });
  });
}
