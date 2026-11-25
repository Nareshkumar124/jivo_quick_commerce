"""Coupon enums (07 §2.5). Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class DiscountType(models.TextChoices):
    FLAT = "FLAT", "Flat amount off"
    PERCENT = "PERCENT", "Percent off"
    # ADR 0002: a reward of one free carton (no money off). The customer picks the size when
    # applying it (`free_variant_id`); the order gets a free line at ₹0.
    FREE_UNIT = "FREE_UNIT", "One free carton (reward)"


class CouponSource(models.TextChoices):
    """Why a coupon exists (ADR 0002). Rewards are personal coupons with a source."""

    NONE = "NONE", "Made by staff"
    WELCOME = "WELCOME", "Welcome reward (new account)"
    REFERRAL_REFERRER = "REFERRAL_REFERRER", "Referral reward (you invited a friend)"
    REFERRAL_REFERRED = "REFERRAL_REFERRED", "Referral reward (you joined with a friend's code)"


class CouponIneligibleReason(models.TextChoices):
    """Why a valid, unexpired coupon does not apply to this cart (`COUPON_NOT_ELIGIBLE`)."""

    MIN_ORDER_VALUE = "MIN_ORDER_VALUE", "The item total is below the coupon's minimum."
    FIRST_ORDER_ONLY = "FIRST_ORDER_ONLY", "Only for your first order."
    NO_ELIGIBLE_ITEMS = "NO_ELIGIBLE_ITEMS", "No items in the cart qualify for this coupon."
    STORE = "STORE", "Not valid at this store."
    # ADR 0002 (free-carton rewards)
    MIN_ORDER_UNITS = (
        "MIN_ORDER_UNITS",
        "A free-carton reward needs the order's minimum paid cartons.",
    )
    FREE_VARIANT_UNAVAILABLE = (
        "FREE_VARIANT_UNAVAILABLE",
        "The size chosen for the free carton is not available here (not sold at this store, "
        "not of the category of a paid line, or out of stock).",
    )


class RewardStatus(models.TextChoices):
    """A free-carton reward's status (ADR 0002 §10), derived from its coupon and order."""

    AVAILABLE = "AVAILABLE", "Can be used"
    CLAIMED = "CLAIMED", "On an order that is not delivered yet"
    USED = "USED", "Used on a delivered order"
    EXPIRED = "EXPIRED", "Expired without being used"


class RewardHistoryKind(models.TextChoices):
    """A line of the Rewards history (ADR 0002 §11)."""

    EARNED = "EARNED", "Reward earned"
    CLAIMED = "CLAIMED", "Reward put on an order"
    USED = "USED", "Reward used (order delivered)"
    EXPIRED = "EXPIRED", "Reward expired"
    VOLUME_FREE = "VOLUME_FREE", "Free cartons with a delivered order (volume offer)"
