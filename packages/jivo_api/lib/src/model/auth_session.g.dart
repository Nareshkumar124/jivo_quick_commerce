// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AuthSessionCWProxy {
  AuthSession access(String access);

  AuthSession refresh(String refresh);

  AuthSession user(Me user);

  AuthSession isNewUser(bool isNewUser);

  AuthSession riderStatus(RiderStatusEnum riderStatus);

  AuthSession deletionCancelled(bool deletionCancelled);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AuthSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AuthSession(...).copyWith(id: 12, name: "My name")
  /// ````
  AuthSession call({
    String access,
    String refresh,
    Me user,
    bool isNewUser,
    RiderStatusEnum riderStatus,
    bool deletionCancelled,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAuthSession.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAuthSession.copyWith.fieldName(...)`
class _$AuthSessionCWProxyImpl implements _$AuthSessionCWProxy {
  const _$AuthSessionCWProxyImpl(this._value);

  final AuthSession _value;

  @override
  AuthSession access(String access) => this(access: access);

  @override
  AuthSession refresh(String refresh) => this(refresh: refresh);

  @override
  AuthSession user(Me user) => this(user: user);

  @override
  AuthSession isNewUser(bool isNewUser) => this(isNewUser: isNewUser);

  @override
  AuthSession riderStatus(RiderStatusEnum riderStatus) =>
      this(riderStatus: riderStatus);

  @override
  AuthSession deletionCancelled(bool deletionCancelled) =>
      this(deletionCancelled: deletionCancelled);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AuthSession(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AuthSession(...).copyWith(id: 12, name: "My name")
  /// ````
  AuthSession call({
    Object? access = const $CopyWithPlaceholder(),
    Object? refresh = const $CopyWithPlaceholder(),
    Object? user = const $CopyWithPlaceholder(),
    Object? isNewUser = const $CopyWithPlaceholder(),
    Object? riderStatus = const $CopyWithPlaceholder(),
    Object? deletionCancelled = const $CopyWithPlaceholder(),
  }) {
    return AuthSession(
      access: access == const $CopyWithPlaceholder()
          ? _value.access
          // ignore: cast_nullable_to_non_nullable
          : access as String,
      refresh: refresh == const $CopyWithPlaceholder()
          ? _value.refresh
          // ignore: cast_nullable_to_non_nullable
          : refresh as String,
      user: user == const $CopyWithPlaceholder()
          ? _value.user
          // ignore: cast_nullable_to_non_nullable
          : user as Me,
      isNewUser: isNewUser == const $CopyWithPlaceholder()
          ? _value.isNewUser
          // ignore: cast_nullable_to_non_nullable
          : isNewUser as bool,
      riderStatus: riderStatus == const $CopyWithPlaceholder()
          ? _value.riderStatus
          // ignore: cast_nullable_to_non_nullable
          : riderStatus as RiderStatusEnum,
      deletionCancelled: deletionCancelled == const $CopyWithPlaceholder()
          ? _value.deletionCancelled
          // ignore: cast_nullable_to_non_nullable
          : deletionCancelled as bool,
    );
  }
}

extension $AuthSessionCopyWith on AuthSession {
  /// Returns a callable class that can be used as follows: `instanceOfAuthSession.copyWith(...)` or like so:`instanceOfAuthSession.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AuthSessionCWProxy get copyWith => _$AuthSessionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuthSession _$AuthSessionFromJson(Map<String, dynamic> json) => $checkedCreate(
  'AuthSession',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'access',
        'refresh',
        'user',
        'is_new_user',
        'rider_status',
        'deletion_cancelled',
      ],
    );
    final val = AuthSession(
      access: $checkedConvert('access', (v) => v as String),
      refresh: $checkedConvert('refresh', (v) => v as String),
      user: $checkedConvert(
        'user',
        (v) => Me.fromJson(v as Map<String, dynamic>),
      ),
      isNewUser: $checkedConvert('is_new_user', (v) => v as bool),
      riderStatus: $checkedConvert(
        'rider_status',
        (v) => $enumDecode(
          _$RiderStatusEnumEnumMap,
          v,
          unknownValue: RiderStatusEnum.unknownDefaultOpenApi,
        ),
      ),
      deletionCancelled: $checkedConvert(
        'deletion_cancelled',
        (v) => v as bool,
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'isNewUser': 'is_new_user',
    'riderStatus': 'rider_status',
    'deletionCancelled': 'deletion_cancelled',
  },
);

Map<String, dynamic> _$AuthSessionToJson(AuthSession instance) =>
    <String, dynamic>{
      'access': instance.access,
      'refresh': instance.refresh,
      'user': instance.user.toJson(),
      'is_new_user': instance.isNewUser,
      'rider_status': _$RiderStatusEnumEnumMap[instance.riderStatus]!,
      'deletion_cancelled': instance.deletionCancelled,
    };

const _$RiderStatusEnumEnumMap = {
  RiderStatusEnum.NONE: 'NONE',
  RiderStatusEnum.PENDING_KYC: 'PENDING_KYC',
  RiderStatusEnum.ACTIVE: 'ACTIVE',
  RiderStatusEnum.REJECTED: 'REJECTED',
  RiderStatusEnum.SUSPENDED: 'SUSPENDED',
  RiderStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
