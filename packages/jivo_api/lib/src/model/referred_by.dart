// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/referral_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'referred_by.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReferredBy {
  /// Returns a new [ReferredBy] instance.
  ReferredBy({
    required this.codeMasked,

    required this.status,

    required this.appliedAt,
  });

  /// The friend's code, partly hidden: \"K7**PQ\".
  @JsonKey(name: r'code_masked', required: true, includeIfNull: false)
  final String codeMasked;

  /// PENDING: both get the reward when the caller's first order is delivered. REWARDED: the reward coupon is in the caller's coupon list. VOID: no reward (the program was off at that delivery).  * `PENDING` - Waiting for the first delivered order * `REWARDED` - Rewarded (both coupons given) * `VOID` - No reward (program off at the first delivery)
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: ReferralStatusEnum.unknownDefaultOpenApi,
  )
  final ReferralStatusEnum status;

  /// When the code was entered (UTC).
  @JsonKey(name: r'applied_at', required: true, includeIfNull: false)
  final DateTime appliedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReferredBy &&
          other.codeMasked == codeMasked &&
          other.status == status &&
          other.appliedAt == appliedAt;

  @override
  int get hashCode =>
      codeMasked.hashCode + status.hashCode + appliedAt.hashCode;

  factory ReferredBy.fromJson(Map<String, dynamic> json) =>
      _$ReferredByFromJson(json);

  Map<String, dynamic> toJson() => _$ReferredByToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
