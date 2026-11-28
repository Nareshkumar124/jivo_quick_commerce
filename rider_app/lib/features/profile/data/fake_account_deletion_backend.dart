import 'package:jivo_api/jivo_api.dart' show AccountDeletion, OtpSent;
import 'package:jivo_core/jivo_core.dart';

import '../domain/account_deletion_repository.dart';

/// Account deletion for `FAKE_API` builds and tests. Follows the schema's
/// `OtpSent`, `AccountDeletion` ("Scheduled") and `OTP_INVALID` /
/// `OTP_EXPIRED` examples. Valid OTP: [validOtp].
class FakeAccountDeletionBackend implements AccountDeletionRepository {
  FakeAccountDeletionBackend({
    this.delay = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const validOtp = '123456';
  static const maxAttempts = 5;

  final Duration delay;
  final DateTime Function() _clock;

  /// Calls made, for tests.
  final List<String> calls = [];

  bool _otpPending = false;
  int _failed = 0;

  @override
  Future<OtpSent> requestDeletionOtp(String phoneE164) async {
    calls.add('requestDeletionOtp $phoneE164');
    await _wait();
    _otpPending = true;
    _failed = 0;
    return OtpSent.fromJson(const {
      'otp_length': 6,
      'expires_in_seconds': 300,
      'resend_after_seconds': 30,
    });
  }

  @override
  Future<AccountDeletion> deleteAccount({
    required String otp,
    String? reason,
  }) async {
    calls.add('deleteAccount $otp');
    await _wait();
    if (!_otpPending) {
      throw const ApiError(
        code: ApiErrorCode.otpExpired,
        rawCode: 'OTP_EXPIRED',
        statusCode: 400,
      );
    }
    if (otp != validOtp) {
      _failed++;
      final remaining = maxAttempts - _failed;
      if (remaining <= 0) {
        _otpPending = false;
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
    _otpPending = false;
    final now = _clock().toUtc();
    return AccountDeletion(
      deletedAt: now,
      anonymiseAfter: now.add(const Duration(days: 30)),
    );
  }

  Future<void> _wait() =>
      delay == Duration.zero ? Future.value() : Future.delayed(delay);
}
