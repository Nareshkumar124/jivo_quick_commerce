import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../launch/presentation/launch_controller.dart';
import '../domain/indian_mobile.dart';
import 'auth_providers.dart';
import 'rider_account_controller.dart';

/// The OTP that was just requested. Kept in a provider (not in route
/// arguments) so the OTP screen can tell when there is nothing to verify.
@immutable
class OtpChallenge {
  const OtpChallenge({
    required this.phone,
    required this.otpLength,
    required this.resendAfterSeconds,
  });

  /// `+91XXXXXXXXXX`.
  final String phone;

  /// `otp_length` from the `OtpSent` response.
  final int otpLength;

  /// `resend_after_seconds` from the `OtpSent` response.
  final int resendAfterSeconds;
}

final otpChallengeProvider =
    NotifierProvider<OtpChallengeNotifier, OtpChallenge?>(
      OtpChallengeNotifier.new,
    );

class OtpChallengeNotifier extends Notifier<OtpChallenge?> {
  @override
  OtpChallenge? build() => null;

  void set(OtpChallenge challenge) => state = challenge;

  void clear() => state = null;
}

/// `details.retry_after_seconds` of an `OTP_RATE_LIMITED` error.
int? retryAfterSeconds(ApiError error) {
  final value = error.details['retry_after_seconds'];
  return value is num ? value.toInt() : null;
}

// ---------------------------------------------------------------- phone step

@immutable
class PhoneLoginState {
  const PhoneLoginState({this.submitting = false, this.error});

  final bool submitting;

  /// The last server error, shown under the field. 426/503 never land here:
  /// they switch to the update or maintenance screen instead.
  final ApiError? error;
}

final phoneLoginControllerProvider =
    NotifierProvider.autoDispose<PhoneLoginController, PhoneLoginState>(
      PhoneLoginController.new,
    );

class PhoneLoginController extends Notifier<PhoneLoginState> {
  @override
  PhoneLoginState build() => const PhoneLoginState();

  /// Requests an OTP for what the rider typed. Returns true when the OTP
  /// screen should open. Invalid input is caught by the screen first.
  Future<bool> requestOtp(String input) async {
    final phone = IndianMobile.toE164(input);
    if (phone == null || state.submitting) return false;
    state = const PhoneLoginState(submitting: true);
    try {
      final sent = await ref.read(authRepositoryProvider).requestOtp(phone);
      ref
          .read(otpChallengeProvider.notifier)
          .set(
            OtpChallenge(
              phone: phone,
              otpLength: sent.otpLength,
              resendAfterSeconds: sent.resendAfterSeconds,
            ),
          );
      unawaited(ref.read(analyticsProvider).logEvent('otp_requested'));
      if (ref.mounted) state = const PhoneLoginState();
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      final handled = reportAppControlError(ref, error);
      if (ref.mounted) {
        state = PhoneLoginState(error: handled ? null : error);
      }
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = const PhoneLoginState();
  }
}

// ------------------------------------------------------------------ OTP step

/// A resend countdown to start. A new [id] restarts it, even with the same
/// number of [seconds].
@immutable
class ResendCooldown {
  const ResendCooldown(this.seconds, this.id);

  final int seconds;
  final int id;

  ResendCooldown next(int seconds) => ResendCooldown(seconds, id + 1);
}

@immutable
class OtpState {
  const OtpState({
    required this.cooldown,
    this.verifying = false,
    this.resending = false,
    this.error,
    this.expired = false,
    this.clearCodeId = 0,
  });

  final ResendCooldown cooldown;
  final bool verifying;
  final bool resending;

  /// `OTP_INVALID` (with `attempts_remaining`), `OTP_RATE_LIMITED` (with
  /// `retry_after_seconds`) or any other failure.
  final ApiError? error;

  /// The code can no longer be used (`OTP_EXPIRED`): Resend becomes the
  /// primary action.
  final bool expired;

  /// Bumped when the typed code should be cleared.
  final int clearCodeId;

  bool get busy => verifying || resending;

  OtpState copyWith({
    ResendCooldown? cooldown,
    bool? verifying,
    bool? resending,
    ApiError? error,
    bool clearError = false,
    bool? expired,
    int? clearCodeId,
  }) => OtpState(
    cooldown: cooldown ?? this.cooldown,
    verifying: verifying ?? this.verifying,
    resending: resending ?? this.resending,
    error: clearError ? null : (error ?? this.error),
    expired: expired ?? this.expired,
    clearCodeId: clearCodeId ?? this.clearCodeId,
  );
}

final otpControllerProvider =
    NotifierProvider.autoDispose<OtpController, OtpState>(OtpController.new);

class OtpController extends Notifier<OtpState> {
  @override
  OtpState build() {
    final challenge = ref.read(otpChallengeProvider);
    return OtpState(
      cooldown: ResendCooldown(challenge?.resendAfterSeconds ?? 30, 0),
    );
  }

  /// `POST /auth/otp/verify/` with the config's `terms_version`. On success
  /// the session starts and the router moves on by `rider_status`.
  Future<void> verify(String code) async {
    final challenge = ref.read(otpChallengeProvider);
    if (challenge == null || state.busy || state.expired) return;
    if (code.length != challenge.otpLength) return;
    final termsVersion = ref
        .read(launchControllerProvider)
        .config
        ?.termsVersion;
    if (termsVersion == null) {
      // Unreachable: the splash does not continue without the config.
      state = state.copyWith(error: const ApiError(code: ApiErrorCode.unknown));
      return;
    }

    // Read before awaiting: once signed in, the router leaves the OTP screen
    // and this auto-dispose controller may be gone.
    final challengeNotifier = ref.read(otpChallengeProvider.notifier);
    final account = ref.read(riderAccountControllerProvider.notifier);
    final auth = ref.read(authRepositoryProvider);

    state = state.copyWith(verifying: true, clearError: true);
    try {
      final result = await auth.verifyOtp(
        phoneE164: challenge.phone,
        otp: code,
        termsVersion: termsVersion,
      );
      await account.signedIn(result);
      challengeNotifier.clear();
      if (ref.mounted) state = state.copyWith(verifying: false);
    } on Object catch (e) {
      if (!ref.mounted) return;
      _onError(ApiError.from(e));
    }
  }

  /// Requests a new code once the countdown has ended (or after expiry).
  Future<void> resend() async {
    final challenge = ref.read(otpChallengeProvider);
    if (challenge == null || state.busy) return;
    state = state.copyWith(resending: true, clearError: true);
    try {
      final sent = await ref
          .read(authRepositoryProvider)
          .requestOtp(challenge.phone);
      ref
          .read(otpChallengeProvider.notifier)
          .set(
            OtpChallenge(
              phone: challenge.phone,
              otpLength: sent.otpLength,
              resendAfterSeconds: sent.resendAfterSeconds,
            ),
          );
      if (!ref.mounted) return;
      state = OtpState(
        cooldown: state.cooldown.next(sent.resendAfterSeconds),
        clearCodeId: state.clearCodeId + 1,
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      _onError(ApiError.from(e));
    }
  }

  void _onError(ApiError error) {
    if (reportAppControlError(ref, error)) {
      state = state.copyWith(verifying: false, resending: false);
      return;
    }
    switch (error.code) {
      case ApiErrorCode.otpExpired:
        state = state.copyWith(
          verifying: false,
          resending: false,
          error: error,
          expired: true,
          clearCodeId: state.clearCodeId + 1,
        );
      case ApiErrorCode.otpRateLimited:
        final wait = retryAfterSeconds(error);
        state = state.copyWith(
          verifying: false,
          resending: false,
          error: error,
          cooldown: wait == null ? null : state.cooldown.next(wait),
        );
      case ApiErrorCode.otpInvalid:
        state = state.copyWith(
          verifying: false,
          resending: false,
          error: error,
          clearCodeId: state.clearCodeId + 1,
        );
      default:
        state = state.copyWith(
          verifying: false,
          resending: false,
          error: error,
        );
    }
  }
}
