import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/order_socket.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/presentation/order_live.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/delivery_cards.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/widget_harness.dart';

/// Live tracking (Phase 6 lookahead) on fake track data.
void main() {
  group('FakeTrackRepository', () {
    test('confirmed → packing → riding → delivered', () async {
      final repo = FakeTrackRepository(ridePings: 2);
      final steps = [for (var i = 0; i < 5; i++) await repo.fetch(7)];
      expect(steps.map((t) => t.status), [
        OrderStatus.accepted,
        OrderStatus.packing,
        OrderStatus.outForDelivery,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ]);
      expect(steps[0].rider, isNull);
      expect(steps[2].deliveryOtp, '4821');
      expect(steps[2].progress, closeTo(0, 0.01));
      expect(steps[3].progress, closeTo(0.5, 0.01));
      expect(steps[4].deliveryOtp, isNull);
      expect(steps[4].progress, 1);
      expect(steps[4].etaAt, isNull);
    });
  });

  group('TrackController', () {
    test('a failed poll keeps the last data', () async {
      final repo = FakeTrackRepository();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          trackRepositoryProvider.overrideWithValue(repo),
          orderRealtimeProvider.overrideWithValue(
            const DisabledOrderRealtime(),
          ),
          trackPollIntervalProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(trackProvider(1), (_, _) {});
      addTearDown(sub.close);
      final first = await container.read(trackProvider(1).future);
      expect(first.status, OrderStatus.accepted);

      repo.failNext = const ApiError(code: ApiErrorCode.network);
      await container.read(trackProvider(1).notifier).poll();
      expect(container.read(trackProvider(1)).value!.status, first.status);

      await container.read(trackProvider(1).notifier).poll();
      expect(
        container.read(trackProvider(1)).value!.status,
        OrderStatus.packing,
      );
    });

    test('polls on a timer while the order is active', () async {
      final repo = FakeTrackRepository();
      final container = ProviderContainer(
        overrides: [
          trackRepositoryProvider.overrideWithValue(repo),
          orderRealtimeProvider.overrideWithValue(
            const DisabledOrderRealtime(),
          ),
          trackPollIntervalProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(trackProvider(1), (_, _) {});
      addTearDown(sub.close);
      await container.read(trackProvider(1).future);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        container.read(trackProvider(1)).value!.status,
        isNot(OrderStatus.accepted),
      );
    });
  });

  testWidgets('the screen: status, ETA, OTP, rider call, sketch', (
    tester,
  ) async {
    final urls = FakeUrlOpener();
    await tester.pumpWidget(
      harness(
        const TrackingScreen(orderId: 3),
        overrides: [
          trackRepositoryProvider.overrideWithValue(
            FakeTrackRepository(startStep: 3),
          ),
          trackPollIntervalProvider.overrideWithValue(Duration.zero),
          urlOpenerProvider.overrideWithValue(urls),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('On the way'), findsWidgets);
    expect(find.byKey(const Key('tracking-eta')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    expect(find.byKey(const Key('route-sketch')), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    await tester.tap(find.byTooltip('Call Ravi Kumar'));
    expect(urls.opened.single, Uri.parse('tel:+919000000099'));
  });

  testWidgets('a failed load offers retry', (tester) async {
    await tester.pumpWidget(
      harness(
        const TrackingScreen(orderId: 3),
        overrides: [
          trackRepositoryProvider.overrideWithValue(
            const UnavailableTrackRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('ETA countdown rounds up and says when it is due', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 4, 10);
    await tester.pumpWidget(
      harness(
        Column(
          children: [
            EtaCountdown(
              etaAt: now.add(const Duration(minutes: 7, seconds: 10)),
              now: () => now,
            ),
            EtaCountdown(etaAt: now, now: () => now),
          ],
        ),
      ),
    );
    expect(find.text('Arriving in 8 mins'), findsOneWidget);
    expect(find.text('Arriving any moment'), findsOneWidget);
  });

  test('progress is 0 before pickup', () {
    const track = OrderTrack(
      orderId: 1,
      orderNumber: 'JV-1',
      status: OrderStatus.packing,
      store: FakeTrackRepository.store,
      destination: FakeTrackRepository.home,
    );
    expect(track.progress, 0);
  });

  group('RiderCard', () {
    testWidgets('no phone (DL-56): the card stays, no call button', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const RiderCard(rider: TrackRider(name: 'Ravi K.'))),
      );
      expect(find.byKey(const Key('rider-card')), findsOneWidget);
      expect(find.text('Ravi K.'), findsOneWidget);
      expect(find.byKey(const Key('call-rider')), findsNothing);
    });

    testWidgets('with a phone: a 48 dp call button', (tester) async {
      await tester.pumpWidget(
        harness(
          const RiderCard(
            rider: TrackRider(name: 'Ravi K.', phone: '+919811122233'),
          ),
        ),
      );
      final call = find.byKey(const Key('call-rider'));
      expect(call, findsOneWidget);
      expect(tester.getSize(call).height, greaterThanOrEqualTo(48));
    });
  });
}
