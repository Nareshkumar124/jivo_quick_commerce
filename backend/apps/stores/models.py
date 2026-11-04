"""Dark stores, opening hours, pricing config, notify-me leads and staff store scoping (07 §2.2).

Geo fields are WGS84 (SRID 4326) with GiST indexes (GeoDjango's default `spatial_index`).
State changes go through `apps.stores.services`; the admin registers these models (admin agent).
"""

from decimal import Decimal

from django.conf import settings
from django.contrib.gis.db import models as gis_models
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models
from simple_history.models import HistoricalRecords

from apps.accounts.validators import pincode_validator
from apps.core.models import TimeStampedModel

store_code_validator = RegexValidator(
    r"^[A-Z0-9][A-Z0-9-]{1,19}$", "Use 2-20 capital letters, digits or dashes, e.g. GGN-01."
)
invoice_prefix_validator = RegexValidator(
    r"^[A-Z0-9]{2,10}$", "Use 2-10 capital letters or digits, e.g. GGN01."
)
gstin_validator = RegexValidator(
    r"^[0-9]{2}[A-Z0-9]{10}[0-9A-Z]{3}$", "Enter a 15-character GSTIN, e.g. 06AAACJ1234F1Z5."
)
fssai_validator = RegexValidator(r"^[0-9]{14}$", "Enter the 14-digit FSSAI licence number.")


class DarkStore(TimeStampedModel):
    code = models.CharField(max_length=20, unique=True, validators=[store_code_validator])
    name = models.CharField(max_length=120, help_text='Shown in the app, e.g. "Jivo Sector 14".')
    address = models.CharField(max_length=300)
    city = models.CharField(max_length=80)
    state = models.CharField(max_length=80)
    pincode = models.CharField(max_length=6, validators=[pincode_validator])
    location = gis_models.PointField(srid=4326, help_text="Store entrance (WGS84).")
    service_area = gis_models.MultiPolygonField(
        srid=4326, help_text="Delivery area. Points inside it are serviceable by this store."
    )
    is_active = models.BooleanField(
        default=True, help_text="Off: the store disappears from the apps (permanently closed)."
    )
    is_accepting_orders = models.BooleanField(
        default=True,
        help_text="Off: temporarily closed. Customers can browse but not check out.",
    )
    avg_prep_minutes = models.PositiveSmallIntegerField(
        default=8, validators=[MinValueValidator(1), MaxValueValidator(120)]
    )
    phone = models.CharField(max_length=15, blank=True)
    gstin = models.CharField(max_length=15, blank=True, validators=[gstin_validator])
    fssai_license_no = models.CharField(max_length=14, blank=True, validators=[fssai_validator])
    invoice_prefix = models.CharField(
        max_length=10, unique=True, validators=[invoice_prefix_validator]
    )
    auto_accept_orders = models.BooleanField(default=False)
    dispatch_radius_km = models.DecimalField(
        max_digits=4, decimal_places=1, default=Decimal("5.0"), validators=[MinValueValidator(0)]
    )
    priority = models.PositiveSmallIntegerField(
        default=100,
        help_text="Tie-break when service areas overlap: the lower number wins (07 §2.2).",
    )

    class Meta:
        ordering = ["priority", "code"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(avg_prep_minutes__gte=1), name="darkstore_prep_minutes_positive"
            ),
        ]

    def __str__(self) -> str:
        return f"{self.code} {self.name}"


class Weekday(models.IntegerChoices):
    MONDAY = 0, "Monday"
    TUESDAY = 1, "Tuesday"
    WEDNESDAY = 2, "Wednesday"
    THURSDAY = 3, "Thursday"
    FRIDAY = 4, "Friday"
    SATURDAY = 5, "Saturday"
    SUNDAY = 6, "Sunday"


class StoreTiming(TimeStampedModel):
    """One opening window on a weekday, in store local time (settings.STORE_TIME_ZONE, IST).

    Several rows per day are allowed (split shifts). A window past midnight is two rows: e.g.
    Friday 18:00-23:59 and Saturday 00:00-02:00. A store with no rows is never open.
    """

    store = models.ForeignKey(DarkStore, on_delete=models.CASCADE, related_name="timings")
    weekday = models.PositiveSmallIntegerField(choices=Weekday.choices)
    opens_at = models.TimeField()
    closes_at = models.TimeField()

    class Meta:
        ordering = ["weekday", "opens_at"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(closes_at__gt=models.F("opens_at")),
                name="storetiming_closes_after_opens",
            ),
            models.CheckConstraint(
                condition=models.Q(weekday__lte=6), name="storetiming_weekday_range"
            ),
        ]
        indexes = [models.Index(fields=["store", "weekday"], name="storetiming_store_day_idx")]

    def __str__(self) -> str:
        return f"{self.get_weekday_display()} {self.opens_at:%H:%M}-{self.closes_at:%H:%M}"


def _money(default: str = "0.00", **kwargs) -> models.DecimalField:
    return models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal(default),
        validators=[MinValueValidator(Decimal("0.00"))],
        **kwargs,
    )


# D-09 business rule defaults (01 §5), placeholders until Jivo confirms them (PM default, Phase
# 3). A new store starts with these; each store's values are edited in the admin.
D09_PRICING = {
    "min_order_value": Decimal("99.00"),
    "delivery_fee": Decimal("25.00"),
    "free_delivery_threshold": Decimal("299.00"),
    "small_cart_fee": Decimal("15.00"),
    "small_cart_threshold": Decimal("149.00"),
    "handling_fee": Decimal("0.00"),
    "cod_enabled": True,
    "cod_max_order_value": Decimal("2000.00"),
}


PRICING_MONEY_FIELDS = (
    "min_order_value",
    "delivery_fee",
    "free_delivery_threshold",
    "small_cart_fee",
    "small_cart_threshold",
    "handling_fee",
    "cod_max_order_value",
)


# T-406c: upper bounds of `PricingConfig.clean()` (generous; they stop typos, not policy).
PRICING_UPPER_BOUNDS = {
    "min_order_value": Decimal("5000.00"),
    "delivery_fee": Decimal("500.00"),
    "free_delivery_threshold": Decimal("10000.00"),
    "small_cart_fee": Decimal("500.00"),
    "small_cart_threshold": Decimal("10000.00"),
    "handling_fee": Decimal("500.00"),
    "cod_max_order_value": Decimal("50000.00"),
}


class PricingConfig(TimeStampedModel):
    """Per-store bill rules (08 §6.2), read by `cart.services.compute_bill()`. Defaults are the
    D-09 values (Phase 3, PM default); a store without a row is billed with them too.
    All thresholds compare against the item total before the coupon."""

    store = models.OneToOneField(DarkStore, on_delete=models.CASCADE, related_name="pricing")
    min_order_value = _money("99.00", help_text="Minimum item total to place an order.")
    delivery_fee = _money("25.00")
    free_delivery_threshold = _money(
        "299.00", help_text="Delivery is free when the item total is at least this."
    )
    small_cart_fee = _money("15.00")
    small_cart_threshold = _money(
        "149.00", help_text="The small-cart fee applies when the item total is below this."
    )
    handling_fee = _money("0.00")
    cod_enabled = models.BooleanField(default=True)
    cod_max_order_value = _money(
        "2000.00", help_text="Cash on delivery only up to this amount to pay."
    )
    history = HistoricalRecords()

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(**{f"{field}__gte": 0 for field in PRICING_MONEY_FIELDS}),
                name="pricingconfig_money_not_negative",
            ),
        ]

    def __str__(self) -> str:
        return f"Pricing for {self.store.code}"

    def clean(self) -> None:
        """Sanity bounds and cross-field checks (T-406c): catch a typo (₹2500 for ₹25) before it
        reaches every bill. Bounds are generous; the admin form shows the messages per field."""
        errors = {}
        for field, upper in PRICING_UPPER_BOUNDS.items():
            value = getattr(self, field)
            if value is not None and value > upper:
                errors[field] = f"Must be at most ₹{upper:,.0f}. Check for a typo."
        if (
            self.cod_enabled
            and self.cod_max_order_value is not None
            and self.min_order_value is not None
            and self.cod_max_order_value < self.min_order_value
        ):
            errors.setdefault(
                "cod_max_order_value",
                "Must be at least the minimum order value, or no order could use COD.",
            )
        if (
            self.small_cart_fee
            and self.small_cart_threshold is not None
            and self.small_cart_threshold <= 0
        ):
            errors.setdefault(
                "small_cart_threshold",
                "Set a threshold above zero, or the small-cart fee never applies.",
            )
        if errors:
            raise ValidationError(errors)


class ServiceabilityRequest(TimeStampedModel):
    """A "Notify me" lead for an unserviced location (03 §2.3), for expansion planning."""

    location = gis_models.PointField(srid=4326)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="serviceability_requests",
    )
    # NULL = no phone given (07 §2.2); cleared when the user's account is anonymised.
    phone = models.CharField(max_length=15, null=True, blank=True)  # noqa: DJ001
    address_text = models.CharField(max_length=500, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["created_at"], name="servicereq_created_idx")]

    def __str__(self) -> str:
        return f"Notify-me {self.pk}"


class StaffStoreAccess(TimeStampedModel):
    """Which stores a store-scoped staff member (Store Manager, Store Staff) can see (05 §3).

    Lives in `stores` (not `accounts`, as first drafted in 07) so accounts does not depend on
    stores. Use `apps.stores.services.stores_for(user)` to scope querysets.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="store_access"
    )
    store = models.ForeignKey(DarkStore, on_delete=models.CASCADE, related_name="staff_access")

    class Meta:
        verbose_name_plural = "staff store access"
        constraints = [
            models.UniqueConstraint(fields=["user", "store"], name="staffstoreaccess_unique"),
        ]

    def __str__(self) -> str:
        return f"{self.user} @ {self.store.code}"
