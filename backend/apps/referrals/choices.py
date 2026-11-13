"""Referral enums (07 §2.5a). Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class ReferralStatus(models.TextChoices):
    """A referred customer's referral: waiting for their first delivered order, rewarded, or
    void (the program was off when that order was delivered)."""

    PENDING = "PENDING", "Waiting for the first delivered order"
    REWARDED = "REWARDED", "Rewarded (both coupons given)"
    VOID = "VOID", "No reward (program off at the first delivery)"


class ReferralIneligibleReason(models.TextChoices):
    """`details.reason` of `REFERRAL_NOT_ELIGIBLE`."""

    HAS_ORDERS = "HAS_ORDERS", "The customer already has an order that was placed."
    PROGRAM_OFF = "PROGRAM_OFF", "The referral program is switched off."
