"""Referral API contract (06 §2.1 "Referral", added 2026-11-13)."""

from rest_framework import serializers

from apps.catalog.serializers import money
from apps.referrals.choices import ReferralStatus


class ReferredBySerializer(serializers.Serializer):
    """The code the caller joined with."""

    code_masked = serializers.CharField(help_text='The friend\'s code, partly hidden: "K7**PQ".')
    status = serializers.ChoiceField(
        choices=ReferralStatus.choices,
        help_text=(
            "PENDING: both get the reward when the caller's first order is delivered. "
            "REWARDED: the reward coupon is in the caller's coupon list. VOID: no reward (the "
            "program was off at that delivery)."
        ),
    )
    applied_at = serializers.DateTimeField(help_text="When the code was entered (UTC).")


class ReferralSerializer(serializers.Serializer):
    """The caller's referral screen."""

    code = serializers.CharField(
        help_text="The caller's own referral code (upper case, 6 characters). Never changes."
    )
    share_message = serializers.CharField(
        help_text="Ready-made text for the share sheet, with the code and the reward amount."
    )
    is_enabled = serializers.BooleanField(
        help_text="False: the program is paused (hide sharing; codes cannot be entered)."
    )
    reward_amount = money('Rupees off for each of the two customers, e.g. "90.00".')
    reward_validity_days = serializers.IntegerField(
        help_text="Days the reward coupon stays valid after it is given."
    )
    reward_min_order_value = money('Minimum item total to use the reward coupon ("0.00" = none).')
    can_apply_code = serializers.BooleanField(
        help_text=(
            "Show the 'Have a referral code?' box only when true: the program is on, the caller "
            "has not entered a code and has no order that was placed yet."
        )
    )
    referred_by = ReferredBySerializer(
        allow_null=True, help_text="The code the caller joined with; null when none."
    )
    friends_joined = serializers.IntegerField(help_text="Customers who entered the caller's code.")
    friends_rewarded = serializers.IntegerField(
        help_text="Of those, how many have had their first order delivered (reward given)."
    )


class ReferralApplySerializer(serializers.Serializer):
    code = serializers.CharField(
        max_length=32,
        help_text="A friend's referral code. Case and spaces are ignored.",
    )
