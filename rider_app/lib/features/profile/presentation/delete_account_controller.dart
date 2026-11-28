import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show AccountDeletion;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../auth/domain/rider_account.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../data/api_account_deletion_repository.dart';
import '../data/fake_account_deletion_backend.dart';
import '../domain/account_deletion_repository.dart';

/// Public page about account deletion (Play's "delete account" URL).
final accountDeletionInfoUrl = Uri.parse(
  'https://quick.jivo.in/legal/delete-account/',
);

final fakeAccountDeletionBackendProvider = Provider<FakeAccountDeletionBackend>(
  (ref) => FakeAccountDeletionBackend(),
);

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  if (ref.watch(appEnvProvider).useFakeApi) {
    return ref.watch(fakeAccountDeletionBackendProvider);
  }
  return ApiAccountDeletionRepository(ref.watch(jivoApiProvider));
});

/// `ApiError.rawCode` when the signed-in account has no phone to send the
/// OTP to (never expected for a rider; shown as its own message).
const noPhoneCode = 'NO_PHONE';

enum DeleteAccountStep { explain, otp }

@immutable
class DeleteAccountState {
  const DeleteAccountState({
    this.step = DeleteAccountStep.explain,
    this.busy = false,
    this.error,
    this.blocked,
    this.phone,
    this.resendAt,
  });

  final DeleteAccountStep step;
  final bool busy;

  /// The last call's error, shown inline.
  final ApiError? error;

  /// Why deletion is refused right now (online, or during a task). Same
  /// rule as logout (04 §2.9): the shift and the task must end first.
  final LogoutResult? blocked;

  /// The phone the OTP went to (E.164).
  final String? phone;

  /// When "Resend OTP" becomes available.
  final DateTime? resendAt;

  DeleteAccountState copyWith({
    DeleteAccountStep? step,
    bool? busy,
    ApiError? error,
    bool clearError = false,
    LogoutResult? blocked,
    bool clearBlocked = false,
    String? phone,
    DateTime? resendAt,
  }) => DeleteAccountState(
    step: step ?? this.step,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    blocked: clearBlocked ? null : (blocked ?? this.blocked),
    phone: phone ?? this.phone,
    resendAt: resendAt ?? this.resendAt,
  );
}

final deleteAccountControllerProvider =
    NotifierProvider.autoDispose<DeleteAccountController, DeleteAccountState>(
      DeleteAccountController.new,
    );

/// Delete account (Play requirement, `03 §2.2`): a `delete_account` OTP to
/// the rider's own phone, then `POST /me/delete/`. The server decides
/// whether the OTP is right and what is deleted; the app only refuses to
/// start while the rider is online or on a task (as for logout).
class DeleteAccountController extends Notifier<DeleteAccountState> {
  @override
  DeleteAccountState build() => const DeleteAccountState();

  AccountDeletionRepository get _repository =>
      ref.read(accountDeletionRepositoryProvider);

  /// Sends (or re-sends) the confirmation OTP. Returns true when it went.
  Future<bool> sendOtp() async {
    if (state.busy) return false;
    state = state.copyWith(busy: true, clearError: true, clearBlocked: true);
    final blocked = await ref
        .read(riderAccountControllerProvider.notifier)
        .logoutBlocker();
    if (!ref.mounted) return false;
    if (blocked != null) {
      state = state.copyWith(busy: false, blocked: blocked);
      return false;
    }
    final account = ref.read(riderAccountControllerProvider);
    final phone = account is AccountLoaded ? account.user.phone : null;
    if (phone == null || phone.isEmpty) {
      state = state.copyWith(
        busy: false,
        error: const ApiError(code: ApiErrorCode.unknown, rawCode: noPhoneCode),
      );
      return false;
    }
    try {
      final sent = await _repository.requestDeletionOtp(phone);
      if (!ref.mounted) return false;
      state = state.copyWith(
        step: DeleteAccountStep.otp,
        busy: false,
        phone: phone,
        resendAt: ref
            .read(clockProvider)()
            .add(Duration(seconds: sent.resendAfterSeconds)),
      );
      return true;
    } on Object catch (error) {
      if (!ref.mounted) return false;
      state = state.copyWith(busy: false, error: ApiError.from(error));
      return false;
    }
  }

  /// Confirms with [otp]. Returns the deletion on success, null on failure
  /// (the error is in [state]). Call [finish] after showing the result.
  Future<AccountDeletion?> confirm(String otp) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true, clearError: true, clearBlocked: true);
    final blocked = await ref
        .read(riderAccountControllerProvider.notifier)
        .logoutBlocker();
    if (!ref.mounted) return null;
    if (blocked != null) {
      state = state.copyWith(busy: false, blocked: blocked);
      return null;
    }
    try {
      final deletion = await _repository.deleteAccount(otp: otp);
      if (!ref.mounted) return deletion;
      state = state.copyWith(busy: false);
      return deletion;
    } on Object catch (error) {
      if (!ref.mounted) return null;
      state = state.copyWith(busy: false, error: ApiError.from(error));
      return null;
    }
  }

  /// The server already revoked every token and deactivated the devices:
  /// sign out locally. The sign-out hook deletes the rider's data on this
  /// phone (location buffer, drafts, alerts).
  Future<void> finish() => ref.read(sessionManagerProvider).signOut();
}
