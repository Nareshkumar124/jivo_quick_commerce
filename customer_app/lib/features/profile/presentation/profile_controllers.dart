import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../auth/domain/auth_models.dart';
import '../domain/user_profile.dart';

/// The signed-in user for the account screens. Uses the user known from
/// sign-in or start-up, otherwise loads `GET /me/`.
class CurrentUser extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final known = ref.read(launchStateProvider).user;
    if (known != null) return known;
    final user = await ref.read(profileRepositoryProvider).fetchMe();
    ref.read(launchStateProvider).setUser(user);
    return user;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(profileRepositoryProvider).fetchMe();
      ref.read(launchStateProvider).setUser(user);
      return user;
    });
  }

  void replace(UserProfile user) {
    ref.read(launchStateProvider).setUser(user);
    state = AsyncData(user);
  }
}

final currentUserProvider = AsyncNotifierProvider<CurrentUser, UserProfile>(
  CurrentUser.new,
  retry: noAutomaticRetry,
);

@immutable
class ProfileFormState {
  const ProfileFormState({this.saving = false, this.error, this.saved = false});

  final bool saving;
  final Object? error;
  final bool saved;

  /// The server rejected the email (generic message by design).
  bool get emailRejected =>
      error != null && ApiError.from(error!).fieldErrors.containsKey('email');

  /// The server rejected the business category (unknown or inactive).
  bool get categoryRejected => businessCategoryRejected(error);

  /// A field error the form shows next to its field, not as a general one.
  bool get hasFieldError => emailRejected || categoryRejected;
}

/// `VALIDATION_ERROR` on `business_category` (an unknown or inactive id):
/// the forms show it under the dropdown (`03 §2.2`).
bool businessCategoryRejected(Object? error) =>
    error != null &&
    ApiError.from(error).fieldErrors.containsKey('business_category');

/// `GET /business-categories/` for the complete-profile and edit-profile
/// dropdowns. Invalidate it to retry.
final businessCategoriesProvider =
    FutureProvider.autoDispose<List<BusinessCategory>>(
      (ref) => ref.watch(profileRepositoryProvider).businessCategories(),
      retry: noAutomaticRetry,
    );

/// Saves Edit profile: name, email and the business fields.
class ProfileFormController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() => const ProfileFormState();

  Future<bool> save({
    required String name,
    String? email,
    int? businessCategoryId,
    String? businessName,
  }) async {
    if (state.saving) return false;
    state = const ProfileFormState(saving: true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .updateProfile(
            name: name,
            email: email,
            businessCategoryId: businessCategoryId,
            businessName: businessName,
          );
      ref.read(currentUserProvider.notifier).replace(user);
      state = const ProfileFormState(saved: true);
      return true;
    } catch (error) {
      state = ProfileFormState(error: error);
      return false;
    }
  }
}

final profileFormProvider =
    NotifierProvider.autoDispose<ProfileFormController, ProfileFormState>(
      ProfileFormController.new,
    );

enum DeleteStep { explain, otp }

@immutable
class DeleteAccountState {
  const DeleteAccountState({
    this.step = DeleteStep.explain,
    this.busy = false,
    this.error,
    this.challenge,
  });

  final DeleteStep step;
  final bool busy;
  final Object? error;
  final OtpChallenge? challenge;
}

/// Delete account (`03 §2.2`): request a `delete_account` OTP for the
/// user's phone, then `POST /me/delete/`. The caller shows the result and
/// then calls [finish] to sign out.
class DeleteAccountController extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountState();

  Future<void> sendOtp(String phone) async {
    if (state.busy) return;
    state = DeleteAccountState(
      step: state.step,
      busy: true,
      challenge: state.challenge,
    );
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone, purpose: OtpPurpose.deleteAccount);
      state = DeleteAccountState(step: DeleteStep.otp, challenge: challenge);
    } catch (error) {
      state = DeleteAccountState(
        step: state.step,
        error: error,
        challenge: state.challenge,
      );
    }
  }

  /// Returns the deletion on success, null on failure (see [state]).
  Future<AccountDeletion?> confirm({
    required String otp,
    String? reason,
  }) async {
    if (state.busy) return null;
    state = DeleteAccountState(
      step: DeleteStep.otp,
      busy: true,
      challenge: state.challenge,
    );
    try {
      final deletion = await ref
          .read(profileRepositoryProvider)
          .deleteAccount(otp: otp, reason: reason);
      state = DeleteAccountState(
        step: DeleteStep.otp,
        challenge: state.challenge,
      );
      return deletion;
    } catch (error) {
      state = DeleteAccountState(
        step: DeleteStep.otp,
        error: error,
        challenge: state.challenge,
      );
      return null;
    }
  }

  /// The backend already revoked every refresh token: just sign out locally.
  Future<void> finish() => ref.read(sessionProvider).signOut();
}

final deleteAccountProvider =
    NotifierProvider.autoDispose<DeleteAccountController, DeleteAccountState>(
      DeleteAccountController.new,
    );
