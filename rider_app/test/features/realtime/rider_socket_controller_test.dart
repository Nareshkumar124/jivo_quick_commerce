import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/domain/backoff.dart';
import 'package:rider_app/features/location/domain/location_service_client.dart';
import 'package:rider_app/features/offers/presentation/offer_controller.dart';
import 'package:rider_app/features/permissions/presentation/permissions_gate_controller.dart';
import 'package:rider_app/features/realtime/data/rider_socket_client.dart';
import 'package:rider_app/features/realtime/presentation/rider_socket_providers.dart';
import 'package:rider_app/features/shift/presentation/home_providers.dart';
import 'package:rider_app/features/shift/presentation/shift_controller.dart';
import 'package:rider_app/features/task/domain/task_status.dart';
import 'package:rider_app/features/task/presentation/task_flow_controller.dart';
import 'package:rider_app/features/task/presentation/task_providers.dart';

import '../../helpers/fake_permissions_service.dart';
import '../../helpers/permission_fixtures.dart';
import '../../helpers/rider_app_harness.dart';
import 'socket_fakes.dart';

const _text = OnlineNotificationText(
  title: "You're online",
  body: 'Jivo Rider is using your location for deliveries.',
  channelName: 'Online status',
  channelDescription: 'Shown while you are online.',
);

/// The rider socket in the app (T-614): runs while an ACTIVE rider is
/// online, feeds the offer, task, cash and home providers, and pauses the
/// offer polling while it is up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RiderTestHarness h;
  late ProviderContainer c;
  late FakeConnector connector;

  OfferState offer() => c.read(offerControllerProvider);
  RiderSocketStatus socket() => c.read(riderSocketControllerProvider);

  Future<void> start({bool poll = false}) async {
    h = RiderTestHarness();
    connector = FakeConnector();
    await h.signedInBefore('+919811122231'); // ACTIVE
    c = await h.container(
      extra: [
        permissionsServiceProvider.overrideWithValue(
          StubbedPermissions(allGranted).service,
        ),
        // An API build: the socket runs and is the offer event source.
        riderSocketEnabledProvider.overrideWithValue(true),
        socketConnectorProvider.overrideWithValue(connector.call),
        socketBackoffFactoryProvider.overrideWithValue(
          () => Backoff(
            initial: const Duration(milliseconds: 10),
            max: const Duration(milliseconds: 10),
            jitter: 0,
          ),
        ),
        offerEventSourceProvider.overrideWith(
          (ref) => ref.watch(socketOfferEventsProvider),
        ),
        offerPollingEnabledProvider.overrideWithValue(poll),
        offerPollIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
        taskPollingEnabledProvider.overrideWithValue(false),
      ],
    );
    // Close the socket so no reconnect timer outlives the test.
    addTearDown(() => c.read(riderSocketClientProvider).stop());
    await c.read(riderAccountControllerProvider.notifier).load();
    c
      ..listen(shiftControllerProvider, (_, _) {})
      ..listen(offerControllerProvider, (_, _) {})
      ..listen(taskFlowControllerProvider, (_, _) {})
      ..listen(riderSocketControllerProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(shiftControllerProvider.notifier).sync();
    await c.read(taskFlowControllerProvider.notifier).load();
  }

  Future<void> goOnlineAndConnect() async {
    expect(
      await c.read(shiftControllerProvider.notifier).goOnline(_text),
      isTrue,
    );
    await pumpEventQueue();
    connector.last.authOk(expiresAt: '2030-01-01T00:00:00Z');
    await pumpEventQueue();
    expect(socket(), RiderSocketStatus.connected);
  }

  test('offline: no socket; online: connects with the JWT first', () async {
    await start();
    expect(connector.uris, isEmpty);
    expect(socket(), RiderSocketStatus.disconnected);

    await goOnlineAndConnect();
    expect(connector.uris.single.path, '/ws/v1/rider/');
    expect(connector.uris.single.scheme, 'ws');
    expect(connector.last.sent.first['type'], 'auth');
    expect(c.read(riderSocketConnectedProvider), isTrue);
  });

  test('going offline closes the socket', () async {
    await start();
    await goOnlineAndConnect();
    expect(await c.read(shiftControllerProvider.notifier).goOffline(), isTrue);
    await pumpEventQueue();
    expect(connector.last.closedByApp, isTrue);
    expect(socket(), RiderSocketStatus.disconnected);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(connector.sockets, hasLength(1), reason: 'no reconnect offline');
  });

  test('offer.new opens the offer; offer.withdrawn ends it', () async {
    await start();
    await goOnlineAndConnect();
    final expires = h.now.add(const Duration(seconds: 30)).toIso8601String();
    connector.last.receive(offerNewMessage(expiresAt: expires));
    await pumpEventQueue();
    expect(offer().phase, OfferPhase.showing);
    expect(offer().offer?.id, 9001);

    connector.last.receive({
      'type': 'offer.withdrawn',
      'data': {'offer_id': 9001, 'task_id': 7001, 'reason': 'ORDER_CANCELLED'},
    });
    await pumpEventQueue();
    expect(offer().phase, OfferPhase.withdrawn);
    expect(h.offerAlerts.dismissed, greaterThan(0));
  });

  test('offer.expired ends the offer too', () async {
    await start();
    await goOnlineAndConnect();
    final expires = h.now.add(const Duration(seconds: 30)).toIso8601String();
    connector.last
      ..receive(offerNewMessage(id: 9002, expiresAt: expires))
      ..receive({
        'type': 'offer.expired',
        'data': {'offer_id': 9002},
      });
    await pumpEventQueue();
    expect(
      offer().phase,
      OfferPhase.expired,
      reason: '"Offer expired", not "Order cancelled"',
    );
  });

  test('offer.withdrawn TAKEN shows "Order taken"', () async {
    await start();
    await goOnlineAndConnect();
    final expires = h.now.add(const Duration(seconds: 30)).toIso8601String();
    connector.last
      ..receive(offerNewMessage(id: 9003, expiresAt: expires))
      ..receive({
        'type': 'offer.withdrawn',
        'data': {'offer_id': 9003, 'reason': 'TAKEN'},
      });
    await pumpEventQueue();
    expect(offer().phase, OfferPhase.taken);
  });

  test('the offer poll pauses while the socket is up and resumes when it '
      'drops', () async {
    await start(poll: true);
    await goOnlineAndConnect();
    int polls() =>
        h.tasks.calls.where((call) => call == 'fetchCurrentOffer').length;
    final connected = polls();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(polls(), connected, reason: 'no polling while connected');

    // Long enough backoff that the socket stays down during the check.
    connector.failNext = 100;
    connector.last.serverClose(1006);
    await pumpEventQueue();
    expect(c.read(riderSocketConnectedProvider), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(polls(), greaterThan(connected + 1), reason: 'polling resumed');
  });

  test('an ended session stops the socket', () async {
    await start();
    await goOnlineAndConnect();
    await h.session.signOut();
    await pumpEventQueue();
    expect(connector.last.closedByApp, isTrue);
    expect(socket(), RiderSocketStatus.disconnected);
    expect(c.read(riderSocketClientProvider).isRunning, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(connector.sockets, hasLength(1), reason: 'no reconnect');
  });

  test('task.updated re-reads the current task and home', () async {
    await start();
    h.tasks.seedTask(h.tasks.newTask(status: TaskStatus.assigned));
    await goOnlineAndConnect();
    await pumpEventQueue();
    final before = h.tasks.calls
        .where((call) => call == 'fetchCurrentTask')
        .length;
    connector.last.receive({
      'type': 'task.updated',
      'data': {'task_id': 1, 'change': 'ORDER_PACKED'},
    });
    await pumpEventQueue();
    expect(
      h.tasks.calls.where((call) => call == 'fetchCurrentTask').length,
      before + 1,
    );
    expect(
      c.read(taskFlowControllerProvider).task?.status,
      TaskStatus.assigned,
    );
  });

  test('cash.updated refreshes the home cash summary', () async {
    await start();
    await goOnlineAndConnect();
    c.listen(todaySummaryProvider, (_, _) {});
    await pumpEventQueue();
    final before = h.today.calls;
    connector.last.receive({
      'type': 'cash.updated',
      'data': <String, Object?>{},
    });
    await pumpEventQueue();
    expect(h.today.calls, greaterThan(before));
  });

  test(
    'a (re)connect re-reads the offer and task; a drop reconnects',
    () async {
      await start();
      await goOnlineAndConnect();
      expect(h.tasks.calls, contains('fetchCurrentOffer'));
      final offers = h.tasks.calls
          .where((x) => x == 'fetchCurrentOffer')
          .length;

      connector.last.serverClose(1006);
      await pumpEventQueue();
      expect(socket(), RiderSocketStatus.disconnected);
      expect(c.read(riderSocketConnectedProvider), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await pumpEventQueue();
      expect(connector.sockets, hasLength(2));
      connector.last.authOk(expiresAt: '2030-01-01T00:00:00Z');
      await pumpEventQueue();
      expect(socket(), RiderSocketStatus.connected);
      expect(
        h.tasks.calls.where((x) => x == 'fetchCurrentOffer').length,
        offers + 1,
      );
    },
  );

  test('riderSocketUri: ws for http, wss for https, never a token', () {
    expect(
      riderSocketUri(Uri.parse('http://localhost:8001')).toString(),
      'ws://localhost:8001/ws/v1/rider/',
    );
    expect(
      riderSocketUri(Uri.parse('https://jqc.jivo.in')).toString(),
      'wss://jqc.jivo.in/ws/v1/rider/',
    );
  });
}
