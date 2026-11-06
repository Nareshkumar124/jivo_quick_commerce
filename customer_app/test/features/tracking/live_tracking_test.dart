import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/order_socket.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:customer_app/features/tracking/presentation/order_live.dart';
import 'package:customer_app/features/tracking/presentation/tracking_map.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ws.dart';
import '../../helpers/widget_harness.dart';

/// Live tracking over the order socket (T-613, `06 §4`): socket events
/// update the screen, polling only while the socket is down.
void main() {
  ({ProviderContainer container, CountingRepo repo, FakeOrderRealtime rt})
  setUp0({Duration poll = const Duration(milliseconds: 50), int start = 2}) {
    final repo = CountingRepo(FakeTrackRepository(startStep: start));
    final rt = FakeOrderRealtime();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        trackRepositoryProvider.overrideWithValue(repo),
        trackPollIntervalProvider.overrideWithValue(poll),
        orderRealtimeProvider.overrideWithValue(rt),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(trackProvider(5), (_, _) {});
    addTearDown(sub.close);
    return (container: container, repo: repo, rt: rt);
  }

  test('socket up: no polling; rider.location and order.eta apply '
      'without a fetch', () async {
    final (:container, :repo, :rt) = setUp0();
    final first = await container.read(trackProvider(5).future);
    expect(first.status, OrderStatus.outForDelivery);
    expect(rt.server.connections, hasLength(1));
    rt.server.last.authOk();
    await pumpEventQueue();
    expect(container.read(trackProvider(5).notifier).live, isTrue);
    final afterLive = repo.fetches; // one re-read when the socket is up
    expect(afterLive, 2);

    rt.server.last
      ..push('rider.location', {
        'order_id': 5,
        'lat': 28.6380,
        'lng': 77.2270,
        'heading': null,
        'recorded_at': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 1))
            .toIso8601String(),
      })
      ..push('order.eta', {
        'order_id': 5,
        'eta_at': '2030-01-01T00:00:00Z',
        'eta_minutes': 3,
      });
    await pumpEventQueue();
    final now = container.read(trackProvider(5)).value!;
    expect(now.rider!.location!.lat, 28.6380);
    expect(now.etaAt, DateTime.utc(2030));

    // No polling while live.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(repo.fetches, afterLive);
  });

  test('a new status re-reads track/; a drop resumes polling', () async {
    final (:container, :repo, :rt) = setUp0();
    await container.read(trackProvider(5).future);
    rt.server.last.authOk();
    await pumpEventQueue();
    final before = repo.fetches;

    rt.server.last.push('order.status', statusData(5, 'DELIVERED'));
    await pumpEventQueue();
    expect(repo.fetches, before + 1);

    rt.server.last.serverClose(1006);
    await pumpEventQueue();
    expect(container.read(trackProvider(5).notifier).live, isFalse);
    final dropped = repo.fetches;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(repo.fetches, greaterThan(dropped));
  });

  test('after a 4404 close the controller resumes polling', () async {
    final (:container, :repo, :rt) = setUp0();
    await container.read(trackProvider(5).future);
    rt.server.last.authOk();
    await pumpEventQueue();
    expect(container.read(trackProvider(5).notifier).live, isTrue);
    final before = repo.fetches;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(repo.fetches, before); // live: no polling

    rt.server.last.serverClose(4404);
    await pumpEventQueue();
    expect(rt.sockets[5]!.stopped, isTrue);
    expect(container.read(trackProvider(5).notifier).live, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(repo.fetches, greaterThan(before + 1));
    expect(rt.server.connections, hasLength(1)); // never reconnects
  });

  test('realtime off: polls like before', () async {
    final repo = CountingRepo(FakeTrackRepository(startStep: 2));
    final container = ProviderContainer(
      overrides: [
        trackRepositoryProvider.overrideWithValue(repo),
        trackPollIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
        orderRealtimeProvider.overrideWithValue(const DisabledOrderRealtime()),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(trackProvider(5), (_, _) {});
    addTearDown(sub.close);
    await container.read(trackProvider(5).future);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(repo.fetches, greaterThan(1));
    expect(container.read(trackProvider(5).notifier).live, isFalse);
  });

  testWidgets('the Mappls map is shown when available, the sketch otherwise', (
    tester,
  ) async {
    final repo = FakeTrackRepository(startStep: 2);
    Widget app({required bool maps}) => harness(
      const TrackingScreen(orderId: 3),
      overrides: [
        trackRepositoryProvider.overrideWithValue(repo),
        trackPollIntervalProvider.overrideWithValue(Duration.zero),
        mapsAvailabilityProvider.overrideWithValue(
          FakeMapsAvailability(available: maps),
        ),
        trackMapBuilderProvider.overrideWithValue(
          (track) => Text('map ${track.rider?.name}'),
        ),
      ],
    );
    await tester.pumpWidget(app(maps: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking-map')), findsOneWidget);
    expect(find.text('map Ravi Kumar'), findsOneWidget);
    expect(find.byKey(const Key('route-sketch')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(maps: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('route-sketch')), findsOneWidget);
  });

  testWidgets('tracking screen follows socket events', (tester) async {
    final rt = FakeOrderRealtime();
    await tester.pumpWidget(
      harness(
        const TrackingScreen(orderId: 3),
        realtime: rt,
        overrides: [
          trackRepositoryProvider.overrideWithValue(
            FakeTrackRepository(startStep: 1),
          ),
          trackPollIntervalProvider.overrideWithValue(Duration.zero),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Packing your order'), findsWidgets);
    rt.server.last
      ..authOk()
      ..push('order.status', statusData(3, 'OUT_FOR_DELIVERY'));
    await tester.pumpAndSettle();
    // The re-read brings the OTP (never sent on the socket).
    expect(find.text('4821'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

/// Counts fetches; steps through the fake's statuses.
class CountingRepo implements TrackRepository {
  CountingRepo(this.inner);

  final FakeTrackRepository inner;
  int fetches = 0;

  @override
  Future<OrderTrack> fetch(int orderId) {
    fetches++;
    return inner.fetch(orderId);
  }
}
