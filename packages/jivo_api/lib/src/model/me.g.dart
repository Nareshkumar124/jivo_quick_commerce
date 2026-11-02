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
