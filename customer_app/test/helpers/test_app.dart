import 'dart:async';
import 'dart:convert';

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/app/providers.dart';
import 'package:customer_app/features/addresses/data/address_repository.dart';
import 'package:customer_app/features/addresses/data/device_location.dart';
import 'package:customer_app/features/auth/data/auth_repository.dart';
import 'package:customer_app/features/auth/data/fake_token_refresher.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/catalog/data/fake_catalog_repository.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/data/payment_launcher.dart';
import 'package:customer_app/features/home/presentation/banner_carousel.dart';
import 'package:customer_app/features/launch/data/config_repository.dart';
import 'package:customer_app/features/location/data/delivery_location_store.dart';
import 'package:customer_app/features/location/data/maps_availability.dart';
import 'package:customer_app/features/location/data/reverse_geocoder.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/notifications/data/notification_repository.dart';
import 'package:customer_app/features/profile/data/profile_repository.dart';
import 'package:customer_app/features/tracking/data/order_socket.dart';
import 'package:customer_app/features/tracking/presentation/order_live.dart';
import 'package:customer_app/shared/connectivity/connectivity.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_config.dart';

const signedInTokens = AuthTokens(access: 'a1', refresh: 'r1');

/// A saved delivery location inside the fake store's area.
const testDeliveryLocation = DeliveryLocation(
  point: FakeServiceabilityRepository.storeLocation,
  title: 'Home',
  subtitle: 'Flat 4B, MG Road, New Delhi',
  addressId: 1,
);

/// The whole app on fakes: no plugin, network or platform channel is used.
class TestApp {
  TestApp({
    this.tokens,
    this.onboardingSeen = true,
    this.appVersion = '1.0.0',
    this.deliveryLocation = testDeliveryLocation,
    this.mapsAvailable = false,
    this.extraOverrides = const [],
    String? autofillCode,
    FakeCommerceBackend? commerce,
    this.cartRepository,
    this.realtime = const DisabledOrderRealtime(),
    this.notifications = const UnavailableNotificationRepository(),
  }) : autofill = FakeOtpAutofill(autofillCode),
       cart = commerce ?? FakeCommerceBackend(latency: Duration.zero);

  final AuthTokens? tokens;
  final bool onboardingSeen;
  final String appVersion;

  /// The remembered delivery location; null starts without one.
  final DeliveryLocation? deliveryLocation;
  final bool mapsAvailable;

  /// Added after the defaults (e.g. a fake map view).
  final List<Override> extraOverrides;

  final config = FakeConfigRepository();
  final auth = FakeAuthRepository();
  final profile = FakeProfileRepository();
  final addresses = FakeAddressRepository();
  final location = FakeDeviceLocation();
  final catalog = FakeCatalogRepository(latency: Duration.zero);
  final serviceability = FakeServiceabilityRepository(latency: Duration.zero);

  /// The fake server cart and orders (one instance, like the server).
  final FakeCommerceBackend cart;

  /// The order sockets (off unless a test scripts them).
  final OrderRealtime realtime;

  /// The inbox (empty unless a test gives one; never the network).
  final NotificationRepository notifications;

  /// Replaces [cart] as the cart repository only (orders stay on [cart]).
  final CartRepository? cartRepository;

  /// How the fake payment sheet answers (no sheet in widget tests).
  FakePaymentChoice Function(PaymentRequest request) onPay = (_) =>
      FakePaymentChoice.succeed;
  late final payments = FakePaymentLauncher(
    choose: (request) async => onPay(request),
  );
  final geocoder = FakeReverseGeocoder();
  final FakeOtpAutofill autofill;
  final urls = FakeUrlOpener();
  final refresher = FakeTokenRefresher();
  final connectivity = StreamController<bool>.broadcast();
  final store = InMemoryTokenStore();
  late final SessionManager session;
  final signals = AppControlSignals();

  Future<void> pump(WidgetTester tester, {bool settle = true}) async {
    SharedPreferences.setMockInitialValues({
      'installed': true,
      'onboarding_seen': onboardingSeen,
      if (deliveryLocation != null)
        DeliveryLocationStore.key: jsonEncode(deliveryLocation!.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    if (tokens != null) await store.write(tokens!);
    session = SessionManager(store: store, refresher: refresher);
    await session.restore();
    addTearDown(connectivity.close);

    await tester.pumpWidget(
      customerAppRoot(
        env: testEnv,
        clientInfo: ClientInfo(
          appName: 'customer',
          appVersion: appVersion,
          platform: 'android',
        ),
        session: session,
        signals: signals,
        prefs: prefs,
        overrides: [
          configRepositoryProvider.overrideWithValue(config),
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profile),
          addressRepositoryProvider.overrideWithValue(addresses),
          deviceLocationProvider.overrideWithValue(location),
          otpAutofillProvider.overrideWithValue(autofill),
          urlOpenerProvider.overrideWithValue(urls),
          connectivityStreamProvider.overrideWithValue(connectivity.stream),
          catalogRepositoryProvider.overrideWithValue(catalog),
          serviceabilityRepositoryProvider.overrideWithValue(serviceability),
          cartRepositoryProvider.overrideWithValue(cartRepository ?? cart),
          orderRepositoryProvider.overrideWithValue(cart),
          orderHistoryRepositoryProvider.overrideWithValue(cart),
          paymentLauncherProvider.overrideWithValue(payments),
          mapsAvailabilityProvider.overrideWithValue(
            FakeMapsAvailability(available: mapsAvailable),
          ),
          reverseGeocoderProvider.overrideWithValue(geocoder),
          bannerAutoScrollProvider.overrideWithValue(null),
          orderRealtimeProvider.overrideWithValue(realtime),
          notificationRepositoryProvider.overrideWithValue(notifications),
          ...extraOverrides,
        ],
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}

/// Types the phone, taps Get OTP and lands on the OTP screen.
Future<void> loginToOtp(WidgetTester tester, String digits) async {
  await tester.enterText(find.byKey(const Key('login-phone')), digits);
  await tester.tap(find.text('Get OTP'));
  await tester.pumpAndSettle();
}
