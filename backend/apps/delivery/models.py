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
from apps.core.crypto import DecryptionError, decrypt
from apps.core.models import TimeStampedModel
from apps.delivery.choices import (
    RIDER_PROFILE_STATUSES,
    CashEntryType,
    CodQrStatus,
    DeliveryFailReason,
    DeliveryTaskStatus,
    DocumentStatus,
    DocumentType,
    EarningType,
    OfferRejectReason,
    OfferStatus,
    PayoutStatus,
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
    dob = models.DateField("date of birth", null=True, help_text="Null once anonymised.")
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
    last_location_at = models.DateTimeField(
        null=True, blank=True, help_text="When the newest point was recorded (device clock)."
    )
    last_location_received_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="Server time a location point last arrived: presence and auto-offline use it.",
    )
    last_heartbeat_at = models.DateTimeField(null=True, blank=True)
    # Cash (slice 5.4): `cash_in_hand` is the running balance of RiderCashLedger.
    cash_in_hand = models.DecimalField(**MONEY, default=Decimal("0.00"))
    cash_limit = models.DecimalField(
        **MONEY,
        default=default_cash_limit,
        validators=[MinValueValidator(Decimal("0.00"))],
        help_text="At or above it the rider gets prepaid offers only (04 §2.7). Default ₹5,000.",
    )
    cash_skipped_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text=(
            "DL-61 (b): when dispatch last left this rider out of a COD offer because cash in "
            "hand + the order amount was over the limit. Cleared by a deposit. Drives the "
            '"deposit cash" banner.'
        ),
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
    kyc_purge_after = models.DateField(
        null=True,
        blank=True,
        help_text=(
            "D-14 default: KYC documents are deleted on this date (1 year after offboarding or "
            "account erasure) by `purge_offboarded_kyc`."
        ),
    )
    anonymised_at = models.DateTimeField(null=True, blank=True)
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
            "last_location_received_at",
            "last_heartbeat_at",
            "cash_skipped_at",
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
                condition=models.Q(cash_in_hand__gte=0), name="delivery_rider_cash_in_hand_gte_0"
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
        """The full account number (decrypted). Only for payouts; never shown in lists.
        Raises `ValidationError` (readable) when it cannot be decrypted."""
        return _decrypt_or_error(self.bank_account_number_encrypted, "bank account number")

    @property
    def cash_limit_reached(self) -> bool:
        return self.cash_in_hand >= self.cash_limit


def _decrypt_or_error(token: str, what: str) -> str:
    from django.core.exceptions import ValidationError

    try:
        return decrypt(token)
    except DecryptionError:
        raise ValidationError(
            f"The stored {what} cannot be decrypted (encryption key missing or rotated). "
            "Ask the rider to enter it again."
        ) from None


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
        """The full document number (PAN/DL/RC), decrypted; "" for Aadhaar and images.
        Raises `ValidationError` (readable) when it cannot be decrypted."""
        return _decrypt_or_error(self.number_encrypted, "document number")


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
    task = models.ForeignKey(
        "DeliveryTask", on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["rider", "recorded_at"], name="delivery_riderlocation_rider_time"
            )
        ]

    def __str__(self) -> str:
        return f"Rider {self.rider_id} at {self.recorded_at:%Y-%m-%d %H:%M:%S}"


# --------------------------------------------------------------------------- slice 5.3

RIDER_BUSY_STATUSES = ["ASSIGNED", "AT_STORE", "PICKED_UP", "AT_CUSTOMER", "FAILED", "RETURNING"]


class AssignmentMode(models.TextChoices):
    AUTO = "AUTO", "Offer accepted"
    MANUAL = "MANUAL", "Assigned by ops"


class DeliveryTask(TimeStampedModel):
    """The delivery of one order (07 §2.8, 08 §3). Created when dispatch starts; states change
    only through `apps.delivery.services` (dispatch, tasks). Lock order on every path: the
    Order row, then this row, then offers, then the rider."""

    order = models.OneToOneField(
        "orders.Order", on_delete=models.PROTECT, related_name="delivery_task"
    )
    store = models.ForeignKey("stores.DarkStore", on_delete=models.PROTECT, related_name="+")
    rider = models.ForeignKey(
        Rider, on_delete=models.PROTECT, null=True, blank=True, related_name="tasks"
    )
    status = models.CharField(max_length=12, choices=DeliveryTaskStatus.choices)
    assignment_mode = models.CharField(max_length=6, choices=AssignmentMode.choices, blank=True)
    attempt_count = models.PositiveSmallIntegerField(
        default=0, help_text="Offers made in the current search round (08 §5 step 6)."
    )
    search_started_at = models.DateTimeField(help_text="Start of the current search round.")
    unassigned_at = models.DateTimeField(null=True, blank=True)
    next_dispatch_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text="When dispatch runs next (retry, or resume after UNASSIGNED).",
    )
    distance_km = models.DecimalField(max_digits=6, decimal_places=2)
    payout_amount = models.DecimalField(**MONEY, help_text="Estimated base + distance pay.")
    cod_amount_previous = models.DecimalField(
        **MONEY, null=True, blank=True, help_text="COD due before the last change (08 T8a)."
    )
    assigned_at = models.DateTimeField(null=True, blank=True)
    arrived_store_at = models.DateTimeField(null=True, blank=True)
    picked_up_at = models.DateTimeField(null=True, blank=True)
    arrived_customer_at = models.DateTimeField(null=True, blank=True)
    arrival_override_reason = models.CharField(max_length=200, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    failed_at = models.DateTimeField(null=True, blank=True)
    fail_reason = models.CharField(max_length=24, choices=DeliveryFailReason.choices, blank=True)
    fail_note = models.CharField(max_length=300, blank=True)
    fail_call_attempts = models.PositiveSmallIntegerField(null=True, blank=True)
    fail_photo = models.FileField(upload_to="delivery-failures/", blank=True, max_length=200)
    returned_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True, help_text="When the task ended.")
    # Delivery OTP (04 §2.6): generated at T9, shown only to the order's owner while out for
    # delivery; encrypted (not hashed) because the customer app shows it.
    delivery_otp_encrypted = models.TextField(blank=True, editable=False)
    otp_attempts = models.PositiveSmallIntegerField(default=0)
    otp_locked_at = models.DateTimeField(null=True, blank=True)
    # Wrong order codes at pickup; locked after PICKUP_CODE_MAX_ATTEMPTS (ops alerted).
    pickup_attempts = models.PositiveSmallIntegerField(default=0)
    pickup_locked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["rider"],
                condition=models.Q(status__in=RIDER_BUSY_STATUSES),
                name="delivery_task_one_active_per_rider",
            ),
            models.CheckConstraint(
                condition=models.Q(rider__isnull=False)
                | models.Q(status__in=["SEARCHING", "OFFERED", "UNASSIGNED", "CANCELLED"]),
                name="delivery_task_rider_when_assigned",
            ),
        ]
        indexes = [
            models.Index(fields=["status", "store"], name="delivery_task_status_store"),
            models.Index(fields=["rider", "-ended_at"], name="delivery_task_rider_ended"),
        ]
        permissions = [
            ("dispatch_order", "Can assign, unassign and re-dispatch riders (manual dispatch)"),
            ("lift_cod_block", "Can lift a customer's automatic COD block (DL-61)"),
        ]

    def __str__(self) -> str:
        return f"Task {self.pk} ({self.status}) for order {self.order_id}"


class DeliveryOffer(models.Model):
    """One offer of a task to a rider (07 §2.8, 08 §5). At most one PENDING per task and per
    rider (partial unique indexes)."""

    task = models.ForeignKey(DeliveryTask, on_delete=models.CASCADE, related_name="offers")
    rider = models.ForeignKey(Rider, on_delete=models.CASCADE, related_name="offers")
    status = models.CharField(max_length=10, choices=OfferStatus.choices)
    offered_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    responded_at = models.DateTimeField(null=True, blank=True)
    reject_reason = models.CharField(max_length=16, choices=OfferRejectReason.choices, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["task"],
                condition=models.Q(status="PENDING"),
                name="delivery_offer_one_pending_per_task",
            ),
            models.UniqueConstraint(
                fields=["rider"],
                condition=models.Q(status="PENDING"),
                name="delivery_offer_one_pending_per_rider",
            ),
        ]
        indexes = [models.Index(fields=["status", "expires_at"], name="delivery_offer_due")]

    def __str__(self) -> str:
        return f"Offer {self.pk} ({self.status})"


class RiderCashLedgerQuerySet(models.QuerySet):
    def update(self, **kwargs):
        raise ValueError("The cash ledger is append-only.")

    def delete(self):
        raise ValueError("The cash ledger is append-only.")


class RiderCashLedger(models.Model):
    """Cash in hand (07 §2.8, 04 §2.7): append-only; `Rider.cash_in_hand` is its running
    balance, changed only together with a new entry under the rider row lock."""

    rider = models.ForeignKey(Rider, on_delete=models.PROTECT, related_name="cash_entries")
    entry_type = models.CharField(max_length=14, choices=CashEntryType.choices)
    amount = models.DecimalField(**MONEY, help_text="Signed: + collected, - deposited.")
    balance_after = models.DecimalField(**MONEY)
    order = models.ForeignKey(
        "orders.Order", on_delete=models.PROTECT, null=True, blank=True, related_name="+"
    )
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    note = models.CharField(max_length=200, blank=True)
    recorded_at = models.DateTimeField(auto_now_add=True)
    # Slice 5.4: the store the cash was collected for (COD_COLLECTED: the order's store) or handed
    # in at (DEPOSIT), for the store's day-end report (05 §1.5); and the deposit form's key, so a
    # double-submitted deposit is recorded once.
    store = models.ForeignKey(
        "stores.DarkStore", on_delete=models.PROTECT, null=True, blank=True, related_name="+"
    )
    idempotency_key = models.CharField(max_length=64, blank=True)

    objects = RiderCashLedgerQuerySet.as_manager()

    class Meta:
        indexes = [
            models.Index(
                fields=["store", "entry_type", "recorded_at"], name="delivery_cash_store_day"
            )
        ]
        permissions = [
            ("record_cash_deposit", "Can record a rider's cash deposit at a store"),
            ("adjust_cash", "Can correct a rider's cash in hand (adjustment)"),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["rider", "idempotency_key"],
                condition=~models.Q(idempotency_key=""),
                name="delivery_cashledger_idempotency_key",
            ),
            models.CheckConstraint(
                condition=~models.Q(amount=0), name="delivery_cashledger_amount_not_zero"
            ),
            models.UniqueConstraint(
                fields=["order"],
                condition=models.Q(entry_type="COD_COLLECTED"),
                name="delivery_cashledger_one_cod_per_order",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.entry_type} {self.amount} (rider {self.rider_id})"


class CodQr(models.Model):
    """A UPI QR for a COD order's amount due (06 §3 `cod-qr`, api-requests #16; Razorpay QR
    Codes: single use, fixed amount). The server confirms payment (webhook `qr_code.credited`,
    or a gateway lookup); the amount always comes from the order, never from the client."""

    task = models.ForeignKey(DeliveryTask, on_delete=models.PROTECT, related_name="cod_qrs")
    order = models.ForeignKey("orders.Order", on_delete=models.PROTECT, related_name="+")
    gateway_qr_id = models.CharField(max_length=64, unique=True)
    image_url = models.URLField(max_length=500)
    amount = models.DecimalField(**MONEY)
    status = models.CharField(max_length=10, choices=CodQrStatus.choices)
    expires_at = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    payment = models.OneToOneField(
        "payments.Payment", on_delete=models.PROTECT, null=True, blank=True, related_name="cod_qr"
    )

    class Meta:
        verbose_name = "COD UPI QR"
        constraints = [
            models.UniqueConstraint(
                fields=["task"],
                condition=models.Q(status__in=["PENDING", "PAID"]),
                name="delivery_codqr_one_open_per_task",
            ),
            models.CheckConstraint(
                condition=models.Q(amount__gt=0), name="delivery_codqr_amount_gt_0"
            ),
        ]

    def __str__(self) -> str:
        return f"QR {self.gateway_qr_id} ({self.status})"


class EarningRule(models.Model):
    """Rider pay (07 §2.8, D-16 default ⚠): `base_per_order` per delivered order plus
    `per_km_rate` for each km of the store-to-drop route distance beyond `per_km_after`. The rule
    in force at a time is the newest with `effective_from` <= that time; with none, the settings
    `RIDER_PAY_BASE_PER_ORDER` / `RIDER_PAY_PER_KM` apply. A rule is not edited once it is in
    force: add a new one."""

    base_per_order = models.DecimalField(**MONEY, validators=[MinValueValidator(Decimal("0.00"))])
    per_km_rate = models.DecimalField(**MONEY, validators=[MinValueValidator(Decimal("0.00"))])
    per_km_after = models.DecimalField(
        max_digits=6,
        decimal_places=2,
        default=Decimal("0.00"),
        validators=[MinValueValidator(Decimal("0.00"))],
        help_text="Km included in the base pay (distance pay starts after them).",
    )
    effective_from = models.DateTimeField(unique=True)
    note = models.CharField(max_length=200, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-effective_from"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(base_per_order__gte=0)
                & models.Q(per_km_rate__gte=0)
                & models.Q(per_km_after__gte=0),
                name="delivery_earningrule_not_negative",
            )
        ]

    def __str__(self) -> str:
        return f"{self.base_per_order} + {self.per_km_rate}/km from {self.effective_from:%Y-%m-%d}"


class Payout(models.Model):
    """A payout to a rider for a period (D-16: weekly bank transfers made offline by Finance and
    recorded here). Its earning lines point at it; `amount` is their sum."""

    rider = models.ForeignKey(Rider, on_delete=models.PROTECT, related_name="payouts")
    period_start = models.DateField(help_text="IST date.")
    period_end = models.DateField(help_text="IST date, inclusive.")
    amount = models.DecimalField(**MONEY)
    status = models.CharField(
        max_length=8, choices=PayoutStatus.choices, default=PayoutStatus.PENDING
    )
    reference = models.CharField(max_length=64, blank=True, help_text="Bank transfer UTR.")
    paid_at = models.DateTimeField(null=True, blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    paid_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(amount__gt=0), name="delivery_payout_amount_gt_0"
            ),
            models.CheckConstraint(
                condition=models.Q(period_end__gte=models.F("period_start")),
                name="delivery_payout_period_order",
            ),
            models.CheckConstraint(
                condition=models.Q(status="PENDING")
                | (models.Q(paid_at__isnull=False) & ~models.Q(reference="")),
                name="delivery_payout_paid_has_reference",
            ),
        ]
        indexes = [models.Index(fields=["rider", "-period_end"], name="delivery_payout_rider")]
        permissions = [
            ("manage_payouts", "Can create payouts, mark them paid and add incentives/penalties"),
        ]

    def __str__(self) -> str:
        return f"Payout {self.pk} to rider {self.rider_id}: {self.amount} ({self.status})"


class RiderEarning(models.Model):
    """One earning line (07 §2.8). A delivered task gets BASE, DISTANCE and TIP (at most one of
    each per task, so recording them twice is a no-op); INCENTIVE and PENALTY are staff
    adjustments (a penalty is negative). `earned_at` (the delivery time) is what date ranges and
    payout periods use. A paid line points at its payout."""

    rider = models.ForeignKey(Rider, on_delete=models.PROTECT, related_name="earnings")
    task = models.ForeignKey(
        DeliveryTask, on_delete=models.PROTECT, null=True, blank=True, related_name="earnings"
    )
    type = models.CharField(max_length=10, choices=EarningType.choices)
    amount = models.DecimalField(**MONEY)
    note = models.CharField(max_length=200, blank=True)
    earned_at = models.DateTimeField()
    payout = models.ForeignKey(
        Payout, on_delete=models.PROTECT, null=True, blank=True, related_name="earnings"
    )
    recorded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["task", "type"],
                condition=models.Q(task__isnull=False),
                name="delivery_earning_one_type_per_task",
            ),
            models.CheckConstraint(
                condition=models.Q(type="PENALTY", amount__lt=0)
                | (~models.Q(type="PENALTY") & models.Q(amount__gt=0)),
                name="delivery_earning_sign",
            ),
        ]
        indexes = [
            models.Index(fields=["rider", "earned_at"], name="delivery_earning_rider_time"),
            models.Index(fields=["rider", "payout"], name="delivery_earning_unpaid"),
        ]

    def __str__(self) -> str:
        return f"{self.type} {self.amount} (rider {self.rider_id})"
