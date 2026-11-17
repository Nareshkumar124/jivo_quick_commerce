import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/providers.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/notifications/data/fake_push_messaging.dart';
import 'package:rider_app/features/notifications/data/firebase_push_messaging.dart';
import 'package:rider_app/features/notifications/data/noop_push_messaging.dart';
import 'package:rider_app/features/notifications/data/push_background.dart';
import 'package:rider_app/features/notifications/data/push_channels.dart';
import 'package:rider_app/features/notifications/data/push_guard_store.dart';
import 'package:rider_app/features/notifications/data/push_setup.dart';
import 'package:rider_app/features/notifications/domain/push_messaging.dart';
import 'package:rider_app/features/notifications/presentation/push_providers.dart';
import 'package:rider_app/features/notifications/presentation/rider_links.dart';
import 'package:rider_app/features/offers/data/offer_alert_notifications.dart';
import 'package:rider_app/features/offers/presentation/offer_controller.dart';

import '../../helpers/rider_app_harness.dart';

/// FCM (D-19): the Firebase adapter, the start-up choice, the background
/// handler, token lifecycle and tap routing, all with fakes (no Firebase).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const texts = (
    offersName: 'Offers',
    offersDescription: 'o',
    ordersName: 'Orders',
    ordersDescription: 'r',
    generalName: 'General',
    generalDescription: 'g',
  );

  group('channels and payloads', () {
    test('channel by server name, else by type or link', () {
      RiderPushChannel ch(Map<String, String> data, [String? named]) =>
          channelForPush(IncomingPush(data: data, androidChannelId: named));

      expect(ch({'type': 'offer.new'}), RiderPushChannel.offers);
      expect(ch({'type': 'offer.withdrawn'}), RiderPushChannel.offers);
      expect(ch({'type': 'task.updated'}), RiderPushChannel.orders);
      expect(ch({'link': 'jivo://rider/task'}), RiderPushChannel.orders);
      expect(ch({'type': 'cash.updated'}), RiderPushChannel.general);
      expect(ch({'type': 'ticket'}), RiderPushChannel.general);
      expect(ch({}), RiderPushChannel.general);
      expect(ch({'type': 'cash.updated'}, 'orders'), RiderPushChannel.orders);
      expect(ch({'type': 'task.updated'}, 'nope'), RiderPushChannel.orders);
      expect(RiderPushChannel.values.map((c) => c.id), [
        'offers',
        'orders',
        'general',
      ]);
    });

    test('push payloads round-trip and never look like an offer alarm', () {
      final payload = encodePushPayload({
        'type': 'task.updated',
        'task_id': '7',
      });
      expect(OfferAlertNotifications.isOfferPayload(payload), isFalse);
      expect(decodePushPayload(payload), {
        'type': 'task.updated',
        'task_id': '7',
      });
      expect(decodePushPayload('offer:12'), isNull);
      expect(decodePushPayload('push:{oops'), isNull);
      expect(decodePushPayload(null), isNull);
    });

    test('notification ids are stable and never clash with fixed ids', () {
      const a = IncomingPush(messageId: 'm-1');
      expect(notificationIdFor(a), notificationIdFor(a));
      expect(
        notificationIdFor(a),
        isNot(notificationIdFor(const IncomingPush(messageId: 'm-2'))),
      );
      for (final id in ['x', 'y', '', '0:1:2']) {
        expect(
          notificationIdFor(IncomingPush(messageId: id)),
          greaterThanOrEqualTo(1 << 30),
        );
      }
    });
  });

  group('initializePush (not-configured path)', () {
    test(
      'no google-services config: push off, no background handler',
      () async {
        var registered = 0;
        final push = await initializePush(
          texts: texts,
          initializeFirebase: () async =>
              throw Exception('[core/no-app] No Firebase App'),
          registerBackgroundHandler: () => registered++,
          fcm: FakeFcmClient.new,
          notifier: FakePushNotifier.new,
        );
        expect(push, isA<NoopPushMessaging>());
        expect(push.isAvailable, isFalse);
        expect(await push.token(), isNull);
        expect(registered, 0);
      },
    );

    test('configured: FCM with the three channels and the background '
        'handler', () async {
      var registered = 0;
      final notifier = FakePushNotifier();
      final push = await initializePush(
        texts: texts,
        initializeFirebase: () async {},
        registerBackgroundHandler: () => registered++,
        fcm: FakeFcmClient.new,
        notifier: () => notifier,
      );
      expect(push, isA<FirebasePushMessaging>());
      expect(push.isAvailable, isTrue);
      expect(registered, 1);
      expect(notifier.channelsCreated, 1);
      expect(await push.token(), 'fcm-1');
    });

    test('a failure while starting FCM leaves push off', () async {
      final push = await initializePush(
        texts: texts,
        initializeFirebase: () async {},
        registerBackgroundHandler: () => throw StateError('no plugin'),
        fcm: FakeFcmClient.new,
        notifier: FakePushNotifier.new,
      );
      expect(push, isA<NoopPushMessaging>());
    });
  });

  group('FirebasePushMessaging', () {
    late FakeFcmClient fcm;
    late FakePushNotifier notifier;
    late FirebasePushMessaging push;
    late List<PushMessage> received;

    setUp(() async {
      fcm = FakeFcmClient();
      notifier = FakePushNotifier();
      push = FirebasePushMessaging(fcm: fcm, notifier: notifier, texts: texts);
      await push.start();
      received = [];
      push.messages.listen(received.add);
    });

    tearDown(() async {
      await push.dispose();
      await fcm.close();
    });

    test('a foreground task update is routed and shown on "orders"', () async {
      fcm.foreground.add(
        const IncomingPush(
          messageId: 'm1',
          title: 'Order ready for pickup',
          body: 'Order JQ-1 is packed.',
          data: {'type': 'task.updated', 'task_id': '7'},
        ),
      );
      await pumpEventQueue();
      expect(received.single.openedApp, isFalse);
      expect(received.single.data['type'], 'task.updated');
      final shown = notifier.shown.single;
      expect(shown.channel, RiderPushChannel.orders);
      expect(decodePushPayload(shown.payload), {
        'type': 'task.updated',
        'task_id': '7',
      });
    });

    test('a foreground offer is not shown: the offer screen and its alarm '
        'are the in-app path', () async {
      fcm.foreground.add(
        const IncomingPush(
          title: 'New order offer',
          body: 'Pickup at Sector 18',
          data: {'type': 'offer.new', 'offer_id': '9'},
        ),
      );
      await pumpEventQueue();
      expect(received.single.data['offer_id'], '9');
      expect(notifier.shown, isEmpty);
    });

    test('a data-only foreground message is routed, not shown', () async {
      fcm.foreground.add(const IncomingPush(data: {'type': 'cash.updated'}));
      await pumpEventQueue();
      expect(received, hasLength(1));
      expect(notifier.shown, isEmpty);
    });

    test('taps: system notification, local notification', () async {
      fcm.opened.add({'type': 'cash.updated'});
      push
        ..onLocalNotificationTap(
          encodePushPayload({'type': 'ticket', 'ticket_id': '4'}),
        )
        ..onLocalNotificationTap('offer:3'); // the offer alarm's: not ours
      await pumpEventQueue();
      expect(
        received.map((m) => (m.data['type'], m.openedApp)),
        unorderedEquals([('cash.updated', true), ('ticket', true)]),
      );
    });

    test('the launch message: FCM first, else the tapped local one, '
        'once', () async {
      push.setLocalLaunchPayload(encodePushPayload({'type': 'cash.updated'}));
      fcm.initial = {'type': 'task.updated'};
      final first = await push.initialMessage();
      expect(first?.data['type'], 'task.updated');
      expect(first?.openedApp, isTrue);
      expect(await push.initialMessage(), isNull);

      final other = FirebasePushMessaging(
        fcm: FakeFcmClient(),
        notifier: notifier,
        texts: texts,
      )..setLocalLaunchPayload(encodePushPayload({'type': 'cash.updated'}));
      expect((await other.initialMessage())?.data['type'], 'cash.updated');
    });

    test('token failures and delete failures never throw', () async {
      fcm.tokenError = Exception('SERVICE_NOT_AVAILABLE');
      expect(await push.token(), isNull);
      fcm.deleteError = Exception('offline');
      await push.deleteToken();
      expect(fcm.deletes, 1);
    });

    test('never asks for notification permission (the permissions gate '
        'does, before going online)', () {
      // FcmClient has no permission call at all; start() created the
      // channels only.
      expect(notifier.channelsCreated, 1);
      expect(notifier.shown, isEmpty);
    });
  });

  group('background handler (data-only offer alarm)', () {
    final bgTexts = backgroundOfferTexts();

    test('offer.new without text rings the full-screen offer alarm', () async {
      final alerts = RecordingOfferAlerts();
      final action = await handleBackgroundPush(
        const IncomingPush(
          data: {'type': 'offer.new', 'offer_id': '41', 'task_id': '7'},
        ),
        alerts,
        texts: bgTexts,
        signedIn: () async => true,
      );
      expect(action, BackgroundPushAction.rangOffer);
      expect(alerts.shownOffers, [41]);
      expect(bgTexts.body, 'Open Jivo Rider to see the pickup and accept it.');
    });

    test('offer.withdrawn / offer.expired remove the alarm, with or without '
        'text', () async {
      for (final (type, title) in [
        ('offer.withdrawn', null),
        ('offer.expired', null),
        ('offer.expired', 'Offer expired'),
      ]) {
        final alerts = RecordingOfferAlerts();
        final action = await handleBackgroundPush(
          IncomingPush(title: title, data: {'type': type, 'offer_id': '41'}),
          alerts,
          texts: bgTexts,
          signedIn: () async => true,
        );
        expect(action, BackgroundPushAction.dismissedOffer, reason: type);
        expect(alerts.dismissedIds, [
          OfferAlertNotifications.offerNotificationId,
        ]);
      }
    });

    test('a message with text is left to the system; others do '
        'nothing', () async {
      final alerts = RecordingOfferAlerts();
      expect(
        await handleBackgroundPush(
          const IncomingPush(
            title: 'New order offer',
            data: {'type': 'offer.new', 'offer_id': '41'},
          ),
          alerts,
          texts: bgTexts,
          signedIn: () async => true,
        ),
        BackgroundPushAction.shownBySystem,
      );
      expect(
        await handleBackgroundPush(
          const IncomingPush(data: {'type': 'task.updated', 'task_id': '1'}),
          alerts,
          texts: bgTexts,
          signedIn: () async => true,
        ),
        BackgroundPushAction.none,
      );
      expect(
        await handleBackgroundPush(
          const IncomingPush(data: {'type': 'offer.new'}),
          alerts,
          texts: bgTexts,
          signedIn: () async => true,
        ),
        BackgroundPushAction.none,
        reason: 'no offer id',
      );
      expect(alerts.shownOffers, isEmpty);
      expect(alerts.dismissedIds, isEmpty);
    });
  });

  group('background alarm guards (code review)', () {
    final bgTexts = backgroundOfferTexts();
    final now = DateTime.utc(2026, 11, 17, 10);

    Future<(BackgroundPushAction, RecordingOfferAlerts)> ring(
      Map<String, String> data, {
      bool signedIn = true,
    }) async {
      final alerts = RecordingOfferAlerts();
      final action = await handleBackgroundPush(
        IncomingPush(data: {'type': 'offer.new', 'offer_id': '41', ...data}),
        alerts,
        texts: bgTexts,
        signedIn: () async => signedIn,
        now: () => now,
      );
      return (action, alerts);
    }

    test('signed out on this phone: no ring', () async {
      final (action, alerts) = await ring({}, signedIn: false);
      expect(action, BackgroundPushAction.skippedSignedOut);
      expect(alerts.shownOffers, isEmpty);
    });

    test('the signed-out flag comes from the guard store', () async {
      final store = InMemoryPushGuardStore();
      final alerts = RecordingOfferAlerts();
      Future<BackgroundPushAction> go() => handleBackgroundPush(
        const IncomingPush(data: {'type': 'offer.new', 'offer_id': '41'}),
        alerts,
        texts: bgTexts,
        signedIn: store.signedIn,
      );
      expect(await go(), BackgroundPushAction.skippedSignedOut);
      await store.setSignedIn(true);
      expect(await go(), BackgroundPushAction.rangOffer);
    });

    test('a delayed push for an expired offer does not ring', () async {
      final expiredAt = now.subtract(const Duration(seconds: 6));
      final (action, alerts) = await ring({
        'expires_at': expiredAt.toIso8601String(),
      });
      expect(action, BackgroundPushAction.skippedExpired);
      expect(alerts.shownOffers, isEmpty);
    });

    test('alarm length: min(30 s, time left), skew-tolerant, 30 s without '
        'expires_at', () async {
      String at(Duration d) => now.add(d).toIso8601String();
      expect(backgroundAlarmTimeout(null, now), const Duration(seconds: 30));
      expect(
        backgroundAlarmTimeout('garbage', now),
        const Duration(seconds: 30),
      );
      expect(
        backgroundAlarmTimeout(at(const Duration(seconds: 12)), now),
        const Duration(seconds: 12),
      );
      expect(
        backgroundAlarmTimeout(at(const Duration(seconds: 45)), now),
        const Duration(seconds: 30),
      );
      // Within the 5 s clock skew: still rings, briefly.
      expect(
        backgroundAlarmTimeout(at(const Duration(seconds: -4)), now),
        backgroundAlarmMinimum,
      );
      expect(
        backgroundAlarmTimeout(at(const Duration(seconds: -6)), now),
        isNull,
      );
      // `Z` (UTC) as the backend sends it.
      expect(
        backgroundAlarmTimeout('2026-11-17T10:00:20Z', now),
        const Duration(seconds: 20),
      );

      final (action, alerts) = await ring({
        'expires_at': at(const Duration(seconds: 12)),
      });
      expect(action, BackgroundPushAction.rangOffer);
      expect(alerts.timeouts, [const Duration(seconds: 12)]);
    });
  });

  group('token lifecycle', () {
    late RiderTestHarness h;
    late FakePushMessaging push;
    late ProviderContainer c;

    Future<void> start({bool signedIn = true}) async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      if (signedIn) await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [pushMessagingProvider.overrideWithValue(push)],
      );
      if (signedIn) {
        await c.read(riderAccountControllerProvider.notifier).load();
      }
      c.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
    }

    test('registered with app=rider at start, again on refresh', () async {
      await start();
      expect(h.devices.registered, ['fcm-token-1']);
      push.refreshToken('fcm-token-2');
      await pumpEventQueue();
      expect(h.devices.registered, ['fcm-token-1', 'fcm-token-2']);
    });

    test('registered after an OTP login', () async {
      await start(signedIn: false);
      expect(h.devices.registered, isEmpty);
      await h.session.signIn(const AuthTokens(access: 'a', refresh: 'r'));
      await pumpEventQueue();
      expect(h.devices.registered, ['fcm-token-1']);
      expect(push.tokenDeletions, 0);
    });

    test('logout: unregistered on the server, then the local token is '
        'deleted', () async {
      await start();
      await c.read(riderAccountControllerProvider.notifier).logout();
      await pumpEventQueue();
      expect(h.devices.unregistered, ['fcm-token-1']);
      expect(push.tokenDeletions, 1);
    });

    test('DL-74 wrong-app sign-out: the local token is deleted (the server '
        'refuses the session, so it cannot be told)', () async {
      await start();
      c.read(wrongAppSignOutProvider)();
      await pumpEventQueue();
      expect(h.session.isSignedIn, isFalse);
      expect(c.read(wrongAppNoticeProvider), isTrue);
      expect(push.tokenDeletions, 1);
      expect(h.devices.unregistered, isEmpty);

      // The next rider on this phone registers a fresh token.
      await h.session.signIn(const AuthTokens(access: 'a', refresh: 'r'));
      await pumpEventQueue();
      expect(h.devices.registered.last, 'fcm-token-new-1');
    });

    test('the signed-in flag follows the session', () async {
      await start();
      expect(h.pushGuard.isSignedIn, isTrue);
      await h.session.signOut(reason: SignOutReason.sessionExpired);
      await pumpEventQueue();
      expect(h.pushGuard.isSignedIn, isFalse);
      await h.session.signIn(const AuthTokens(access: 'a', refresh: 'r'));
      await pumpEventQueue();
      expect(h.pushGuard.isSignedIn, isTrue);
    });

    test('an offline token delete at sign-out is retried on the next '
        'start', () async {
      await start();
      push.failDeletes = true;
      c.read(wrongAppSignOutProvider)();
      await pumpEventQueue();
      expect(push.tokenDeletions, 0);
      expect(h.pushGuard.isSignedIn, isFalse, reason: 'no alarms meanwhile');
      expect(h.pushGuard.deletePending, isTrue);

      // Next start, signed out and online again.
      push.failDeletes = false;
      final c2 = await h.container(
        extra: [pushMessagingProvider.overrideWithValue(push)],
      );
      c2.listen(pushRegistrationControllerProvider, (_, _) {});
      await pumpEventQueue();
      expect(push.tokenDeletions, 1);
      expect(h.pushGuard.deletePending, isFalse);
    });

    test('a pending delete runs before the next rider registers', () async {
      await start();
      push.failDeletes = true;
      await h.session.signOut(reason: SignOutReason.sessionExpired);
      await pumpEventQueue();
      expect(h.pushGuard.deletePending, isTrue);
      push.failDeletes = false;
      await h.session.signIn(const AuthTokens(access: 'a', refresh: 'r'));
      await pumpEventQueue();
      expect(push.tokenDeletions, 1);
      expect(h.pushGuard.deletePending, isFalse);
      expect(h.devices.registered.last, 'fcm-token-new-1');
    });

    test('an expired session deletes the token too', () async {
      await start();
      await h.session.signOut(reason: SignOutReason.sessionExpired);
      await pumpEventQueue();
      expect(push.tokenDeletions, 1);
    });

    test('a signed-out start deletes nothing', () async {
      await start(signedIn: false);
      expect(push.tokenDeletions, 0);
    });
  });

  group('tapped pushes route by payload', () {
    late RiderTestHarness h;
    late FakePushMessaging push;
    late ProviderContainer c;
    late List<String> opened;

    Future<void> start({bool loadAccount = true}) async {
      h = RiderTestHarness();
      push = FakePushMessaging();
      opened = [];
      await h.signedInBefore('+919811122231');
      c = await h.container(
        extra: [
          pushMessagingProvider.overrideWithValue(push),
          riderLinkNavigatorProvider.overrideWithValue(opened.add),
        ],
      );
      c
        ..listen(offerControllerProvider, (_, _) {})
        ..listen(pushMessageHandlerProvider, (_, _) {});
      if (loadAccount) {
        await c.read(riderAccountControllerProvider.notifier).load();
      }
      await pumpEventQueue();
    }

    Future<void> tap(Map<String, String> data) async {
      push.deliver(PushMessage(data, openedApp: true));
      await pumpEventQueue();
    }

    test('task events open the task; cash the ledger; replies the '
        'ticket', () async {
      await start();
      await tap({'type': 'task.updated', 'task_id': '7'});
      await tap({'type': 'task.updated', 'link': 'jivo://rider/task'});
      await tap({'type': 'cash.updated'});
      await tap({'type': 'cash.updated', 'link': 'jivo://rider/cash'});
      await tap({'type': 'ticket', 'ticket_id': '12'});
      expect(opened, [
        Routes.task,
        Routes.task,
        Routes.cash,
        Routes.cash,
        Routes.ticket(12),
      ]);
    });

    test('unknown links and unknown types go home', () async {
      await start();
      await tap({'type': 'task.updated', 'link': 'jivo://rider/somewhere'});
      await tap({'type': 'payout.paid'});
      await tap({'link': 'https://example.com'});
      await tap({'type': 'promo', 'link': 'jivo://rider/cash'});
      expect(opened, [Routes.home, Routes.home, Routes.home, Routes.cash]);
    });

    test('not tapped (foreground): refreshed, never navigated', () async {
      await start();
      for (final data in [
        {'type': 'task.updated', 'task_id': '7'},
        {'type': 'cash.updated'},
        {'type': 'payout.paid'},
      ]) {
        push.deliver(PushMessage(data));
      }
      await pumpEventQueue();
      expect(opened, isEmpty);
    });

    test('a tap that started the app waits for the account', () async {
      await start(loadAccount: false);
      await tap({'type': 'task.updated', 'task_id': '7'});
      expect(opened, isEmpty);
      await c.read(riderAccountControllerProvider.notifier).load();
      await pumpEventQueue();
      expect(opened, [Routes.task]);
    });

    test('a tapped offer that is still open on the server opens it', () async {
      await start();
      final offer = h.tasks.simulateOffer(pushed: false);
      await tap({'type': 'offer.new', 'offer_id': '${offer.id}'});
      final state = c.read(offerControllerProvider);
      expect(state.phase, OfferPhase.showing);
      expect(state.offer?.id, offer.id);
    });

    test(
      'a tapped offer that expired meanwhile shows "Offer expired"',
      () async {
        await start();
        final offer = h.tasks.simulateOffer(
          pushed: false,
          expiresIn: const Duration(seconds: 30),
        );
        h.now = h.now.add(const Duration(seconds: 31));
        await tap({
          'type': 'offer.new',
          'offer_id': '${offer.id}',
          'task_id': '${offer.taskId}',
        });
        final state = c.read(offerControllerProvider);
        expect(state.phase, OfferPhase.expired);
        expect(state.isOpen, isTrue, reason: 'the offer screen says so');

        // OK closes it; the same notification again changes nothing new.
        c.read(offerControllerProvider.notifier).acknowledge();
        expect(c.read(offerControllerProvider).isOpen, isFalse);
      },
    );

    test('the tapped offer alarm (offer:<id>) is the same as a tapped '
        'offer.new', () {
      final message = offerAlertTapMessage('offer:41');
      expect(message.openedApp, isTrue);
      expect(message.data, {'type': 'offer.new', 'offer_id': '41'});
      expect(offerAlertTapMessage('offer:x').data, {'type': 'offer.new'});
    });

    test('rider_links: unknown links are null (the handler sends them '
        'home)', () {
      expect(routeForRiderLink('jivo://rider/task'), Routes.task);
      expect(routeForRiderLink('jivo://rider/nope'), isNull);
    });
  });
}

class FakeFcmClient implements FcmClient {
  final foreground = StreamController<IncomingPush>.broadcast();
  final opened = StreamController<Map<String, String>>.broadcast();
  final refresh = StreamController<String>.broadcast();
  Map<String, String>? initial;
  Object? tokenError;
  Object? deleteError;
  int deletes = 0;

  Future<void> close() async {
    await foreground.close();
    await opened.close();
    await refresh.close();
  }

  @override
  Future<String?> getToken() async {
    final error = tokenError;
    if (error != null) throw error;
    return 'fcm-1';
  }

  @override
  Future<void> deleteToken() async {
    deletes++;
    final error = deleteError;
    if (error != null) throw error;
  }

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<IncomingPush> get onForegroundMessage => foreground.stream;

  @override
  Stream<Map<String, String>> get onMessageOpenedApp => opened.stream;

  @override
  Future<Map<String, String>?> initialMessageData() async => initial;
}

class FakePushNotifier implements PushNotifier {
  int channelsCreated = 0;
  final shown = <({int id, RiderPushChannel channel, String payload})>[];

  @override
  Future<void> createChannels(RiderPushChannelTexts texts) async =>
      channelsCreated++;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required RiderPushChannel channel,
    required RiderPushChannelTexts texts,
    required String payload,
  }) async => shown.add((id: id, channel: channel, payload: payload));
}

class RecordingOfferAlerts extends OfferAlertNotifications {
  final shownOffers = <int>[];
  final timeouts = <Duration>[];
  final dismissedIds = <int>[];

  @override
  Future<void> showOffer({
    required int offerId,
    required String title,
    required String body,
    required String channelName,
    required Duration timeout,
  }) async {
    shownOffers.add(offerId);
    timeouts.add(timeout);
  }

  @override
  Future<void> dismiss({
    int id = OfferAlertNotifications.testNotificationId,
  }) async => dismissedIds.add(id);
}
