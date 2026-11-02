// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_status_enum.dart';
import 'package:jivo_api/src/model/me.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_session.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AuthSession {
  /// Returns a new [AuthSession] instance.
  AuthSession({
    required this.access,

    required this.refresh,

    required this.user,

    required this.isNewUser,

    required this.riderStatus,

    required this.deletionCancelled,
  });

  /// JWT access token, valid 15 minutes.
  @JsonKey(name: r'access', required: true, includeIfNull: false)
  final String access;

  /// JWT refresh token, valid 30 days, single use.
  @JsonKey(name: r'refresh', required: true, includeIfNull: false)
  final String refresh;

  @JsonKey(name: r'user', required: true, includeIfNull: false)
  final Me user;

  /// True when this verification created the account. Show the complete-profile screen when `is_new_user` is true or `user.is_profile_complete` is false.
  @JsonKey(name: r'is_new_user', required: true, includeIfNull: false)
  final bool isNewUser;

  /// Always present (NONE without a rider profile). The rider app routes on it: NONE -> registration, PENDING_KYC/REJECTED -> status screen, ACTIVE -> home, SUSPENDED -> blocked. The customer app ignores it.  * `NONE` - No rider profile: show registration * `PENDING_KYC` - Registered, waiting for KYC approval * `ACTIVE` - Approved: can go online * `REJECTED` - KYC rejected: see the reason, re-submit * `SUSPENDED` - Suspended by ops
  @JsonKey(
    name: r'rider_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderStatusEnum.unknownDefaultOpenApi,
  )
  final RiderStatusEnum riderStatus;

  /// True when this login cancelled a pending account deletion (login within the 30-day grace period restores the account): show a notice. Normally false.
  @JsonKey(name: r'deletion_cancelled', required: true, includeIfNull: false)
  final bool deletionCancelled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.access == access &&
          other.refresh == refresh &&
          other.user == user &&
          other.isNewUser == isNewUser &&
          other.riderStatus == riderStatus &&
          other.deletionCancelled == deletionCancelled;

  @override
  int get hashCode =>
      access.hashCode +
      refresh.hashCode +
      user.hashCode +
      isNewUser.hashCode +
      riderStatus.hashCode +
      deletionCancelled.hashCode;

  factory AuthSession.fromJson(Map<String, dynamic> json) =>
      _$AuthSessionFromJson(json);

  Map<String, dynamic> toJson() => _$AuthSessionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
