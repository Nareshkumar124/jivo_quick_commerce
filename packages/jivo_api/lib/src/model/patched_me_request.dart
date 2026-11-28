// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_me_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedMeRequest {
  /// Returns a new [PatchedMeRequest] instance.
  PatchedMeRequest({
    this.name,

    this.email,

    this.marketingOptIn,

    this.businessCategory,

    this.businessName,
  });

  /// Cannot be blanked once sent. Empty after a skipped profile.
  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  /// Optional. Send null (or an empty string) to remove it. Must be unique.
  @JsonKey(name: r'email', required: false, includeIfNull: false)
  final String? email;

  /// Consent to promotional push notifications.
  @JsonKey(name: r'marketing_opt_in', required: false, includeIfNull: false)
  final bool? marketingOptIn;

  /// Optional. An id from `GET /business-categories/` (active only). Null removes it. Re-sending the user's current category is accepted even if it was deactivated since.
  @JsonKey(name: r'business_category', required: false, includeIfNull: false)
  final int? businessCategory;

  /// Optional shop / business name. An empty string removes it.
  @JsonKey(name: r'business_name', required: false, includeIfNull: false)
  final String? businessName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedMeRequest &&
          other.name == name &&
          other.email == email &&
          other.marketingOptIn == marketingOptIn &&
          other.businessCategory == businessCategory &&
          other.businessName == businessName;

  @override
  int get hashCode =>
      name.hashCode +
      (email == null ? 0 : email.hashCode) +
      marketingOptIn.hashCode +
      (businessCategory == null ? 0 : businessCategory.hashCode) +
      businessName.hashCode;

  factory PatchedMeRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedMeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedMeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
