import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../data/fake_rider_onboarding_backend.dart';
import '../data/platform_kyc_images.dart';
import '../domain/image_compression.dart';
import '../domain/image_picking.dart';
import '../domain/kyc_document.dart';
import '../domain/rider_onboarding_repository.dart';
import '../domain/rider_profile.dart';

/// Whether the registration / KYC screens (04 §2.2, P5 lookahead) run.
///
/// TODO(api): there is no rider API until the end of P4, so they run only
/// against the fake, and only in the dev flavor (DL-30), with or without
/// `FAKE_API` (so a real Phase 1 login with `rider_status: NONE` reaches the
/// form). Staging and prod keep the Phase 1 placeholders, even with
/// `FAKE_API`: these fakes never run there.
final riderOnboardingEnabledProvider = Provider<bool>(
  (ref) => ref.watch(appEnvProvider).flavor == Flavor.dev,
);

/// The fake rider backend (TODO(api)). Overridden in tests (no delay).
final fakeRiderOnboardingBackendProvider = Provider<FakeRiderOnboardingBackend>(
  (ref) => FakeRiderOnboardingBackend(clock: ref.watch(clockProvider)),
);

/// TODO(api): bind to the generated client when the rider contract lands
/// (end of P4): an `ApiRiderOnboardingRepository` mapping the generated
/// types to the domain models, chosen when `!env.useFakeApi`.
final riderOnboardingRepositoryProvider = Provider<RiderOnboardingRepository>((
  ref,
) {
  if (!ref.watch(riderOnboardingEnabledProvider)) {
    return const UnavailableRiderOnboardingRepository();
  }
  final fake = ref.watch(fakeRiderOnboardingBackendProvider);
  fake.currentRider = () {
    final account = ref.read(riderAccountControllerProvider);
    if (account is! AccountLoaded) return null;
    return (
      key: account.user.phone ?? 'user-${account.user.id}',
      status: account.riderStatus,
    );
  };
  return fake;
});

final kycImagePickerProvider = Provider<KycImagePicker>(
  (ref) => ImagePickerKycPicker(),
);

final imageCodecProvider = Provider<ImageCodec>(
  (ref) => const NativeImageCodec(),
);

final pendingCaptureStoreProvider = Provider<PendingCaptureStore>(
  (ref) => const FilePendingCaptureStore(),
);

/// On sign-out: forgets a camera capture that Android interrupted and
/// deletes its photo, so the next rider on this phone never gets the
/// previous rider's KYC photo recovered into their documents. Never throws.
Future<void> discardInterruptedKycCapture(Ref ref) async {
  try {
    final picker = ref.read(kycImagePickerProvider);
    final lost = await picker.retrieveLost();
    if (lost != null) await picker.discard(lost);
    await ref.read(pendingCaptureStoreProvider).clear();
  } on Object catch (error) {
    debugPrint('discardInterruptedKycCapture: ${error.runtimeType}');
  }
}

/// Stores for the preferred-home-store dropdown.
final storeOptionsProvider = FutureProvider.autoDispose<List<StoreOption>>(
  (ref) => ref.watch(riderOnboardingRepositoryProvider).fetchStores(),
);

final riderProfileControllerProvider =
    AsyncNotifierProvider.autoDispose<RiderProfileController, RiderProfile>(
      RiderProfileController.new,
    );

/// `GET /rider/me/` for the status screen and the steps under it. Alive
/// while the status screen is in the stack (auto-dispose), so a new login
/// never sees the previous rider's profile.
class RiderProfileController extends AsyncNotifier<RiderProfile> {
  @override
  Future<RiderProfile> build() async {
    try {
      final profile = await ref
          .watch(riderOnboardingRepositoryProvider)
          .fetchProfile();
      _syncRiderStatus(profile);
      return profile;
    } on Object catch (e) {
      final error = ApiError.from(e);
      reportAppControlError(ref, error);
      throw error;
    }
  }

  /// Reloads, keeping the current profile on screen meanwhile. Never throws
  /// (a failure shows as the error state).
  Future<void> reload() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Object {
      // Shown by the screen.
    }
  }

  /// After `POST /rider/documents/`: shows the new status without a reload.
  void documentUploaded(RiderDocument document) {
    final profile = state.value;
    if (profile != null) state = AsyncData(profile.withDocument(document));
  }

  /// After `PUT /rider/bank-account/`.
  void bankAccountSaved(BankAccountSummary summary) {
    final profile = state.value;
    if (profile != null) {
      state = AsyncData(profile.copyWith(bankAccount: summary));
    }
  }

  /// The rider saw "You're approved" and continues: routing moves to home.
  void continueAsApproved() => ref
      .read(riderAccountControllerProvider.notifier)
      .riderStatusChanged(RiderStatusEnum.ACTIVE);

  /// Keeps routing in step with the review result. `ACTIVE` is not applied
  /// here, or the router would leave before the rider sees "approved"
  /// ([continueAsApproved] applies it).
  void _syncRiderStatus(RiderProfile profile) {
    if (profile.status == RiderStatusEnum.ACTIVE ||
        profile.status == RiderStatusEnum.unknownDefaultOpenApi) {
      return;
    }
    ref
        .read(riderAccountControllerProvider.notifier)
        .riderStatusChanged(profile.status);
  }
}

/// Analytics parameters for onboarding events: types only, never numbers.
Map<String, Object> documentEventParameters(KycDocumentType type) => {
  'doc_type': type.wireValue,
};
