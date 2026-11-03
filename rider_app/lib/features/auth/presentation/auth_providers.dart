import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';

import '../../../app/providers.dart';
import '../../location/data/location_buffer_file.dart';
import '../data/api_auth_repository.dart';
import '../data/fake_auth_backend.dart';
import '../data/otp_autofill.dart';
import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';

/// One fake backend shared by the auth and account fakes (same signed-in
/// user), used when `FAKE_API` is on and in widget tests.
final fakeAuthBackendProvider = Provider<FakeAuthBackend>(
  (ref) => FakeAuthBackend(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeAuthBackendProvider);
  }
  return ApiAuthRepository(ref.watch(jivoApiProvider));
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeAuthBackendProvider);
  }
  return ApiAuthRepository(ref.watch(jivoApiProvider));
});

final otpAutofillProvider = Provider<OtpAutofill>(
  (ref) => const SmsUserConsentAutofill(),
);

final locationDataCleanerProvider = Provider<LocationDataCleaner>(
  (ref) => const FileLocationDataCleaner(),
);
