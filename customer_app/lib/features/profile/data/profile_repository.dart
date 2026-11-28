import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show
        AccountDeleteRequest,
        EmailOtpForMeRequest,
        EmailVerifyRequest,
        JivoApi,
        PatchedMeRequest,
        PhoneOtpSendRequest,
        PhoneVerifyRequest;
import 'package:jivo_core/jivo_core.dart';

import '../../auth/data/auth_repository.dart'
    show challengeFromSent, userProfileFromMe;
import '../../auth/domain/auth_models.dart';
import '../domain/user_profile.dart';

abstract interface class ProfileRepository {
  /// `GET /me/`. Throws [ApiError].
  Future<UserProfile> fetchMe();

  /// `PATCH /me/`. A null or empty [email] removes it. Throws [ApiError].
  Future<UserProfile> updateProfile({required String name, String? email});

  /// `POST /me/delete/` with a `delete_account` OTP. Throws [ApiError].
  Future<AccountDeletion> deleteAccount({required String otp, String? reason});

  /// `POST /me/phone/otp/`: an SMS OTP to add [phone] (`+91…`) to an
  /// account without one. Throws [ApiError].
  Future<OtpChallenge> requestPhoneOtp(String phone);

  /// `POST /me/phone/verify/`; `PHONE_IN_USE` when another account has the
  /// number. Throws [ApiError].
  Future<UserProfile> verifyPhone({required String phone, required String otp});

  /// `POST /me/email/otp/`: an email OTP to verify [email]. Throws [ApiError].
  Future<OtpChallenge> requestEmailOtp(String email);

  /// `POST /me/email/verify/`; `EMAIL_IN_USE` when another account has it
  /// verified. Throws [ApiError].
  Future<UserProfile> verifyEmail({required String email, required String otp});
}

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final JivoApi _api;

  @override
  Future<UserProfile> fetchMe() => _guard(
    () async =>
        userProfileFromMe((await _api.getAccountApi().meRetrieve()).data!),
  );

  @override
  Future<UserProfile> updateProfile({required String name, String? email}) =>
      _guard(() async {
        // The generated model drops null fields, so removal is sent as '' (the
        // contract accepts null or an empty string).
        final me = (await _api.getAccountApi().meUpdate(
          patchedMeRequest: PatchedMeRequest(
            name: name.trim(),
            email: email?.trim() ?? '',
          ),
        )).data!;
        return userProfileFromMe(me);
      });

  @override
  Future<AccountDeletion> deleteAccount({
    required String otp,
    String? reason,
  }) => _guard(() async {
    final trimmed = reason?.trim();
    final result = (await _api.getAccountApi().meDeleteAccount(
      accountDeleteRequest: AccountDeleteRequest(
        otp: otp,
        reason: trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    )).data!;
    return AccountDeletion(
      deletedAt: result.deletedAt,
      anonymiseAfter: result.anonymiseAfter,
    );
  });

  @override
  Future<OtpChallenge> requestPhoneOtp(String phone) => _guard(() async {
    final sent = (await _api.getAccountApi().mePhoneOtp(
      phoneOtpSendRequest: PhoneOtpSendRequest(phone: phone),
    )).data!;
    return challengeFromSent(sent, phone);
  });

  @override
  Future<UserProfile> verifyPhone({
    required String phone,
    required String otp,
  }) => _guard(() async {
    final me = (await _api.getAccountApi().mePhoneVerify(
      phoneVerifyRequest: PhoneVerifyRequest(phone: phone, otp: otp),
    )).data!;
    return userProfileFromMe(me);
  });

  @override
  Future<OtpChallenge> requestEmailOtp(String email) => _guard(() async {
    final sent = (await _api.getAccountApi().meEmailOtp(
      emailOtpForMeRequest: EmailOtpForMeRequest(email: email),
    )).data!;
    return challengeFromSent(sent, email, method: LoginMethod.email);
  });

  @override
  Future<UserProfile> verifyEmail({
    required String email,
    required String otp,
  }) => _guard(() async {
    final me = (await _api.getAccountApi().meEmailVerify(
      emailVerifyRequest: EmailVerifyRequest(email: email, otp: otp),
    )).data!;
    return userProfileFromMe(me);
  });
}

Future<T> _guard<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiError.fromDioException(e);
  }
}

/// TODO(api): a backend stand-in for `--dart-define=FAKE_API=true` and tests.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([UserProfile? profile])
    : profile =
          profile ??
          const UserProfile(
            id: 1,
            phone: '+919000000001',
            name: 'Test Customer',
            isProfileComplete: true,
          );

  UserProfile profile;
  ApiError? fetchError;
  ApiError? updateError;
  ApiError? deleteError;
  ApiError? contactError;
  final List<(String, String?)> deletions = [];
  final List<String> phoneOtpRequests = [];
  final List<String> emailOtpRequests = [];

  @override
  Future<UserProfile> fetchMe() async {
    final error = fetchError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String name,
    String? email,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    final cleanEmail = email?.trim();
    final newEmail = cleanEmail == null || cleanEmail.isEmpty
        ? null
        : cleanEmail;
    profile = UserProfile(
      id: profile.id,
      phone: profile.phone,
      name: name.trim(),
      email: newEmail,
      isProfileComplete: name.trim().isNotEmpty,
      hasPhone: profile.hasPhone,
      emailVerified: profile.emailVerified && newEmail == profile.email,
    );
    return profile;
  }

  void _check(String otp) {
    final error = contactError;
    if (error != null) throw error;
    if (otp != '123456') {
      throw const ApiError(
        code: ApiErrorCode.otpInvalid,
        statusCode: 400,
        details: {'attempts_remaining': 4},
      );
    }
  }

  OtpChallenge _sent(String to, LoginMethod method) => OtpChallenge(
    destination: to,
    method: method,
    otpLength: 6,
    resendAfterSeconds: 30,
    expiresInSeconds: 300,
  );

  @override
  Future<OtpChallenge> requestPhoneOtp(String phone) async {
    final error = contactError;
    if (error != null) throw error;
    phoneOtpRequests.add(phone);
    return _sent(phone, LoginMethod.phone);
  }

  @override
  Future<UserProfile> verifyPhone({
    required String phone,
    required String otp,
  }) async {
    _check(otp);
    profile = UserProfile(
      id: profile.id,
      phone: phone,
      name: profile.name,
      email: profile.email,
      isProfileComplete: profile.isProfileComplete,
      emailVerified: profile.emailVerified,
    );
    return profile;
  }

  @override
  Future<OtpChallenge> requestEmailOtp(String email) async {
    final error = contactError;
    if (error != null) throw error;
    emailOtpRequests.add(email);
    return _sent(email, LoginMethod.email);
  }

  @override
  Future<UserProfile> verifyEmail({
    required String email,
    required String otp,
  }) async {
    _check(otp);
    profile = UserProfile(
      id: profile.id,
      phone: profile.phone,
      name: profile.name,
      email: email,
      isProfileComplete: profile.isProfileComplete,
      hasPhone: profile.hasPhone,
      emailVerified: true,
    );
    return profile;
  }

  @override
  Future<AccountDeletion> deleteAccount({
    required String otp,
    String? reason,
  }) async {
    final error = deleteError;
    if (error != null) throw error;
    if (otp != '123456') {
      throw const ApiError(
        code: ApiErrorCode.otpInvalid,
        statusCode: 400,
        details: {'attempts_remaining': 4},
      );
    }
    deletions.add((otp, reason));
    final now = DateTime.utc(2026, 11, 2, 10);
    return AccountDeletion(
      deletedAt: now,
      anonymiseAfter: now.add(const Duration(days: 30)),
    );
  }
}
