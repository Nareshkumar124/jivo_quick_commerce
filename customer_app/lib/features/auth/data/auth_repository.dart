import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        AppEnum,
        JivoApi,
        LogoutRequest,
        Me,
        OtpPurposeEnum,
        OtpSendRequest,
        OtpVerifyRequest;
import 'package:jivo_core/jivo_core.dart';

import '../../profile/domain/user_profile.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  /// `POST /auth/otp/request/` for the customer app. Throws [ApiError].
  Future<OtpChallenge> requestOtp(
    String phone, {
    OtpPurpose purpose = OtpPurpose.login,
  });

  /// `POST /auth/otp/verify/` with the consent [termsVersion]. Throws [ApiError].
  Future<SignInResult> verifyOtp({
    required String phone,
    required String otp,
    required String termsVersion,
  });

  /// `POST /auth/logout/`: revokes [refreshToken] and, with [fcmToken],
  /// stops pushes to this device. Throws [ApiError].
  Future<void> logout(String refreshToken, {String? fcmToken});
}

UserProfile userProfileFromMe(Me me) => UserProfile(
  id: me.id,
  phone: me.phone ?? '',
  name: me.name,
  email: (me.email?.isEmpty ?? true) ? null : me.email,
  isProfileComplete: me.isProfileComplete,
);

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this._api);

  final JivoApi _api;

  @override
  Future<OtpChallenge> requestOtp(
    String phone, {
    OtpPurpose purpose = OtpPurpose.login,
  }) => _guard(() async {
    final sent = (await _api.getAuthApi().authOtpRequest(
      otpSendRequest: OtpSendRequest(
        phone: phone,
        app: AppEnum.customer,
        purpose: switch (purpose) {
          OtpPurpose.login => OtpPurposeEnum.login,
          OtpPurpose.deleteAccount => OtpPurposeEnum.deleteAccount,
        },
      ),
    )).data!;
    return OtpChallenge(
      phone: phone,
      otpLength: sent.otpLength,
      resendAfterSeconds: sent.resendAfterSeconds,
      expiresInSeconds: sent.expiresInSeconds,
    );
  });

  @override
  Future<SignInResult> verifyOtp({
    required String phone,
    required String otp,
    required String termsVersion,
  }) => _guard(() async {
    final session = (await _api.getAuthApi().authOtpVerify(
      otpVerifyRequest: OtpVerifyRequest(
        phone: phone,
        otp: otp,
        app: AppEnum.customer,
        termsVersion: termsVersion,
      ),
    )).data!;
    return SignInResult(
      tokens: AuthTokens(access: session.access, refresh: session.refresh),
      user: userProfileFromMe(session.user),
      isNewUser: session.isNewUser,
      deletionCancelled: session.deletionCancelled,
    );
  });

  @override
  Future<void> logout(String refreshToken, {String? fcmToken}) => _guard(
    () => _api.getAuthApi().authLogout(
      logoutRequest: LogoutRequest(refresh: refreshToken, fcmToken: fcmToken),
    ),
  );
}

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

/// TODO(api): a backend stand-in for `--dart-define=FAKE_API=true` and tests.
/// Every phone accepts OTP `123456`; `+919000000001` is an existing,
/// complete profile, other numbers are new users.
class FakeAuthRepository implements AuthRepository {
  static const validOtp = '123456';
  static const existingPhone = '+919000000001';

  final List<(String, OtpPurpose)> otpRequests = [];
  final List<String> loggedOutTokens = [];
  final List<String> verifiedTermsVersions = [];
  ApiError? requestError;
  ApiError? verifyError;
  bool deletionCancelled = false;
  int _tokenCounter = 0;

  @override
  Future<OtpChallenge> requestOtp(
    String phone, {
    OtpPurpose purpose = OtpPurpose.login,
  }) async {
    final error = requestError;
    if (error != null) throw error;
    otpRequests.add((phone, purpose));
    return OtpChallenge(
      phone: phone,
      otpLength: 6,
      resendAfterSeconds: 30,
      expiresInSeconds: 300,
    );
  }

  @override
  Future<SignInResult> verifyOtp({
    required String phone,
    required String otp,
    required String termsVersion,
  }) async {
    verifiedTermsVersions.add(termsVersion);
    final error = verifyError;
    if (error != null) throw error;
    if (otp != validOtp) {
      throw const ApiError(
        code: ApiErrorCode.otpInvalid,
        statusCode: 400,
        details: {'attempts_remaining': 4},
      );
    }
    final existing = phone == existingPhone;
    _tokenCounter++;
    return SignInResult(
      tokens: AuthTokens(
        access: 'fake-access-$_tokenCounter',
        refresh: 'fake-refresh-$_tokenCounter',
      ),
      user: UserProfile(
        id: existing ? 1 : 2,
        phone: phone,
        name: existing ? 'Test Customer' : '',
        isProfileComplete: existing,
      ),
      isNewUser: !existing,
      deletionCancelled: deletionCancelled,
    );
  }

  @override
  Future<void> logout(String refreshToken, {String? fcmToken}) async {
    loggedOutTokens.add(refreshToken);
    if (fcmToken != null) loggedOutFcmTokens.add(fcmToken);
  }

  /// The push tokens sent with [logout].
  final List<String> loggedOutFcmTokens = [];
}
