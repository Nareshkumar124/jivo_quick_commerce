import 'package:jivo_api/jivo_api.dart' show AuthSession, OtpSent;

/// Phone OTP login for the rider app (`06 §2.1`). Every call sends
/// `app: rider`. Methods throw jivo_core's `ApiError` on failure.
abstract interface class AuthRepository {
  /// `POST /api/v1/auth/otp/request/` with `purpose: login`.
  Future<OtpSent> requestOtp(String phoneE164);

  /// `POST /api/v1/auth/otp/verify/`. [termsVersion] comes from
  /// `config/app` and is recorded as the rider's consent (DPDP).
  Future<AuthSession> verifyOtp({
    required String phoneE164,
    required String otp,
    required String termsVersion,
  });

  /// `POST /api/v1/auth/logout/`: blacklists [refreshToken]; with
  /// [fcmToken] the server also stops push to this phone.
  Future<void> logout({required String refreshToken, String? fcmToken});
}
