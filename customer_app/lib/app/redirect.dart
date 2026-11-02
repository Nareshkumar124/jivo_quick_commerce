import 'package:jivo_core/jivo_core.dart';

/// Route paths.
abstract final class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const updateRequired = '/update-required';
  static const maintenance = '/maintenance';
  static const login = '/login';
  static const otp = '/login/otp';
  static const completeProfile = '/complete-profile';
  static const home = '/home';
  static const account = '/account';
  static const editProfile = '/account/profile';
  static const addresses = '/account/addresses';
  static const newAddress = '/account/addresses/new';
  static const deleteAccount = '/account/delete';

  static String editAddress(int id) => '/account/addresses/$id';

  /// Screens that only make sense before the user is in the app.
  static const _entry = {
    splash,
    onboarding,
    login,
    otp,
    completeProfile,
    updateRequired,
    maintenance,
  };
}

/// Where the router must send the user, or null to stay (`03 §1`).
///
/// Order: a force update blocks everything, then maintenance; until start-up
/// finished, the splash; signed out: onboarding (first launch) then login;
/// signed in: complete-profile while the profile is incomplete, otherwise
/// away from the entry screens to home.
String? resolveRedirect({
  required String location,
  required AppControlEvent? control,
  required SessionStatus session,
  required bool ready,
  required bool onboardingSeen,
  required bool? profileComplete,
  required bool hasOtpChallenge,
}) {
  String? go(String target) => location == target ? null : target;

  if (control is AppUpdateRequired) return go(Routes.updateRequired);
  if (control is MaintenanceMode) return go(Routes.maintenance);

  if (!ready || session == SessionStatus.unknown) return go(Routes.splash);

  if (session == SessionStatus.signedOut) {
    if (!onboardingSeen) return go(Routes.onboarding);
    if (location == Routes.otp && hasOtpChallenge) return null;
    return go(Routes.login);
  }

  if (profileComplete == false) return go(Routes.completeProfile);
  if (Routes._entry.contains(location)) return Routes.home;
  return null;
}
