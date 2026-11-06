import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/launch_state.dart';
import '../../../app/providers.dart';
import '../../../app/repositories.dart';
import '../../notifications/presentation/push_registration.dart';
import '../../../shared/validation/validators.dart';
import '../domain/auth_models.dart';

/// Notices to show once on the next screen.
enum AppNotice { deletionCancelled }

class PendingNotice extends Notifier<AppNotice?> {
  @override
  AppNotice? build() => null;

  void show(AppNotice notice) => state = notice;

  /// Returns the notice and clears it.
  AppNotice? take() {
    final notice = state;
    state = null;
    return notice;
  }
}

final pendingNoticeProvider = NotifierProvider<PendingNotice, AppNotice?>(
  PendingNotice.new,
);

@immutable
class AuthFlowState {
  const AuthFlowState({
    this.challenge,
    this.requesting = false,
    this.verifying = false,
    this.error,
  });

  /// The OTP sent for the phone being verified. Null before Get OTP.
  final OtpChallenge? challenge;
  final bool requesting;
  final bool verifying;

  /// The last failure, shown through `describeErrorWithDetails`.
  final Object? error;

  bool get busy => requesting || verifying;
}

/// Login → OTP → signed in (`03 §2.2`). Kept alive across the two screens,
/// so the phone and the challenge survive navigation.
class AuthFlowController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  /// Requests a login OTP for 10 [digits]. Returns true on success.
  Future<bool> requestOtp(String digits) async {
    if (state.busy || !Validators.isMobile(digits)) return false;
    return _request(Validators.toE164(digits));
  }

  /// Sends a new OTP to the same phone.
  Future<bool> resend() async {
    final phone = state.challenge?.phone;
    if (phone == null || state.busy) return false;
    return _request(phone);
  }

  Future<bool> _request(String phone) async {
    state = AuthFlowState(challenge: state.challenge, requesting: true);
    try {
      final challenge = await ref
          .read(authRepositoryProvider)
          .requestOtp(phone);
      state = AuthFlowState(challenge: challenge);
      return true;
    } catch (error) {
      state = AuthFlowState(challenge: state.challenge, error: error);
      return false;
    }
  }

  /// Verifies [otp]. On success the session signs in and the router moves on.
  Future<void> verify(String otp) async {
    final challenge = state.challenge;
    final config = ref.read(launchStateProvider).config;
    if (challenge == null || config == null || state.busy) return;
    state = AuthFlowState(challenge: challenge, verifying: true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .verifyOtp(
            phone: challenge.phone,
            otp: otp,
            termsVersion: config.termsVersion,
          );
      // Everything the next screen needs is set before signIn(): signing in
      // triggers the redirect, which disposes this screen.
      ref
          .read(launchStateProvider)
          .setUser(result.user, profileComplete: !result.needsProfile);
      if (result.deletionCancelled) {
        ref
            .read(pendingNoticeProvider.notifier)
            .show(AppNotice.deletionCancelled);
      }
      await ref.read(sessionProvider).signIn(result.tokens);
      state = const AuthFlowState();
    } catch (error) {
      state = AuthFlowState(challenge: challenge, error: error);
    }
  }

  void clearError() {
    if (state.error != null) state = AuthFlowState(challenge: state.challenge);
  }

  /// Back to the phone screen.
  void reset() => state = const AuthFlowState();
}

final authFlowProvider = NotifierProvider<AuthFlowController, AuthFlowState>(
  AuthFlowController.new,
);

/// Seconds until "Resend OTP" is enabled. Ticks once a second.
class ResendCountdown extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  void start(int seconds) {
    _timer?.cancel();
    state = seconds;
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state - 1;
      if (state <= 0) timer.cancel();
    });
  }
}

final resendCountdownProvider =
    NotifierProvider.autoDispose<ResendCountdown, int>(ResendCountdown.new);

/// Logs out (`03 §2.2`): revokes the refresh token, then signs out locally
/// even if the call fails (the sign-out hook clears local data).
///
/// If the access token had expired, the logout call itself triggers a token
/// refresh, which rotates the pair, so the token sent is already revoked and
/// the new one is still live. In that case the new token is revoked too.
final logoutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final session = ref.read(sessionProvider);
    final repository = ref.read(authRepositoryProvider);
    const timeout = Duration(seconds: 10);
    final sent = session.refreshToken;
    // This device's push token, so the server stops pushing to it.
    final messaging = ref.read(pushMessagingProvider);
    String? fcmToken;
    if (messaging.isConfigured) {
      try {
        fcmToken = await messaging.getToken().timeout(timeout);
      } catch (_) {
        // Logout goes ahead without it.
      }
    }
    if (sent != null) {
      try {
        await repository.logout(sent, fcmToken: fcmToken).timeout(timeout);
        final rotated = session.refreshToken;
        if (rotated != null && rotated != sent) {
          await repository
              .logout(rotated, fcmToken: fcmToken)
              .timeout(timeout);
        }
      } catch (_) {
        // Best effort: the user is signed out locally regardless.
      }
    }
    await session.signOut();
  };
});

/// Whether [error] is the given API error code.
bool isApiError(Object? error, ApiErrorCode code) =>
    error != null && ApiError.from(error).code == code;
