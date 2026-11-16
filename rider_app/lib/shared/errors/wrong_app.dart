import 'package:jivo_core/jivo_core.dart';

/// DL-74: the rider API (`/api/v1/rider/*` and `/ws/v1/rider/`) takes
/// rider-app tokens only.
///
/// The backend answers a customer-app token with 403 `PERMISSION_DENIED`
/// and `details.reason` = `WRONG_APP_TOKEN` (06 §2.1 "App tokens", §6). As
/// this app always sends `X-App-Name: rider`, the backend's header check
/// (which runs first) refuses a customer token with `details.reason` =
/// `APP_HEADER_MISMATCH`: the same situation for the rider, so it is treated
/// the same. The rider socket sends an `error` message with code
/// `WRONG_APP_TOKEN` before closing with 4403.
abstract final class WrongApp {
  static const wrongAppToken = 'WRONG_APP_TOKEN';
  static const appHeaderMismatch = 'APP_HEADER_MISMATCH';

  /// Whether [error] means "this session belongs to another Jivo app".
  static bool isWrongApp(ApiError error) =>
      (error.statusCode == null || error.statusCode == 403) &&
      error.code == ApiErrorCode.permissionDenied &&
      (error.reason == wrongAppToken || error.reason == appHeaderMismatch);

  /// The rider socket's `error` message code before its 4403 close.
  static bool isWrongAppSocketCode(String code) => code == wrongAppToken;
}
