import 'package:jivo_core/jivo_core.dart';

import '../features/auth/domain/rider_account.dart';
import '../features/auth/domain/rider_destination.dart';
import 'routes.dart';

/// Where the app must be. Returns null to stay on [location], or the path to
/// redirect to.
///
/// Order (04 §1, §2.1):
/// 1. dev tools (dev flavor only) are never redirected, so the Phase 0 spike
///    and the offer full-screen-intent launch keep working;
/// 2. force update, then maintenance ([appControl], from 426/503 or
///    `config/app`; a force update outranks maintenance);
/// 3. config not loaded or session not restored yet: splash;
/// 4. signed in but `rider_status` not loaded (or `GET /me/` failed on the
///    network): splash, which offers Retry;
/// 5. optional update not dismissed: the update prompt;
/// 6. signed out: login (the OTP step only while an OTP is pending);
/// 7. signed in: the screen for `rider_status`.
String? riderRedirect({
  required String location,
  required AppControlEvent? appControl,
  required bool configLoaded,
  required bool softUpdatePending,
  required SessionStatus sessionStatus,
  required RiderAccountState account,
  required bool hasOtpChallenge,
  required bool showDevTools,
}) {
  if (showDevTools && Routes.isDevRoute(location)) return null;

  switch (appControl) {
    case AppUpdateRequired():
      return _goTo(location, Routes.update);
    case MaintenanceMode():
      return _goTo(location, Routes.maintenance);
    case null:
      break;
  }

  if (!configLoaded || sessionStatus == SessionStatus.unknown) {
    return _goTo(location, Routes.splash);
  }
  final signedIn = sessionStatus == SessionStatus.signedIn;
  if (signedIn && account is! AccountLoaded) {
    return _goTo(location, Routes.splash);
  }
  if (softUpdatePending) return _goTo(location, Routes.update);

  if (!signedIn || account is! AccountLoaded) {
    if (location == Routes.otp && hasOtpChallenge) return null;
    return _goTo(location, Routes.login);
  }
  return _goTo(location, routeFor(destinationFor(account.riderStatus)));
}

/// The route of a signed-in rider's landing screen.
String routeFor(RiderDestination destination) => switch (destination) {
  RiderDestination.register => Routes.register,
  RiderDestination.status => Routes.riderStatus,
  RiderDestination.home => Routes.home,
};

String? _goTo(String location, String target) =>
    location == target ? null : target;
