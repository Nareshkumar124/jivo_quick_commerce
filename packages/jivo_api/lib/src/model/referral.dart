// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/coupon_discount_type_enum.dart';
import 'package:jivo_api/src/model/referred_by.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'referral.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Referral {
  /// Returns a new [Referral] instance.
  Referral({
    required this.code,

    required this.shareMessage,

    required this.isEnabled,

    required this.rewardType,

    required this.rewardQuantity,

    required this.rewardLabel,

    required this.rewardAmount,

    required this.rewardValidityDays,

    required this.rewardMinOrderValue,

    required this.canApplyCode,

    required this.referredBy,

    required this.friendsJoined,

    required this.friendsRewarded,
  });

  /// The caller's own referral code (upper case, 6 characters). Never changes.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// Ready-made text for the share sheet, with the code and the reward amount.
  @JsonKey(name: r'share_message', required: true, includeIfNull: false)
  final String shareMessage;

  /// False: the program is paused (hide sharing; codes cannot be entered).
  @JsonKey(name: r'is_enabled', required: true, includeIfNull: false)
  final bool isEnabled;

  /// ADR 0002: FREE_UNIT = each of the two customers gets one free carton (show `reward_label`, never a ₹ amount). The only value sent today.  * `FLAT` - Flat amount off * `PERCENT` - Percent off * `FREE_UNIT` - One free carton (reward)
  @JsonKey(
    name: r'reward_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CouponDiscountTypeEnum.unknownDefaultOpenApi,
  )
  final CouponDiscountTypeEnum rewardType;

  /// Free cartons each customer gets (1).
  // minimum: 1
  @JsonKey(name: r'reward_quantity', required: true, includeIfNull: false)
  final int rewardQuantity;

  /// Ready-made text, e.g. \"1 free carton\".
  @JsonKey(name: r'reward_label', required: true, includeIfNull: false)
  final String rewardLabel;

  /// Deprecated (ADR 0002): the old ₹ reward setting, not given any more. Use `reward_type` / `reward_label`.
  @JsonKey(name: r'reward_amount', required: true, includeIfNull: false)
  final String rewardAmount;

  /// Days the reward stays valid after it is given.
  @JsonKey(name: r'reward_validity_days', required: true, includeIfNull: false)
  final int rewardValidityDays;

  /// Deprecated (ADR 0002): free-carton rewards need the store's minimum paid cartons instead. Always \"0.00\".
  @JsonKey(
    name: r'reward_min_order_value',
    required: true,
    includeIfNull: false,
  )
  final String rewardMinOrderValue;

  /// Show the 'Have a referral code?' box only when true: the program is on, the caller has not entered a code and has no order that was placed yet.
  @JsonKey(name: r'can_apply_code', required: true, includeIfNull: false)
  final bool canApplyCode;

  /// The code the caller joined with; null when none.
  @JsonKey(name: r'referred_by', required: true, includeIfNull: true)
  final ReferredBy? referredBy;

  /// Customers who entered the caller's code.
  @JsonKey(name: r'friends_joined', required: true, includeIfNull: false)
  final int friendsJoined;

  /// Of those, how many have had their first order delivered (reward given).
  @JsonKey(name: r'friends_rewarded', required: true, includeIfNull: false)
  final int friendsRewarded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Referral &&
          other.code == code &&
          other.shareMessage == shareMessage &&
          other.isEnabled == isEnabled &&
          other.rewardType == rewardType &&
          other.rewardQuantity == rewardQuantity &&
          other.rewardLabel == rewardLabel &&
          other.rewardAmount == rewardAmount &&
          other.rewardValidityDays == rewardValidityDays &&
          other.rewardMinOrderValue == rewardMinOrderValue &&
          other.canApplyCode == canApplyCode &&
          other.referredBy == referredBy &&
          other.friendsJoined == friendsJoined &&
          other.friendsRewarded == friendsRewarded;

  @override
  int get hashCode =>
      code.hashCode +
      shareMessage.hashCode +
      isEnabled.hashCode +
      rewardType.hashCode +
      rewardQuantity.hashCode +
      rewardLabel.hashCode +
      rewardAmount.hashCode +
      rewardValidityDays.hashCode +
      rewardMinOrderValue.hashCode +
      canApplyCode.hashCode +
      (referredBy == null ? 0 : referredBy.hashCode) +
      friendsJoined.hashCode +
      friendsRewarded.hashCode;

  factory Referral.fromJson(Map<String, dynamic> json) =>
      _$ReferralFromJson(json);

  Map<String, dynamic> toJson() => _$ReferralToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
