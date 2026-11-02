import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_api/jivo_api.dart' show AuthSession, RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../location/presentation/location_debug_controller.dart';
import '../../offers/presentation/offer_alert_providers.dart';
import '../../onboarding/presentation/onboarding_providers.dart';
import '../domain/rider_account.dart';
import 'auth_providers.dart';
import 'login_controllers.dart';

enum LogoutResult {
  done,

  /// The rider is online (location service running): go offline first
  /// (04 §2.9).
  blockedWhileOnline,
}

final riderAccountControllerProvider =
    NotifierProvider<RiderAccountController, RiderAccountState>(
      RiderAccountController.new,
    );

/// The signed-in rider's account and `rider_status`, on top of jivo_core's
/// [SessionManager] (which owns the tokens):
/// - after OTP verify: from the `AuthSession` response;
/// - after an app restart with stored tokens: from `GET /me/`;
/// - on any sign-out (logout or session expired): rider data on the device
///   is deleted by a sign-out hook.
class RiderAccountController extends Notifier<RiderAccountState> {
  SessionManager get _session => ref.read(sessionManagerProvider);

  @override
  RiderAccountState build() {
    final removeHook = ref
        .watch(sessionManagerProvider)
        .addSignOutHook(_onSignOut);
    ref.onDispose(removeHook);
    return const AccountUnknown();
  }

  /// Runs after jivo_core cleared the tokens and before it announces
  /// `signedOut`, for both logout and an expired session.
  Future<void> _onSignOut(SignOutReason reason) async {
    await ref.read(locationDataCleanerProvider).clear();
    await discardInterruptedKycCapture(ref);
    try {
      await ref.read(offerAlertNotificationsProvider).dismiss();
    } on Object catch (error) {
      debugPrint('RiderAccountController: dismissing offer alert: $error');
    }
    ref.read(otpChallengeProvider.notifier).clear();
    unawaited(ref.read(analyticsProvider).setUserId(null));
    state = const AccountUnknown();
  }

  /// Signed in from stored tokens: `GET /me/` decides the route by
  /// `rider_status`.
  ///
  /// The session only ends when the server rejects it (jivo_core signs out
  /// on a refresh `TOKEN_INVALID`; a 401 that survives the refresh also ends
  /// it). No network, timeouts and 5xx keep the tokens
  /// ([AccountLoadFailed]): riders on patchy networks must not be logged out
  /// by a bad signal.
  Future<void> load() async {
    if (!_session.isSignedIn) return;
    state = const AccountUnknown();
    try {
      final me = await ref.read(accountRepositoryProvider).fetchMe();
      if (!_session.isSignedIn) return;
      state = AccountLoaded(user: me, riderStatus: me.riderStatus);
      unawaited(ref.read(analyticsProvider).setUserId('${me.id}'));
    } on Object catch (e) {
      final error = ApiError.from(e);
      if (!_session.isSignedIn) return;
      if (error.code == ApiErrorCode.authRequired ||
          error.code == ApiErrorCode.tokenInvalid) {
        await _session.signOut(reason: SignOutReason.sessionExpired);
        return;
      }
      reportAppControlError(ref, error);
      state = AccountLoadFailed(error);
    }
  }

  /// After a successful OTP verify. The account is set before the session
  /// announces `signedIn`, so the router goes straight to the right screen.
  Future<void> signedIn(AuthSession session) async {
    state = AccountLoaded(user: session.user, riderStatus: session.riderStatus);
    try {
      await _session.signIn(
        AuthTokens(access: session.access, refresh: session.refresh),
      );
    } on Object {
      state = const AccountUnknown();
      rethrow;
    }
    final analytics = ref.read(analyticsProvider);
    unawaited(analytics.setUserId('${session.user.id}'));
    unawaited(
      analytics.logEvent(
        'login_success',
        parameters: {
          'rider_status': session.riderStatus.value,
          'is_new_user': session.isNewUser,
        },
      ),
    );
  }

  /// A rider endpoint reported a new `rider_status` (registration created
  /// the profile, or `GET /rider/me/` shows a review result). Updates the
  /// routing without another `GET /me/`. Read the status from
  /// [AccountLoaded.riderStatus], never from `user.riderStatus`, which is the
  /// value at login.
  void riderStatusChanged(RiderStatusEnum status) {
    final current = state;
    if (current is! AccountLoaded || current.riderStatus == status) return;
    state = AccountLoaded(user: current.user, riderStatus: status);
  }

  /// Logout (04 §2.9): refused while online. Otherwise revokes the refresh
  /// token on the server (best effort) and ends the local session, which
  /// deletes the location buffer through the sign-out hook.
  Future<LogoutResult> logout() async {
    if (await ref.read(locationServiceClientProvider).isRunning()) {
      return LogoutResult.blockedWhileOnline;
    }
    final refresh = _session.refreshToken;
    if (refresh != null) {
      try {
        await ref.read(authRepositoryProvider).logout(refreshToken: refresh);
      } on Object catch (error) {
        debugPrint('RiderAccountController.logout: server logout: $error');
      }
    }
    await _session.signOut();
    unawaited(ref.read(analyticsProvider).logEvent('logout'));
    return LogoutResult.done;
  }
}

/// The one place that handles 426 / 503 from a call the app made. Real API
/// calls are already reported by jivo_core's `AppControlInterceptor`; this
/// also covers the fakes. Returns true when [error] is one of them, so the
/// caller does not show it inline (the router shows the blocking screen).
bool reportAppControlError(Ref ref, ApiError error) {
  final signals = ref.read(appControlSignalsProvider);
  // Don't overwrite what the interceptor reported (it has the server's
  // maintenance message and store URL).
  switch (error.code) {
    case ApiErrorCode.appUpdateRequired:
      if (signals.current is! AppUpdateRequired) {
        signals.reportUpdateRequired(
          AppUpdateRequired.fromDetails(error.details),
        );
      }
      return true;
    case ApiErrorCode.maintenance:
      if (signals.current is! MaintenanceMode) {
        signals.reportMaintenance(const MaintenanceMode());
      }
      return true;
    default:
      return false;
  }
}
