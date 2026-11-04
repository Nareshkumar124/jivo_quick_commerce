"""Coupon enums (07 §2.5). Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class DiscountType(models.TextChoices):
    FLAT = "FLAT", "Flat amount off"
    PERCENT = "PERCENT", "Percent off"


class CouponIneligibleReason(models.TextChoices):
    """Why a valid, unexpired coupon does not apply to this cart (`COUPON_NOT_ELIGIBLE`)."""

    MIN_ORDER_VALUE = "MIN_ORDER_VALUE", "The item total is below the coupon's minimum."
    FIRST_ORDER_ONLY = "FIRST_ORDER_ONLY", "Only for your first order."
    NO_ELIGIBLE_ITEMS = "NO_ELIGIBLE_ITEMS", "No items in the cart qualify for this coupon."
    STORE = "STORE", "Not valid at this store."
