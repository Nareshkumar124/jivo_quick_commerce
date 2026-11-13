// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'referral_apply_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReferralApplyRequest {
  /// Returns a new [ReferralApplyRequest] instance.
  ReferralApplyRequest({required this.code});

  /// A friend's referral code. Case and spaces are ignored.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferralApplyRequest && other.code == code;

  @override
  int get hashCode => code.hashCode;

  factory ReferralApplyRequest.fromJson(Map<String, dynamic> json) =>
      _$ReferralApplyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ReferralApplyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
