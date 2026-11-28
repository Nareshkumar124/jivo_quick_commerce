/// How a rider can sign in, from `GET /api/v1/auth/methods/?app=rider`
/// (admin setting per app). The app falls back to [phone] when the call
/// fails, so login is never blocked by it.
enum LoginMethod { phone, email }

/// Support contact shown when an email is not a rider's (the rider app
/// cannot create a rider from an email; new riders register by phone).
abstract final class RiderSupportContact {
  static const email = 'info@jivo.in';
  static const phone = '+918595349565';
}

/// Raw error codes of the email login that jivo_core's `ApiErrorCode` does
/// not list yet (compared with `ApiError.rawCode`).
abstract final class EmailLoginErrorCodes {
  /// 403: the rider app does not know this email (no rider with it as a
  /// verified email).
  static const emailNotRegistered = 'EMAIL_NOT_REGISTERED';

  /// 403: this sign-in method is switched off for the rider app;
  /// `details.methods` lists the ones that are on.
  static const loginMethodDisabled = 'LOGIN_METHOD_DISABLED';
}

/// A light check before sending: the server validates the email.
bool looksLikeEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
