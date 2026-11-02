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
  PatchedMeRequest({this.name, this.email, this.marketingOptIn});

  /// Required to complete the profile. Cannot be blanked.
  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  /// Optional. Send null (or an empty string) to remove it. Must be unique.
  @JsonKey(name: r'email', required: false, includeIfNull: false)
  final String? email;

  /// Consent to promotional push notifications.
  @JsonKey(name: r'marketing_opt_in', required: false, includeIfNull: false)
  final bool? marketingOptIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedMeRequest &&
          other.name == name &&
          other.email == email &&
          other.marketingOptIn == marketingOptIn;

  @override
  int get hashCode =>
      name.hashCode +
      (email == null ? 0 : email.hashCode) +
      marketingOptIn.hashCode;

  factory PatchedMeRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedMeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedMeRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
