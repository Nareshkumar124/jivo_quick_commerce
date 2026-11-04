import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart' show Flavor;

import '../features/addresses/data/address_repository.dart';
import '../features/addresses/data/device_location.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/otp_autofill.dart';
import '../features/cart/data/api_cart_repository.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/cart/data/fake_commerce_backend.dart';
import '../features/catalog/data/api_catalog_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/checkout/data/fake_payment_launcher.dart';
import '../features/checkout/data/gateway_payment_launcher.dart';
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
import '../features/notifications/data/notification_repository.dart';
import '../features/orders/data/api_order_history_repository.dart';
import '../features/orders/data/api_order_repository.dart';
import '../features/orders/data/order_history_repository.dart';
import '../features/orders/data/order_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/tracking/data/track_repository.dart';
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

/// Whether this build has a cart: the dev flavor until the cart is proven
/// against the real backend at S3-B. Staging and prod show "cart coming
/// soon" instead of ADD (DL-30/DL-32).
final cartAvailableProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).flavor == Flavor.dev,
);

/// The stand-in for the server cart and orders (`06 §2.5`, `§2.6`) for the
/// dev flavor's `FAKE_API=true` and tests. One instance serves both
/// repositories, so placing an order clears the cart. Never built for
/// staging or prod.
final fakeCommerceBackendProvider = Provider<FakeCommerceBackend>(
  (ref) => FakeCommerceBackend()..seedDemoOrders(),
);

/// The server cart (`06 §2.5`): the API in the dev flavor, the fake with
/// `FAKE_API=true`, nothing in staging/prod yet.
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  if (!ref.watch(cartAvailableProvider)) {
    return const UnavailableCartRepository();
  }
  if (_fake(ref)) return ref.watch(fakeCommerceBackendProvider);
  return ApiCartRepository(
    ref.watch(jivoApiProvider),
    () => ref.read(currentStoreIdProvider),
  );
});

/// Orders and payments (`06 §2.6`), wired like [cartRepositoryProvider].
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (!ref.watch(cartAvailableProvider)) {
    return const UnavailableOrderRepository();
  }
  if (_fake(ref)) return ref.watch(fakeCommerceBackendProvider);
  return ApiOrderRepository(
    ref.watch(jivoApiProvider),
    () => ref.read(currentStoreIdProvider),
  );
});

/// "My orders", order detail, cancel, reorder and invoice (`06 §2.6`),
/// wired like [orderRepositoryProvider].
final orderHistoryRepositoryProvider = Provider<OrderHistoryRepository>((ref) {
  if (!ref.watch(cartAvailableProvider)) {
    return const UnavailableOrderHistoryRepository();
  }
  if (_fake(ref)) return ref.watch(fakeCommerceBackendProvider);
  return ApiOrderHistoryRepository(
    ref.watch(jivoApiProvider),
    () => ref.read(currentStoreIdProvider),
  );
});

/// Whether this build can show live tracking. TODO(api): true only on
/// fakes until `GET /orders/{id}/track/` (Phase 5) is bound.
final trackingAvailableProvider = Provider<bool>((ref) => _fake(ref));

/// Live tracking data (Phase 6 lookahead on fakes).
final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) =>
      _fake(ref) ? FakeTrackRepository() : const UnavailableTrackRepository(),
);

/// The notification inbox (Phase 6 lookahead on fakes). TODO(api): bind the
/// inbox endpoints when the Phase 6 contract lands.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _fake(ref)
      ? FakeNotificationRepository()
      : const UnavailableNotificationRepository(),
);

/// The root navigator, for sheets opened outside a widget (the dev fake
/// payment sheet).
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

/// Razorpay checkout, chosen by the key the server sends: in the dev flavor
/// the server's local fake gateway (`rzp_fake_…`, `06 §2.6`) is paid with
/// the fake sheet; any other key opens real Razorpay. Staging and prod
/// never get the fake.
final paymentLauncherProvider = Provider<PaymentLauncher>((ref) {
  final flavor = ref.watch(appEnvProvider).flavor;
  final navigatorKey = ref.watch(rootNavigatorKeyProvider);
  return GatewayPaymentLauncher(
    flavor: flavor,
    real: RazorpayPaymentLauncher(),
    fake: flavor == Flavor.dev
        ? FakePaymentLauncher(
            choose: (request) => showFakePaymentSheet(navigatorKey, request),
          )
        : null,
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
