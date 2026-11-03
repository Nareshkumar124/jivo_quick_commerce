import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart' show Flavor;

import '../features/addresses/data/address_repository.dart';
import '../features/addresses/data/device_location.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/otp_autofill.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/cart/data/fake_commerce_backend.dart';
import '../features/catalog/data/api_catalog_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/checkout/data/fake_payment_launcher.dart';
import '../features/checkout/data/payment_flow.dart';
import '../features/checkout/data/payment_launcher.dart';
import '../features/checkout/data/razorpay_payment_launcher.dart';
import '../features/checkout/domain/idempotency_key.dart';
import '../features/launch/data/config_repository.dart';
import '../features/location/data/api_serviceability_repository.dart';
import '../features/location/data/delivery_location_store.dart';
import '../features/location/data/maps_availability.dart';
import '../features/location/data/reverse_geocoder.dart';
import '../features/location/data/serviceability_repository.dart';
import '../features/location/presentation/delivery_controller.dart';
import '../features/orders/data/order_repository.dart';
import '../features/profile/data/profile_repository.dart';
import 'providers.dart';

/// Repositories: the API implementation, or a fake with `FAKE_API=true` in
/// the dev flavor only (never staging or prod). Tests override these
/// providers.
bool _fake(Ref ref) {
  final env = ref.watch(appEnvProvider);
  return env.useFakeApi && env.flavor == Flavor.dev;
}

final configRepositoryProvider = Provider<ConfigRepository>(
  (ref) => _fake(ref)
      ? FakeConfigRepository()
      : ApiConfigRepository(ref.watch(jivoApiProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => _fake(ref)
      ? FakeAuthRepository()
      : ApiAuthRepository(ref.watch(jivoApiProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => _fake(ref)
      ? FakeProfileRepository()
      : ApiProfileRepository(ref.watch(jivoApiProvider)),
);

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => _fake(ref)
      ? FakeAddressRepository()
      : ApiAddressRepository(ref.watch(jivoApiProvider)),
);

final deviceLocationProvider = Provider<DeviceLocation>(
  (ref) => const GeolocatorDeviceLocation(),
);

final otpAutofillProvider = Provider<OtpAutofill>(
  (ref) => SmartAuthOtpAutofill(),
);

/// The catalog for the serving store (`06 §2.4`), or the placeholder
/// catalog with `FAKE_API`.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => _fake(ref)
      ? FakeCatalogRepository()
      : ApiCatalogRepository(
          ref.watch(jivoApiProvider),
          () => ref.read(currentStoreIdProvider),
        ),
);

/// Serviceability and notify-me (`06 §2.3`).
final serviceabilityRepositoryProvider = Provider<ServiceabilityRepository>(
  (ref) => _fake(ref)
      ? FakeServiceabilityRepository()
      : ApiServiceabilityRepository(ref.watch(jivoApiProvider)),
);

/// Whether this build has a cart. Until the Phase 3 cart API is wired
/// (S3-A), only the dev flavor has one (the fake backend below), and
/// staging/prod show "cart coming soon" instead of ADD (DL-30/DL-32).
final cartAvailableProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).flavor == Flavor.dev,
);

/// TODO(api): the stand-in for the server cart and orders (`06 §2.5`,
/// `§2.6`) in the dev flavor until S3-A. One instance serves both
/// repositories, so placing an order clears the cart. Never built for
/// staging or prod: the providers below only read it when
/// [cartAvailableProvider] is true.
final fakeCommerceBackendProvider = Provider<FakeCommerceBackend>(
  (ref) => FakeCommerceBackend(),
);

/// TODO(api): the server cart (`06 §2.5`) at S3-A.
final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => ref.watch(cartAvailableProvider)
      ? ref.watch(fakeCommerceBackendProvider)
      : const UnavailableCartRepository(),
);

/// TODO(api): `POST /orders/`, verify, retry-payment and cancel (`06 §2.6`)
/// at S3-A.
final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ref.watch(cartAvailableProvider)
      ? ref.watch(fakeCommerceBackendProvider)
      : const UnavailableOrderRepository(),
);

/// The root navigator, for sheets opened outside a widget (the dev fake
/// payment sheet).
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

/// Razorpay checkout; in the dev flavor a fake sheet, because there are no
/// Razorpay test keys yet (D-01). TODO(api): the dev flavor keeps the fake
/// against the backend's fake gateway once its signature scheme is known.
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  if (ref.watch(appEnvProvider).flavor != Flavor.dev) {
    return RazorpayPaymentLauncher();
  }
  final navigatorKey = ref.watch(rootNavigatorKeyProvider);
  return FakePaymentLauncher(
    choose: (request) => showFakePaymentSheet(navigatorKey, request),
  );
});

final paymentFlowProvider = Provider<PaymentFlow>(
  (ref) => PaymentFlow(
    orders: ref.watch(orderRepositoryProvider),
    launcher: ref.watch(paymentLauncherProvider),
  ),
);

/// Makes `Idempotency-Key` values (tests override it).
final idempotencyKeyProvider = Provider<String Function()>(
  (ref) => newIdempotencyKey,
);

/// Whether this build can show a Mappls map (D-03); see README.
final mapsAvailabilityProvider = Provider<MapsAvailability>(
  (ref) => const PlatformMapsAvailability(),
);

/// The address under the map pin (Mappls reverse geocoding, D-03).
final reverseGeocoderProvider = Provider<ReverseGeocoder>(
  (ref) => const MapplsReverseGeocoder(),
);

final deliveryLocationStoreProvider = Provider<DeliveryLocationStore>(
  (ref) => DeliveryLocationStore(ref.watch(sharedPreferencesProvider)),
);
