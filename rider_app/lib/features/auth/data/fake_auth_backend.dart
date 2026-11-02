import 'package:jivo_api/jivo_api.dart'
    show AuthSession, Me, OtpSent, RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';

import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';

/// TODO(api): stands in for the Phase 1 auth endpoints until the backend
/// implements them. Responses and errors follow the examples in
/// `backend/openapi/schema.yaml` (`OtpSent`, `AuthSession` "Rider app"
/// examples, `OTP_INVALID` with `attempts_remaining`, `OTP_EXPIRED`,
/// `OTP_RATE_LIMITED` with `retry_after_seconds`).
///
/// Dev test numbers (use OTP [validOtp]):
/// - last digit 2: `PENDING_KYC`, 3: `REJECTED`, 4: `SUSPENDED`,
///   5: `NONE` (no rider profile), anything else: `ACTIVE`
/// - [rateLimitedPhone]: every OTP request is rate limited
class FakeAuthBackend implements AuthRepository, AccountRepository {
  FakeAuthBackend({this.delay = const Duration(milliseconds: 400)});

  static const validOtp = '123456';
  static const rateLimitedPhone = '+919999999999';
  static const maxAttempts = 5;

  final Duration delay;

  String? _pendingPhone;
  int _failedAttempts = 0;
  Me? _currentUser;

  /// Calls made, for tests.
  final List<String> calls = [];

  /// When true, every OTP request fails with `OTP_RATE_LIMITED`.
  bool rateLimitRequests = false;

  @override
  Future<OtpSent> requestOtp(String phoneE164) async {
    calls.add('requestOtp $phoneE164');
    await _wait();
    if (rateLimitRequests || phoneE164 == rateLimitedPhone) {
      throw const ApiError(
        code: ApiErrorCode.otpRateLimited,
        rawCode: 'OTP_RATE_LIMITED',
        details: {'retry_after_seconds': 540},
        statusCode: 429,
      );
    }
    _pendingPhone = phoneE164;
    _failedAttempts = 0;
    return OtpSent.fromJson(const {
      'otp_length': 6,
      'expires_in_seconds': 300,
      'resend_after_seconds': 30,
    });
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phoneE164,
    required String otp,
    required String termsVersion,
  }) async {
    calls.add('verifyOtp $phoneE164 $otp terms=$termsVersion');
    await _wait();
    if (_pendingPhone != phoneE164 || _failedAttempts >= maxAttempts) {
      throw const ApiError(
        code: ApiErrorCode.otpExpired,
        rawCode: 'OTP_EXPIRED',
        statusCode: 400,
      );
    }
    if (otp != validOtp) {
      _failedAttempts++;
      final remaining = maxAttempts - _failedAttempts;
      if (remaining == 0) {
        throw const ApiError(
          code: ApiErrorCode.otpExpired,
          rawCode: 'OTP_EXPIRED',
          statusCode: 400,
        );
      }
      throw ApiError(
        code: ApiErrorCode.otpInvalid,
        rawCode: 'OTP_INVALID',
        details: {'attempts_remaining': remaining},
        statusCode: 400,
      );
    }
    _pendingPhone = null;
    final status = statusForPhone(phoneE164);
    final user = Me.fromJson({
      'id': 57,
      'phone': phoneE164,
      'name': status == RiderStatusEnum.NONE ? '' : 'Ravi Kumar',
      'email': null,
      'marketing_opt_in': false,
      'is_profile_complete': status != RiderStatusEnum.NONE,
      'rider_status': status.value,
      'created_at': '2026-10-28T04:00:00Z',
    });
    _currentUser = user;
    return AuthSession.fromJson({
      'access': 'fake-access-token',
      'refresh': 'fake-refresh-token',
      'user': user.toJson(),
      'is_new_user': status == RiderStatusEnum.NONE,
      'rider_status': status.value,
      'deletion_cancelled': false,
    });
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    calls.add('logout');
    await _wait();
    _currentUser = null;
  }

  @override
  Future<Me> fetchMe() async {
    calls.add('fetchMe');
    await _wait();
    final user = _currentUser;
    if (user == null) {
      throw const ApiError(
        code: ApiErrorCode.authRequired,
        rawCode: 'AUTH_REQUIRED',
        statusCode: 401,
      );
    }
    return user;
  }

  /// Signs in [phoneE164] directly, as if a session was restored.
  void seedSignedIn(String phoneE164) {
    _currentUser = Me.fromJson({
      'id': 57,
      'phone': phoneE164,
      'name': 'Ravi Kumar',
      'email': null,
      'marketing_opt_in': false,
      'is_profile_complete': true,
      'rider_status': statusForPhone(phoneE164).value,
      'created_at': '2026-10-28T04:00:00Z',
    });
  }

  static RiderStatusEnum statusForPhone(String phoneE164) =>
      switch (phoneE164.isEmpty ? '' : phoneE164[phoneE164.length - 1]) {
        '2' => RiderStatusEnum.PENDING_KYC,
        '3' => RiderStatusEnum.REJECTED,
        '4' => RiderStatusEnum.SUSPENDED,
        '5' => RiderStatusEnum.NONE,
        _ => RiderStatusEnum.ACTIVE,
      };

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }
}
