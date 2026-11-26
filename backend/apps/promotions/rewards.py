"""Free-carton rewards (ADR 0002 §7-§13), built on the personal coupon system (no second
rewards system).

A reward is a personal `Coupon` (`owner` set) with `discount_type` FREE_UNIT (`value` = its
number of free cartons, no money off), one use, an expiry and a `source`. ADR 0003: the number
comes from `ReferralSettings` when the reward is created (`welcome_reward_quantity` for WELCOME,
`reward_quantity` for each referral reward); rewards given earlier keep their own number.
- WELCOME: one per customer account created from now on, given by the OTP login that creates
  the account (`grant_welcome_reward`; the database keeps at most one per owner);
- REFERRAL_REFERRER / REFERRAL_REFERRED: both people of a referral, when the friend's first
  order is delivered (`apps.referrals.services.reward_for_order`).

The customer applies it like any coupon: without a size when the store has a fixed free size
(ADR 0003, `PricingConfig.free_unit_variant`), else with the size they pick (`free_variant_id`,
ADR 0002); the cart then has a free REWARD line of `value` cartons, and the order stores it as a
free order line. It takes the order's
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

# ADR 0003: a reward's cartons are its own `Coupon.free_units`; `carton_label()` is the text.
HISTORY_LIMIT = 100
WELCOME_CONSTRAINT = "coupon_one_welcome_reward_per_owner"

# Titles are "<N free cartons>: <reason>" (ADR 0003: N is the reward's own number).
TITLE_REASONS = {
    CouponSource.WELCOME: "welcome reward",
    CouponSource.REFERRAL_REFERRER: "you invited a friend",
    CouponSource.REFERRAL_REFERRED: "you joined with a friend's code",
}
DESCRIPTIONS = {
    CouponSource.WELCOME: "Welcome to Jivo: {label} with an order, only for you.",
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


def carton_label(quantity: int) -> str:
    """ADR 0003: "1 free carton" / "2 free cartons"."""
    return f"{quantity} free carton{'' if quantity == 1 else 's'}"


def reward_title(source: str, quantity: int) -> str:
    return f"{carton_label(quantity)}: {TITLE_REASONS[source]}"


def setting_quantity(config, source: str) -> int:
    """ADR 0003: the free cartons a new reward of `source` gives (`ReferralSettings`)."""
    if source == CouponSource.WELCOME:
        return config.welcome_reward_quantity
    return config.reward_quantity


def create_reward(owner, *, source: str, now: datetime | None = None, config=None) -> Coupon:
    """A new free-carton reward for `owner`: its number of cartons and its validity days are
    read from `ReferralSettings` now (`config`, loaded when not given; ADR 0003). Runs in the
    caller's transaction."""
    from apps.promotions.services import create_personal_coupon
    from apps.referrals.models import ReferralSettings

    config = config or ReferralSettings.load()
    quantity = setting_quantity(config, source)
    return create_personal_coupon(
        owner,
        amount=quantity,
        valid_days=config.reward_validity_days,
        min_order_value=0,
        title=reward_title(source, quantity),
        description=DESCRIPTIONS[source].format(label=carton_label(quantity)),
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


def _reward_body(state: RewardState, free_variant: dict | None) -> dict:
    coupon = state.coupon
    return {
        "code": coupon.code,
        "title": coupon.title,
        "quantity": coupon.free_units,
        "free_variant": free_variant,
        "source": coupon.source,
        "status": state.status,
        "expires_at": coupon.ends_at,
        "order_number": state.order.order_number if state.order is not None else None,
    }


def _entry(at, kind: str, title: str, quantity: int, order=None) -> dict:
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
    units = coupon.free_units
    entries = [_entry(coupon.created_at, RewardHistoryKind.EARNED, title, units)]
    for redemption in coupon.redemptions.all():
        order = redemption.order
        entries.append(
            _entry(redemption.created_at, RewardHistoryKind.CLAIMED, title, units, order=order)
        )
    if state.status == RewardStatus.USED:
        order = state.order
        at = order.delivered_at or order.delivery_failed_at or order.updated_at
        entries.append(_entry(at, RewardHistoryKind.USED, title, units, order=order))
    elif state.status == RewardStatus.EXPIRED:
        at = coupon.ends_at if coupon.ends_at is not None and coupon.ends_at <= now else None
        entries.append(_entry(at or coupon.updated_at, RewardHistoryKind.EXPIRED, title, units))
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


def store_for_rewards(user, header_store_id: int | None) -> int | None:
    """ADR 0003: the store whose fixed free size the Rewards screen shows: the active store in
    the optional `X-Store-Id` header, else the store of the caller's cart (its last store), else
    None. Never an error."""
    from apps.cart.models import Cart
    from apps.core.exceptions import ApiError
    from apps.stores.services import active_store

    if header_store_id is not None:
        try:
            return active_store(header_store_id).pk
        except ApiError:
            pass  # unknown or deactivated: fall back to the cart's store
    return Cart.objects.filter(user=user).values_list("store_id", flat=True).first()


def rewards_body(user, *, now: datetime | None = None, store_id: int | None = None) -> dict:
    """`GET /account/rewards/` (the `Rewards` component): the caller's own rewards only.
    `free_variant` is the fixed free size of `store_id` (ADR 0003), the same for each reward."""
    from apps.cart.services import fixed_free_variant_body

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
    shown = [*available, *claimed]
    free_variant = fixed_free_variant_body(store_id) if shown else None
    return {
        "available": [_reward_body(state, free_variant) for state in shown],
        "history": history[:HISTORY_LIMIT],
    }
