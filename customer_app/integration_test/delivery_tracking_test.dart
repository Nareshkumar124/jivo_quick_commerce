// Phase 5 end-to-end delivery, customer side (T-516, `development-phase.md`
// §3 Phase 5, §7): the customer follows an order through dispatch, pickup
// and delivery on the order detail, which polls `GET /orders/{id}/track/`
// every 10 s. While the order is OUT_FOR_DELIVERY the detail shows the
// rider and the delivery OTP, which the rider (rider app, or
// `simulate_rider`) enters at the door; the order then turns DELIVERED.
//
// Against the real backend (dev flavor, the PM's device run): place a COD
// order for the test customer first (checkout, or the API), then
//   flutter test integration_test/delivery_tracking_test.dart --flavor dev \
//     -d <device> --dart-define=API_BASE_URL=http://localhost:8001 \
//     --dart-define=ORDER_ID=<id>
// and drive the rider side (accept → pickup → arrive → OTP) while it waits.
// It logs `DELIVERY otp=<code>` when the OTP appears, for the rider step.
// WAIT_MINUTES (default 15) bounds the wait.
//
// On fakes (no backend): --dart-define=FAKE_API=true runs the same steps on
// the fake tracker (confirmed → packing → riding → delivered) with a fast
// poll. The output's `DELIVERY mode=` line says which one ran.
import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/app/router.dart';
import 'package:customer_app/features/auth/presentation/login_screen.dart';
import 'package:customer_app/features/auth/presentation/otp_screen.dart';
import 'package:customer_app/features/home/presentation/banner_carousel.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/profile/presentation/profile_form.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

const phoneDigits = String.fromEnvironment(
  'TEST_PHONE',
  defaultValue: '9000000001',
);
const otp = String.fromEnvironment('TEST_OTP', defaultValue: '123456');
const orderIdDefine = int.fromEnvironment('ORDER_ID');
const waitMinutes = int.fromEnvironment('WAIT_MINUTES', defaultValue: 15);

void log(String line) => debugPrint('DELIVERY $line');

/// Counts the track polls that went over the wire.
class _TrackCounter extends Interceptor {
  int polls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.endsWith('/track/')) polls++;
    handler.next(options);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'delivery: the order detail shows the rider and OTP, then delivered',
    timeout: const Timeout(Duration(minutes: waitMinutes + 3)),
    (tester) async {
      final env = AppEnv.fromEnvironment(Flavor.dev);
      final fake = env.useFakeApi;
      log('mode=${fake ? 'fake' : 'real'} api=${env.apiBaseUrl}');
      if (!fake && orderIdDefine == 0) {
        fail('Pass --dart-define=ORDER_ID=<an active COD order id>.');
      }

      final clientInfo = await ClientInfo.fromPlatform(
        appName: customerAppName,
      );
      await initializeFormatting();
      SharedPreferences.setMockInitialValues({
        'installed': true,
        'onboarding_seen': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final session = createSession(
        env: env,
        clientInfo: clientInfo,
        store: InMemoryTokenStore(),
      );
      await session.restore();

      await tester.pumpWidget(
        customerAppRoot(
          env: env,
          clientInfo: clientInfo,
          session: session,
          signals: AppControlSignals(),
          prefs: prefs,
          overrides: [
            otpAutofillProvider.overrideWithValue(FakeOtpAutofill()),
            bannerAutoScrollProvider.overrideWithValue(null),
            if (fake)
              trackPollIntervalProvider.overrideWithValue(
                const Duration(milliseconds: 400),
              ),
          ],
        ),
      );

      // 1. Log in as the test customer.
      await pumpUntilFound(tester, find.byKey(LoginScreen.phoneFieldKey));
      final container = ProviderScope.containerOf(
        tester.element(find.byKey(LoginScreen.phoneFieldKey)),
      );
      final counter = _TrackCounter();
      container.read(dioProvider).interceptors.add(counter);
      await tester.enterText(
        find.byKey(LoginScreen.phoneFieldKey),
        phoneDigits,
      );
      await tester.tap(find.text('Get OTP'));
      await pumpUntilFound(tester, find.byKey(OtpScreen.otpFieldKey));
      await tester.enterText(find.byKey(OtpScreen.otpFieldKey), otp);
      final profile = find.byKey(ProfileForm.nameFieldKey);
      await pumpUntilFound(
        tester,
        find.byWidgetPredicate(
          (w) =>
              w.key == const Key('home-screen') ||
              w.key == ProfileForm.nameFieldKey,
        ),
      );
      if (profile.evaluate().isNotEmpty) {
        await tester.enterText(profile, 'Delivery Tester');
        await tester.tap(find.text('Continue'));
        await pumpUntilFound(tester, find.byKey(const Key('home-screen')));
      }
      expect(container.read(trackingAvailableProvider), isTrue);

      // 2. Open the order detail (a seeded active order on fakes).
      final orderId = fake
          ? container
                .read(fakeCommerceBackendProvider)
                .orders
                .firstWhere((o) => o.status.isActive)
                .id
          : orderIdDefine;
      container.read(routerProvider).push('/orders/$orderId');
      await pumpUntilFound(tester, find.byKey(const Key('order-detail')));
      log('order=$orderId');

      // 3. Wait for OUT_FOR_DELIVERY: rider card and delivery OTP.
      final deadline = DateTime.now().add(
        const Duration(minutes: waitMinutes),
      );
      Future<void> waitFor(Finder finder, String what) async {
        while (finder.evaluate().isEmpty) {
          if (DateTime.now().isAfter(deadline)) {
            fail('timed out waiting for $what (polls=${counter.polls})');
          }
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.pump();
      }

      await waitFor(find.byKey(const Key('delivery-otp-code')), 'the OTP');
      final code = tester
          .widget<Text>(find.byKey(const Key('delivery-otp-code')))
          .data;
      log('otp=$code polls=${counter.polls}');
      expect(code, matches(RegExp(r'^\d{4,6}$')));
      expect(find.byKey(const Key('rider-card')), findsOneWidget);

      // 4. The rider enters the OTP; the order turns DELIVERED and the OTP
      // goes away. (On fakes only the tracker moves: the fake order stays
      // as seeded, so the tracked status is checked instead.)
      if (fake) {
        while (container.read(trackProvider(orderId)).value?.status !=
            OrderStatus.delivered) {
          if (DateTime.now().isAfter(deadline)) fail('timed out (fake)');
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.pump();
        expect(find.byKey(const Key('delivery-otp')), findsNothing);
      } else {
        await waitFor(
          find.descendant(
            of: find.byKey(const Key('order-status')),
            matching: find.text('Delivered'),
          ),
          'DELIVERED',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('delivery-otp')), findsNothing);
        expect(find.byKey(const Key('rider-card')), findsNothing);
        expect(counter.polls, greaterThan(0));
      }
      log('delivered polls=${counter.polls}');

      // Leave the detail so polling stops.
      container.read(routerProvider).go('/home');
      await tester.pumpAndSettle();
    },
  );
}
