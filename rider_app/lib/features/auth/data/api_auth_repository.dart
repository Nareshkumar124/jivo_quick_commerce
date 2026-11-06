import 'package:jivo_api/jivo_api.dart'
    show
        AppEnum,
        AuthSession,
        JivoApi,
        LogoutRequest,
        Me,
        OtpPurposeEnum,
        OtpSendRequest,
        OtpSent,
        OtpVerifyRequest;
import 'package:jivo_core/jivo_core.dart';

import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';

/// [AuthRepository] and [AccountRepository] over the generated client.
class ApiAuthRepository implements AuthRepository, AccountRepository {
  const ApiAuthRepository(this._api);

  final JivoApi _api;

  @override
  Future<OtpSent> requestOtp(String phoneE164) => _call(
    () async => (await _api.getAuthApi().authOtpRequest(
      otpSendRequest: OtpSendRequest(
        phone: phoneE164,
        app: AppEnum.rider,
        purpose: OtpPurposeEnum.login,
      ),
    )).data,
  );

  @override
  Future<AuthSession> verifyOtp({
    required String phoneE164,
    required String otp,
    required String termsVersion,
  }) => _call(
    () async => (await _api.getAuthApi().authOtpVerify(
      otpVerifyRequest: OtpVerifyRequest(
        phone: phoneE164,
        otp: otp,
        app: AppEnum.rider,
        termsVersion: termsVersion,
      ),
    )).data,
  );

  @override
  Future<void> logout({required String refreshToken, String? fcmToken}) async {
    try {
      await _api.getAuthApi().authLogout(
        logoutRequest: LogoutRequest(refresh: refreshToken, fcmToken: fcmToken),
      );
    } on Object catch (error) {
      throw ApiError.from(error);
    }
  }

  @override
  Future<Me> fetchMe() =>
      _call(() async => (await _api.getAccountApi().meRetrieve()).data);

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
