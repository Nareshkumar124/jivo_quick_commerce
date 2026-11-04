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
  static const categories = '/categories';
  static const orderAgain = '/order-again';
  static const search = '/search';
  static const location = '/location';
  static const mapPicker = '/location/map';
  static const notServiceable = '/location/not-serviceable';
  static const account = '/account';
  static const editProfile = '/account/profile';
  static const addresses = '/account/addresses';
  static const newAddress = '/account/addresses/new';
  static const deleteAccount = '/account/delete';

  /// Under Home, on the root navigator: `go` keeps Home behind them.
  static const cart = '/home/cart';
  static const checkout = '/home/cart/checkout';

  /// The order-placed screen (`03 §2.9`).
  static String orderSuccess(int orderId) => '/orders/$orderId/success';

  /// Payment failed / retry for a `PAYMENT_PENDING` order (`03 §2.9`).
  static String paymentFailed(int orderId) => '/orders/$orderId/payment';

  static String editAddress(int id) => '/account/addresses/$id';

  /// Product list of a category; [sub] preselects a sub-category.
  static String category(String slug, {String? sub}) => Uri(
    path: '/category/$slug',
    queryParameters: sub == null ? null : {'sub': sub},
  ).toString();

  static String product(String slug) => '/product/$slug';

  static String collection(String slug) => '/collection/$slug';

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
