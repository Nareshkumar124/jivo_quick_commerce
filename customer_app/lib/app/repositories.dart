import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart' show Flavor;

import '../features/addresses/data/address_repository.dart';
import '../features/addresses/data/device_location.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/otp_autofill.dart';
import '../features/cart/data/cart_repository.dart';
import '../features/catalog/data/api_catalog_repository.dart';
import '../features/catalog/data/catalog_repository.dart';
import '../features/catalog/data/fake_catalog_repository.dart';
import '../features/launch/data/config_repository.dart';
import '../features/location/data/api_serviceability_repository.dart';
import '../features/location/data/delivery_location_store.dart';
import '../features/location/data/maps_availability.dart';
import '../features/location/data/reverse_geocoder.dart';
import '../features/location/data/serviceability_repository.dart';
import '../features/location/presentation/delivery_controller.dart';
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

/// Whether this build has a cart. The server cart arrives in Phase 3; until
/// then only the dev flavor keeps one in memory, and staging/prod show
/// "cart coming soon" instead of ADD (DL-30/DL-32).
final cartAvailableProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).flavor == Flavor.dev,
);

/// TODO(P3): the server cart (`06 §2.5`).
final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => ref.watch(cartAvailableProvider)
      ? InMemoryCartRepository()
      : const UnavailableCartRepository(),
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
