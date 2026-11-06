import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/location/domain/backoff.dart';
import 'package:rider_app/features/notifications/data/fake_push_messaging.dart';
import 'package:rider_app/features/notifications/domain/push_messaging.dart';
import 'package:rider_app/features/notifications/domain/rider_push.dart';
import 'package:rider_app/features/notifications/presentation/push_providers.dart';
import 'package:rider_app/features/offers/presentation/offer_controller.dart';

import '../../helpers/rider_app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RiderPush.parse (06 §4.3, api-requests #41)', () {
    test('offer.new, offer.withdrawn, task.updated', () {
      expect(
        RiderPush.parse({'type': 'offer.new', 'offer_id': '7'}),
        isA<OfferPush>().having((p) => p.offerId, 'offerId', 7),
      );
      expect(
        RiderPush.parse({'type': 'offer.withdrawn', 'offer_id': '7'}),
        isA<OfferWithdrawnPush>().having((p) => p.offerId, 'offerId', 7),
      );
      expect(
        RiderPush.parse({'type': 'task.updated', 'task_id': '3'}),
        isA<TaskUpdatedPush>(),
      );
    });

    test('unknown or malformed pushes are ignored', () {
      expect(RiderPush.parse({}), isA<UnknownPush>());
      expect(RiderPush.parse({'type': 'promo'}), isA<UnknownPush>());
      expect(
        RiderPush.parse({'type': 'offer.withdrawn', 'offer_id': 'x'}),
        isA<UnknownPush>(),
      );
    });
  });

  group('token registration (POST /me/devices/)', () {
    late RiderTestHarness h;
    late FakePushMessaging push;

    Future<ProviderContainer> start({bool signedIn = true}) async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      if (signedIn) await h.signedInBefore('+919811122231');
      final c = await h.container(
        extra: [
          pushMessagingProvider.overrideWithValue(push),
          pushBackoffFactoryProvider.overrideWithValue(
            () => Backoff(
              initial: const Duration(milliseconds: 10),
              max: const Duration(milliseconds: 40),
            ),
          ),
        ],
      );
      c.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
      return c;
    }

    test('registers the token for a signed-in rider, once', () async {
      final c = await start();
      expect(h.devices.registered, ['fcm-token-1']);
      await c
          .read(pushRegistrationControllerProvider.notifier)
          .registerCurrent();
      expect(h.devices.registered, ['fcm-token-1'], reason: 'deduplicated');
    });

    test('a rotated token is registered again', () async {
      await start();
      push.refreshToken('fcm-token-2');
      await pumpEventQueue();
      expect(h.devices.registered, ['fcm-token-1', 'fcm-token-2']);
    });

    test('nothing is registered while signed out', () async {
      await start(signedIn: false);
      expect(h.devices.registered, isEmpty);
    });

    test('a network failure retries with backoff', () async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      await h.signedInBefore('+919811122231');
      h.devices.nextError = const ApiError(code: ApiErrorCode.network);
      final c = await h.container(
        extra: [
          pushMessagingProvider.overrideWithValue(push),
          pushBackoffFactoryProvider.overrideWithValue(
            () => Backoff(
              initial: const Duration(milliseconds: 10),
              max: const Duration(milliseconds: 40),
            ),
          ),
        ],
      );
      c.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
      expect(h.devices.registered, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(h.devices.registered, ['fcm-token-1']);
    });

    test('a 4xx is not retried', () async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      await h.signedInBefore('+919811122231');
      h.devices.nextError = const ApiError(
        code: ApiErrorCode.validationError,
        statusCode: 400,
      );
      final c = await h.container(
        extra: [pushMessagingProvider.overrideWithValue(push)],
      );
      c.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(h.devices.registered, isEmpty);
      expect(
        c.read(pushRegistrationControllerProvider).lastError?.code,
        ApiErrorCode.validationError,
      );
    });
  });

  group('offer pushes route to the offer screen', () {
    late RiderTestHarness h;
    late FakePushMessaging push;
    late ProviderContainer c;

    setUp(() async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [pushMessagingProvider.overrideWithValue(push)],
      );
      await c.read(riderAccountControllerProvider.notifier).load();
      c
        ..listen(offerControllerProvider, (_, _) {})
        ..listen(pushMessageHandlerProvider, (_, _) {});
      await pumpEventQueue();
    });

    test('offer.new fetches the offer from the server and opens it', () async {
      // The server has an offer; the push only says so (no event stream).
      final offer = h.tasks.simulateOffer();
      c.read(offerControllerProvider.notifier).acknowledge();
      await pumpEventQueue();
      expect(c.read(offerControllerProvider).offer?.id, offer.id);

      push.deliver(
        PushMessage({'type': 'offer.new', 'offer_id': '${offer.id}'}),
      );
      await pumpEventQueue();
      expect(c.read(offerControllerProvider).isOpen, isTrue);
      expect(h.tasks.calls, contains('fetchCurrentOffer'));
    });

    test('offer.withdrawn ends the open offer and removes its alert', () async {
      final offer = h.tasks.simulateOffer();
      await pumpEventQueue();
      expect(c.read(offerControllerProvider).phase, OfferPhase.showing);

      push.deliver(
        PushMessage({'type': 'offer.withdrawn', 'offer_id': '${offer.id}'}),
      );
      await pumpEventQueue();
      expect(c.read(offerControllerProvider).phase, OfferPhase.withdrawn);
      expect(h.offerAlerts.dismissed, greaterThan(0));
    });
  });

  group('logout unregisters the push token (DELETE /me/devices/)', () {
    late RiderTestHarness h;
    late FakePushMessaging push;
    late ProviderContainer c;

    Future<void> start() async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [pushMessagingProvider.overrideWithValue(push)],
      );
      await c.read(riderAccountControllerProvider.notifier).load();
      c.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
      expect(h.devices.registered, ['fcm-token-1']);
    }

    test(
      'before the session ends; the token also goes with auth/logout',
      () async {
        await start();
        final result = await c
            .read(riderAccountControllerProvider.notifier)
            .logout();

        expect(result, LogoutResult.done);
        expect(h.devices.unregistered, ['fcm-token-1']);
        expect(h.backend.calls, contains('logout fcm=fcm-token-1'));
        expect(h.session.isSignedIn, isFalse);
      },
    );

    test('a failed unregister never blocks logout', () async {
      await start();
      h.devices.nextError = const ApiError(code: ApiErrorCode.network);
      final result = await c
          .read(riderAccountControllerProvider.notifier)
          .logout();

      expect(result, LogoutResult.done);
      expect(h.devices.unregistered, isEmpty);
      expect(h.backend.calls, contains('logout fcm=fcm-token-1'));
      expect(h.session.isSignedIn, isFalse);
    });

    test('no push set up (no Firebase yet): plain logout', () async {
      h = RiderTestHarness();
      await h.signedInBefore('+919811122231');
      c = await h.container();
      await c.read(riderAccountControllerProvider.notifier).load();
      await c.read(riderAccountControllerProvider.notifier).logout();
      expect(h.devices.unregistered, isEmpty);
      expect(h.backend.calls, contains('logout'));
    });
  });
}
