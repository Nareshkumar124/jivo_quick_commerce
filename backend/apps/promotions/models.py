"""Coupons and their use by orders (07 §2.5).

A coupon with an `owner` is personal (07 §2.5, added 2026-11-13): only that customer sees it in
the coupon sheet and can apply or use it (`apps.promotions.services.is_for`). Referral rewards
are personal coupons.

Free-carton rewards (ADR 0002) are personal coupons too: `discount_type` FREE_UNIT (value 1 =
one carton, no money off) with a `source` (WELCOME, REFERRAL_REFERRER, REFERRAL_REFERRED). A
customer has at most one WELCOME reward (database rule). Their status (AVAILABLE, CLAIMED, USED,
EXPIRED) is derived from the coupon's redemptions and their orders
(`apps.promotions.rewards`).

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
from apps.promotions.choices import CouponSource, DiscountType

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
        help_text=(
            "FLAT: rupees off. PERCENT: percent off (at most 100). FREE_UNIT: free cartons "
            "(always 1)."
        ),
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
    # Added 2026-11-13 (referral rewards): a personal coupon is seen and usable only by its owner.
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="personal_coupons",
        help_text=(
            "Personal coupon: only this customer sees it and can use it (e.g. a referral "
            "reward). Empty = a public coupon."
        ),
    )
    # ADR 0002: why the coupon exists (rewards). `db_default` so the previous release (during a
    # deploy) can still insert coupons.
    source = models.CharField(
        max_length=20,
        choices=CouponSource.choices,
        default=CouponSource.NONE,
        db_default=CouponSource.NONE,
        help_text="Welcome and referral rewards are made by the system; staff coupons are NONE.",
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
            # ADR 0002: a free-carton coupon gives exactly one carton.
            models.CheckConstraint(
                condition=~Q(discount_type=DiscountType.FREE_UNIT) | Q(value=1),
                name="coupon_free_unit_is_one",
            ),
            # ADR 0002 (code review): a free-carton coupon is always a personal reward, never a
            # public coupon or a staff one.
            models.CheckConstraint(
                condition=~Q(discount_type=DiscountType.FREE_UNIT)
                | (Q(owner__isnull=False) & ~Q(source=CouponSource.NONE)),
                name="coupon_free_unit_is_a_reward",
            ),
            # ADR 0002 §7/§13: one welcome reward per customer, ever.
            models.UniqueConstraint(
                fields=["owner"],
                condition=Q(source=CouponSource.WELCOME),
                name="coupon_one_welcome_reward_per_owner",
            ),
        ]
        indexes = [
            models.Index(fields=["is_active", "is_visible"], name="coupon_listing_idx"),
            models.Index(fields=["owner", "discount_type"], name="coupon_owner_type_idx"),
        ]

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
        if self.discount_type == DiscountType.FREE_UNIT:
            errors = {}
            if self.value != 1:
                errors["value"] = "A free-carton coupon gives exactly 1 carton."
            if self.owner_id is None or self.source == CouponSource.NONE:
                errors["discount_type"] = (
                    "Free-carton coupons are rewards made by the system (welcome and referral) "
                    "for one customer. Choose flat or percent off."
                )
            if errors:
                raise ValidationError(errors)
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
