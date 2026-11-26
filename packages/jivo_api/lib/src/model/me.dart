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

    this.businessCategory,

    required this.businessCategoryName,

    this.businessName,

    required this.isProfileComplete,

    required this.riderStatus,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Login phone. Not editable in v1.
  @JsonKey(name: r'phone', required: true, includeIfNull: true)
  final String? phone;

  /// Cannot be blanked once sent. Empty after a skipped profile.
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// Optional. Send null (or an empty string) to remove it. Must be unique.
  @JsonKey(name: r'email', required: false, includeIfNull: false)
  final String? email;

  /// Consent to promotional push notifications.
  @JsonKey(name: r'marketing_opt_in', required: false, includeIfNull: false)
  final bool? marketingOptIn;

  /// Optional. An id from `GET /business-categories/` (active only). Null removes it.
  @JsonKey(name: r'business_category', required: false, includeIfNull: false)
  final int? businessCategory;

  /// The chosen category's name, for display. Null when none.
  @JsonKey(name: r'business_category_name', required: true, includeIfNull: true)
  final String? businessCategoryName;

  /// Optional shop / business name. An empty string removes it.
  @JsonKey(name: r'business_name', required: false, includeIfNull: false)
  final String? businessName;

  /// False only for a new user who has neither submitted (PATCH `/me/` with `name`, `business_category` or `business_name`) nor skipped (`POST /me/profile-prompt/skip/`) the complete-profile screen: show that screen while it is false. Accounts created before 2026-11-26 are always true.
  @JsonKey(name: r'is_profile_complete', required: true, includeIfNull: false)
  final bool isProfileComplete;

  /// Rider profile status; NONE without a rider profile (`POST /rider/register/`).  * `NONE` - No rider profile: show registration * `PENDING_KYC` - Registered, waiting for KYC approval * `ACTIVE` - Approved: can go online * `REJECTED` - KYC rejected: see the reason, re-submit * `SUSPENDED` - Suspended by ops
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
          other.businessCategory == businessCategory &&
          other.businessCategoryName == businessCategoryName &&
          other.businessName == businessName &&
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
      (businessCategory == null ? 0 : businessCategory.hashCode) +
      (businessCategoryName == null ? 0 : businessCategoryName.hashCode) +
      businessName.hashCode +
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
