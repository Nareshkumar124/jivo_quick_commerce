import 'package:jivo_api/jivo_api.dart'
    show
        AccountDeleteRequest,
        AccountDeletion,
        AppEnum,
        EmailOtpSendRequest,
        JivoApi,
        OtpPurposeEnum,
        OtpSendRequest,
        OtpSent;
import 'package:jivo_core/jivo_core.dart';

import '../domain/account_deletion_repository.dart';

/// [AccountDeletionRepository] over the generated client.
class ApiAccountDeletionRepository implements AccountDeletionRepository {
  const ApiAccountDeletionRepository(this._api);

  final JivoApi _api;

  @override
  Future<OtpSent> requestDeletionOtp(String phoneE164) => _call(
    () async => (await _api.getAuthApi().authOtpRequest(
      otpSendRequest: OtpSendRequest(
        phone: phoneE164,
        app: AppEnum.rider,
        purpose: OtpPurposeEnum.deleteAccount,
      ),
    )).data,
  );

  @override
  Future<OtpSent> requestDeletionOtpByEmail(String email) => _call(
    () async => (await _api.getAuthApi().authEmailOtpRequest(
      emailOtpSendRequest: EmailOtpSendRequest(
        email: email,
        app: AppEnum.rider,
        purpose: OtpPurposeEnum.deleteAccount,
      ),
    )).data,
  );

  @override
  Future<AccountDeletion> deleteAccount({
    required String otp,
    String? reason,
  }) => _call(
    () async => (await _api.getAccountApi().meDeleteAccount(
      accountDeleteRequest: AccountDeleteRequest(otp: otp, reason: reason),
    )).data,
  );

  static Future<T> _call<T>(Future<T?> Function() request) async {
    try {
      final data = await request();
      if (data == null) throw const ApiError(code: ApiErrorCode.unknown);
      return data;
    } on Object catch (error) {
      throw ApiError.from(error);
    }
  }
}
