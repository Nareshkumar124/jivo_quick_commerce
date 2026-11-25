"""Free-carton rewards (ADR 0002 §7-§13), built on the personal coupon system (no second
rewards system).

A reward is a personal `Coupon` (`owner` set) with `discount_type` FREE_UNIT (value 1 = one
carton, no money off), one use, an expiry and a `source`:
- WELCOME: one per customer account created from now on, given by the OTP login that creates
  the account (`grant_welcome_reward`; the database keeps at most one per owner);
- REFERRAL_REFERRER / REFERRAL_REFERRED: both people of a referral, when the friend's first
  order is delivered (`apps.referrals.services.reward_for_order`).

The customer applies it like any coupon, with the size they pick (`free_variant_id`); the cart
then has a free REWARD line, and the order stores it as a free order line. It takes the order's
single coupon slot, and the order still needs the store's minimum paid cartons.

**Status** (ADR 0002 §10) is derived, never stored, from the coupon's redemption that counts
(HELD or APPLIED; there is at most one, the usage limit is 1) and that redemption's order:
- AVAILABLE: no counted redemption, active and not expired;
- CLAIMED: on an order that is not finished yet;
- USED: that order was delivered. An order whose delivery failed (DELIVERY_FAILED / RETURNED)
  also uses it up: the reward comes back only through the cancel and payment-failed paths
  (ADR 0002 §13), where the redemption is RELEASED / REVERSED;
- EXPIRED: no counted redemption and past its expiry (or switched off by staff).
"""

from dataclasses import dataclass
from datetime import datetime

from django.db import IntegrityError, transaction
from django.db.models import F, Prefetch, Sum
from django.utils import timezone

from apps.promotions.choices import CouponSource, DiscountType, RewardHistoryKind, RewardStatus
from apps.promotions.models import COUNTED_STATUSES, Coupon, CouponRedemption

REWARD_UNITS = 1  # cartons per reward (Coupon.value of a FREE_UNIT coupon)
REWARD_LABEL = "1 free carton"
HISTORY_LIMIT = 100
WELCOME_CONSTRAINT = "coupon_one_welcome_reward_per_owner"

TITLES = {
    CouponSource.WELCOME: "1 free carton: welcome reward",
    CouponSource.REFERRAL_REFERRER: "1 free carton: you invited a friend",
    CouponSource.REFERRAL_REFERRED: "1 free carton: you joined with a friend's code",
}
DESCRIPTIONS = {
    CouponSource.WELCOME: "Welcome to Jivo. One free carton of the size you choose, only for you.",
    CouponSource.REFERRAL_REFERRER: "Your reward for inviting a friend. One use, only for you.",
    CouponSource.REFERRAL_REFERRED: (
        "Your reward for joining with a friend's code. One use, only for you."
    ),
}
HISTORY_TITLES = {
    CouponSource.WELCOME: "Welcome reward",
    CouponSource.REFERRAL_REFERRER: "Referral reward: you invited a friend",
    CouponSource.REFERRAL_REFERRED: "Referral reward: you joined with a friend's code",
}
PREFIXES = {
    CouponSource.WELCOME: "WEL",
    CouponSource.REFERRAL_REFERRER: "REF",
    CouponSource.REFERRAL_REFERRED: "REF",
}
# Orders that used the reward up without a delivery (ADR 0002 §13: no return path).
CONSUMED_WITHOUT_DELIVERY = ("DELIVERY_FAILED", "RETURNED")


def is_reward(coupon: Coupon | None) -> bool:
    return coupon is not None and coupon.discount_type == DiscountType.FREE_UNIT


def reward_validity_days() -> int:
    from apps.referrals.models import ReferralSettings

    return ReferralSettings.load().reward_validity_days


def create_reward(owner, *, source: str, now: datetime | None = None) -> Coupon:
    """A new free-carton reward for `owner`, valid `ReferralSettings.reward_validity_days`
    days. Runs in the caller's transaction."""
    from apps.promotions.services import create_personal_coupon

    return create_personal_coupon(
        owner,
        amount=REWARD_UNITS,
        valid_days=reward_validity_days(),
        min_order_value=0,
        title=TITLES[source],
        description=DESCRIPTIONS[source],
        prefix=PREFIXES[source],
        now=now,
        discount_type=DiscountType.FREE_UNIT,
        source=source,
    )


def grant_welcome_reward(user, *, now: datetime | None = None) -> Coupon | None:
    """ADR 0002 §7: the one welcome reward of a new customer account. Idempotent: None when the
    customer already has one (also when a concurrent call created it first; the database keeps
    one per owner). Called by the OTP login that creates the account, in its transaction."""
    if Coupon.objects.filter(owner=user, source=CouponSource.WELCOME).exists():
        return None
    try:
        with transaction.atomic():
            return create_reward(user, source=CouponSource.WELCOME, now=now)
    except IntegrityError as error:
        if WELCOME_CONSTRAINT in str(error):
            return None
        raise


# --------------------------------------------------------------------------- status


@dataclass(frozen=True, slots=True)
class RewardState:
    coupon: Coupon
    status: str
    redemption: CouponRedemption | None  # the counted one (CLAIMED / USED), else None

    @property
    def order(self):
        return self.redemption.order if self.redemption is not None else None


def _counted(coupon: Coupon) -> CouponRedemption | None:
    """The redemption that uses the reward (HELD/APPLIED), from the `redemptions` prefetch."""
    return next(
        (r for r in coupon.redemptions.all() if r.status in COUNTED_STATUSES),
        None,
    )


def reward_state(coupon: Coupon, now: datetime | None = None) -> RewardState:
    """The reward's status now (module doc). Uses the `redemptions` (+ order) prefetch of
    `rewards_of()` when present."""
    from apps.orders.choices import OrderStatus

    now = now or timezone.now()
    redemption = _counted(coupon)
    if redemption is not None:
        order_status = redemption.order.status
        if order_status == OrderStatus.DELIVERED or order_status in CONSUMED_WITHOUT_DELIVERY:
            return RewardState(coupon, RewardStatus.USED, redemption)
        return RewardState(coupon, RewardStatus.CLAIMED, redemption)
    expired = not coupon.is_active or (coupon.ends_at is not None and coupon.ends_at <= now)
    return RewardState(coupon, RewardStatus.EXPIRED if expired else RewardStatus.AVAILABLE, None)


def rewards_of(user):
    """The caller's free-carton rewards with their redemptions and orders (2 queries)."""
    return (
        Coupon.objects.filter(owner=user, discount_type=DiscountType.FREE_UNIT)
        .prefetch_related(
            Prefetch(
                "redemptions",
                queryset=CouponRedemption.objects.select_related("order").order_by(
                    "created_at", "id"
                ),
            )
        )
        .order_by("created_at", "id")
    )


# --------------------------------------------------------------------------- the Rewards screen


def _reward_body(state: RewardState) -> dict:
    coupon = state.coupon
    return {
        "code": coupon.code,
        "title": coupon.title,
        "source": coupon.source,
        "status": state.status,
        "expires_at": coupon.ends_at,
        "order_number": state.order.order_number if state.order is not None else None,
    }


def _entry(at, kind: str, title: str, quantity: int = REWARD_UNITS, order=None) -> dict:
    return {
        "at": at,
        "kind": kind,
        "title": title,
        "quantity": quantity,
        "order_number": order.order_number if order is not None else None,
    }


def _history(state: RewardState, now: datetime) -> list[dict]:
    coupon = state.coupon
    title = HISTORY_TITLES.get(coupon.source, coupon.title)
    entries = [_entry(coupon.created_at, RewardHistoryKind.EARNED, title)]
    for redemption in coupon.redemptions.all():
        order = redemption.order
        entries.append(_entry(redemption.created_at, RewardHistoryKind.CLAIMED, title, order=order))
    if state.status == RewardStatus.USED:
        order = state.order
        at = order.delivered_at or order.delivery_failed_at or order.updated_at
        entries.append(_entry(at, RewardHistoryKind.USED, title, order=order))
    elif state.status == RewardStatus.EXPIRED:
        at = coupon.ends_at if coupon.ends_at is not None and coupon.ends_at <= now else None
        entries.append(_entry(at or coupon.updated_at, RewardHistoryKind.EXPIRED, title))
    return entries


def _volume_history(user) -> list[dict]:
    """The volume-offer free cartons of each delivered order (1 query)."""
    from apps.orders.choices import FreeSource, OrderStatus
    from apps.orders.models import OrderItem

    rows = (
        OrderItem.objects.filter(
            order__user=user,
            order__status=OrderStatus.DELIVERED,
            is_free=True,
            free_source=FreeSource.VOLUME_OFFER,
        )
        .values("order__order_number", "order__delivered_at")
        .annotate(units=Sum(F("quantity") - F("quantity_unavailable")))
        .order_by()
    )
    entries = []
    for row in rows:
        if not row["units"]:
            continue
        units = row["units"]
        entries.append(
            {
                "at": row["order__delivered_at"],
                "kind": RewardHistoryKind.VOLUME_FREE,
                "title": f"{units} free carton{'s' if units != 1 else ''} with your order",
                "quantity": units,
                "order_number": row["order__order_number"],
            }
        )
    return entries


def rewards_body(user, *, now: datetime | None = None) -> dict:
    """`GET /account/rewards/` (the `Rewards` component): the caller's own rewards only."""
    now = now or timezone.now()
    states = [reward_state(coupon, now) for coupon in rewards_of(user)]
    available = sorted(
        (s for s in states if s.status == RewardStatus.AVAILABLE),
        key=lambda s: (s.coupon.ends_at is None, s.coupon.ends_at or now, s.coupon.pk),
    )
    claimed = [s for s in states if s.status == RewardStatus.CLAIMED]
    history = [entry for state in states for entry in _history(state, now)]
    history += _volume_history(user)
    history.sort(key=lambda entry: (entry["at"], entry["kind"]), reverse=True)
    return {
        "available": [_reward_body(state) for state in [*available, *claimed]],
        "history": history[:HISTORY_LIMIT],
    }
