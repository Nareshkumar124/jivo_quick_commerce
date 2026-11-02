/// Route paths.
abstract final class Routes {
  static const splash = '/splash';
  static const update = '/update';
  static const maintenance = '/maintenance';

  static const login = '/login';
  static const otp = '/login/otp';

  /// `rider_status: NONE`: the registration form (04 §2.2, screen 3).
  static const register = '/register';

  /// `PENDING_KYC`, `REJECTED`, `SUSPENDED` (and unknown values): the
  /// approval status screen (screen 6), the hub of the application steps.
  static const riderStatus = '/rider-status';

  /// Application steps under the status screen, open to `PENDING_KYC` and
  /// `REJECTED` riders only (screens 4 and 5).
  static const documents = '/rider-status/documents';
  static const bankDetails = '/rider-status/bank';

  /// One document's capture and upload, e.g. `/rider-status/documents/pan`.
  static String documentCapture(String wireValue) =>
      '$documents/${wireValue.toLowerCase()}';

  /// `ACTIVE`.
  static const home = '/';

  /// ACTIVE riders: the incoming offer (04 §2.4, screen 9), while one is open.
  static const offer = '/offer';

  /// ACTIVE riders: the current task, step by step (screens 10–14). While a
  /// task is active this is the only place the rider can be.
  static const task = '/task';
  static const taskScan = '/task/scan';
  static const taskFail = '/task/fail';

  static bool isTaskRoute(String location) =>
      location == task || location.startsWith('$task/');

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
