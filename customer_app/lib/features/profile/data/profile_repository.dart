import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show AccountDeleteRequest, JivoApi, PatchedMeRequest;
import 'package:jivo_core/jivo_core.dart';

import '../../auth/data/auth_repository.dart' show userProfileFromMe;
import '../domain/user_profile.dart';

abstract interface class ProfileRepository {
  /// `GET /me/`. Throws [ApiError].
  Future<UserProfile> fetchMe();

  /// `PATCH /me/`. A null or empty [email] removes it. Throws [ApiError].
  Future<UserProfile> updateProfile({required String name, String? email});

  /// `POST /me/delete/` with a `delete_account` OTP. Throws [ApiError].
  Future<AccountDeletion> deleteAccount({required String otp, String? reason});
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
  final List<(String, String?)> deletions = [];

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
    profile = UserProfile(
      id: profile.id,
      phone: profile.phone,
      name: name.trim(),
      email: cleanEmail == null || cleanEmail.isEmpty ? null : cleanEmail,
      isProfileComplete: name.trim().isNotEmpty,
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
