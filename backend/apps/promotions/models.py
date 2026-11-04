"""Coupons and their use by orders (07 §2.5).

A coupon's use is a `CouponRedemption` row per order, whose status follows the order (08 T1-T5):
- HELD: the order awaits online payment; it already counts against the usage limits.
- APPLIED: the order is placed (COD at once, online when the payment is captured).
- RELEASED: the hold ended without a sale (payment failed or abandoned); it no longer counts.
- REVERSED: an applied use was undone (order cancelled, Phase 4); it no longer counts.
Rows change only through `apps.promotions.services`.
"""

from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
from django.db import models
from django.db.models import F, Q
from django.db.models.functions import Upper
from simple_history.models import HistoricalRecords

from apps.core.models import TimeStampedModel
from apps.promotions.choices import DiscountType

COUPON_CODE_MAX_LENGTH = 30
MONEY = {"max_digits": 12, "decimal_places": 2}


class Coupon(TimeStampedModel):
    code = models.CharField(
        max_length=COUPON_CODE_MAX_LENGTH,
        help_text="What customers type; case-insensitive and stored in capitals, e.g. JIVO50.",
    )
    title = models.CharField(max_length=80, help_text='Shown in the app, e.g. "Flat ₹50 off".')
    description = models.CharField(
        max_length=200, blank=True, help_text='One line of terms, e.g. "On orders of ₹299+".'
    )
    discount_type = models.CharField(max_length=10, choices=DiscountType.choices)
    value = models.DecimalField(
        **MONEY,
        validators=[MinValueValidator(Decimal("0.01"))],
        help_text="FLAT: rupees off. PERCENT: percent off (at most 100).",
    )
    max_discount = models.DecimalField(
        **MONEY,
        null=True,
        blank=True,
        validators=[MinValueValidator(Decimal("0.01"))],
        help_text="Cap on the discount (for PERCENT coupons). Empty = no cap.",
    )
    min_order_value = models.DecimalField(
        **MONEY,
        default=Decimal("0.00"),
        validators=[MinValueValidator(Decimal("0.00"))],
        help_text="Minimum item total, before the coupon (D-09).",
    )
    starts_at = models.DateTimeField(null=True, blank=True, help_text="Empty = valid now.")
    ends_at = models.DateTimeField(null=True, blank=True, help_text="Empty = never expires.")
    usage_limit_total = models.PositiveIntegerField(
        null=True, blank=True, help_text="Uses across all customers. Empty = unlimited."
    )
    usage_limit_per_user = models.PositiveIntegerField(
        null=True, blank=True, default=1, help_text="Uses per customer. Empty = unlimited."
    )
    first_order_only = models.BooleanField(
        default=False, help_text="Only for customers with no earlier order that was placed."
    )
    stores = models.ManyToManyField(
        "stores.DarkStore", blank=True, related_name="coupons", help_text="Empty = all stores."
    )
    categories = models.ManyToManyField(
        "catalog.Category",
        blank=True,
        related_name="coupons",
        help_text=(
            "Empty = the whole cart. Otherwise the discount is on the items in these categories "
            "(a top-level category includes its sub-categories) and never more than their total."
        ),
    )
    is_active = models.BooleanField(default=True)
    is_visible = models.BooleanField(
        default=True, help_text="Listed in the app's coupon sheet. Hidden codes still work."
    )
    history = HistoricalRecords()

    class Meta:
        ordering = ["code"]
        constraints = [
            models.UniqueConstraint(Upper("code"), name="coupon_code_unique_ci"),
            models.CheckConstraint(condition=Q(value__gt=0), name="coupon_value_positive"),
            models.CheckConstraint(
                condition=~Q(discount_type=DiscountType.PERCENT) | Q(value__lte=100),
                name="coupon_percent_at_most_100",
            ),
            models.CheckConstraint(
                condition=Q(max_discount__isnull=True) | Q(max_discount__gt=0),
                name="coupon_max_discount_positive",
            ),
            models.CheckConstraint(
                condition=Q(min_order_value__gte=0), name="coupon_min_order_not_negative"
            ),
            models.CheckConstraint(
                condition=Q(starts_at__isnull=True)
                | Q(ends_at__isnull=True)
                | Q(ends_at__gt=F("starts_at")),
                name="coupon_ends_after_start",
            ),
        ]
        indexes = [models.Index(fields=["is_active", "is_visible"], name="coupon_listing_idx")]

    def __str__(self) -> str:
        return self.code

    def save(self, *args, **kwargs) -> None:
        self.code = (self.code or "").strip().upper()
        super().save(*args, **kwargs)

    def clean(self) -> None:
        super().clean()
        self.code = (self.code or "").strip().upper()
        if self.discount_type == DiscountType.PERCENT and self.value and self.value > 100:
            raise ValidationError({"value": "A percent coupon is at most 100."})
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValidationError({"ends_at": "Must be after the start."})


class RedemptionStatus(models.TextChoices):
    HELD = "HELD", "Held (order awaiting payment)"
    APPLIED = "APPLIED", "Applied"
    RELEASED = "RELEASED", "Released (no sale)"
    REVERSED = "REVERSED", "Reversed (order cancelled)"


# Statuses that use up the coupon (count against its limits).
COUNTED_STATUSES = (RedemptionStatus.HELD, RedemptionStatus.APPLIED)


class CouponRedemption(TimeStampedModel):
    coupon = models.ForeignKey(Coupon, on_delete=models.PROTECT, related_name="redemptions")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="coupon_redemptions"
    )
    order = models.OneToOneField(
        "orders.Order", on_delete=models.PROTECT, related_name="coupon_redemption"
    )
    discount_amount = models.DecimalField(**MONEY)
    status = models.CharField(max_length=10, choices=RedemptionStatus.choices)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=Q(discount_amount__gte=0), name="couponredemption_amount_not_negative"
            ),
        ]
        indexes = [
            models.Index(fields=["coupon", "status"], name="redemption_coupon_status_idx"),
            models.Index(fields=["coupon", "user", "status"], name="redemption_coupon_user_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.coupon_id} on order {self.order_id}: {self.status}"
