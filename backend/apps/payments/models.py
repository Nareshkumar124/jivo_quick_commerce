"""Payments, refunds and gateway webhook events (07 §2.7, 08 §4).

- `Payment`: one row per payment attempt on an order (a retry creates a new row). The amount is
  always the server-side order's, never the client's.
- `Refund`: always to the original payment (08 §4 rule 4). `idempotency_key` makes the refund
  task safe to retry (e.g. "t3a:<payment id>" for a late capture's automatic refund).
- `PaymentWebhookEvent`: only events with a valid signature are stored, so an unauthenticated
  caller can never claim an `event_id` before Razorpay's real event arrives.
"""

from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.core.models import TimeStampedModel

MONEY = {"max_digits": 12, "decimal_places": 2}


class Gateway(models.TextChoices):
    RAZORPAY = "RAZORPAY", "Razorpay"
    COD = "COD", "Cash on delivery"
    RAZORPAY_QR = "RAZORPAY_QR", "Razorpay UPI QR (COD)"


class PaymentAttemptStatus(models.TextChoices):
    """08 §4 `Payment.status`."""

    CREATED = "CREATED", "Created"
    AUTHORIZED = "AUTHORIZED", "Authorized"
    CAPTURED = "CAPTURED", "Captured"
    FAILED = "FAILED", "Failed"


class Payment(TimeStampedModel):
    order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="payments")
    gateway = models.CharField(max_length=12, choices=Gateway.choices)
    gateway_order_id = models.CharField(max_length=64, blank=True)
    gateway_payment_id = models.CharField(max_length=64, null=True, blank=True)  # noqa: DJ001
    amount = models.DecimalField(**MONEY)
    currency = models.CharField(max_length=3, default="INR")
    status = models.CharField(max_length=12, choices=PaymentAttemptStatus.choices)
    method = models.CharField(
        max_length=20, blank=True, help_text="upi / card / netbanking / wallet / cash."
    )
    error_code = models.CharField(max_length=64, blank=True)
    error_description = models.CharField(max_length=255, blank=True)
    raw = models.JSONField(default=dict, blank=True)
    captured_at = models.DateTimeField(null=True, blank=True)
    idempotency_key = models.CharField(
        max_length=64, blank=True, help_text="The retry-payment Idempotency-Key, if any."
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["gateway_order_id"],
                condition=~Q(gateway_order_id=""),
                name="payment_gateway_order_id_unique",
            ),
            models.UniqueConstraint(
                fields=["gateway_payment_id"],
                condition=Q(gateway_payment_id__isnull=False),
                name="payment_gateway_payment_id_unique",
            ),
            models.UniqueConstraint(
                fields=["order", "idempotency_key"],
                condition=~Q(idempotency_key=""),
                name="payment_order_idempotency_key_unique",
            ),
            models.CheckConstraint(condition=Q(amount__gt=0), name="payment_amount_positive"),
        ]
        indexes = [models.Index(fields=["order", "-created_at"], name="payment_order_idx")]

    def __str__(self) -> str:
        return f"{self.gateway} {self.gateway_order_id or self.pk}: {self.status}"


class RefundStatus(models.TextChoices):
    PENDING = "PENDING", "Pending"
    PROCESSED = "PROCESSED", "Processed"
    FAILED = "FAILED", "Failed"


class Refund(TimeStampedModel):
    payment = models.ForeignKey(Payment, on_delete=models.PROTECT, related_name="refunds")
    order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="refunds")
    amount = models.DecimalField(**MONEY)
    reason = models.CharField(max_length=255)
    gateway_refund_id = models.CharField(max_length=64, blank=True)
    status = models.CharField(
        max_length=10, choices=RefundStatus.choices, default=RefundStatus.PENDING
    )
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="initiated_refunds",
        help_text="Empty for automatic refunds.",
    )
    processed_at = models.DateTimeField(null=True, blank=True)
    idempotency_key = models.CharField(
        max_length=64, unique=True, help_text='Makes the refund task safe to retry ("t3a:...").'
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["gateway_refund_id"],
                condition=~Q(gateway_refund_id=""),
                name="refund_gateway_refund_id_unique",
            ),
            models.CheckConstraint(condition=Q(amount__gt=0), name="refund_amount_positive"),
        ]
        permissions = [
            ("issue_refund", "Can refund an order (within the role's limit) or retry a refund"),
        ]

    def __str__(self) -> str:
        return f"Refund {self.amount} on order {self.order_id}: {self.status}"


class PaymentWebhookEvent(models.Model):
    """A signed gateway event, stored once per `event_id` (08 §4 rule 2)."""

    event_id = models.CharField(max_length=64, unique=True)
    event_type = models.CharField(max_length=64)
    payload = models.JSONField()
    signature_valid = models.BooleanField(
        default=True, help_text="Always true: events with a bad signature are never stored."
    )
    processed_at = models.DateTimeField(null=True, blank=True)
    error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [models.Index(fields=["event_type", "-created_at"], name="webhook_type_idx")]

    def __str__(self) -> str:
        return f"{self.event_type} {self.event_id}"
