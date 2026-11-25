"""Phase 3 API contract: coupons offered for the current cart (06 §2.5, 03 §2.8)."""

from rest_framework import serializers

from apps.cart.serializers import money_or_null
from apps.catalog.serializers import money
from apps.promotions.choices import (
    CouponIneligibleReason,
    CouponSource,
    DiscountType,
    RewardHistoryKind,
    RewardStatus,
)


class CouponOfferSerializer(serializers.Serializer):
    """A coupon in the 'Apply coupon' sheet, evaluated against the current cart."""

    code = serializers.CharField(help_text="Upper case. Apply with `POST /cart/coupon/`.")
    title = serializers.CharField(help_text='e.g. "Flat ₹50 off".')
    description = serializers.CharField(
        allow_blank=True, help_text='Terms in one line, e.g. "On orders above ₹299".'
    )
    discount_type = serializers.ChoiceField(
        choices=DiscountType.choices,
        help_text=(
            "FREE_UNIT (ADR 0002): a free-carton reward. Applying it needs `free_variant_id` "
            '(the size the customer picks); it gives no money off (`savings` "0.00").'
        ),
    )
    value = money(
        'FLAT: rupees off ("50.00"). PERCENT: percent off ("10.00" = 10%). FREE_UNIT: free '
        'cartons ("1.00").'
    )
    max_discount = money_or_null("Cap on the discount (PERCENT coupons); null when uncapped.")
    min_order_value = money('Minimum `item_total` (before the coupon), "0.00" when none.')
    ends_at = serializers.DateTimeField(
        allow_null=True, help_text="UTC expiry (show 'Expires on ...' in IST); null = no expiry."
    )
    is_applied = serializers.BooleanField(help_text="True for the coupon on the cart now.")
    is_eligible = serializers.BooleanField(help_text="Show APPLY enabled only when true.")
    savings = money_or_null(
        "What it would save on this cart now (the server's `coupon_discount`); null when not "
        "eligible."
    )
    ineligible_reason = serializers.ChoiceField(
        choices=CouponIneligibleReason.choices, allow_null=True
    )
    message = serializers.CharField(
        allow_null=True,
        help_text="Why it is not eligible, with the fix (e.g. 'Add items worth ₹716 more').",
    )
    amount_to_unlock = money_or_null(
        "MIN_ORDER_VALUE only: item value still needed. Null otherwise."
    )
    is_personal = serializers.BooleanField(
        help_text=(
            "True for the customer's own personal coupon (e.g. a referral reward): show a "
            "'For you' label and its expiry (`ends_at`). Added 2026-11-13."
        )
    )
    source = serializers.ChoiceField(
        choices=CouponSource.choices,
        help_text="ADR 0002: WELCOME / REFERRAL_* for rewards, NONE for staff coupons.",
    )
    free_variant_id = serializers.IntegerField(
        allow_null=True,
        help_text=(
            "FREE_UNIT and applied to the cart: the size picked for the free carton. Null "
            "otherwise."
        ),
    )


class CouponListSerializer(serializers.Serializer):
    results = CouponOfferSerializer(
        many=True,
        help_text=(
            "Visible coupons valid at this store now, eligible first (highest savings first), "
            "then the rest. Expired, used-up and other-store coupons are not listed. Not "
            "paginated."
        ),
    )


# --------------------------------------------------------------------------- rewards (ADR 0002)


class RewardSerializer(serializers.Serializer):
    """A free-carton reward the caller can use, or has put on an order not delivered yet."""

    code = serializers.CharField(
        help_text=(
            "Apply it with `POST /cart/coupon/` {`code`, `free_variant_id`} (the customer picks "
            "the size)."
        )
    )
    title = serializers.CharField(help_text='e.g. "1 free carton: welcome reward".')
    source = serializers.ChoiceField(
        choices=CouponSource.choices, help_text="WELCOME, REFERRAL_REFERRER or REFERRAL_REFERRED."
    )
    status = serializers.ChoiceField(
        choices=RewardStatus.choices,
        help_text=(
            "AVAILABLE: show **Use**. CLAIMED: on order `order_number`, not delivered yet (it "
            "comes back to AVAILABLE if that order is cancelled or its payment fails, unless it "
            "has expired by then)."
        ),
    )
    expires_at = serializers.DateTimeField(
        allow_null=True, help_text="UTC (show the date in IST); null = no expiry."
    )
    order_number = serializers.CharField(
        allow_null=True, help_text="CLAIMED: the order it is on. Null when AVAILABLE."
    )


class RewardHistoryEntrySerializer(serializers.Serializer):
    """One line of the Rewards history, newest first."""

    at = serializers.DateTimeField(help_text="When it happened (UTC).")
    kind = serializers.ChoiceField(
        choices=RewardHistoryKind.choices,
        help_text=(
            "EARNED: a reward was given. CLAIMED: put on an order. USED: that order was "
            "delivered. EXPIRED: it ran out unused. VOLUME_FREE: free cartons of the volume "
            "offer with a delivered order."
        ),
    )
    title = serializers.CharField(help_text='Display text, e.g. "Welcome reward".')
    quantity = serializers.IntegerField(min_value=1, help_text="Free cartons (1 for a reward).")
    order_number = serializers.CharField(
        allow_null=True, help_text="The order concerned; null for EARNED and EXPIRED."
    )


class RewardsSerializer(serializers.Serializer):
    """The caller's free-carton rewards (ADR 0002 §9-§11)."""

    available = RewardSerializer(
        many=True,
        help_text="AVAILABLE rewards (soonest expiry first), then CLAIMED ones. [] when none.",
    )
    history = RewardHistoryEntrySerializer(
        many=True,
        help_text=(
            "Newest first, at most the latest 100 entries: rewards earned, claimed, used and "
            "expired, and the volume-offer free cartons of each delivered order."
        ),
    )
