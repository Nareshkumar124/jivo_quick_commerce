import 'package:jivo_api/jivo_api.dart' show AccountDeletion, OtpSent;

/// In-app account deletion (Google Play requirement; `03 §2.2`), the same
/// two calls the customer app makes:
/// 1. `POST /api/v1/auth/otp/request/` with the rider's own phone,
///    `app: rider` and `purpose: delete_account`;
/// 2. `POST /api/v1/me/delete/` with that OTP.
///
/// On success the server revokes every refresh token and deactivates the
/// rider's devices; the app then only signs out locally. Methods throw
/// jivo_core's `ApiError` on failure.
abstract interface class AccountDeletionRepository {
  Future<OtpSent> requestDeletionOtp(String phoneE164);

  Future<AccountDeletion> deleteAccount({required String otp, String? reason});
}
