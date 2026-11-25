import 'package:flutter/foundation.dart';

/// Where a referral the customer joined with stands (`ReferredBy.status`).
enum ReferralStatus {
  /// Both get the reward when the customer's first order is delivered.
  pending,

  /// Both reward coupons were given (the customer's is in their coupons).
  rewarded,

  /// No reward: the program was off at that first delivery.
  noReward,

  /// A status this app version doesn't know (additive API change).
  unknown,
}

/// The friend's code the customer joined with.
@immutable
class ReferredBy {
  const ReferredBy({
    required this.codeMasked,
    required this.status,
    required this.appliedAt,
  });

  /// Partly hidden, e.g. `AB**7P`.
  final String codeMasked;
  final ReferralStatus status;

  /// UTC.
  final DateTime appliedAt;

  @override
  bool operator ==(Object other) =>
      other is ReferredBy &&
      other.codeMasked == codeMasked &&
      other.status == status &&
      other.appliedAt == appliedAt;

  @override
  int get hashCode => Object.hash(codeMasked, status, appliedAt);
}

/// What each of the two customers gets (ADR 0002 replaced ₹90 with a free
/// carton; the server says which with a reward-type flag).
enum ReferralRewardType {
  /// Rupees off ([ReferralInfo.rewardAmount]): the old ₹90 reward.
  amount,

  /// A free-carton reward ([ReferralInfo.rewardQuantity] cartons).
  freeCarton,
}

/// The customer's referral screen (`GET /account/referral/`).
///
/// Money stays the server's decimal strings (`"90.00"`): display only.
@immutable
class ReferralInfo {
  const ReferralInfo({
    required this.code,
    required this.shareMessage,
    required this.isEnabled,
    required this.rewardAmount,
    required this.rewardValidityDays,
    required this.rewardMinOrderValue,
    required this.canApplyCode,
    required this.friendsJoined,
    required this.friendsRewarded,
    this.referredBy,
    this.rewardType = ReferralRewardType.amount,
    this.rewardQuantity = 1,
  });

  /// The customer's own code (upper case). Never changes.
  final String code;

  /// Ready-made text to share, with the code and the reward.
  final String shareMessage;

  /// False: the program is paused (no sharing, no entering codes).
  final bool isEnabled;

  /// Rupees off for each of the two customers, e.g. `"90.00"`. Only for
  /// [ReferralRewardType.amount]; never shown for a free carton.
  final String rewardAmount;

  /// Rupees off, or free cartons (ADR 0002).
  final ReferralRewardType rewardType;

  /// Free cartons each customer gets (1) for [ReferralRewardType.freeCarton].
  final int rewardQuantity;

  bool get isFreeCarton => rewardType == ReferralRewardType.freeCarton;

  /// Days the reward coupon stays valid after it is given.
  final int rewardValidityDays;

  /// Minimum item total to use the reward (`"0.00"` = none).
  final String rewardMinOrderValue;

  /// Show "Have a referral code?" only when true: the program is on, no
  /// code was entered and no order was placed yet.
  final bool canApplyCode;

  /// The code the customer joined with; null when none.
  final ReferredBy? referredBy;

  /// Customers who entered this customer's code.
  final int friendsJoined;

  /// Of those, how many had their first order delivered (reward given).
  final int friendsRewarded;

  @override
  bool operator ==(Object other) =>
      other is ReferralInfo &&
      other.code == code &&
      other.shareMessage == shareMessage &&
      other.isEnabled == isEnabled &&
      other.rewardAmount == rewardAmount &&
      other.rewardValidityDays == rewardValidityDays &&
      other.rewardMinOrderValue == rewardMinOrderValue &&
      other.canApplyCode == canApplyCode &&
      other.referredBy == referredBy &&
      other.friendsJoined == friendsJoined &&
      other.friendsRewarded == friendsRewarded &&
      other.rewardType == rewardType &&
      other.rewardQuantity == rewardQuantity;

  @override
  int get hashCode => Object.hash(
    code,
    shareMessage,
    isEnabled,
    rewardAmount,
    rewardValidityDays,
    rewardMinOrderValue,
    canApplyCode,
    referredBy,
    friendsJoined,
    friendsRewarded,
    rewardType,
    rewardQuantity,
  );
}
