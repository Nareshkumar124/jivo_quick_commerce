"""Phase 5 rider API contract (06 §3, 04, api-requests #2-#27).

Explicit (non-model) serializers: the shapes are the contract, independent of storage. Conventions
as everywhere (02 §5): money is a 2-decimal string, times are UTC ISO 8601, dates are IST calendar
dates (`YYYY-MM-DD`), coordinates are JSON numbers in decimal degrees (WGS84).
"""

from datetime import date

from django.conf import settings
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from rest_framework import serializers

from apps.accounts.choices import RiderStatus
from apps.accounts.validators import indian_mobile_validator
from apps.cart.serializers import DeliveryInstructionsSerializer, money_or_null
from apps.catalog.serializers import money
from apps.cms.serializers import RiderLocationSettingsSerializer
from apps.delivery import validators
from apps.delivery.choices import (
    MOTORISED_VEHICLES,
    NUMBERED_DOCUMENTS,
    CashEntryType,
    CodMode,
    CodQrStatus,
    DeliveryFailReason,
    DeliveryTaskStatus,
    DocumentStatus,
    DocumentType,
    EarningType,
    OfferRejectReason,
    PaymentType,
    PayoutStatus,
    ShiftEndedBy,
    ShiftEndReason,
    VehicleType,
)
from apps.orders.choices import OrderStatus
from apps.orders.serializers import OrderAddressSerializer

IST_DATE = "IST calendar date, YYYY-MM-DD."
NOTE_MAX_LENGTH = 300


def latitude(help_text: str = "Latitude (WGS84), decimal degrees.") -> serializers.FloatField:
    return serializers.FloatField(min_value=-90, max_value=90, help_text=help_text)


def longitude(help_text: str = "Longitude (WGS84), decimal degrees.") -> serializers.FloatField:
    return serializers.FloatField(min_value=-180, max_value=180, help_text=help_text)


def _django_validator(func):
    """Wrap a `apps.delivery.validators` normaliser as a DRF field validator."""

    def run(value):
        try:
            return func(value)
        except DjangoValidationError as exc:
            raise serializers.ValidationError(exc.messages) from exc

    return run


# --------------------------------------------------------------------------- shared pieces


class RiderStoreSerializer(serializers.Serializer):
    """A dark store as the rider app lists it (registration dropdown, profile)."""

    id = serializers.IntegerField()
    name = serializers.CharField(help_text='e.g. "Jivo Sector 14".')
    city = serializers.CharField()


class RiderHomeStoreSerializer(RiderStoreSerializer):
    """The home store with its position (go-online radius, navigation; api-requests #40)."""

    lat = latitude("Store entrance latitude.")
    lng = longitude("Store entrance longitude.")


class RiderCashSerializer(serializers.Serializer):
    """Cash in hand (04 §2.7). `limit_reached` is the server's verdict: show the "Deposit cash"
    banner on it, never compare the amounts on the phone."""

    cash_in_hand = money("COD cash collected and not yet deposited.")
    cash_limit = money("The rider's limit (default ₹5,000).")
    limit_reached = serializers.BooleanField(
        help_text="True at or above the limit: only prepaid offers are sent (08 §5)."
    )


class RiderDocumentSerializer(serializers.Serializer):
    """One KYC document as the rider sees it. The file itself is never sent back."""

    doc_type = serializers.ChoiceField(choices=DocumentType.choices)
    status = serializers.ChoiceField(
        choices=DocumentStatus.choices,
        help_text="PENDING (in review), APPROVED (locked), REJECTED (upload a new copy).",
    )
    doc_number_masked = serializers.CharField(
        allow_null=True,
        help_text=(
            'Masked number ("XXXX XXXX 1234" for Aadhaar, "ABXXXXXX4F" for PAN, the last 4 '
            "characters for DL/RC); null for the photo and the Aadhaar back."
        ),
    )
    review_note = serializers.CharField(
        allow_blank=True, help_text='Why ops rejected it ("" otherwise). Show it with REJECTED.'
    )
    uploaded_at = serializers.DateTimeField()
    reviewed_at = serializers.DateTimeField(allow_null=True)


class RiderBankAccountSerializer(serializers.Serializer):
    """Bank details for payouts, masked (09 §3). The full account number is never sent back."""

    holder_name = serializers.CharField()
    account_number_masked = serializers.CharField(help_text='"XXXXXX6789".')
    ifsc = serializers.CharField()
    upi_id = serializers.CharField(allow_null=True)
    updated_at = serializers.DateTimeField()


class RiderTodaySerializer(serializers.Serializer):
    """Home "Today" card (04 §2.3): the IST day so far, computed by the server."""

    date = serializers.DateField(help_text=IST_DATE)
    orders_delivered = serializers.IntegerField()
    earnings = money("Everything earned today (orders, tips, adjustments).")
    cash_in_hand = money("Same as `cash.cash_in_hand`.")
    online_seconds = serializers.IntegerField(
        help_text="Time online today, the current shift included up to now."
    )


class RiderProfileSerializer(serializers.Serializer):
    """`GET /rider/me/`: everything the onboarding, status, home and profile screens need."""

    id = serializers.IntegerField()
    phone = serializers.CharField(help_text="Login phone (E.164).")
    status = serializers.ChoiceField(
        choices=RiderStatus.choices,
        help_text=(
            "PENDING_KYC, ACTIVE, REJECTED or SUSPENDED (never NONE here). Same value as "
            "`rider_status` of `GET /me/`."
        ),
    )
    rejection_reason = serializers.CharField(
        allow_blank=True, help_text='Shown on the status screen when REJECTED ("" otherwise).'
    )
    suspension_reason = serializers.CharField(
        allow_blank=True, help_text='Shown when SUSPENDED ("" otherwise).'
    )
    full_name = serializers.CharField()
    dob = serializers.DateField(help_text="Date of birth.")
    emergency_contact_name = serializers.CharField()
    emergency_contact_phone = serializers.CharField(help_text="E.164.")
    vehicle_type = serializers.ChoiceField(choices=VehicleType.choices)
    vehicle_number = serializers.CharField(
        allow_null=True, help_text='e.g. "HR26DQ1234"; null for a bicycle or e-bike.'
    )
    preferred_store = RiderStoreSerializer(help_text="The store chosen at registration.")
    home_store = RiderHomeStoreSerializer(
        allow_null=True,
        help_text="Set by ops on approval; offers come only from this store. Null before.",
    )
    photo_url = serializers.URLField(
        allow_null=True,
        help_text=(
            "Signed link to the rider's photo (the PHOTO document), valid until "
            "`photo_url_expires_at` (1 hour). Null without a photo. Do not cache past expiry."
        ),
    )
    photo_url_expires_at = serializers.DateTimeField(allow_null=True)
    rating_avg = serializers.CharField(
        allow_null=True,
        help_text='Average customer rating, one decimal ("4.8"); null until rated (Phase 7).',
    )
    documents = RiderDocumentSerializer(many=True, help_text="Uploaded documents, any status.")
    required_documents = serializers.ListField(
        child=serializers.ChoiceField(choices=DocumentType.choices),
        help_text=(
            "Documents this rider needs (D-14 default): PHOTO, AADHAAR_FRONT, AADHAAR_BACK, PAN; "
            "plus DL and RC for MOTORBIKE/SCOOTER. Follows `vehicle_type`."
        ),
    )
    missing_documents = serializers.ListField(
        child=serializers.ChoiceField(choices=DocumentType.choices),
        help_text="Required documents not uploaded yet or REJECTED: the rider must upload these.",
    )
    bank_account = RiderBankAccountSerializer(allow_null=True)
    ready_for_review = serializers.BooleanField(
        help_text=(
            "True when nothing required is missing (documents and bank details): the "
            'application waits for ops. Show "Documents under review".'
        )
    )
    is_online = serializers.BooleanField()
    cash = RiderCashSerializer()
    today = RiderTodaySerializer()
    created_at = serializers.DateTimeField()


class StoreListSerializer(serializers.Serializer):
    results = RiderStoreSerializer(many=True)


# --------------------------------------------------------------------------- registration & KYC


class RiderProfileFieldsSerializer(serializers.Serializer):
    """Shared validation of the editable profile fields (register and PATCH)."""

    full_name = serializers.CharField(max_length=120, help_text="Legal name, as on the documents.")
    dob = serializers.DateField(help_text="Date of birth. The rider must be 18 or older (IST).")
    emergency_contact_name = serializers.CharField(max_length=120)
    emergency_contact_phone = serializers.CharField(
        max_length=15,
        validators=[indian_mobile_validator],
        help_text="Indian mobile number (E.164, +91...), not the rider's own number.",
    )
    preferred_store_id = serializers.IntegerField(help_text="From `GET /rider/stores/`.")
    vehicle_type = serializers.ChoiceField(choices=VehicleType.choices)
    vehicle_number = serializers.CharField(
        max_length=20,
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text=(
            "Required for MOTORBIKE and SCOOTER (e.g. HR26DQ1234; spaces and hyphens are "
            "ignored); must be empty or null for BICYCLE and E_BIKE."
        ),
    )

    def validate_full_name(self, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2:
            raise serializers.ValidationError("Enter your full name.")
        return value

    def validate_emergency_contact_name(self, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise serializers.ValidationError("Enter the contact's name.")
        return value

    def validate_dob(self, value: date) -> date:
        today = timezone.localdate(timezone=_ist())
        years = settings.RIDER_MIN_AGE_YEARS
        try:
            limit = today.replace(year=today.year - years)
        except ValueError:  # 29 February
            limit = today.replace(year=today.year - years, day=28)
        if value > limit:
            raise serializers.ValidationError(f"You must be at least {years} years old.")
        if value.year < today.year - 100:
            raise serializers.ValidationError("Enter a valid date of birth.")
        return value

    def validate_emergency_contact_phone(self, value: str) -> str:
        user = self.context.get("user")
        if user is not None and value == user.phone:
            raise serializers.ValidationError("Use someone else's number, not your own.")
        return value

    def validate_vehicle_number(self, value):
        if not value:
            return ""
        return _django_validator(validators.vehicle_number)(value)

    def _check_vehicle(self, attrs: dict, current=None) -> dict:
        vehicle_type = attrs.get("vehicle_type", getattr(current, "vehicle_type", None))
        if "vehicle_number" in attrs or "vehicle_type" in attrs:
            number = attrs.get("vehicle_number", getattr(current, "vehicle_number", ""))
            if vehicle_type in MOTORISED_VEHICLES and not number:
                raise serializers.ValidationError({"vehicle_number": ["Enter the vehicle number."]})
            if vehicle_type not in MOTORISED_VEHICLES and number:
                if "vehicle_number" in attrs:
                    raise serializers.ValidationError(
                        {"vehicle_number": ["Only motorbikes and scooters have a number here."]}
                    )
                attrs["vehicle_number"] = ""
        return attrs


def _ist():
    from zoneinfo import ZoneInfo

    return ZoneInfo(settings.STORE_TIME_ZONE)


class RiderRegisterSerializer(RiderProfileFieldsSerializer):
    def validate(self, attrs: dict) -> dict:
        attrs.setdefault("vehicle_number", "")
        return self._check_vehicle(attrs)


class RiderProfileUpdateSerializer(RiderProfileFieldsSerializer):
    """PATCH: every field optional. Which fields may change depends on the status (see the
    operation's description)."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        for field in self.fields.values():
            field.required = False

    def validate(self, attrs: dict) -> dict:
        return self._check_vehicle(attrs, self.context.get("rider"))


class RiderDocumentUploadSerializer(serializers.Serializer):
    """`multipart/form-data`: `doc_type`, `file` and, for numbered documents, `number`."""

    doc_type = serializers.ChoiceField(choices=DocumentType.choices)
    file = serializers.FileField(
        help_text=(
            "JPEG or PNG, at most 1 MB (1,048,576 bytes). Re-encoded on the server as JPEG "
            "without metadata (EXIF, GPS)."
        )
    )
    number = serializers.CharField(
        max_length=32,
        required=False,
        allow_blank=True,
        help_text=(
            "Required for AADHAAR_FRONT (12 digits, Verhoeff check), PAN (ABCDE1234F), DL and "
            "RC (the vehicle number); must be absent for PHOTO and AADHAAR_BACK. Spaces and "
            "hyphens are ignored. Only the masked number is ever returned; Aadhaar is never "
            "stored in full."
        ),
    )

    NUMBER_RULES = {
        DocumentType.AADHAAR_FRONT: validators.aadhaar_number,
        DocumentType.PAN: validators.pan_number,
        DocumentType.DL: validators.driving_licence_number,
        DocumentType.RC: validators.vehicle_number,
    }

    def validate_file(self, value):
        if value.size > settings.RIDER_DOCUMENT_MAX_BYTES:
            raise serializers.ValidationError("The image must be 1 MB or smaller.")
        return value

    def validate(self, attrs: dict) -> dict:
        doc_type = attrs["doc_type"]
        number = (attrs.get("number") or "").strip()
        if doc_type in NUMBERED_DOCUMENTS:
            if not number:
                raise serializers.ValidationError({"number": ["Enter the document number."]})
            try:
                attrs["number"] = self.NUMBER_RULES[doc_type](number)
            except DjangoValidationError as exc:
                raise serializers.ValidationError({"number": exc.messages}) from exc
        elif number:
            raise serializers.ValidationError({"number": ["This document has no number."]})
        else:
            attrs["number"] = ""
        return attrs


class RiderBankAccountUpdateSerializer(serializers.Serializer):
    holder_name = serializers.CharField(max_length=120, help_text="As on the bank account.")
    account_number = serializers.CharField(
        max_length=24, help_text="9 to 18 digits. Stored encrypted; only the last 4 are shown."
    )
    ifsc = serializers.CharField(max_length=16, help_text="e.g. HDFC0001234.")
    upi_id = serializers.CharField(
        max_length=256,
        required=False,
        allow_null=True,
        allow_blank=True,
        help_text='Optional, e.g. name@okhdfcbank. Send null or "" to remove.',
    )

    def validate_holder_name(self, value: str) -> str:
        value = " ".join(value.split())
        if len(value) < 2:
            raise serializers.ValidationError("Enter the account holder's name.")
        return value

    def validate_account_number(self, value: str) -> str:
        return _django_validator(validators.bank_account_number)(value)

    def validate_ifsc(self, value: str) -> str:
        return _django_validator(validators.ifsc_code)(value)

    def validate_upi_id(self, value):
        if not value:
            return ""
        return _django_validator(validators.upi_id)(value)


# --------------------------------------------------------------------------- shift & location


class ShiftStartSerializer(serializers.Serializer):
    lat = latitude("Current position (precise location).")
    lng = longitude()
    accuracy = serializers.FloatField(
        min_value=0, required=False, help_text="Reported accuracy in metres (optional)."
    )


class RiderShiftSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    started_at = serializers.DateTimeField()
    ended_at = serializers.DateTimeField(allow_null=True)
    end_reason = serializers.ChoiceField(
        choices=ShiftEndReason.choices,
        allow_null=True,
        help_text="MANUAL, AUTO_OFFLINE (no location for 10 min) or ADMIN; null while open.",
    )
    ended_by = serializers.ChoiceField(
        choices=ShiftEndedBy.choices,
        allow_null=True,
        help_text="rider, system or ops; null while open.",
    )


class ShiftStateSerializer(serializers.Serializer):
    """The rider's shift after `shift/start` or `shift/end`."""

    is_online = serializers.BooleanField()
    shift = RiderShiftSerializer(
        allow_null=True, help_text="The current shift (online), or the one just ended."
    )
    prepaid_only = serializers.BooleanField(
        help_text=(
            "True when cash in hand is at or above the limit: online, but only prepaid offers "
            'come (04 §2.3). Show the "Deposit cash" banner.'
        )
    )
    cash = RiderCashSerializer()
    location = RiderLocationSettingsSerializer()
    server_time = serializers.DateTimeField(help_text="Server clock, for skew correction.")


class LocationPointSerializer(serializers.Serializer):
    lat = latitude()
    lng = longitude()
    accuracy = serializers.FloatField(min_value=0, help_text="Horizontal accuracy, metres.")
    speed = serializers.FloatField(
        min_value=0, required=False, allow_null=True, help_text="Metres per second."
    )
    heading = serializers.FloatField(
        min_value=0,
        max_value=360,
        required=False,
        allow_null=True,
        help_text="Degrees from north, 0-360.",
    )
    recorded_at = serializers.DateTimeField(
        help_text="When the fix was taken (UTC). The de-duplication key with the rider."
    )
    is_mocked = serializers.BooleanField(
        required=False,
        default=False,
        help_text="True when Android reports a mock location (fraud signal, api-requests #5).",
    )


class LocationBatchSerializer(serializers.Serializer):
    points = LocationPointSerializer(
        many=True,
        min_length=1,
        help_text=(
            "1 to `max_batch` points (default 50), any order. Send a batch again unchanged if "
            "its response was lost: points already stored are skipped."
        ),
    )

    def validate_points(self, value: list) -> list:
        limit = self.context.get("max_batch") or 50
        if len(value) > limit:
            raise serializers.ValidationError(f"Send at most {limit} points per request.")
        return value


class LocationBatchResultSerializer(serializers.Serializer):
    accepted = serializers.IntegerField(help_text="Points stored now.")
    duplicates = serializers.IntegerField(help_text="Points already stored (a resent batch).")
    rejected = serializers.IntegerField(
        help_text=(
            "Points not stored: recorded more than 24 hours ago, or more than 2 minutes in the "
            "future. Do not resend them."
        )
    )
    location = RiderLocationSettingsSerializer()
    server_time = serializers.DateTimeField()


class HeartbeatSerializer(serializers.Serializer):
    """`POST /rider/heartbeat/`: "the app is alive" plus a status check (no body needed)."""

    is_online = serializers.BooleanField(
        help_text="False after an auto-offline or ops action: stop the location service."
    )
    pending_offer_id = serializers.IntegerField(
        allow_null=True, help_text="A PENDING offer for this rider: open `offers/current/`."
    )
    active_task_id = serializers.IntegerField(allow_null=True)
    shift = RiderShiftSerializer(
        allow_null=True,
        help_text=(
            "The open shift, or the last one: when `is_online` turned false, `ended_at` and "
            '`ended_by` say when and why ("set offline at 14:05, no location").'
        ),
    )
    location = RiderLocationSettingsSerializer()
    server_time = serializers.DateTimeField()


# --------------------------------------------------------------------------- offers


class RiderOfferSerializer(serializers.Serializer):
    """An order offered to the rider (04 §2.4). The full address and phone appear only in the
    task, after accepting."""

    id = serializers.IntegerField()
    task_id = serializers.IntegerField()
    store_name = serializers.CharField()
    drop_locality = serializers.CharField(help_text='Area only, e.g. "Sector 21, Gurugram".')
    distance_km = serializers.DecimalField(
        max_digits=6, decimal_places=2, help_text='Store to drop (road estimate), e.g. "2.40".'
    )
    payment_type = serializers.ChoiceField(choices=PaymentType.choices)
    cod_amount = money_or_null("Cash to collect for COD; null for prepaid.")
    estimated_payout = money("What the rider earns for this order (before tips).")
    item_count = serializers.IntegerField()
    offered_at = serializers.DateTimeField()
    expires_at = serializers.DateTimeField(
        help_text="Accept before this (offered_at + 30 s). Correct with `server_time`."
    )


class CurrentOfferSerializer(serializers.Serializer):
    offer = RiderOfferSerializer(allow_null=True, help_text="The pending offer, or null.")
    server_time = serializers.DateTimeField(help_text="Server clock, for the countdown.")


class OfferRejectSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(
        choices=OfferRejectReason.choices, required=False, allow_null=True
    )


# --------------------------------------------------------------------------- the task


class TaskStoreSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    name = serializers.CharField()
    address = serializers.CharField()
    phone = serializers.CharField(allow_blank=True)
    lat = latitude()
    lng = longitude()


class TaskItemSerializer(serializers.Serializer):
    name = serializers.CharField(help_text="Product name.")
    variant = serializers.CharField(help_text='e.g. "1 L".')
    quantity = serializers.IntegerField(help_text="Units in the bag (after any unavailable).")


class TaskGeofenceSerializer(serializers.Serializer):
    store_radius_m = serializers.IntegerField(help_text="`arrived-store` allowed within this.")
    customer_radius_m = serializers.IntegerField(
        help_text="`arrived-customer` allowed within this (or with `override_reason`)."
    )


class DeliveryOtpStateSerializer(serializers.Serializer):
    length = serializers.IntegerField(help_text="Digits of the customer's delivery OTP (4).")
    attempts_remaining = serializers.IntegerField(help_text="Of 5.")
    locked = serializers.BooleanField(
        help_text="True after 5 wrong OTPs: ops are alerted; call support."
    )


class CodQrSerializer(serializers.Serializer):
    """A UPI QR for the COD amount (Razorpay QR). The server confirms payment; poll
    `tasks/current/` (or this endpoint) until `status` is PAID."""

    qr_id = serializers.CharField()
    image_url = serializers.URLField(help_text="https PNG of the QR code.")
    amount = money("Exactly the amount due.")
    status = serializers.ChoiceField(choices=CodQrStatus.choices)
    expires_at = serializers.DateTimeField()


class EarningLineSerializer(serializers.Serializer):
    type = serializers.ChoiceField(choices=EarningType.choices)
    amount = money('Signed: a PENALTY is negative ("-20.00").')
    note = serializers.CharField(allow_blank=True)


class TaskEarningsSerializer(serializers.Serializer):
    total = money("Sum of the lines.")
    lines = EarningLineSerializer(many=True)


class RiderTaskSerializer(serializers.Serializer):
    """The rider's delivery task with everything the task screens need (api-requests #13)."""

    id = serializers.IntegerField()
    status = serializers.ChoiceField(choices=DeliveryTaskStatus.choices)
    order_id = serializers.IntegerField()
    order_number = serializers.CharField()
    order_status = serializers.ChoiceField(
        choices=OrderStatus.choices,
        help_text='ACCEPTED/PACKING: show "Packing…"; PACKED: "Ready for pickup".',
    )
    ready_for_pickup = serializers.BooleanField(help_text="True once the order is PACKED.")
    payment_type = serializers.ChoiceField(choices=PaymentType.choices)
    cod_amount_due = money_or_null(
        "COD: exactly what to collect (it can drop if the store removed items); null if prepaid."
    )
    cod_amount_previous = money_or_null(
        "COD: the amount before the last change since the offer (store removed items, 08 "
        'T8a), for "Collect ₹X (was ₹Y)"; null when unchanged or prepaid. The rider also gets '
        "a push when it changes."
    )
    store = TaskStoreSerializer()
    customer_address = OrderAddressSerializer(
        help_text="The drop address (receiver name and phone included), revealed on accept."
    )
    instructions = DeliveryInstructionsSerializer()
    items = TaskItemSerializer(many=True)
    item_count = serializers.IntegerField(help_text="Units in the bag.")
    distance_km = serializers.DecimalField(
        max_digits=6, decimal_places=2, help_text="Store to drop (road estimate)."
    )
    estimated_payout = money("Base + distance pay for this order (tips come on delivery).")
    geofence = TaskGeofenceSerializer()
    delivery_otp = DeliveryOtpStateSerializer()
    cod_qr = CodQrSerializer(allow_null=True, help_text="The UPI QR, once generated.")
    assigned_at = serializers.DateTimeField()
    arrived_store_at = serializers.DateTimeField(allow_null=True)
    picked_up_at = serializers.DateTimeField(allow_null=True)
    arrived_customer_at = serializers.DateTimeField(allow_null=True)
    not_reachable_after = serializers.DateTimeField(
        allow_null=True,
        help_text=(
            "`arrived_customer_at` + 10 minutes: from then on CUSTOMER_NOT_REACHABLE is "
            "accepted. Null before arriving."
        ),
    )
    delivered_at = serializers.DateTimeField(allow_null=True)
    failed_at = serializers.DateTimeField(allow_null=True)
    fail_reason = serializers.ChoiceField(choices=DeliveryFailReason.choices, allow_null=True)
    returned_at = serializers.DateTimeField(allow_null=True)
    earnings = TaskEarningsSerializer(
        allow_null=True, help_text="Set once DELIVERED (base, distance, tip...)."
    )


class RecentTaskSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    order_number = serializers.CharField()
    status = serializers.ChoiceField(
        choices=DeliveryTaskStatus.choices, help_text="DELIVERED, RETURNED or CANCELLED."
    )
    ended_at = serializers.DateTimeField()


class CurrentTaskSerializer(serializers.Serializer):
    task = RiderTaskSerializer(
        allow_null=True,
        help_text=(
            "The active task (ASSIGNED, AT_STORE, PICKED_UP, AT_CUSTOMER, RETURNING), or null."
        ),
    )
    recent_task = RecentTaskSerializer(
        allow_null=True,
        help_text=(
            "When `task` is null: the rider's last task if it ended in the last 10 minutes "
            "(delivered, returned, or cancelled by the store/customer/ops), so a lost response "
            "can be explained. Null otherwise."
        ),
    )
    server_time = serializers.DateTimeField()


class PositionSerializer(serializers.Serializer):
    lat = latitude()
    lng = longitude()
    accuracy = serializers.FloatField(
        min_value=0,
        required=False,
        allow_null=True,
        help_text="Metres; widens the geofence by at most 50 m.",
    )


class ArrivedCustomerSerializer(PositionSerializer):
    override_reason = serializers.CharField(
        max_length=200,
        required=False,
        allow_blank=True,
        help_text=(
            "Outside the geofence (wrong pin, gated society...): a short reason lets the rider "
            "mark arrival anyway. Logged for ops."
        ),
    )


class PickupSerializer(serializers.Serializer):
    order_code = serializers.CharField(
        max_length=64,
        help_text=(
            "The 4-character order code typed by the rider (ASCII letters and digits), or the "
            "whole bag QR payload `JQC1:<order_number>:<code>` as scanned. Case-insensitive. "
            "Anything else (non-ASCII, wrong shape): 400 `PICKUP_CODE_INVALID`."
        ),
    )

    def validate_order_code(self, value: str) -> str:
        from apps.core.errors import ErrorCode
        from apps.core.exceptions import ApiError
        from apps.delivery.services.tasks import code_format_ok

        if not code_format_ok(value):
            raise ApiError(ErrorCode.PICKUP_CODE_INVALID)
        return value.strip()


class CodCollectionSerializer(serializers.Serializer):
    mode = serializers.ChoiceField(choices=CodMode.choices)
    amount = serializers.DecimalField(
        max_digits=12, decimal_places=2, help_text="Must equal `cod_amount_due` exactly."
    )


class DeliverSerializer(serializers.Serializer):
    otp = serializers.RegexField(
        r"^[0-9]{4}$", help_text="The 4-digit delivery OTP the customer reads out."
    )
    cod = CodCollectionSerializer(
        required=False,
        allow_null=True,
        help_text="Required for COD orders, absent for prepaid.",
    )


class DeliveryFailSerializer(serializers.Serializer):
    """`multipart/form-data` (the optional photo)."""

    reason = serializers.ChoiceField(choices=DeliveryFailReason.choices)
    note = serializers.CharField(
        max_length=NOTE_MAX_LENGTH,
        required=False,
        allow_blank=True,
        help_text="Required for OTHER.",
    )
    call_attempts = serializers.IntegerField(
        min_value=0,
        required=False,
        help_text="Calls made to the customer. CUSTOMER_NOT_REACHABLE needs at least 2.",
    )
    photo = serializers.ImageField(
        required=False, help_text="Optional JPEG/PNG (e.g. the door), at most 1 MB."
    )

    def validate(self, attrs: dict) -> dict:
        if attrs["reason"] == DeliveryFailReason.OTHER and not attrs.get("note", "").strip():
            raise serializers.ValidationError({"note": ["Describe what happened."]})
        if (
            attrs["reason"] == DeliveryFailReason.CUSTOMER_NOT_REACHABLE
            and attrs.get("call_attempts", 0) < settings.RIDER_NOT_REACHABLE_MIN_CALLS
        ):
            raise serializers.ValidationError(
                {
                    "call_attempts": [
                        f"Call the customer at least {settings.RIDER_NOT_REACHABLE_MIN_CALLS} "
                        "times first."
                    ]
                }
            )
        photo = attrs.get("photo")
        if photo is not None and photo.size > settings.RIDER_DOCUMENT_MAX_BYTES:
            raise serializers.ValidationError({"photo": ["The image must be 1 MB or smaller."]})
        return attrs


# --------------------------------------------------------------------------- records


class BeforeIdQuerySerializer(serializers.Serializer):
    before_id = serializers.IntegerField(
        required=False,
        min_value=1,
        help_text=(
            "Stable paging (api-requests #24): only entries older than this id. Follow `next`, "
            "which carries it; new entries never shift what is already listed."
        ),
    )


class _FromToQuery(serializers.Serializer):
    """Query parameters `from` and `to` (Python keywords: validated as `from_date`/`to_date`)."""

    FROM_HELP = IST_DATE
    TO_HELP = f"{IST_DATE} Inclusive."

    def get_fields(self):
        fields = super().get_fields()
        fields["from"] = serializers.DateField(
            required=False, source="from_date", help_text=self.FROM_HELP
        )
        fields["to"] = serializers.DateField(
            required=False, source="to_date", help_text=self.TO_HELP
        )
        return fields


class DateRangeQuerySerializer(_FromToQuery):
    FROM_HELP = f"{IST_DATE} Default: today."
    TO_HELP = f"{IST_DATE} Inclusive. Default: `from`. At most 366 days after `from`."

    MAX_DAYS = 366

    def validate(self, attrs: dict) -> dict:
        today = timezone.localdate(timezone=_ist())
        start = attrs.get("from_date") or today
        end = attrs.get("to_date") or start
        if end < start:
            raise serializers.ValidationError({"to": ["Must not be before `from`."]})
        if (end - start).days >= self.MAX_DAYS:
            raise serializers.ValidationError({"to": ["Choose at most 366 days."]})
        return {**attrs, "from_date": start, "to_date": end}


class HistoryQuerySerializer(_FromToQuery, BeforeIdQuerySerializer):
    FROM_HELP = f"{IST_DATE} Optional: tasks ended on or after this day."
    TO_HELP = f"{IST_DATE} Optional: tasks ended on or before this day."

    def validate(self, attrs: dict) -> dict:
        start, end = attrs.get("from_date"), attrs.get("to_date")
        if start and end and end < start:
            raise serializers.ValidationError({"to": ["Must not be before `from`."]})
        return attrs


class TaskHistoryItemSerializer(serializers.Serializer):
    task_id = serializers.IntegerField()
    order_number = serializers.CharField()
    status = serializers.ChoiceField(
        choices=DeliveryTaskStatus.choices, help_text="DELIVERED, RETURNED or CANCELLED."
    )
    store_name = serializers.CharField()
    drop_locality = serializers.CharField()
    distance_km = serializers.DecimalField(
        max_digits=6,
        decimal_places=2,
        allow_null=True,
        help_text="Null for a task cancelled before pickup.",
    )
    payout = money_or_null("Earned for this task (all lines); null if nothing was earned.")
    completed_at = serializers.DateTimeField(help_text="When it ended.")


class BeforeIdPageSerializer(serializers.Serializer):
    count = serializers.IntegerField(help_text="All entries, whatever `before_id`.")
    next = serializers.URLField(allow_null=True, help_text="Older entries (carries `before_id`).")
    previous = serializers.URLField(allow_null=True, help_text="Always null.")


class PaginatedTaskHistorySerializer(BeforeIdPageSerializer):
    results = TaskHistoryItemSerializer(many=True)


class EarningsOrderSerializer(serializers.Serializer):
    task_id = serializers.IntegerField()
    order_number = serializers.CharField()
    completed_at = serializers.DateTimeField()
    total = money("Sum of `lines`.")
    lines = EarningLineSerializer(many=True)


class EarningsAdjustmentSerializer(serializers.Serializer):
    type = serializers.ChoiceField(
        choices=EarningType.choices, help_text="INCENTIVE or PENALTY (not tied to an order)."
    )
    amount = money("Signed.")
    note = serializers.CharField(allow_blank=True)
    recorded_at = serializers.DateTimeField()


class EarningTotalsSerializer(serializers.Serializer):
    BASE = money("Base pay.")
    DISTANCE = money("Distance pay.")
    TIP = money("Tips.")
    INCENTIVE = money("Incentives.")
    PENALTY = money("Penalties (zero or negative).")


class EarningsSerializer(serializers.Serializer):
    """Every total is computed by the server; the app shows them as sent."""

    from_date = serializers.DateField()
    to_date = serializers.DateField()
    total = money("All earnings in the range.")
    orders_count = serializers.IntegerField(help_text="Delivered orders in the range.")
    totals_by_type = EarningTotalsSerializer()
    orders = EarningsOrderSerializer(
        many=True, help_text="Newest first, at most 200 (see `orders_truncated`)."
    )
    orders_truncated = serializers.BooleanField(
        help_text="True when the range has more than 200 orders: the totals still cover all."
    )
    adjustments = EarningsAdjustmentSerializer(many=True)

    def get_fields(self):
        fields = super().get_fields()
        # Published as `from` / `to` (Python keywords).
        fields.pop("from_date")
        fields.pop("to_date")
        return {
            "from": serializers.DateField(help_text=IST_DATE),
            "to": serializers.DateField(help_text=f"{IST_DATE} Inclusive."),
            **fields,
        }


class CashLedgerEntrySerializer(serializers.Serializer):
    id = serializers.IntegerField()
    entry_type = serializers.ChoiceField(choices=CashEntryType.choices)
    amount = money('Signed: + collected, - deposited ("-1500.00").')
    balance_after = money("Cash in hand after this entry.")
    order_number = serializers.CharField(allow_null=True)
    note = serializers.CharField(allow_blank=True)
    recorded_at = serializers.DateTimeField()


class PaginatedCashLedgerSerializer(BeforeIdPageSerializer):
    results = CashLedgerEntrySerializer(many=True)


class PayoutSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    period_start = serializers.DateField(help_text=IST_DATE)
    period_end = serializers.DateField(help_text=f"{IST_DATE} Inclusive.")
    amount = money("Paid or to be paid.")
    status = serializers.ChoiceField(choices=PayoutStatus.choices)
    reference = serializers.CharField(allow_null=True, help_text="Bank transfer reference (UTR).")
    paid_at = serializers.DateTimeField(allow_null=True, help_text="UTC instant; null if PENDING.")


class PaginatedPayoutListSerializer(serializers.Serializer):
    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = PayoutSerializer(many=True)
