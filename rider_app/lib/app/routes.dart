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

  /// ACTIVE riders, between orders: earnings and payouts (screen 15), cash
  /// (16), history (17), profile and documents (18).
  static const earnings = '/earnings';
  static const payouts = '/payouts';
  static const cash = '/cash';
  static const history = '/history';

  /// One past task, e.g. `/history/7001`.
  static String historyDetail(int taskId) => '$history/$taskId';
  static const profile = '/profile';

  /// ACTIVE riders: the in-app inbox (P6).
  static const inbox = '/inbox';
  static const profileDocuments = '/profile/documents';

  /// An ACTIVE rider re-uploads one rejected (or missing) document, e.g.
  /// `/profile/documents/dl` (04 §2.9).
  static String profileDocumentCapture(String wireValue) =>
      '$profileDocuments/${wireValue.toLowerCase()}';

  static bool isAccountRoute(String location) => [
    earnings,
    payouts,
    cash,
    history,
    profile,
    inbox,
  ].any((root) => location == root || location.startsWith('$root/'));

  /// Permissions gate (04 §2.1, screen 7) and the prominent location
  /// disclosure: the go-online guard. ACTIVE riders reach it from home (and
  /// during a task, if a permission was revoked).
  static const permissions = '/permissions';
  static const disclosure = '/permissions/disclosure';

  static bool isPermissionsRoute(String location) =>
      location == permissions || location.startsWith('$permissions/');

  // Dev flavor only (Phase 0 spike).
  static const locationDebug = '/dev/location';
  static const offerPreview = '/dev/offer-preview';

  /// Routes that skip the launch/session guard (dev tools).
  static bool isDevRoute(String location) =>
      location.startsWith('/dev/') || location.startsWith(permissions);
}
