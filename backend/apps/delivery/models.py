"""Riders and delivery (07 §2.8). Phase 5 slice 5.1: the rider profile, KYC documents and bank
details. Shifts and locations (5.2), tasks and offers (5.3), cash, earnings and payouts (5.4)
are added by their slices.

Personal data rules (09 §3, D-14 default):
- KYC files live in the private bucket (`default` storage, signed short-lived URLs only).
- Aadhaar: only the masked number is stored (`XXXX XXXX 1234`), never the full number.
- PAN, DL and RC numbers and the bank account number are encrypted (`apps.core.crypto`) with a
  masked copy for display. Nothing shows the full numbers except an explicit staff action.
"""

import secrets
from decimal import Decimal

from django.conf import settings
from django.contrib.gis.db import models as gis_models
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from simple_history.models import HistoricalRecords

from apps.accounts.choices import RiderStatus
from apps.core.crypto import decrypt
from apps.core.models import TimeStampedModel
from apps.delivery.choices import (
    RIDER_PROFILE_STATUSES,
    DocumentStatus,
    DocumentType,
    ShiftEndReason,
    VehicleType,
    required_documents,
)

MONEY = {"max_digits": 12, "decimal_places": 2}


def default_cash_limit() -> Decimal:
    return settings.RIDER_DEFAULT_CASH_LIMIT


class Rider(TimeStampedModel):
    """A delivery partner (1:1 with a `User`, 02 §6). Created by `POST /rider/register/` in
    PENDING_KYC; ops approve it (ACTIVE) and set the home store (04 §2.2)."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name="rider_profile"
    )
    status = models.CharField(
        max_length=12, choices=RIDER_PROFILE_STATUSES, default=RiderStatus.PENDING_KYC
    )
    rejection_reason = models.CharField(
        max_length=300, blank=True, help_text="Shown to the rider when the application is rejected."
    )
    suspension_reason = models.CharField(max_length=300, blank=True)
    full_name = models.CharField(max_length=120, help_text="Legal name, as on the documents.")
    dob = models.DateField("date of birth")
    emergency_contact_name = models.CharField(max_length=120)
    emergency_contact_phone = models.CharField(max_length=15)
    vehicle_type = models.CharField(max_length=12, choices=VehicleType.choices)
    vehicle_number = models.CharField(
        max_length=16, blank=True, help_text="Motorised vehicles only, e.g. HR26DQ1234."
    )
    preferred_store = models.ForeignKey(
        "stores.DarkStore",
        on_delete=models.PROTECT,
        related_name="rider_applicants",
        help_text="The store the rider asked for at registration.",
    )
    home_store = models.ForeignKey(
        "stores.DarkStore",
        on_delete=models.PROTECT,
        null=True,
        blank=True,
        related_name="riders",
        help_text="Set by ops on approval. Offers come only from this store (04).",
    )
    # Shift and location state (slice 5.2). Location writes use queryset updates (no history).
    is_online = models.BooleanField(default=False)
    current_location = gis_models.PointField(srid=4326, null=True, blank=True)
    last_location_at = models.DateTimeField(null=True, blank=True)
    last_heartbeat_at = models.DateTimeField(null=True, blank=True)
    # Cash (slice 5.4): `cash_in_hand` is the running balance of RiderCashLedger.
    cash_in_hand = models.DecimalField(**MONEY, default=Decimal("0.00"))
    cash_limit = models.DecimalField(
        **MONEY,
        default=default_cash_limit,
        validators=[MinValueValidator(Decimal("0.00"))],
        help_text="At or above it the rider gets prepaid offers only (04 §2.7). Default ₹5,000.",
    )
    rating_avg = models.DecimalField(
        max_digits=2,
        decimal_places=1,
        null=True,
        blank=True,
        validators=[MinValueValidator(Decimal("1.0")), MaxValueValidator(Decimal("5.0"))],
        help_text="Average customer rating (ratings arrive in Phase 7).",
    )
    # Bank details (04 §2.2). The account number is encrypted; `bank_account_last4` is for
    # display. Payouts are made offline by Finance (D-16).
    bank_account_name = models.CharField(max_length=120, blank=True)
    bank_account_number_encrypted = models.TextField(blank=True, editable=False)
    bank_account_last4 = models.CharField(max_length=4, blank=True, editable=False)
    ifsc = models.CharField(max_length=11, blank=True)
    upi_id = models.CharField(max_length=256, blank=True)
    bank_updated_at = models.DateTimeField(null=True, blank=True)
    # Review trail.
    submitted_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When the application was last (re)submitted for review.",
    )
    approved_at = models.DateTimeField(null=True, blank=True)
    approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )

    history = HistoricalRecords(
        excluded_fields=[
            "current_location",
            "last_location_at",
            "last_heartbeat_at",
            "updated_at",
        ]
    )

    class Meta:
        indexes = [
            models.Index(fields=["status", "home_store"], name="delivery_rider_status_store"),
            models.Index(fields=["home_store", "is_online"], name="delivery_rider_online"),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(cash_limit__gte=0), name="delivery_rider_cash_limit_gte_0"
            ),
            models.CheckConstraint(
                condition=~models.Q(status=RiderStatus.ACTIVE) | models.Q(home_store__isnull=False),
                name="delivery_rider_active_has_home_store",
            ),
            models.CheckConstraint(
                condition=models.Q(is_online=False) | models.Q(status=RiderStatus.ACTIVE),
                name="delivery_rider_online_only_active",
            ),
        ]
        permissions = [
            ("review_rider", "Can approve, reject and suspend riders and review KYC documents"),
            ("view_kyc_document_file", "Can open KYC document files"),
        ]

    def __str__(self) -> str:
        return f"{self.full_name} ({self.get_status_display()})"

    @property
    def required_documents(self) -> list[str]:
        return required_documents(self.vehicle_type)

    @property
    def has_bank_account(self) -> bool:
        return bool(self.bank_account_number_encrypted)

    def bank_account_number(self) -> str:
        """The full account number (decrypted). Only for payouts; never shown in lists."""
        return decrypt(self.bank_account_number_encrypted)

    @property
    def cash_limit_reached(self) -> bool:
        return self.cash_in_hand >= self.cash_limit


def kyc_upload_to(instance, filename: str) -> str:
    # Random, unguessable keys in the private bucket; never the rider's name or number.
    return f"kyc/{instance.rider_id}/{instance.doc_type.lower()}-{secrets.token_hex(12)}.jpg"


class RiderDocument(TimeStampedModel):
    """The current copy of one KYC document (07 §2.8). One row per (rider, type): a new upload
    replaces the file and goes back to PENDING review; an APPROVED copy cannot be replaced."""

    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name="documents")
    doc_type = models.CharField(max_length=16, choices=DocumentType.choices)
    file = models.FileField(upload_to=kyc_upload_to, max_length=200)
    number_encrypted = models.TextField(
        blank=True,
        editable=False,
        help_text="PAN, DL and RC numbers (encrypted). Aadhaar is never stored in full.",
    )
    doc_number_masked = models.CharField(max_length=24, blank=True)
    status = models.CharField(
        max_length=10, choices=DocumentStatus.choices, default=DocumentStatus.PENDING
    )
    review_note = models.CharField(max_length=300, blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    uploaded_at = models.DateTimeField()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["rider", "doc_type"], name="delivery_riderdocument_one_per_type"
            )
        ]
        ordering = ["rider_id", "id"]

    def __str__(self) -> str:
        return f"{self.get_doc_type_display()} ({self.get_status_display()})"

    def number(self) -> str:
        """The full document number (PAN/DL/RC), decrypted; "" for Aadhaar and images."""
        return decrypt(self.number_encrypted)


# --------------------------------------------------------------------------- slice 5.2


class RiderShift(models.Model):
    """One online period (07 §2.8): going online starts it, going offline (or the auto-offline
    job, or ops) ends it. At most one open shift per rider (partial unique index)."""

    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name="shifts")
    started_at = models.DateTimeField()
    ended_at = models.DateTimeField(null=True, blank=True)
    start_location = gis_models.PointField(srid=4326, spatial_index=False)
    end_reason = models.CharField(max_length=12, choices=ShiftEndReason.choices, blank=True)
    ended_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
        help_text="The staff user for an ADMIN end.",
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["rider"],
                condition=models.Q(ended_at__isnull=True),
                name="delivery_ridershift_one_open",
            ),
            models.CheckConstraint(
                condition=models.Q(ended_at__isnull=True)
                | models.Q(ended_at__gte=models.F("started_at")),
                name="delivery_ridershift_end_after_start",
            ),
        ]
        indexes = [models.Index(fields=["rider", "-started_at"], name="delivery_shift_rider_start")]

    def __str__(self) -> str:
        return f"Shift {self.pk} of rider {self.rider_id}"


class RiderLocation(models.Model):
    """A GPS point sent by the rider app (07 §2.8). 30-day retention (`purge_old_locations`,
    Phase 6). Unique per (rider, recorded_at): a batch sent again after a lost response is
    de-duplicated (api-requests #3). The latest point is also kept on the rider and in Redis."""

    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name="locations")
    point = gis_models.PointField(srid=4326, spatial_index=False)  # history: no spatial queries
    accuracy_m = models.FloatField()
    speed = models.FloatField(null=True, blank=True, help_text="m/s")
    heading = models.FloatField(null=True, blank=True, help_text="degrees")
    recorded_at = models.DateTimeField()
    received_at = models.DateTimeField(auto_now_add=True)
    is_mocked = models.BooleanField(default=False)
    shift = models.ForeignKey(
        RiderShift, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    # `task` (nullable FK to DeliveryTask) arrives with the tasks of slice 5.3.

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["rider", "recorded_at"], name="delivery_riderlocation_rider_time"
            )
        ]

    def __str__(self) -> str:
        return f"Rider {self.rider_id} at {self.recorded_at:%Y-%m-%d %H:%M:%S}"
