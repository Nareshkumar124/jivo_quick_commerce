"""Customer referrals (07 §2.5a, added 2026-11-13).

- `ReferralSettings`: one row (id 1) the admin edits: on/off, reward amount, validity, minimum,
  and (ADR 0003) the free cartons of the welcome reward and of each referral reward.
- `ReferralCode`: each customer's own code, created on their first `GET /account/referral/`.
- `Referral`: a customer (`referred`) entered another customer's (`referrer`) code. At most one
  per referred customer, ever. When the referred customer's first order is delivered, both get
  a personal coupon (`apps.referrals.services.reward_for_order`): since ADR 0002 (2026-11-25) a
  free-carton reward (FREE_UNIT) each; referrals rewarded before that got a ₹ FLAT coupon
  (`reward_amount` set).
Rows change only through `apps.referrals.services`.
"""

from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.db.models import F, Q
from simple_history.models import HistoricalRecords

from apps.core.models import TimeStampedModel
from apps.referrals.choices import ReferralStatus

SINGLETON_ID = 1
CODE_MAX_LENGTH = 12
MONEY = {"max_digits": 12, "decimal_places": 2}

DEFAULT_REWARD_AMOUNT = Decimal("90.00")
DEFAULT_VALIDITY_DAYS = 30
DEFAULT_MIN_ORDER_VALUE = Decimal("0.00")
MAX_REWARD_AMOUNT = Decimal("1000.00")
# ADR 0003: free cartons per reward (welcome and referral). The same bound as a FREE_UNIT
# coupon's `value` (`apps.promotions.models.MAX_FREE_UNITS`).
DEFAULT_REWARD_QUANTITY = 1
MAX_REWARD_QUANTITY = 10


class ReferralSettings(TimeStampedModel):
    """The referral program's settings (user decisions, 2026-11-13): a single row edited in the
    admin. Read when a code is entered (on/off) and when a reward is given (all fields)."""

    is_enabled = models.BooleanField(
        default=True,
        help_text=(
            "Off: customers cannot enter codes, and a referred customer whose first order is "
            "delivered while it is off gets no reward (the referral becomes VOID)."
        ),
    )
    reward_amount = models.DecimalField(
        **MONEY,
        default=DEFAULT_REWARD_AMOUNT,
        validators=[MinValueValidator(Decimal("1.00")), MaxValueValidator(MAX_REWARD_AMOUNT)],
        help_text=(
            "Not used since ADR 0002 (2026-11-25): the referral reward is now free cartons "
            "for each of the two customers (`reward_quantity`). Kept for the referrals rewarded "
            "before."
        ),
    )
    reward_validity_days = models.PositiveSmallIntegerField(
        default=DEFAULT_VALIDITY_DAYS,
        validators=[MinValueValidator(1), MaxValueValidator(365)],
        help_text=(
            "Days a reward stays valid after it is given: the referral rewards and the welcome "
            "reward (ADR 0002)."
        ),
    )
    reward_min_order_value = models.DecimalField(
        **MONEY,
        default=DEFAULT_MIN_ORDER_VALUE,
        validators=[MinValueValidator(Decimal("0.00"))],
        help_text=(
            "Not used by free-carton rewards (ADR 0002): they need the store's minimum paid "
            "cartons instead. Kept for the ₹ reward coupons given before."
        ),
    )
    # ADR 0003: how many free cartons each reward gives. Read when a reward is created; rewards
    # given earlier keep their own number. `db_default` so the previous release (during a
    # deploy) can still create the row.
    welcome_reward_quantity = models.PositiveSmallIntegerField(
        default=DEFAULT_REWARD_QUANTITY,
        db_default=DEFAULT_REWARD_QUANTITY,
        validators=[MinValueValidator(1), MaxValueValidator(MAX_REWARD_QUANTITY)],
        help_text=(
            "Free cartons in the welcome reward of a new customer account (1 to 10). Rewards "
            "already given keep their own number."
        ),
    )
    reward_quantity = models.PositiveSmallIntegerField(
        default=DEFAULT_REWARD_QUANTITY,
        db_default=DEFAULT_REWARD_QUANTITY,
        validators=[MinValueValidator(1), MaxValueValidator(MAX_REWARD_QUANTITY)],
        help_text=(
            "Free cartons each of the two customers gets for a referral (1 to 10). Rewards "
            "already given keep their own number."
        ),
    )
    history = HistoricalRecords()

    class Meta:
        verbose_name = "referral settings"
        verbose_name_plural = "referral settings"
        constraints = [
            models.CheckConstraint(condition=Q(id=SINGLETON_ID), name="referralsettings_singleton"),
            models.CheckConstraint(
                condition=Q(reward_amount__gt=0), name="referralsettings_amount_positive"
            ),
            models.CheckConstraint(
                condition=Q(reward_min_order_value__gte=0),
                name="referralsettings_min_order_not_negative",
            ),
            models.CheckConstraint(
                condition=Q(reward_validity_days__gte=1),
                name="referralsettings_validity_at_least_1",
            ),
            # ADR 0003: 1 to 10 free cartons per reward.
            models.CheckConstraint(
                condition=Q(welcome_reward_quantity__gte=1)
                & Q(welcome_reward_quantity__lte=MAX_REWARD_QUANTITY),
                name="referralsettings_welcome_quantity_1_to_10",
            ),
            models.CheckConstraint(
                condition=Q(reward_quantity__gte=1) & Q(reward_quantity__lte=MAX_REWARD_QUANTITY),
                name="referralsettings_reward_quantity_1_to_10",
            ),
        ]

    def __str__(self) -> str:
        return "Referral settings"

    def save(self, *args, **kwargs) -> None:
        self.pk = SINGLETON_ID
        if self._state.adding:
            # Saving a new instance while the row exists updates that row (keep created_at).
            created_at = (
                ReferralSettings.objects.filter(pk=SINGLETON_ID)
                .values_list("created_at", flat=True)
                .first()
            )
            if created_at is not None:
                self.created_at = created_at
                self._state.adding = False
        super().save(*args, **kwargs)

    @classmethod
    def load(cls) -> "ReferralSettings":
        config, _ = cls.objects.get_or_create(pk=SINGLETON_ID)
        return config


class ReferralCode(TimeStampedModel):
    """A customer's own referral code: created once, never changed."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="referral_code"
    )
    code = models.CharField(
        max_length=CODE_MAX_LENGTH,
        unique=True,
        help_text="Upper case, e.g. K7M2PQ. Friends type it in the app.",
    )

    class Meta:
        ordering = ["code"]

    def __str__(self) -> str:
        return self.code

    def save(self, *args, **kwargs) -> None:
        self.code = (self.code or "").strip().upper()
        super().save(*args, **kwargs)


class Referral(TimeStampedModel):
    """`referred` joined with `referrer`'s code. Rewarded once, when `referred`'s first order is
    delivered (both get a personal coupon)."""

    referrer = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="referrals_made"
    )
    referred = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="referral",
        help_text="A customer can enter a referral code only once.",
    )
    code = models.CharField(max_length=CODE_MAX_LENGTH, help_text="The code that was entered.")
    status = models.CharField(
        max_length=10, choices=ReferralStatus.choices, default=ReferralStatus.PENDING
    )
    reward_order = models.ForeignKey(
        "orders.Order",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="+",
        help_text="The referred customer's delivered order that gave the reward (or the VOID).",
    )
    reward_amount = models.DecimalField(
        **MONEY,
        null=True,
        blank=True,
        help_text="Rupees of the old ₹ reward coupons; empty for free-carton rewards (ADR 0002).",
    )
    referrer_coupon = models.ForeignKey(
        "promotions.Coupon", on_delete=models.PROTECT, null=True, blank=True, related_name="+"
    )
    referred_coupon = models.ForeignKey(
        "promotions.Coupon", on_delete=models.PROTECT, null=True, blank=True, related_name="+"
    )
    rewarded_at = models.DateTimeField(null=True, blank=True)
    note = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ["-created_at", "-id"]
        constraints = [
            models.CheckConstraint(condition=~Q(referrer=F("referred")), name="referral_not_self"),
            models.CheckConstraint(
                condition=~Q(status=ReferralStatus.REWARDED)
                | Q(
                    reward_order__isnull=False,
                    referrer_coupon__isnull=False,
                    referred_coupon__isnull=False,
                    rewarded_at__isnull=False,
                ),
                name="referral_rewarded_complete",
            ),
        ]
        indexes = [models.Index(fields=["referrer", "status"], name="referral_referrer_status_idx")]

    def __str__(self) -> str:
        return f"{self.referred_id} by {self.referrer_id} ({self.code}): {self.status}"
