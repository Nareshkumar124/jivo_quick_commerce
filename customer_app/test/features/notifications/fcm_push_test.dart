import 'dart:async';

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/features/checkout/presentation/order_success_screen.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/notifications/data/device_repository.dart';
import 'package:customer_app/features/notifications/data/firebase_push_messaging.dart';
import 'package:customer_app/features/notifications/data/push_channels.dart';
import 'package:customer_app/features/notifications/data/push_messaging.dart';
import 'package:customer_app/features/notifications/data/push_setup.dart';
import 'package:customer_app/features/notifications/presentation/notification_tap_router.dart';
import 'package:customer_app/features/notifications/presentation/push_registration.dart';
import 'package:customer_app/shared/links/deep_links.dart';
import 'package:customer_app/shared/storage/app_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_config.dart';
import '../cart/cart_fixtures.dart';
import '../checkout/checkout_flow_test.dart' show openCheckout;

/// The FCM adapter (D-19): channels, foreground display, taps, the
/// permission moments, token register/refresh/delete and the build without
/// Firebase.
void main() {
  setUpAll(initializeFormatting);

  const texts = (
    ordersName: 'Order updates',
    ordersDescription: 'Orders',
    generalName: 'Offers and news',
    generalDescription: 'Other',
  );

  group('channels and payloads', () {
    test('the server-named channel wins; otherwise by payload', () {
      expect(
        channelFor(
          const IncomingPush(
            androidChannelId: 'general',
            data: {'type': 'order', 'order_id': '1'},
          ),
        ),
        PushChannel.general,
      );
      expect(
        channelFor(const IncomingPush(data: {'type': 'order'})),
        PushChannel.orders,
      );
      expect(
        channelFor(const IncomingPush(data: {'type': 'ticket'})),
        PushChannel.orders,
      );
      expect(
        channelFor(const IncomingPush(data: {'link': 'jivo://orders/12/rate'})),
        PushChannel.orders,
      );
      expect(
        channelFor(const IncomingPush(data: {'type': 'product'})),
        PushChannel.general,
      );
      expect(
        channelFor(const IncomingPush(androidChannelId: 'unknown')),
        PushChannel.general,
      );
      expect(PushChannel.orders.id, 'orders');
      expect(PushChannel.general.id, 'general');
    });

    test('the payload round-trips the FCM data as strings', () {
      final payload = encodePushPayload({
        'type': 'order',
        'order_id': 1203,
        'skip': null,
      });
      expect(decodePushPayload(payload), {'type': 'order', 'order_id': '1203'});
      expect(decodePushPayload(null), isNull);
      expect(decodePushPayload(''), isNull);
      expect(decodePushPayload('offer:12'), isNull);
      expect(decodePushPayload('[1]'), isNull);
    });

    test('notification ids are positive and stable per message', () {
      const a = IncomingPush(messageId: 'm-1');
      expect(
        notificationIdFor(a),
        notificationIdFor(const IncomingPush(messageId: 'm-1')),
      );
      expect(
        notificationIdFor(a),
        isNot(notificationIdFor(const IncomingPush(messageId: 'm-2'))),
      );
      expect(notificationIdFor(a), greaterThanOrEqualTo(0));
      expect(
        notificationIdFor(const IncomingPush(data: {'type': 'order'})),
        greaterThanOrEqualTo(0),
      );
    });
  });

  group('FirebasePushMessaging', () {
    late _FakeFcm fcm;
    late _FakeLocal local;
    late FirebasePushMessaging push;

    setUp(() async {
      fcm = _FakeFcm();
      local = _FakeLocal();
      push = FirebasePushMessaging(fcm: fcm, local: local, texts: texts);
      await push.start();
      addTearDown(push.dispose);
      addTearDown(fcm.close);
    });

    test('start creates both channels with the l10n names', () {
      expect(local.initialized, isTrue);
      expect(local.channelTexts, texts);
      expect(push.isConfigured, isTrue);
    });

    test('a foreground push is shown on its channel with the data as '
        'payload; a data-only one is not shown', () async {
      fcm.foreground.add(
        const IncomingPush(
          messageId: 'm-1',
          title: 'Order on the way',
          body: 'Ravi is bringing it',
          data: {'type': 'order', 'order_id': '1203'},
        ),
      );
      fcm.foreground.add(const IncomingPush(data: {'type': 'order'}));
      await pumpEventQueue();
      final shown = local.shown.single;
      expect(shown.title, 'Order on the way');
      expect(shown.body, 'Ravi is bringing it');
      expect(shown.channel, PushChannel.orders);
      expect(shown.id, notificationIdFor(const IncomingPush(messageId: 'm-1')));
      expect(decodePushPayload(shown.payload), {
        'type': 'order',
        'order_id': '1203',
      });
    });

    test('a promo in the foreground goes to the general channel', () async {
      fcm.foreground.add(
        const IncomingPush(
          title: 'New',
          data: {'type': 'product', 'slug': 'jivo-ghee'},
        ),
      );
      await pumpEventQueue();
      expect(local.shown.single.channel, PushChannel.general);
    });

    test('taps on the local notification and on the system notification '
        'both reach onNotificationTap', () async {
      final taps = <Map<String, Object?>>[];
      final sub = push.onNotificationTap.listen(taps.add);
      addTearDown(sub.cancel);

      local.tap(encodePushPayload({'type': 'ticket', 'ticket_id': '4'}));
      local.tap('not json');
      fcm.opened.add({'link': 'jivo://collection/oils'});
      await pumpEventQueue();
      expect(taps, [
        {'type': 'ticket', 'ticket_id': '4'},
        {'link': 'jivo://collection/oils'},
      ]);
    });

    test(
      'the launching notification: FCM first, then a local one, once',
      () async {
        fcm.initial = {'type': 'order', 'order_id': '7'};
        local.launch = encodePushPayload({'type': 'order', 'order_id': '8'});
        expect(await push.takeInitialNotification(), {
          'type': 'order',
          'order_id': '7',
        });
        expect(await push.takeInitialNotification(), isNull);

        final other = FirebasePushMessaging(
          fcm: _FakeFcm(),
          local: local,
          texts: texts,
        );
        expect(await other.takeInitialNotification(), {
          'type': 'order',
          'order_id': '8',
        });
      },
    );

    test('permission: granted, denied, or failing is "denied"', () async {
      expect(await push.requestPermission(), isTrue);
      fcm.grant = false;
      expect(await push.requestPermission(), isFalse);
      fcm.failPermission = true;
      expect(await push.requestPermission(), isFalse);
      expect(fcm.permissionRequests, 3);
    });

    test('token: read, refreshed, deleted; a failure is no token', () async {
      expect(await push.getToken(), 'fcm-1');
      final refreshed = <String>[];
      final sub = push.onTokenRefresh.listen(refreshed.add);
      addTearDown(sub.cancel);
      fcm.refresh.add('fcm-2');
      await pumpEventQueue();
      expect(refreshed, ['fcm-2']);

      await push.deleteToken();
      expect(fcm.deletes, 1);

      fcm.failToken = true;
      expect(await push.getToken(), isNull);
    });

    test('local notifications failing to start do not stop push', () async {
      final broken = FirebasePushMessaging(
        fcm: _FakeFcm(),
        local: _FakeLocal()..failInit = true,
        texts: texts,
      );
      await broken.start();
      expect(await broken.getToken(), 'fcm-1');
    });
  });

  group('initializePush', () {
    test('without a Firebase config the app runs with push off', () async {
      final push = await initializePush(
        texts: texts,
        initializeFirebase: () async =>
            throw Exception('Failed to load FirebaseOptions from resource'),
        fcm: () => fail('must not touch FCM'),
        local: () => fail('must not touch local notifications'),
      );
      expect(push, isA<NoopPushMessaging>());
      expect(push.isConfigured, isFalse);
      expect(await push.getToken(), isNull);
    });

    test('with a config: the FCM adapter, started', () async {
      final local = _FakeLocal();
      final push = await initializePush(
        texts: texts,
        initializeFirebase: () async {},
        fcm: _FakeFcm.new,
        local: () => local,
      );
      expect(push, isA<FirebasePushMessaging>());
      expect(local.initialized, isTrue);
      expect(local.channelTexts, texts);
    });

    test('the channel names come from l10n', () {
      final defaults = defaultPushChannelTexts();
      expect(defaults.ordersName, 'Order updates');
      expect(defaults.generalName, 'Offers and news');
    });
  });

  group('PushPermissionPrompt', () {
    late AppFlags flags;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      flags = AppFlags(await SharedPreferences.getInstance());
    });

    test('asks once per moment on this install', () async {
      final messaging = FakePushMessaging(token: 't')
        ..permissionGranted = false;
      addTearDown(messaging.close);
      final prompt = PushPermissionPrompt(messaging: messaging, flags: flags);

      expect(await prompt.maybeAsk(PushPermissionMoment.signIn), isFalse);
      expect(await prompt.maybeAsk(PushPermissionMoment.signIn), isNull);
      expect(await prompt.maybeAsk(PushPermissionMoment.firstOrder), isFalse);
      expect(await prompt.maybeAsk(PushPermissionMoment.firstOrder), isNull);
      expect(messaging.permissionRequests, 2);
      expect(flags.pushPermissionAsked('signIn'), isTrue);

      // A new prompt (next app start) remembers it.
      final again = PushPermissionPrompt(messaging: messaging, flags: flags);
      expect(await again.maybeAsk(PushPermissionMoment.signIn), isNull);
      expect(messaging.permissionRequests, 2);
    });

    test('push off: never asks, never marks', () async {
      final prompt = PushPermissionPrompt(
        messaging: const NoopPushMessaging(),
        flags: flags,
      );
      expect(await prompt.maybeAsk(PushPermissionMoment.signIn), isNull);
      expect(flags.pushPermissionAsked('signIn'), isFalse);
    });
  });

  group('PushRegistrar with the permission moments', () {
    late SessionManager session;
    late FakePushMessaging messaging;
    late FakeDeviceRepository devices;
    late PushRegistrar registrar;

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    Future<PushRegistrar> make() async {
      SharedPreferences.setMockInitialValues({});
      final flags = AppFlags(await SharedPreferences.getInstance());
      final r = PushRegistrar(
        messaging: messaging,
        devices: devices,
        clientInfo: testClientInfo,
        session: session,
        prompt: PushPermissionPrompt(messaging: messaging, flags: flags),
      );
      addTearDown(r.dispose);
      return r;
    }

    setUp(() async {
      session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: _NoRefresh(),
      );
      await session.restore();
      messaging = FakePushMessaging(token: 'tok-1');
      addTearDown(messaging.close);
      devices = FakeDeviceRepository();
      registrar = await make();
    });

    test('sign-in asks for permission, then registers the token', () async {
      registrar.start();
      await session.signIn(signedInTokens);
      await settle();
      expect(messaging.permissionRequests, 1);
      expect(devices.calls.single.fcmToken, 'tok-1');
    });

    test(
      'denied permission still registers (opt-in later in settings)',
      () async {
        messaging.permissionGranted = false;
        registrar.start();
        await session.signIn(signedInTokens);
        await settle();
        expect(devices.calls, hasLength(1));
      },
    );

    test('an app start while signed in registers without asking', () async {
      await session.signIn(signedInTokens);
      registrar.start();
      await settle();
      expect(messaging.permissionRequests, 0);
      expect(devices.calls.single.fcmToken, 'tok-1');
    });

    test('a token refresh registers the new token', () async {
      await session.signIn(signedInTokens);
      registrar.start();
      await settle();
      messaging.rotate('tok-2');
      await settle();
      expect(devices.calls.map((c) => c.fcmToken), ['tok-1', 'tok-2']);
    });

    test('sign-out deletes the local token; the next sign-in registers a '
        'new one', () async {
      await session.signIn(signedInTokens);
      registrar.start();
      await settle();
      await session.signOut();
      await settle();
      expect(messaging.tokenDeletions, 1);
      expect(registrar.registered, isNull);
      expect(registrar.token, isNull);

      await session.signIn(signedInTokens);
      await settle();
      expect(devices.calls.map((c) => c.fcmToken), ['tok-1', 'tok-new-1']);
    });

    test('push off: no prompt, no registration, no delete', () async {
      final noop = PushRegistrar(
        messaging: const NoopPushMessaging(),
        devices: devices,
        clientInfo: testClientInfo,
        session: session,
      )..start();
      addTearDown(noop.dispose);
      await session.signIn(signedInTokens);
      await settle();
      await session.signOut();
      await settle();
      expect(devices.calls, isEmpty);
    });
  });

  group('taps from FCM payloads route through deep links', () {
    late SessionManager session;
    late _MockRouter router;

    setUp(() async {
      session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: _NoRefresh(),
      );
      await session.restore();
      await session.signIn(signedInTokens);
      router = _MockRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
    });

    Future<FirebasePushMessaging> started(
      _FakeFcm fcm,
      _FakeLocal local,
    ) async {
      final push = FirebasePushMessaging(fcm: fcm, local: local, texts: texts);
      await push.start();
      final tapRouter = NotificationTapRouter(
        messaging: push,
        router: router,
        session: session,
        launch: LaunchState(onboardingSeen: true)..markReady(),
        trackingAvailable: () => true,
        ratingAvailable: () => true,
        supportAvailable: () => true,
      )..start();
      addTearDown(tapRouter.dispose);
      addTearDown(push.dispose);
      addTearDown(fcm.close);
      return push;
    }

    test('foreground order push tapped: order tracking', () async {
      final fcm = _FakeFcm();
      final local = _FakeLocal();
      await started(fcm, local);
      fcm.foreground.add(
        const IncomingPush(
          title: 'Out for delivery',
          data: {'type': 'order', 'order_id': '1203'},
        ),
      );
      await pumpEventQueue();
      local.tap(local.shown.single.payload);
      await pumpEventQueue();
      verify(() => router.push<Object?>('/orders/1203/track')).called(1);
    });

    test('background taps: ticket, link, product', () async {
      final fcm = _FakeFcm();
      await started(fcm, _FakeLocal());
      fcm.opened
        ..add({'type': 'ticket', 'ticket_id': '4'})
        ..add({'link': 'jivo://orders/9/rate'})
        ..add({'type': 'product', 'slug': 'jivo-ghee'})
        ..add({'link': 'https://evil.example/orders/1'});
      await pumpEventQueue();
      verifyInOrder([
        () => router.push<Object?>('/account/help/tickets/4'),
        () => router.push<Object?>('/orders/9/rate'),
        () => router.push<Object?>('/product/jivo-ghee'),
      ]);
      verifyNoMoreInteractions(router);
    });

    test('a cold start from a notification opens its screen', () async {
      final fcm = _FakeFcm()..initial = {'type': 'order', 'order_id': '5'};
      await started(fcm, _FakeLocal());
      await pumpEventQueue();
      verify(() => router.push<Object?>('/orders/5/track')).called(1);
    });

    test('the same payloads map like deep links', () {
      expect(
        notificationLocation(const {
          'link': 'jivo://support/tickets',
        }, supportAvailable: true),
        '/account/help/tickets',
      );
    });
  });

  group('the first order asks for notification permission', () {
    testWidgets('once, on the order-placed screen; never on cold start', (
      tester,
    ) async {
      final push = FakePushMessaging(token: 'tok-1');
      addTearDown(push.close);
      final devices = FakeDeviceRepository();
      final app = TestApp(
        tokens: signedInTokens,
        extraOverrides: [
          pushMessagingProvider.overrideWithValue(push),
          deviceRepositoryProvider.overrideWithValue(devices),
        ],
      );
      await app.cart.setQuantity(
        101,
        2,
        preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
      );
      await openCheckout(tester, app);
      expect(push.permissionRequests, 0, reason: 'cold start never asks');
      expect(devices.calls.single.fcmToken, 'tok-1');

      await tester.tap(find.byKey(const Key('pay-cod')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderSuccessScreen), findsOneWidget);
      expect(push.permissionRequests, 1);
    });
  });
}

class _FakeFcm implements FcmClient {
  final foreground = StreamController<IncomingPush>.broadcast();
  final opened = StreamController<Map<String, Object?>>.broadcast();
  final refresh = StreamController<String>.broadcast();
  Map<String, Object?>? initial;
  bool grant = true;
  bool failPermission = false;
  bool failToken = false;
  int permissionRequests = 0;
  int deletes = 0;

  Future<void> close() async {
    await foreground.close();
    await opened.close();
    await refresh.close();
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    if (failPermission) throw Exception('no activity');
    return grant;
  }

  @override
  Future<String?> getToken() async {
    if (failToken) throw Exception('SERVICE_NOT_AVAILABLE');
    return 'fcm-1';
  }

  @override
  Future<void> deleteToken() async => deletes++;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<IncomingPush> get onForegroundMessage => foreground.stream;

  @override
  Stream<Map<String, Object?>> get onMessageOpenedApp => opened.stream;

  @override
  Future<Map<String, Object?>?> initialMessageData() async => initial;
}

typedef _Shown = ({
  int id,
  String title,
  String body,
  PushChannel channel,
  String payload,
});

class _FakeLocal implements LocalNotifier {
  bool initialized = false;
  bool failInit = false;
  PushChannelTexts? channelTexts;
  String? launch;
  final List<_Shown> shown = [];
  void Function(String? payload)? _onTap;

  void tap(String? payload) => _onTap?.call(payload);

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (failInit) throw Exception('plugin missing');
    initialized = true;
    _onTap = onTap;
  }

  @override
  Future<void> createChannels(PushChannelTexts texts) async =>
      channelTexts = texts;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required PushChannel channel,
    required PushChannelTexts texts,
    required String payload,
  }) async => shown.add((
    id: id,
    title: title,
    body: body,
    channel: channel,
    payload: payload,
  ));

  @override
  Future<String?> launchPayload() async => launch;
}

class _NoRefresh implements TokenRefresher {
  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      throw const ApiError(code: ApiErrorCode.tokenInvalid);
}

class _MockRouter extends Mock implements GoRouter {}
