/// Route paths.
abstract final class Routes {
  static const splash = '/splash';
  static const update = '/update';
  static const maintenance = '/maintenance';

  static const login = '/login';
  static const otp = '/login/otp';

  /// `rider_status: NONE`: registration placeholder (registration is P5).
  static const register = '/register';

  /// `PENDING_KYC`, `REJECTED`, `SUSPENDED` (and unknown values).
  static const riderStatus = '/rider-status';

  /// `ACTIVE`.
  static const home = '/';

  // Dev flavor only (Phase 0 spike).
  /// Permissions gate (04 §2.1). Becomes the go-online guard in P5.
  static const permissions = '/permissions';
  static const disclosure = '/permissions/disclosure';
  static const locationDebug = '/dev/location';
  static const offerPreview = '/dev/offer-preview';

  /// Routes that skip the launch/session guard (dev tools).
  static bool isDevRoute(String location) =>
      location.startsWith('/dev/') || location.startsWith(permissions);
}
