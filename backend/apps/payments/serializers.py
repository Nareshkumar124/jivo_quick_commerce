"""Phase 3 API contract: payment verification and the Razorpay webhook (06 §2.6, 08 §4)."""

from rest_framework import serializers

from apps.payments.choices import WebhookResult

# Razorpay ids are a prefix plus (today) 14 letters and digits; a little slack is allowed.
RAZORPAY_ORDER_ID_PATTERN = r"^order_[A-Za-z0-9]{10,40}$"
RAZORPAY_PAYMENT_ID_PATTERN = r"^pay_[A-Za-z0-9]{10,40}$"
SIGNATURE_PATTERN = r"^[0-9a-f]{64}$"


class PaymentVerifySerializer(serializers.Serializer):
    order_id = serializers.IntegerField(min_value=1, help_text="Our order id (`Order.id`).")
    razorpay_order_id = serializers.RegexField(
        RAZORPAY_ORDER_ID_PATTERN, help_text="From the checkout success callback."
    )
    razorpay_payment_id = serializers.RegexField(
        RAZORPAY_PAYMENT_ID_PATTERN, help_text="From the checkout success callback."
    )
    razorpay_signature = serializers.RegexField(
        SIGNATURE_PATTERN, help_text="From the checkout success callback (64 hex characters)."
    )


class RazorpayWebhookEventSerializer(serializers.Serializer):
    """A Razorpay webhook event (only the fields the server reads are listed; others are
    ignored). Sent by Razorpay, never by the apps."""

    entity = serializers.CharField(required=False, help_text='"event".')
    account_id = serializers.CharField(required=False)
    event = serializers.CharField(
        help_text=(
            "Handled: `payment.captured`, `payment.failed`, `refund.processed`, `refund.failed`. "
            "Others are acknowledged and ignored."
        )
    )
    contains = serializers.ListField(child=serializers.CharField(), required=False)
    payload = serializers.DictField(
        child=serializers.JSONField(), help_text="The entities, e.g. `payment.entity`."
    )
    created_at = serializers.IntegerField(required=False, help_text="Unix time.")


class WebhookAckSerializer(serializers.Serializer):
    status = serializers.ChoiceField(choices=WebhookResult.choices)
