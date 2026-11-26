import 'package:dio/dio.dart';
import 'package:jivo_api/jivo_api.dart'
    show AccountDeleteRequest, JivoApi, PatchedMeRequest;
import 'package:jivo_api/jivo_api.dart' as api show BusinessCategory;
import 'package:jivo_core/jivo_core.dart';

import '../../auth/data/auth_repository.dart' show userProfileFromMe;
import '../domain/user_profile.dart';

abstract interface class ProfileRepository {
  /// `GET /me/`. Throws [ApiError].
  Future<UserProfile> fetchMe();

  /// `PATCH /me/` from Edit profile. A null or empty [email] removes it.
  /// [businessCategoryId] and [businessName] are sent only when not null
  /// (an empty [businessName] removes it). Throws [ApiError].
  Future<UserProfile> updateProfile({
    required String name,
    String? email,
    int? businessCategoryId,
    String? businessName,
  });

  /// Submit on the complete-profile screen (`03 §2.2`): `PATCH /me/` with
  /// `name`, the optional `business_category` and `business_name`. The
  /// server then reports `is_profile_complete: true`. Throws [ApiError].
  Future<UserProfile> submitBusinessProfile({
    required String name,
    int? businessCategoryId,
    String businessName = '',
  });

  /// Skip on the complete-profile screen: `POST /me/profile-prompt/skip/`.
  /// Throws [ApiError].
  Future<UserProfile> skipProfilePrompt();

  /// `GET /business-categories/`: active categories in admin order.
  /// Throws [ApiError].
  Future<List<BusinessCategory>> businessCategories();

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
  Future<UserProfile> updateProfile({
    required String name,
    String? email,
    int? businessCategoryId,
    String? businessName,
  }) => _guard(() async {
    // The generated model drops null fields, so removal is sent as '' (the
    // contract accepts null or an empty string).
    final me = (await _api.getAccountApi().meUpdate(
      patchedMeRequest: PatchedMeRequest(
        name: name.trim(),
        email: email?.trim() ?? '',
        businessCategory: businessCategoryId,
        businessName: businessName?.trim(),
      ),
    )).data!;
    return userProfileFromMe(me);
  });

  @override
  Future<UserProfile> submitBusinessProfile({
    required String name,
    int? businessCategoryId,
    String businessName = '',
  }) => _guard(() async {
    final me = (await _api.getAccountApi().meUpdate(
      patchedMeRequest: PatchedMeRequest(
        name: name.trim(),
        businessCategory: businessCategoryId,
        businessName: businessName.trim(),
      ),
    )).data!;
    return userProfileFromMe(me);
  });

  @override
  Future<UserProfile> skipProfilePrompt() => _guard(
    () async => userProfileFromMe(
      (await _api.getAccountApi().meProfilePromptSkip()).data!,
    ),
  );

  @override
  Future<List<BusinessCategory>> businessCategories() => _guard(() async {
    final list = (await _api.getAccountApi().businessCategoriesList()).data!;
    return [for (final c in list) _category(c)];
  });

  static BusinessCategory _category(api.BusinessCategory c) =>
      BusinessCategory(id: c.id, name: c.name, slug: c.slug);

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
  ApiError? skipError;
  ApiError? categoriesError;
  final List<(String, String?)> deletions = [];

  /// Calls of [skipProfilePrompt].
  int skips = 0;

  /// Calls of [businessCategories].
  int categoryLoads = 0;

  /// Each `PATCH /me/` from complete-profile: name, category id, business
  /// name.
  final List<(String, int?, String)> businessSubmits = [];

  List<BusinessCategory> categories = const [
    BusinessCategory(id: 1, name: 'Kirana / General store', slug: 'kirana'),
    BusinessCategory(id: 2, name: 'Restaurant / Café', slug: 'restaurant-cafe'),
    BusinessCategory(id: 3, name: 'Household', slug: 'household'),
  ];

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
    int? businessCategoryId,
    String? businessName,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    final cleanEmail = email?.trim();
    final category = _categoryById(businessCategoryId);
    profile = UserProfile(
      id: profile.id,
      phone: profile.phone,
      name: name.trim(),
      email: cleanEmail == null || cleanEmail.isEmpty ? null : cleanEmail,
      isProfileComplete: true,
      businessCategoryId: category?.id ?? profile.businessCategoryId,
      businessCategoryName: category?.name ?? profile.businessCategoryName,
      businessName: businessName?.trim() ?? profile.businessName,
    );
    return profile;
  }

  @override
  Future<UserProfile> submitBusinessProfile({
    required String name,
    int? businessCategoryId,
    String businessName = '',
  }) async {
    final error = updateError;
    if (error != null) throw error;
    businessSubmits.add((name.trim(), businessCategoryId, businessName.trim()));
    final category = _categoryById(businessCategoryId);
    profile = UserProfile(
      id: profile.id,
      phone: profile.phone,
      name: name.trim(),
      email: profile.email,
      isProfileComplete: true,
      businessCategoryId: category?.id,
      businessCategoryName: category?.name,
      businessName: businessName.trim(),
    );
    return profile;
  }

  @override
  Future<UserProfile> skipProfilePrompt() async {
    final error = skipError;
    if (error != null) throw error;
    skips++;
    profile = profile.copyWith(isProfileComplete: true);
    return profile;
  }

  @override
  Future<List<BusinessCategory>> businessCategories() async {
    categoryLoads++;
    final error = categoriesError;
    if (error != null) throw error;
    return categories;
  }

  BusinessCategory? _categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
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
