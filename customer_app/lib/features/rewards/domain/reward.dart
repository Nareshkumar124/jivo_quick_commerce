import 'package:flutter/foundation.dart';

import '../../cart/domain/cart.dart';

/// Rewards (ADR 0002, 0003, `GET /account/rewards/`): the customer's
/// free-carton rewards (welcome gift, referral) and their history. A reward
/// is a personal coupon on the server, so it is used through the cart's
/// normal apply-coupon call: with no size when the store has a fixed free
/// size (ADR 0003), else with the size the customer picks.

/// `status` of a reward (ADR 0002 rule 10).
enum RewardStatus {
  /// Can be used now.
  available('AVAILABLE'),

  /// On an order that is placed but not delivered yet.
  claimed('CLAIMED'),

  /// The order with it was delivered (history only).
  used('USED'),

  /// Ran out unused (history only).
  expired('EXPIRED'),

  /// A status this build doesn't know (a newer server).
  unknown(null);

  const RewardStatus(this.wireValue);

  final String? wireValue;

  static RewardStatus fromWire(String? value) => values.firstWhere(
    (status) => status.wireValue != null && status.wireValue == value,
    orElse: () => unknown,
  );

  /// Shown in the main list; used and expired ones only in the history.
  bool get isListed => this == available || this == claimed;
}

/// One reward in the main list (`available[]`).
@immutable
class Reward {
  const Reward({
    required this.code,
    required this.title,
    required this.source,
    required this.status,
    this.expiresAt,
    this.orderNumber,
    this.discountType = CouponDiscountType.freeUnit,
    this.quantity = 1,
    this.freeVariant,
    this.freeVariantId,
  });

  /// The personal coupon's code (what apply-coupon takes).
  final String code;

  /// The server's title, shown for a reward that is not a free carton.
  final String title;
  final RewardSource source;
  final RewardStatus status;

  /// UTC; null when it doesn't expire.
  final DateTime? expiresAt;

  /// For [RewardStatus.claimed]: the order it is on.
  final String? orderNumber;

  /// What it gives. The rewards list is free cartons (ADR 0002); a type
  /// the server may add later is shown with its [title].
  final CouponDiscountType discountType;

  /// Free cartons it gives (`quantity`, ADR 0003). The server's number; a
  /// server before ADR 0003 doesn't send it, and its rewards were 1.
  final int quantity;

  /// The free carton's size, when the store has a fixed one
  /// (`free_variant`, ADR 0003). Shown on the card ("1 L × 12").
  final FreeVariant? freeVariant;

  /// The fixed size's id from the cart's coupon list (`CouponOffer.
  /// free_variant_id`), when the rewards list didn't name a size.
  final int? freeVariantId;

  bool get isFreeCarton => discountType == CouponDiscountType.freeUnit;

  /// Can be used now (the Use button).
  bool get canUse => status == RewardStatus.available;

  /// The server gave a fixed free size (ADR 0003): Use applies the reward
  /// directly, with no size sheet. Otherwise the size sheet picks one.
  bool get hasFixedSize => freeVariant != null || freeVariantId != null;

  /// This reward with what the cart's coupon list adds: the store's fixed
  /// size and the quantity, when the rewards list didn't send them.
  Reward withOffer(CouponOffer offer) => Reward(
    code: code,
    title: title,
    source: source,
    status: status,
    expiresAt: expiresAt,
    orderNumber: orderNumber,
    discountType: discountType,
    quantity: quantity,
    freeVariant: freeVariant,
    freeVariantId:
        freeVariantId ?? (offer.isApplied ? null : offer.freeVariantId),
  );
}

/// `history[].kind`.
enum RewardHistoryKind {
  earned('EARNED'),
  claimed('CLAIMED'),
  used('USED'),
  expired('EXPIRED'),

  /// Free cartons from the volume offer on a delivered order.
  volumeFree('VOLUME_FREE'),
  unknown(null);

  const RewardHistoryKind(this.wireValue);

  final String? wireValue;

  static RewardHistoryKind fromWire(String? value) => values.firstWhere(
    (kind) => kind.wireValue != null && kind.wireValue == value,
    orElse: () => unknown,
  );
}

/// One row of the rewards history (`history[]`).
@immutable
class RewardHistoryEntry {
  const RewardHistoryEntry({
    required this.at,
    required this.kind,
    required this.title,
    this.quantity = 1,
    this.orderNumber,
  });

  /// UTC.
  final DateTime at;
  final RewardHistoryKind kind;

  /// The server's line, e.g. "Welcome gift".
  final String title;

  /// Free cartons in this event.
  final int quantity;
  final String? orderNumber;
}

/// `GET /account/rewards/`.
@immutable
class RewardsSummary {
  const RewardsSummary({this.available = const [], this.history = const []});

  static const empty = RewardsSummary();

  /// AVAILABLE and CLAIMED rewards (the main list).
  final List<Reward> available;
  final List<RewardHistoryEntry> history;

  /// The main list: only available and claimed rewards, even if the server
  /// sends others; available ones first, then by expiry (soonest first).
  List<Reward> get listed {
    final rewards = [
      for (final reward in available)
        if (reward.status.isListed) reward,
    ];
    rewards.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) return byStatus;
      final aEnds = a.expiresAt;
      final bEnds = b.expiresAt;
      if (aEnds == null || bEnds == null) {
        return (aEnds == null ? 1 : 0) - (bEnds == null ? 1 : 0);
      }
      return aEnds.compareTo(bEnds);
    });
    return rewards;
  }

  /// The history, newest first.
  List<RewardHistoryEntry> get timeline =>
      [...history]..sort((a, b) => b.at.compareTo(a.at));
}

/// What the Rewards screen's main list shows, from the rewards list and
/// the cart's coupon list (`GET /cart/coupons/`), with no code twice:
///
/// - [RewardsAndCoupons.rewards]: [rewards] (already filtered to available
///   and claimed), then any free-carton coupon the rewards list doesn't
///   have (e.g. while the rewards list failed to load), as an available
///   reward so it can still be used;
/// - [RewardsAndCoupons.coupons]: the other coupons.
///
/// A reward that is also in the coupon list takes the coupon's fixed free
/// size when the rewards list named none (ADR 0003, [Reward.withOffer]).
RewardsAndCoupons splitRewardsAndCoupons({
  required List<Reward> rewards,
  required List<CouponOffer> coupons,
}) {
  final offers = <String, CouponOffer>{};
  for (final coupon in coupons) {
    offers.putIfAbsent(coupon.code.toUpperCase(), () => coupon);
  }
  final known = {for (final reward in rewards) reward.code.toUpperCase()};
  final listed = [
    for (final reward in rewards)
      switch (offers[reward.code.toUpperCase()]) {
        final offer? when offer.isFreeCarton => reward.withOffer(offer),
        _ => reward,
      },
  ];
  final extra = <Reward>[];
  final plain = <CouponOffer>[];
  for (final coupon in coupons) {
    if (!known.add(coupon.code.toUpperCase())) continue;
    if (coupon.isFreeCarton) {
      extra.add(
        Reward(
          code: coupon.code,
          title: coupon.title,
          source: coupon.source,
          status: RewardStatus.available,
          expiresAt: coupon.endsAt,
          quantity: coupon.freeQuantity ?? 1,
          freeVariantId: coupon.isApplied ? null : coupon.freeVariantId,
        ),
      );
    } else {
      plain.add(coupon);
    }
  }
  return RewardsAndCoupons(rewards: [...listed, ...extra], coupons: plain);
}

/// See [splitRewardsAndCoupons].
@immutable
class RewardsAndCoupons {
  const RewardsAndCoupons({required this.rewards, required this.coupons});

  final List<Reward> rewards;
  final List<CouponOffer> coupons;

  bool get isEmpty => rewards.isEmpty && coupons.isEmpty;
}
