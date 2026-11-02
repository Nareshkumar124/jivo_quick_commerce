// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/rider_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'me.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Me {
  /// Returns a new [Me] instance.
  Me({
    required this.id,

    required this.phone,

    required this.name,

    this.email,

    this.marketingOptIn,

    required this.isProfileComplete,

    required this.riderStatus,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Login phone. Not editable in v1.
  @JsonKey(name: r'phone', required: true, includeIfNull: true)
  final String? phone;

  /// Required to complete the profile. Cannot be blanked.
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// Optional. Send null (or an empty string) to remove it. Must be unique.
  @JsonKey(name: r'email', required: false, includeIfNull: false)
  final String? email;

  /// Consent to promotional push notifications.
  @JsonKey(name: r'marketing_opt_in', required: false, includeIfNull: false)
  final bool? marketingOptIn;

  /// False until a name is set: show the complete-profile screen.
  @JsonKey(name: r'is_profile_complete', required: true, includeIfNull: false)
  final bool isProfileComplete;

  /// Rider profile status; NONE without a rider profile (always NONE until Phase 5).  * `NONE` - No rider profile: show registration * `PENDING_KYC` - Registered, waiting for KYC approval * `ACTIVE` - Approved: can go online * `REJECTED` - KYC rejected: see the reason, re-submit * `SUSPENDED` - Suspended by ops
  @JsonKey(
    name: r'rider_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderStatusEnum.unknownDefaultOpenApi,
  )
  final RiderStatusEnum riderStatus;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Me &&
          other.id == id &&
          other.phone == phone &&
          other.name == name &&
          other.email == email &&
          other.marketingOptIn == marketingOptIn &&
          other.isProfileComplete == isProfileComplete &&
          other.riderStatus == riderStatus &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      id.hashCode +
      (phone == null ? 0 : phone.hashCode) +
      name.hashCode +
      (email == null ? 0 : email.hashCode) +
      marketingOptIn.hashCode +
      isProfileComplete.hashCode +
      riderStatus.hashCode +
      createdAt.hashCode;

  factory Me.fromJson(Map<String, dynamic> json) => _$MeFromJson(json);

  Map<String, dynamic> toJson() => _$MeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
