import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
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
/// 7. signed in and ACTIVE: the task screens while a task is active (or its
///    end is unread), else the offer screen while an offer is open, else
///    home or the rider's records (earnings, cash, history, profile) in
///    builds that have them ([recordsEnabled]; dev flavor until the rider
///    API lands);
/// 8. signed in: the screen for `rider_status`. `PENDING_KYC` and
///    `REJECTED` riders may also open the application steps under it
///    (documents, bank details); everyone else gets exactly that screen.
String? riderRedirect({
  required String location,
  required AppControlEvent? appControl,
  required bool configLoaded,
  required bool softUpdatePending,
  required SessionStatus sessionStatus,
  required RiderAccountState account,
  required bool hasOtpChallenge,
  required bool showDevTools,
  bool hasRiderTask = false,
  bool hasOffer = false,
  bool recordsEnabled = false,
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
  if (account.riderStatus == RiderStatusEnum.ACTIVE) {
    // One order at a time: a task (until the rider acknowledges how it
    // ended) keeps them on the task screens, then an open offer.
    if (hasRiderTask) return Routes.isTaskRoute(location) ? null : Routes.task;
    if (hasOffer) return _goTo(location, Routes.offer);
    // Between orders: home and the rider's own records, where those routes
    // exist (a stray link elsewhere goes home, not to an error page).
    if (recordsEnabled && Routes.isAccountRoute(location)) return null;
  }
  final target = routeFor(destinationFor(account.riderStatus));
  if (canEditApplication(account.riderStatus) &&
      location.startsWith('$target/')) {
    return null;
  }
  return _goTo(location, target);
}

/// The route of a signed-in rider's landing screen.
String routeFor(RiderDestination destination) => switch (destination) {
  RiderDestination.register => Routes.register,
  RiderDestination.status => Routes.riderStatus,
  RiderDestination.home => Routes.home,
};

String? _goTo(String location, String target) =>
    location == target ? null : target;
