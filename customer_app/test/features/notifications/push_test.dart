import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/notifications/data/device_repository.dart';
import 'package:customer_app/features/notifications/data/push_messaging.dart';
import 'package:customer_app/app/launch_state.dart';
import 'package:customer_app/features/notifications/presentation/notification_tap_router.dart';
import 'package:customer_app/features/notifications/presentation/push_registration.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/support/data/support_repository.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/fake_http.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_config.dart';

/// FCM token registration (`POST /me/devices/`) and notification taps.
void main() {
  group('ApiDeviceRepository', () {
    test('registers the token for the customer app', () async {
      final http = FakeHttp(
        (_) => (
          200,
          {
            'id': 7,
            'fcm_token': 'tok-1',
            'app': 'customer',
            'platform': 'ios',
            'app_version': '1.0.0+1',
            'is_active': true,
            'last_seen_at': '2026-11-04T10:00:00Z',
          },
        ),
      );
      await ApiDeviceRepository(http.api()).register(
        fcmToken: 'tok-1',
        platform: 'ios',
        appVersion: '1.0.0+1',
      );
      expect(http.requests.single.path, '/api/v1/me/devices/');
      expect(http.requests.single.method, 'POST');
      expect(http.body(0), {
        'fcm_token': 'tok-1',
        'app': 'customer',
        'platform': 'ios',
        'app_version': '1.0.0+1',
      });
    });

    test('maps the error envelope', () async {
      final http = FakeHttp(
        (_) => (
          400,
          {
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Some fields are invalid.',
              'details': <String, Object?>{},
            },
          },
        ),
      );
      expect(
        ApiDeviceRepository(http.api()).register(
          fcmToken: 't',
          platform: 'android',
          appVersion: 'x',
        ),
        throwsA(
          isA<ApiError>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.validationError,
          ),
        ),
      );
    });
  });

  test('logout sends the push token when there is one', () async {
    final http = FakeHttp((_) => (204, null));
    await ApiAuthRepository(http.api()).logout('r1', fcmToken: 'tok-1');
    expect(http.body(0), {'refresh': 'r1', 'fcm_token': 'tok-1'});
  });

  group('PushRegistrar', () {
    late SessionManager session;
    late FakePushMessaging messaging;
    late FakeDeviceRepository devices;
    late PushRegistrar registrar;

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: _NoRefresh(),
      );
      await session.restore();
      messaging = FakePushMessaging(token: 'tok-1');
      devices = FakeDeviceRepository();
      registrar = PushRegistrar(
        messaging: messaging,
        devices: devices,
        clientInfo: testClientInfo,
        session: session,
      );
      addTearDown(registrar.dispose);
      addTearDown(messaging.close);
    });

    test('signed out: nothing is registered until sign-in', () async {
      registrar.start();
      await settle();
      expect(devices.calls, isEmpty);

      await session.signIn(signedInTokens);
      await settle();
      await settle();
      expect(devices.calls.single, (
        fcmToken: 'tok-1',
        platform: 'android',
        appVersion: '1.0.0+1',
      ));
      expect(messaging.permissionRequests, 1);
    });

    test('signed in at start: registers once; a refresh re-registers', () async {
      await session.signIn(signedInTokens);
      registrar.start();
      await settle();
      await registrar.sync();
      expect(devices.calls, hasLength(1), reason: 'same token, same session');

      messaging.rotate('tok-2');
      await settle();
      await settle();
      expect(devices.calls.map((c) => c.fcmToken), ['tok-1', 'tok-2']);
      expect(registrar.token, 'tok-2');
    });

    test('a failed call is retried at the next trigger', () async {
      await session.signIn(signedInTokens);
      devices.failNext = const ApiError(code: ApiErrorCode.network);
      await registrar.sync();
      expect(devices.calls, isEmpty);
      expect(registrar.registered, isNull);

      await registrar.sync();
      expect(devices.calls, hasLength(1));
    });

    test('sign-out forgets the registration; the next sign-in sends it '
        'again (the token may move to another user)', () async {
      await session.signIn(signedInTokens);
      registrar.start();
      await settle();
      await settle();
      await session.signOut();
      await settle();
      expect(registrar.registered, isNull);
      await session.signIn(signedInTokens);
      await settle();
      await settle();
      expect(devices.calls, hasLength(2));
    });

    test('no push provider: no permission prompt, no call', () async {
      await session.signIn(signedInTokens);
      final noop = PushRegistrar(
        messaging: const NoopPushMessaging(),
        devices: devices,
        clientInfo: testClientInfo,
        session: session,
      )..start();
      addTearDown(noop.dispose);
      await noop.sync();
      expect(devices.calls, isEmpty);
    });

    test('no token (permission or provider unavailable): no call', () async {
      await session.signIn(signedInTokens);
      messaging.token = null;
      await registrar.sync();
      expect(devices.calls, isEmpty);
    });
  });

  group('NotificationTapRouter', () {
    test('a tap while signed out is dropped, not opened for the next user',
        () async {
      final session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: _NoRefresh(),
      );
      await session.restore();
      final launch = LaunchState(onboardingSeen: true)..markReady();
      final router = _MockRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
      final push = FakePushMessaging(token: 't');
      final tapRouter = NotificationTapRouter(
        messaging: push,
        router: router,
        session: session,
        launch: launch,
        trackingAvailable: () => true,
      )..start();
      addTearDown(tapRouter.dispose);
      addTearDown(push.close);

      tapRouter.handle({'type': 'order', 'order_id': 5});
      expect(tapRouter.pending, isNull);

      await session.signIn(signedInTokens);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => router.push<Object?>(any()));
      verifyNever(() => router.go(any()));

      // Signed in now: a tap opens right away.
      tapRouter.handle({'type': 'order', 'order_id': 5});
      verify(() => router.push<Object?>('/orders/5/track')).called(1);
    });

    test('a tap during start-up is held, then opened once in the app',
        () async {
      final session = SessionManager(
        store: InMemoryTokenStore(),
        refresher: _NoRefresh(),
      );
      await session.restore();
      await session.signIn(signedInTokens);
      final launch = LaunchState(onboardingSeen: true);
      final router = _MockRouter();
      when(() => router.push<Object?>(any())).thenAnswer((_) async => null);
      final tapRouter = NotificationTapRouter(
        messaging: const NoopPushMessaging(),
        router: router,
        session: session,
        launch: launch,
        trackingAvailable: () => false,
      );
      tapRouter.handle({'type': 'product', 'slug': 'jivo-ghee'});
      expect(tapRouter.pending, '/product/jivo-ghee');
      launch.addListener(tapRouter.flushForTest);
      launch.markReady();
      verify(() => router.go('/home')).called(1);
      verify(() => router.push<Object?>('/product/jivo-ghee')).called(1);
      expect(tapRouter.pending, isNull);
    });
  });

  group('notification taps', () {
    late FakeCommerceBackend backend;
    setUp(() {
      backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
    });

    TestApp app(FakePushMessaging push, FakeDeviceRepository devices) =>
        TestApp(
          tokens: signedInTokens,
          commerce: backend,
          extraOverrides: [
            pushMessagingProvider.overrideWithValue(push),
            deviceRepositoryProvider.overrideWithValue(devices),
            trackingAvailableProvider.overrideWithValue(true),
            trackRepositoryProvider.overrideWithValue(FakeTrackRepository()),
            trackPollIntervalProvider.overrideWithValue(Duration.zero),
          ],
        );

    testWidgets('the app registers the device after start-up', (
      tester,
    ) async {
      final push = FakePushMessaging(token: 'tok-9');
      final devices = FakeDeviceRepository();
      await app(push, devices).pump(tester);
      expect(devices.calls.single.fcmToken, 'tok-9');
    });

    testWidgets('a tap while running opens the product', (tester) async {
      final push = FakePushMessaging(token: 't');
      await app(push, FakeDeviceRepository()).pump(tester);
      push.tap({'type': 'product', 'slug': 'jivo-canola-oil'});
      await tester.pumpAndSettle();
      expect(find.text('Jivo Canola Oil'), findsWidgets);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('the launching notification opens order tracking after '
        'start-up', (tester) async {
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
      final push = FakePushMessaging(
        token: 't',
        initialNotification: {'type': 'order', 'order_id': '$id'},
      );
      await app(push, FakeDeviceRepository()).pump(tester);
      expect(find.byKey(const Key('tracking')), findsOneWidget);
    });

    testWidgets('a support reply push (support.ticket_replied: type ticket + '
        'ticket_id) opens the ticket', (tester) async {
      final push = FakePushMessaging(token: 't');
      await TestApp(
        tokens: signedInTokens,
        commerce: backend,
        extraOverrides: [
          pushMessagingProvider.overrideWithValue(push),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
          supportAvailableProvider.overrideWithValue(true),
          supportRepositoryProvider.overrideWithValue(FakeSupportRepository()),
        ],
      ).pump(tester);
      // The FCM data payload exactly as the backend's fcm_payload sends it.
      push.tap({'type': 'ticket', 'ticket_id': '1'});
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ticket-thread')), findsOneWidget);
      expect(find.text('TK-000001'), findsOneWidget);
    });

    testWidgets('an unknown payload is ignored', (tester) async {
      final push = FakePushMessaging(token: 't');
      await app(push, FakeDeviceRepository()).pump(tester);
      push.tap({'type': 'promo'});
      push.tap({'link': 'https://evil.example/orders/1'});
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsNothing);
    });
  });
}

class _NoRefresh implements TokenRefresher {
  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      throw const ApiError(code: ApiErrorCode.tokenInvalid);
}

class _MockRouter extends Mock implements GoRouter {}
