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
import '../features/cms/data/cms_repository.dart';
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
import '../features/rating/data/api_rating_repository.dart';
import '../features/rating/data/rating_repository.dart';
import '../features/referral/data/referral_repository.dart';
import '../features/rewards/data/rewards_repository.dart';
import '../features/support/data/api_support_repository.dart';
import '../features/support/data/support_repository.dart';
import '../features/support/data/ticket_photo_picker.dart';
import '../features/tracking/data/track_repository.dart';
import 'providers.dart';

/// Repositories: the API implementation, or a fake with `FAKE_API=true` in
/// the dev flavor only (never staging or prod). Tests override these
/// providers.
bool _fake(Ref ref) => isFakeApi(ref);

/// Whether this build runs on fakes (`FAKE_API=true`, dev flavor only).
bool isFakeApi(Ref ref) {
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

/// Refer a friend (`/account/referral/*`): the API, the fake with
/// `FAKE_API`.
final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => _fake(ref)
      ? FakeReferralRepository()
      : ApiReferralRepository(ref.watch(jivoApiProvider)),
);

/// Rewards (`GET /account/rewards/`, ADR 0002): the API, the demo fake with
/// `FAKE_API`.
final rewardsRepositoryProvider = Provider<RewardsRepository>(
  (ref) => _fake(ref)
      ? FakeRewardsRepository.demo()
      : ApiRewardsRepository(
          ref.watch(jivoApiProvider),
          () => ref.read(currentStoreIdProvider),
        ),
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

/// Whether this build has a cart, orders and tracking: every flavor since
/// the Play Store launch (2026-11-28; staging since 2026-11-13, prod was
/// off until launch, DL-30/DL-32). Tests override it to cover the
/// "cart coming soon" fallback.
final cartAvailableProvider = Provider<bool>((ref) => true);

/// The stand-in for the server cart and orders (`06 §2.5`, `§2.6`) for the
/// dev flavor's `FAKE_API=true` and tests. One instance serves both
/// repositories, so placing an order clears the cart. Never built for
/// staging or prod.
final fakeCommerceBackendProvider = Provider<FakeCommerceBackend>(
  (ref) =>
      FakeCommerceBackend(
          // The demo rules, plus "buy 10 get 1 free" (ADR 0002), every
          // free carton the 1 L size (ADR 0003).
          rules: FakeBillRules(
            freeUnitEvery: 10,
            freeUnitVariantId: FakeRewardsRepository.demoFreeVariant.id,
          ),
          variantLookup: fakeCatalogVariant,
        )
        ..rewardCoupons.add(
          const FakeCoupon.freeCarton(
            code: FakeRewardsRepository.welcomeCode,
            title: '2 free cartons',
            description: 'Free 1 L cartons',
            freeQuantity: FakeRewardsRepository.demoQuantity,
          ),
        )
        ..seedDemoOrders(),
);

/// The server cart (`06 §2.5`): the API in the dev flavor, the fake with
/// `FAKE_API=true` (dev only), nothing where [cartAvailableProvider] is off.
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

/// Whether this build can show live tracking: wherever orders exist (the
/// same switch as [cartAvailableProvider]); `GET /orders/{id}/track/`
/// is bound since P5.
final trackingAvailableProvider = Provider<bool>(
  (ref) => ref.watch(cartAvailableProvider),
);

/// Live tracking (`GET /orders/{id}/track/`, polled every 10 s): the API,
/// the fake with `FAKE_API`, nothing where there are no orders.
final trackRepositoryProvider = Provider<TrackRepository>((ref) {
  if (!ref.watch(trackingAvailableProvider)) {
    return const UnavailableTrackRepository();
  }
  if (_fake(ref)) return FakeTrackRepository();
  return ApiTrackRepository(ref.watch(jivoApiProvider));
});

/// The notification inbox (`/me/notifications/*`, P6): the API, the fake
/// with `FAKE_API`.
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => _fake(ref)
      ? FakeNotificationRepository()
      : ApiNotificationRepository(ref.watch(jivoApiProvider)),
);

/// Whether order rating is shown: in every flavor since the P7 ratings API
/// (`orders_rating_*`). Rating needs a delivered order, so it only appears
/// where orders exist.
final ratingAvailableProvider = Provider<bool>((ref) => true);

/// Order and rider ratings: the API in every flavor, the fake only with
/// `FAKE_API` in the dev flavor.
final ratingRepositoryProvider = Provider<RatingRepository>((ref) {
  if (_fake(ref)) return FakeRatingRepository();
  return ApiRatingRepository(ref.watch(jivoApiProvider));
});

/// Whether FAQs and support tickets are shown: every flavor since the Play
/// Store launch (2026-11-28; P7 support API, T-713). Tests override it.
final supportAvailableProvider = Provider<bool>((ref) => true);

/// FAQs and tickets: the API, the fake with `FAKE_API`.
final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (!ref.watch(supportAvailableProvider)) {
    return const UnavailableSupportRepository();
  }
  if (_fake(ref)) return FakeSupportRepository();
  return ApiSupportRepository(ref.watch(jivoApiProvider));
});

/// Camera or gallery for support ticket photos (tests override it).
final ticketPhotoPickerProvider = Provider<TicketPhotoPicker>(
  (ref) => ImagePickerTicketPhotoPicker(),
);

/// Whether the policy pages open in the in-app CMS viewer: every flavor
/// since the launch policy pages are live (2026-11-28, `load_legal_pages`).
/// A page the server lacks offers its web URL instead
/// ([PolicyLinks.forSlug]). When false (tests), the `config/app` policy
/// URLs open in the browser.
final cmsAvailableProvider = Provider<bool>((ref) => true);

/// CMS pages: the API, the fake with `FAKE_API`.
final cmsRepositoryProvider = Provider<CmsRepository>((ref) {
  if (!ref.watch(cmsAvailableProvider)) return const UnavailableCmsRepository();
  if (_fake(ref)) return FakeCmsRepository();
  return ApiCmsRepository(ref.watch(jivoApiProvider));
});

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

/// Whether this build can show a Google map (DL-80); see README.
final mapsAvailabilityProvider = Provider<MapsAvailability>(
  (ref) => const PlatformMapsAvailability(),
);

/// The address under the map pin (platform geocoder, DL-80).
final reverseGeocoderProvider = Provider<ReverseGeocoder>(
  (ref) => const PlatformReverseGeocoder(),
);

final deliveryLocationStoreProvider = Provider<DeliveryLocationStore>(
  (ref) => DeliveryLocationStore(ref.watch(sharedPreferencesProvider)),
);
