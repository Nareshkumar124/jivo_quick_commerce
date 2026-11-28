// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MeCWProxy {
  Me id(int id);

  Me phone(String? phone);

  Me name(String name);

  Me email(String? email);

  Me marketingOptIn(bool? marketingOptIn);

  Me hasPhone(bool hasPhone);

  Me emailVerified(bool emailVerified);

  Me businessCategory(int? businessCategory);

  Me businessCategoryName(String? businessCategoryName);

  Me businessName(String? businessName);

  Me isProfileComplete(bool isProfileComplete);

  Me riderStatus(RiderStatusEnum riderStatus);

  Me createdAt(DateTime createdAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Me(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Me(...).copyWith(id: 12, name: "My name")
  /// ````
  Me call({
    int id,
    String? phone,
    String name,
    String? email,
    bool? marketingOptIn,
    bool hasPhone,
    bool emailVerified,
    int? businessCategory,
    String? businessCategoryName,
    String? businessName,
    bool isProfileComplete,
    RiderStatusEnum riderStatus,
    DateTime createdAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMe.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMe.copyWith.fieldName(...)`
class _$MeCWProxyImpl implements _$MeCWProxy {
  const _$MeCWProxyImpl(this._value);

  final Me _value;

  @override
  Me id(int id) => this(id: id);

  @override
  Me phone(String? phone) => this(phone: phone);

  @override
  Me name(String name) => this(name: name);

  @override
  Me email(String? email) => this(email: email);

  @override
  Me marketingOptIn(bool? marketingOptIn) =>
      this(marketingOptIn: marketingOptIn);

  @override
  Me hasPhone(bool hasPhone) => this(hasPhone: hasPhone);

  @override
  Me emailVerified(bool emailVerified) => this(emailVerified: emailVerified);

  @override
  Me businessCategory(int? businessCategory) =>
      this(businessCategory: businessCategory);

  @override
  Me businessCategoryName(String? businessCategoryName) =>
      this(businessCategoryName: businessCategoryName);

  @override
  Me businessName(String? businessName) => this(businessName: businessName);

  @override
  Me isProfileComplete(bool isProfileComplete) =>
      this(isProfileComplete: isProfileComplete);

  @override
  Me riderStatus(RiderStatusEnum riderStatus) => this(riderStatus: riderStatus);

  @override
  Me createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Me(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Me(...).copyWith(id: 12, name: "My name")
  /// ````
  Me call({
    Object? id = const $CopyWithPlaceholder(),
    Object? phone = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? email = const $CopyWithPlaceholder(),
    Object? marketingOptIn = const $CopyWithPlaceholder(),
    Object? hasPhone = const $CopyWithPlaceholder(),
    Object? emailVerified = const $CopyWithPlaceholder(),
    Object? businessCategory = const $CopyWithPlaceholder(),
    Object? businessCategoryName = const $CopyWithPlaceholder(),
    Object? businessName = const $CopyWithPlaceholder(),
    Object? isProfileComplete = const $CopyWithPlaceholder(),
    Object? riderStatus = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
  }) {
    return Me(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String?,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      email: email == const $CopyWithPlaceholder()
          ? _value.email
          // ignore: cast_nullable_to_non_nullable
          : email as String?,
      marketingOptIn: marketingOptIn == const $CopyWithPlaceholder()
          ? _value.marketingOptIn
          // ignore: cast_nullable_to_non_nullable
          : marketingOptIn as bool?,
      hasPhone: hasPhone == const $CopyWithPlaceholder()
          ? _value.hasPhone
          // ignore: cast_nullable_to_non_nullable
          : hasPhone as bool,
      emailVerified: emailVerified == const $CopyWithPlaceholder()
          ? _value.emailVerified
          // ignore: cast_nullable_to_non_nullable
          : emailVerified as bool,
      businessCategory: businessCategory == const $CopyWithPlaceholder()
          ? _value.businessCategory
          // ignore: cast_nullable_to_non_nullable
          : businessCategory as int?,
      businessCategoryName: businessCategoryName == const $CopyWithPlaceholder()
          ? _value.businessCategoryName
          // ignore: cast_nullable_to_non_nullable
          : businessCategoryName as String?,
      businessName: businessName == const $CopyWithPlaceholder()
          ? _value.businessName
          // ignore: cast_nullable_to_non_nullable
          : businessName as String?,
      isProfileComplete: isProfileComplete == const $CopyWithPlaceholder()
          ? _value.isProfileComplete
          // ignore: cast_nullable_to_non_nullable
          : isProfileComplete as bool,
      riderStatus: riderStatus == const $CopyWithPlaceholder()
          ? _value.riderStatus
          // ignore: cast_nullable_to_non_nullable
          : riderStatus as RiderStatusEnum,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
    );
  }
}

extension $MeCopyWith on Me {
  /// Returns a callable class that can be used as follows: `instanceOfMe.copyWith(...)` or like so:`instanceOfMe.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MeCWProxy get copyWith => _$MeCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Me _$MeFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Me',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'phone',
        'name',
        'has_phone',
        'email_verified',
        'business_category_name',
        'is_profile_complete',
        'rider_status',
        'created_at',
      ],
    );
    final val = Me(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      phone: $checkedConvert('phone', (v) => v as String?),
      name: $checkedConvert('name', (v) => v as String),
      email: $checkedConvert('email', (v) => v as String?),
      marketingOptIn: $checkedConvert('marketing_opt_in', (v) => v as bool?),
      hasPhone: $checkedConvert('has_phone', (v) => v as bool),
      emailVerified: $checkedConvert('email_verified', (v) => v as bool),
      businessCategory: $checkedConvert(
        'business_category',
        (v) => (v as num?)?.toInt(),
      ),
      businessCategoryName: $checkedConvert(
        'business_category_name',
        (v) => v as String?,
      ),
      businessName: $checkedConvert('business_name', (v) => v as String?),
      isProfileComplete: $checkedConvert(
        'is_profile_complete',
        (v) => v as bool,
      ),
      riderStatus: $checkedConvert(
        'rider_status',
        (v) => $enumDecode(
          _$RiderStatusEnumEnumMap,
          v,
          unknownValue: RiderStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'marketingOptIn': 'marketing_opt_in',
    'hasPhone': 'has_phone',
    'emailVerified': 'email_verified',
    'businessCategory': 'business_category',
    'businessCategoryName': 'business_category_name',
    'businessName': 'business_name',
    'isProfileComplete': 'is_profile_complete',
    'riderStatus': 'rider_status',
    'createdAt': 'created_at',
  },
);

Map<String, dynamic> _$MeToJson(Me instance) => <String, dynamic>{
  'id': instance.id,
  'phone': instance.phone,
  'name': instance.name,
  'email': ?instance.email,
  'marketing_opt_in': ?instance.marketingOptIn,
  'has_phone': instance.hasPhone,
  'email_verified': instance.emailVerified,
  'business_category': ?instance.businessCategory,
  'business_category_name': instance.businessCategoryName,
  'business_name': ?instance.businessName,
  'is_profile_complete': instance.isProfileComplete,
  'rider_status': _$RiderStatusEnumEnumMap[instance.riderStatus]!,
  'created_at': instance.createdAt.toIso8601String(),
};

const _$RiderStatusEnumEnumMap = {
  RiderStatusEnum.NONE: 'NONE',
  RiderStatusEnum.PENDING_KYC: 'PENDING_KYC',
  RiderStatusEnum.ACTIVE: 'ACTIVE',
  RiderStatusEnum.REJECTED: 'REJECTED',
  RiderStatusEnum.SUSPENDED: 'SUSPENDED',
  RiderStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
