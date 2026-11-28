import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        AppEnum,
        AuthSession,
        EmailOtpSendRequest,
        EmailOtpVerifyRequest,
        JivoApi,
        LoginMethodEnum,
        LogoutRequest,
        Me,
        OtpPurposeEnum,
        OtpSendRequest,
        OtpSent,
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

  /// `GET /auth/methods/?app=customer`: the sign-in methods switched on,
  /// in the server's order (never empty). Throws [ApiError].
  Future<List<LoginMethod>> loginMethods();

  /// `POST /auth/email-otp/request/` for the customer app. Throws [ApiError].
  Future<OtpChallenge> requestEmailOtp(
    String email, {
    OtpPurpose purpose = OtpPurpose.login,
  });

  /// `POST /auth/email-otp/verify/` with the consent [termsVersion]; the
  /// same session as [verifyOtp]. Throws [ApiError].
  Future<SignInResult> verifyEmailOtp({
    required String email,
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
  hasPhone: me.hasPhone,
  emailVerified: me.emailVerified,
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
    return challengeFromSent(sent, phone);
  });

  @override
  Future<List<LoginMethod>> loginMethods() => _guard(() async {
    final result = (await _api.getAuthApi().authMethods(
      app: AppEnum.customer.value,
    )).data!;
    final methods = <LoginMethod>[
      for (final m in result.methods)
        if (m == LoginMethodEnum.phone)
          LoginMethod.phone
        else if (m == LoginMethodEnum.email)
          LoginMethod.email,
    ];
    return methods.isEmpty ? const [LoginMethod.phone] : methods;
  });

  @override
  Future<OtpChallenge> requestEmailOtp(
    String email, {
    OtpPurpose purpose = OtpPurpose.login,
  }) => _guard(() async {
    final sent = (await _api.getAuthApi().authEmailOtpRequest(
      emailOtpSendRequest: EmailOtpSendRequest(
        email: email,
        app: AppEnum.customer,
        purpose: switch (purpose) {
          OtpPurpose.login => OtpPurposeEnum.login,
          OtpPurpose.deleteAccount => OtpPurposeEnum.deleteAccount,
        },
      ),
    )).data!;
    return challengeFromSent(sent, email, method: LoginMethod.email);
  });

  @override
  Future<SignInResult> verifyEmailOtp({
    required String email,
    required String otp,
    required String termsVersion,
  }) => _guard(() async {
    final session = (await _api.getAuthApi().authEmailOtpVerify(
      emailOtpVerifyRequest: EmailOtpVerifyRequest(
        email: email,
        otp: otp,
        app: AppEnum.customer,
        termsVersion: termsVersion,
      ),
    )).data!;
    return _signInResult(session);
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
    return _signInResult(session);
  });

  @override
  Future<void> logout(String refreshToken, {String? fcmToken}) => _guard(
    () => _api.getAuthApi().authLogout(
      logoutRequest: LogoutRequest(refresh: refreshToken, fcmToken: fcmToken),
    ),
  );
}

SignInResult _signInResult(AuthSession session) => SignInResult(
  tokens: AuthTokens(access: session.access, refresh: session.refresh),
  user: userProfileFromMe(session.user),
  isNewUser: session.isNewUser,
  deletionCancelled: session.deletionCancelled,
);

/// An [OtpSent] response as an [OtpChallenge] for [destination].
OtpChallenge challengeFromSent(
  OtpSent sent,
  String destination, {
  LoginMethod method = LoginMethod.phone,
}) => OtpChallenge(
  destination: destination,
  method: method,
  otpLength: sent.otpLength,
  resendAfterSeconds: sent.resendAfterSeconds,
  expiresInSeconds: sent.expiresInSeconds,
);

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

/// TODO(api): a backend stand-in for `--dart-define=FAKE_API=true` and tests.
/// Every phone and email accepts OTP `123456`; `+919000000001` is an
/// existing, complete profile, other numbers are new users. Every email is
/// a new user without a phone.
class FakeAuthRepository implements AuthRepository {
  static const validOtp = '123456';
  static const existingPhone = '+919000000001';

  /// What [loginMethods] returns; [methodsError] makes it fail instead.
  List<LoginMethod> methods = const [LoginMethod.phone];
  ApiError? methodsError;
  int methodsCalls = 0;

  final List<(String, OtpPurpose)> otpRequests = [];
  final List<(String, OtpPurpose)> emailOtpRequests = [];
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
      destination: phone,
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
  Future<List<LoginMethod>> loginMethods() async {
    methodsCalls++;
    final error = methodsError;
    if (error != null) throw error;
    return methods;
  }

  @override
  Future<OtpChallenge> requestEmailOtp(
    String email, {
    OtpPurpose purpose = OtpPurpose.login,
  }) async {
    final error = requestError;
    if (error != null) throw error;
    emailOtpRequests.add((email, purpose));
    return OtpChallenge(
      destination: email,
      method: LoginMethod.email,
      otpLength: 6,
      resendAfterSeconds: 30,
      expiresInSeconds: 300,
    );
  }

  @override
  Future<SignInResult> verifyEmailOtp({
    required String email,
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
    _tokenCounter++;
    return SignInResult(
      tokens: AuthTokens(
        access: 'fake-access-$_tokenCounter',
        refresh: 'fake-refresh-$_tokenCounter',
      ),
      user: UserProfile(
        id: 3,
        phone: '',
        name: '',
        email: email,
        isProfileComplete: false,
        hasPhone: false,
        emailVerified: true,
      ),
      isNewUser: true,
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
