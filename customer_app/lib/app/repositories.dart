import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/addresses/data/address_repository.dart';
import '../features/addresses/data/device_location.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/otp_autofill.dart';
import '../features/launch/data/config_repository.dart';
import '../features/profile/data/profile_repository.dart';
import 'providers.dart';

/// Repositories: the API implementation, or a fake with `FAKE_API=true`
/// (never in prod). Tests override these providers.
bool _fake(Ref ref) => ref.watch(appEnvProvider).useFakeApi;

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
