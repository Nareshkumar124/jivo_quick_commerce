"""Phase 3 API contract: coupons offered for the current cart (06 §2.5, 03 §2.8)."""

from rest_framework import serializers

from apps.cart.serializers import money_or_null
from apps.catalog.serializers import money
from apps.promotions.choices import CouponIneligibleReason, DiscountType


class CouponOfferSerializer(serializers.Serializer):
    """A coupon in the 'Apply coupon' sheet, evaluated against the current cart."""

    code = serializers.CharField(help_text="Upper case. Apply with `POST /cart/coupon/`.")
    title = serializers.CharField(help_text='e.g. "Flat ₹50 off".')
    description = serializers.CharField(
        allow_blank=True, help_text='Terms in one line, e.g. "On orders above ₹299".'
    )
    discount_type = serializers.ChoiceField(choices=DiscountType.choices)
    value = money('FLAT: rupees off ("50.00"). PERCENT: percent off ("10.00" = 10%).')
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


class CouponListSerializer(serializers.Serializer):
    results = CouponOfferSerializer(
        many=True,
        help_text=(
            "Visible coupons valid at this store now, eligible first (highest savings first), "
            "then the rest. Expired, used-up and other-store coupons are not listed. Not "
            "paginated."
        ),
    )
