import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/helpers.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../domain/referral.dart';

/// One customer's referral screen (`GET /account/referral/`), one entry per
/// user id. Kept for the session so the Account row and the checkout card
/// share one load; the Referral screen reloads it when opened.
///
/// Per user, so a reload never shows the previous user's data while it runs
/// (Riverpod keeps the last value during a reload). It also watches
/// [signedInUserIdProvider]: once its user is signed out (any path) it ends
/// in `AUTH_REQUIRED` without a request, and it loads again when that user
/// signs in again.
class ReferralController extends AsyncNotifier<ReferralInfo> {
  ReferralController(this.userId);

  final int userId;

  @override
  Future<ReferralInfo> build() async {
    if (ref.watch(signedInUserIdProvider) != userId) {
      throw const ApiError(code: ApiErrorCode.authRequired);
    }
    return ref.read(referralRepositoryProvider).fetch();
  }

  /// Shows the server's answer to this user's apply.
  void replace(ReferralInfo info) {
    if (ref.mounted) state = AsyncData(info);
  }
}

final referralProvider =
    AsyncNotifierProvider.family<ReferralController, ReferralInfo, int>(
      ReferralController.new,
      retry: noAutomaticRetry,
    );

/// The signed-in customer's referral screen; loading while nobody is signed
/// in. Widgets watch this; reloads go to [referralProvider] for the user.
final currentReferralProvider = Provider<AsyncValue<ReferralInfo>>((ref) {
  final userId = ref.watch(signedInUserIdProvider);
  if (userId == null) return const AsyncLoading();
  return ref.watch(referralProvider(userId));
});

@immutable
class ReferralApplyState {
  const ReferralApplyState({
    this.busy = false,
    this.error,
    this.missingCode = false,
  });

  /// The request is in flight: the Apply button is disabled.
  final bool busy;

  /// The server's refusal (`REFERRAL_*`, `RATE_LIMITED`, network).
  final Object? error;

  /// Apply was tapped with an empty field (nothing was sent).
  final bool missingCode;
}

/// "Have a referral code?": sends the friend's code once.
class ReferralApplyController extends Notifier<ReferralApplyState> {
  @override
  ReferralApplyState build() => const ReferralApplyState();

  /// True when the code was applied; the new referral state is then in
  /// [referralProvider] for the user.
  Future<bool> apply(String code) async {
    if (state.busy) return false;
    if (code.trim().isEmpty) {
      state = const ReferralApplyState(missingCode: true);
      return false;
    }
    final userId = ref.read(signedInUserIdProvider);
    if (userId == null) return false;
    // Taken now: the screen may close (or the user sign out) while the
    // request is in flight; the answer still belongs to this user only.
    final referral = ref.read(referralProvider(userId).notifier);
    state = const ReferralApplyState(busy: true);
    try {
      referral.replace(await ref.read(referralRepositoryProvider).apply(code));
    } catch (error) {
      if (ref.mounted) state = ReferralApplyState(error: error);
      return false;
    }
    if (!ref.mounted) return true;
    state = const ReferralApplyState();
    unawaited(
      ref
          .read(analyticsProvider)
          .logEvent('referral_code_applied', parameters: const {}),
    );
    return true;
  }

  /// The customer edits the code: drop the old error.
  void clearError() {
    if (state.error != null || state.missingCode) {
      state = const ReferralApplyState();
    }
  }
}

final referralApplyProvider =
    NotifierProvider.autoDispose<ReferralApplyController, ReferralApplyState>(
      ReferralApplyController.new,
    );

/// Whether the signed-in customer closed the "Have a referral code?" card at
/// checkout (remembered per user on this device). Keyed on
/// [signedInUserIdProvider], so it never carries one user's choice over to
/// the next.
class ReferralPromptDismissed extends Notifier<bool> {
  @override
  bool build() {
    final userId = ref.watch(signedInUserIdProvider);
    if (userId == null) return false;
    return ref.read(appFlagsProvider).referralPromptDismissed(userId);
  }

  Future<void> dismiss() async {
    final userId = ref.read(signedInUserIdProvider);
    state = true;
    if (userId == null) return;
    try {
      await ref.read(appFlagsProvider).dismissReferralPrompt(userId);
    } catch (_) {
      // Hidden for this session anyway.
    }
  }
}

final referralPromptDismissedProvider =
    NotifierProvider<ReferralPromptDismissed, bool>(
      ReferralPromptDismissed.new,
    );
