from decimal import ROUND_HALF_UP, Decimal

from django.contrib.auth.base_user import AbstractBaseUser
from django.contrib.auth.models import PermissionsMixin
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import Point
from django.core.validators import RegexValidator
from django.db import models

from apps.accounts.choices import AddressLabel, AppName, OtpPurpose, Platform, RiderStatus
from apps.accounts.managers import (
    CustomerManager,
    UserManager,
    normalise_email,
    normalise_optional,
)
from apps.core.models import TimeStampedModel

# E.164 within the documented char(15): "+" and up to 14 digits. India: +91 and 10 digits.
# Phase 1 adds the +91 rule for OTP login.
phone_validator = RegexValidator(
    regex=r"^\+[1-9][0-9]{6,13}$",
    message="Enter the phone number in E.164 format, e.g. +919876543210.",
)


class User(AbstractBaseUser, PermissionsMixin, TimeStampedModel):
    """One table for everyone (02 §6). Fields per 07 §2.1.

    - Customers and riders sign in with `phone` + OTP (Phase 1) and have no usable password.
    - Staff sign in to the admin / Ops Console with `email` + password (Django sessions), so
      `email` is the USERNAME_FIELD. A rider profile and staff roles live in other tables.
    - `auth_id` is reserved for the Jivo Auth identity (D-04) and unused until that integration.
    """

    # Unique when set; NULL (never "") when absent, so many users can have none.
    phone = models.CharField(
        max_length=15,
        unique=True,
        null=True,
        blank=True,
        validators=[phone_validator],
        help_text="E.164, e.g. +919876543210. Login identifier for customers and riders.",
    )
    email = models.EmailField(
        unique=True,
        null=True,
        blank=True,
        help_text="Stored lowercase. Login identifier for staff.",
    )
    name = models.CharField(max_length=120, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(
        default=False, help_text="Can log in to the admin site and the Ops Console."
    )
    auth_id = models.CharField(
        max_length=64,
        unique=True,
        null=True,
        blank=True,
        help_text="Reserved: Jivo Auth identity (D-04). Set only by the Jivo Auth integration.",
    )
    marketing_opt_in = models.BooleanField(default=False, help_text="Promotional push consent.")
    deleted_at = models.DateTimeField(
        null=True, blank=True, help_text="Set on account deletion; PII is anonymised by a job."
    )
    deletion_reason = models.CharField(max_length=500, blank=True)
    anonymised_at = models.DateTimeField(
        null=True, blank=True, help_text="Set once personal data has been anonymised."
    )
    # DPDP consent (09 §4): the terms/privacy version accepted at OTP login, and when.
    terms_version = models.CharField(max_length=32, blank=True)
    terms_accepted_at = models.DateTimeField(null=True, blank=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    class Meta:
        verbose_name = "user"
        verbose_name_plural = "users"

    def __str__(self) -> str:
        return self.phone or self.email or f"User {self.pk}"

    @property
    def is_profile_complete(self) -> bool:
        return bool(self.name.strip())

    @property
    def rider_status(self) -> str:
        """NONE until Phase 5 adds the Rider profile (07 §2.8); then the profile's status."""
        return RiderStatus.NONE

    def clean(self) -> None:
        super().clean()
        self._normalise_identifiers()

    def save(self, *args, **kwargs) -> None:
        self._normalise_identifiers()
        super().save(*args, **kwargs)

    def _normalise_identifiers(self) -> None:
        self.email = normalise_email(self.email)
        self.phone = normalise_optional(self.phone)
        self.auth_id = normalise_optional(self.auth_id)


class Customer(User):
    """Proxy for the Customers admin (05 §2): non-staff users only, with its own permissions so
    support/ops can block customers without being able to edit staff accounts or roles."""

    objects = CustomerManager()

    class Meta:
        proxy = True
        verbose_name = "customer"
        verbose_name_plural = "customers"
        # DL-35: "Anonymise now" is Super Admin only (Super Admin holds every accounts
        # permission; no other role is granted this one).
        permissions = [
            ("anonymise_customer", "Can anonymise a customer now (deletion requested only)"),
        ]


class OTPRequest(TimeStampedModel):
    """One OTP sent to a phone (07 §2.1). The code is stored only as a keyed hash."""

    phone = models.CharField(max_length=15)
    app = models.CharField(max_length=16, choices=AppName.choices)
    purpose = models.CharField(max_length=20, choices=OtpPurpose.choices, default=OtpPurpose.LOGIN)
    code_hash = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    verified_at = models.DateTimeField(null=True, blank=True)
    sms_sent_at = models.DateTimeField(
        null=True, blank=True, help_text="Set when the SMS went out (keeps the task idempotent)."
    )
    ip = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.CharField(max_length=256, blank=True)

    class Meta:
        verbose_name = "OTP request"
        indexes = [
            models.Index(fields=["phone", "app", "purpose", "-created_at"], name="otp_lookup_idx"),
            models.Index(fields=["created_at"], name="otp_created_idx"),
        ]

    def __str__(self) -> str:
        return f"OTP {self.purpose} for {self.app} ({self.pk})"


class Device(TimeStampedModel):
    """A push-notification registration (07 §2.1). Upserted by `fcm_token`."""

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="devices")
    app = models.CharField(max_length=16, choices=AppName.choices)
    platform = models.CharField(max_length=16, choices=Platform.choices)
    fcm_token = models.CharField(max_length=512, unique=True)
    app_version = models.CharField(max_length=32)
    is_active = models.BooleanField(default=True)
    last_seen_at = models.DateTimeField()

    class Meta:
        indexes = [models.Index(fields=["user", "is_active"], name="device_user_active_idx")]

    def __str__(self) -> str:
        return f"{self.app}/{self.platform} device {self.pk}"


COORDINATE_QUANTUM = Decimal("0.000001")


def to_coordinate(value: float | Decimal) -> Decimal:
    """Round a latitude/longitude to 6 decimal places (about 0.1 m)."""
    return Decimal(str(value)).quantize(COORDINATE_QUANTUM, rounding=ROUND_HALF_UP)


class Address(TimeStampedModel):
    """A saved delivery address (07 §2.1).

    Phase 2 adds `location` (PostGIS Point, SRID 4326), the field geo queries use. Migration is
    backward compatible: `lat`/`lng` decimals stay and are always written together with
    `location` (code still running from before Phase 2 writes only the decimals, so geo queries
    fall back to them via `address_point()`). A later migration switches reads to `location` and
    drops the decimals. The API shape (`lat`, `lng` numbers) never changes.
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="addresses")
    label = models.CharField(max_length=10, choices=AddressLabel.choices)
    custom_label = models.CharField(max_length=40, blank=True)
    receiver_name = models.CharField(max_length=120)
    receiver_phone = models.CharField(max_length=15)
    house = models.CharField(max_length=120)
    building_street = models.CharField(max_length=200)
    landmark = models.CharField(max_length=120, blank=True)
    area = models.CharField(max_length=120, blank=True)
    city = models.CharField(max_length=80)
    state = models.CharField(max_length=80)
    pincode = models.CharField(max_length=6)
    lat = models.DecimalField(max_digits=9, decimal_places=6)
    lng = models.DecimalField(max_digits=9, decimal_places=6)
    location = gis_models.PointField(srid=4326, null=True, blank=True)
    is_default = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        verbose_name_plural = "addresses"
        constraints = [
            models.UniqueConstraint(
                fields=["user"],
                condition=models.Q(is_default=True, is_deleted=False),
                name="address_one_default_per_user",
            ),
            models.CheckConstraint(
                condition=models.Q(lat__gte=-90, lat__lte=90, lng__gte=-180, lng__lte=180),
                name="address_lat_lng_range",
            ),
        ]
        indexes = [models.Index(fields=["user", "is_deleted"], name="address_user_live_idx")]

    def __str__(self) -> str:
        return f"{self.get_label_display()} address {self.pk}"

    def save(self, *args, **kwargs) -> None:
        """`location` always follows `lat`/`lng`, whoever writes them (service, admin, shell).
        A save limited to other fields (`update_fields` without lat/lng) leaves it alone."""
        update_fields = kwargs.get("update_fields")
        writes_coordinates = update_fields is None or bool({"lat", "lng"} & set(update_fields))
        if writes_coordinates and self.lat is not None and self.lng is not None:
            self.location = Point(float(self.lng), float(self.lat), srid=4326)
            if update_fields is not None:
                kwargs["update_fields"] = {*update_fields, "location"}
        super().save(*args, **kwargs)
