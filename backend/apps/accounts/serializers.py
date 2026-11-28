"""Phase 1 API contract: auth, account, devices and addresses (06 §2.1, §2.2).

Explicit (non-model) serializers: the request/response shapes are the contract, independent of
storage (e.g. Address `lat`/`lng` vs a PostGIS Point from Phase 2).
"""

from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers
from rest_framework.fields import empty

from apps.accounts.choices import (
    AddressLabel,
    AppName,
    LoginMethod,
    Platform,
    RequestableOtpPurpose,
    RiderStatus,
)
from apps.accounts.models import BusinessCategory
from apps.accounts.validators import (
    indian_mobile_validator,
    otp_code_validator,
    pincode_validator,
)
from apps.core.middleware import APP_VERSION_PATTERN


@extend_schema_field(OpenApiTypes.EMAIL)
class OptionalEmailField(serializers.Field):
    """A nullable email where an empty string also means "none".

    Published as one nullable `string` with `format: email` (no `oneOf`/`minLength`, which the
    Dart generator cannot handle); "" is still accepted on input and stored as null.
    """

    default_error_messages = {"invalid": "Enter a valid email address."}

    def __init__(self, **kwargs):
        kwargs.setdefault("allow_null", True)
        super().__init__(**kwargs)

    def run_validation(self, data=empty):
        if isinstance(data, str) and not data.strip():
            data = None
        return super().run_validation(data)

    def to_internal_value(self, data) -> str:
        if not isinstance(data, str) or len(data.strip()) > 254:
            self.fail("invalid")
        value = data.strip()
        try:
            validate_email(value)
        except DjangoValidationError:
            self.fail("invalid")
        return value

    def to_representation(self, value):
        return value


# --------------------------------------------------------------------------- auth


class OtpSendSerializer(serializers.Serializer):
    phone = serializers.CharField(
        validators=[indian_mobile_validator], help_text="E.164 Indian mobile, e.g. +919876543210."
    )
    app = serializers.ChoiceField(
        choices=AppName.choices, help_text="The app asking. Same value as `X-App-Name`."
    )
    purpose = serializers.ChoiceField(
        choices=RequestableOtpPurpose.choices,
        default=RequestableOtpPurpose.LOGIN,
        help_text=(
            "`login` (default): for `/auth/otp/verify/`. `delete_account`: for `/me/delete/` "
            "only; it can never log anyone in."
        ),
    )


class OtpSentSerializer(serializers.Serializer):
    otp_length = serializers.IntegerField(help_text="Digits in the OTP (6).")
    expires_in_seconds = serializers.IntegerField(help_text="The OTP is valid this long (300).")
    resend_after_seconds = serializers.IntegerField(
        help_text="Enable the Resend button after this many seconds (30)."
    )


class OtpVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(validators=[indian_mobile_validator])
    otp = serializers.CharField(validators=[otp_code_validator], help_text="6 digits.")
    app = serializers.ChoiceField(
        choices=AppName.choices,
        help_text="Must match the `app` the OTP was requested for. Authoritative over X-App-Name.",
    )
    terms_version = serializers.CharField(
        max_length=32,
        help_text=(
            "The Terms & Privacy version the user accepted on the login screen: send "
            "`terms_version` from `/config/app/` (DPDP consent record)."
        ),
    )


class LoginEmailField(serializers.EmailField):
    """A required email, trimmed and stored lowercase (unique case-insensitively)."""

    def __init__(self, **kwargs):
        kwargs.setdefault("max_length", 254)
        super().__init__(**kwargs)

    def to_internal_value(self, data) -> str:
        return super().to_internal_value(data).strip().lower()


class EmailOtpSendSerializer(serializers.Serializer):
    email = LoginEmailField(help_text="The email to send the code to. Case does not matter.")
    app = serializers.ChoiceField(
        choices=AppName.choices, help_text="The app asking. Same value as `X-App-Name`."
    )
    purpose = serializers.ChoiceField(
        choices=RequestableOtpPurpose.choices,
        default=RequestableOtpPurpose.LOGIN,
        help_text=(
            "`login` (default): for `/auth/email-otp/verify/`. `delete_account`: for "
            "`/me/delete/` by an account without a phone; it can never log anyone in."
        ),
    )


class EmailOtpVerifySerializer(serializers.Serializer):
    email = LoginEmailField()
    otp = serializers.CharField(validators=[otp_code_validator], help_text="6 digits.")
    app = serializers.ChoiceField(
        choices=AppName.choices,
        help_text="Must match the `app` the OTP was requested for. Authoritative over X-App-Name.",
    )
    terms_version = serializers.CharField(
        max_length=32,
        help_text=(
            "The Terms & Privacy version the user accepted on the login screen: send "
            "`terms_version` from `/config/app/` (DPDP consent record)."
        ),
    )


class AppQuerySerializer(serializers.Serializer):
    app = serializers.ChoiceField(choices=AppName.choices)


class LoginMethodsSerializer(serializers.Serializer):
    app = serializers.ChoiceField(choices=AppName.choices, help_text="The app asked about.")
    methods = serializers.ListField(
        child=serializers.ChoiceField(choices=LoginMethod.choices),
        help_text=(
            'The sign-in methods to offer, in display order: `["phone"]`, `["email"]` or '
            '`["phone", "email"]` (show a Phone / Email choice). Never empty.'
        ),
    )


class PhoneOtpSendSerializer(serializers.Serializer):
    phone = serializers.CharField(
        validators=[indian_mobile_validator], help_text="E.164 Indian mobile, e.g. +919876543210."
    )


class PhoneVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(validators=[indian_mobile_validator])
    otp = serializers.CharField(validators=[otp_code_validator], help_text="6 digits.")


class EmailOtpForMeSerializer(serializers.Serializer):
    email = LoginEmailField(help_text="The email to verify. Case does not matter.")


class EmailVerifySerializer(serializers.Serializer):
    email = LoginEmailField()
    otp = serializers.CharField(validators=[otp_code_validator], help_text="6 digits.")


CATEGORY_NOT_IN_LIST = "Choose a business category from the list."


class BusinessCategorySerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    name = serializers.CharField(read_only=True, help_text="Shown in the dropdown.")
    slug = serializers.SlugField(read_only=True, help_text="Stable key, e.g. `restaurant-cafe`.")


class MeSerializer(serializers.Serializer):
    """The signed-in user. PATCH accepts `name`, `email`, `marketing_opt_in`,
    `business_category` and `business_name`."""

    id = serializers.IntegerField(read_only=True)
    phone = serializers.CharField(
        read_only=True,
        allow_null=True,
        help_text=(
            "Login phone. Null for an email sign-up until a phone is added with "
            "`POST /me/phone/verify/`; never changed once set (v1)."
        ),
    )
    name = serializers.CharField(
        max_length=120, help_text="Cannot be blanked once sent. Empty after a skipped profile."
    )
    email = OptionalEmailField(
        required=False,
        help_text="Optional. Send null (or an empty string) to remove it. Must be unique.",
    )
    marketing_opt_in = serializers.BooleanField(
        required=False, help_text="Consent to promotional push notifications."
    )
    has_phone = serializers.BooleanField(
        read_only=True,
        help_text=(
            "False for an account created by email sign-in that has not added a phone yet. "
            "Customers must add one (`POST /me/phone/otp/`, `POST /me/phone/verify/`) before "
            "placing an order: `POST /orders/` answers 422 `PHONE_REQUIRED` until then."
        ),
    )
    email_verified = serializers.BooleanField(
        read_only=True,
        help_text=(
            "True when `email` was proved with an email code, so it works for email sign-in. "
            "Changing `email` with PATCH makes it false again (verify with `POST /me/email/otp/`)."
        ),
    )
    business_category = serializers.PrimaryKeyRelatedField(
        queryset=BusinessCategory.objects.all(),
        required=False,
        allow_null=True,
        error_messages={"does_not_exist": CATEGORY_NOT_IN_LIST},
        help_text=(
            "Optional. An id from `GET /business-categories/` (active only). Null removes it. "
            "Re-sending the user's current category is accepted even if it was deactivated since."
        ),
    )
    business_category_name = serializers.CharField(
        source="business_category.name",
        read_only=True,
        allow_null=True,
        help_text="The chosen category's name, for display. Null when none.",
    )
    business_name = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
        help_text="Optional shop / business name. An empty string removes it.",
    )
    is_profile_complete = serializers.BooleanField(
        read_only=True,
        help_text=(
            "Always true for riders and staff. Otherwise false only for a new user who has "
            "(PATCH `/me/` with `name`, "
            "`business_category` or `business_name`) nor skipped "
            "(`POST /me/profile-prompt/skip/`) the complete-profile screen: show that screen "
            "while it is false. Accounts created before 2026-11-26 are always true."
        ),
    )
    rider_status = serializers.ChoiceField(
        choices=RiderStatus.choices,
        read_only=True,
        help_text="Rider profile status; NONE without a rider profile (`POST /rider/register/`).",
    )
    created_at = serializers.DateTimeField(read_only=True)

    def validate_business_category(self, value):
        """Only switching TO an inactive category is refused: a form that re-sends the user's
        current (since deactivated) category still saves. Needs `request` in the context."""
        if value is None or value.is_active:
            return value
        request = self.context.get("request")
        if request is not None and request.user.business_category_id == value.pk:
            return value
        raise serializers.ValidationError(CATEGORY_NOT_IN_LIST)


class AuthSessionSerializer(serializers.Serializer):
    access = serializers.CharField(help_text="JWT access token, valid 15 minutes.")
    refresh = serializers.CharField(help_text="JWT refresh token, valid 30 days, single use.")
    user = MeSerializer()
    is_new_user = serializers.BooleanField(
        help_text=(
            "True when this verification created the account. Show the complete-profile screen "
            "only while `user.is_profile_complete` is false (03 §2.2)."
        )
    )
    rider_status = serializers.ChoiceField(
        choices=RiderStatus.choices,
        help_text=(
            "Always present (NONE without a rider profile). The rider app routes on it: NONE -> "
            "registration, PENDING_KYC/REJECTED -> status screen, ACTIVE -> home, SUSPENDED -> "
            "blocked. The customer app ignores it."
        ),
    )
    deletion_cancelled = serializers.BooleanField(
        help_text=(
            "True when this login cancelled a pending account deletion (login within the 30-day "
            "grace period restores the account): show a notice. Normally false."
        )
    )


class TokenRefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField(help_text="The current refresh token. It is single use.")


class TokenPairSerializer(serializers.Serializer):
    access = serializers.CharField(help_text="New access token (15 minutes).")
    refresh = serializers.CharField(
        help_text="New refresh token (30 days). Replace the stored one; the old one is revoked."
    )


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField(help_text="The refresh token to revoke.")
    fcm_token = serializers.CharField(
        required=False, max_length=512, help_text="This device's FCM token, to stop its pushes."
    )


class AccountDeleteSerializer(serializers.Serializer):
    otp = serializers.CharField(
        validators=[otp_code_validator],
        help_text=(
            "OTP from `POST /auth/otp/request/` with `purpose: delete_account` for the caller's "
            "own phone. A login OTP is rejected."
        ),
    )
    reason = serializers.CharField(
        required=False, allow_blank=True, max_length=500, help_text="Optional feedback."
    )


class AccountDeletionSerializer(serializers.Serializer):
    deleted_at = serializers.DateTimeField(help_text="When the deletion was recorded.")
    anonymise_after = serializers.DateTimeField(
        help_text="Personal data is anonymised after this time (30-day grace period, 07 §4)."
    )


class DeviceSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    fcm_token = serializers.CharField(max_length=512, help_text="Firebase Cloud Messaging token.")
    app = serializers.ChoiceField(choices=AppName.choices)
    platform = serializers.ChoiceField(choices=Platform.choices)
    app_version = serializers.RegexField(
        APP_VERSION_PATTERN,
        max_length=32,
        help_text='Installed app version, e.g. "1.4.2" or "1.4.2+37".',
    )
    is_active = serializers.BooleanField(read_only=True)
    last_seen_at = serializers.DateTimeField(read_only=True)


class DeviceUnregisterSerializer(serializers.Serializer):
    fcm_token = serializers.CharField(max_length=512, help_text="The token to stop pushing to.")


# --------------------------------------------------------------------------- addresses


class AddressSerializer(serializers.Serializer):
    id = serializers.IntegerField(read_only=True)
    label = serializers.ChoiceField(choices=AddressLabel.choices)
    custom_label = serializers.CharField(
        max_length=40,
        required=False,
        allow_blank=True,
        help_text='Shown instead of the label when set, e.g. "Mom\'s place".',
    )
    receiver_name = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
        help_text=(
            "Defaults to the user's name. Send an empty string to reset it to the user's own "
            "(copied when saved). Omit it to keep the current value; null is rejected."
        ),
    )
    receiver_phone = serializers.CharField(
        required=False,
        allow_blank=True,
        validators=[indian_mobile_validator],
        help_text=(
            "Defaults to the user's phone. Send an empty string to reset it to the user's own "
            "(copied when saved). Omit it to keep the current value; null is rejected."
        ),
    )
    house = serializers.CharField(max_length=120, help_text="House / flat / floor.")
    building_street = serializers.CharField(max_length=200, help_text="Building and street.")
    landmark = serializers.CharField(max_length=120, required=False, allow_blank=True)
    area = serializers.CharField(max_length=120, required=False, allow_blank=True)
    city = serializers.CharField(max_length=80)
    state = serializers.CharField(max_length=80)
    pincode = serializers.CharField(validators=[pincode_validator])
    lat = serializers.FloatField(
        min_value=-90,
        max_value=90,
        help_text="Map pin latitude (WGS84). Required. Stored to 6 decimal places.",
    )
    lng = serializers.FloatField(
        min_value=-180,
        max_value=180,
        help_text="Map pin longitude (WGS84). Required. Stored to 6 decimal places.",
    )
    is_default = serializers.BooleanField(
        read_only=True, help_text="Change it with `POST /addresses/{id}/set-default/`."
    )
    is_serviceable = serializers.SerializerMethodField(
        help_text=(
            "True when an active store (open or not) delivers to the address, checked on every "
            "read: the pin is inside its service area or, for a store that delivers by pincode "
            "(ADR 0004), the address pincode is one of its active pincodes. An unserviceable "
            "address can be saved but not used for an order: show it flagged (03 §2.4). Added "
            "in Phase 2."
        )
    )
    created_at = serializers.DateTimeField(read_only=True)
    updated_at = serializers.DateTimeField(read_only=True)

    def get_is_serviceable(self, address) -> bool:
        # Annotated by addresses.with_serviceability() on reads; computed for a new or moved
        # address (the same address rule, ADR 0004).
        value = getattr(address, "is_serviceable", None)
        if value is None:
            from apps.stores.services import is_address_serviceable

            return is_address_serviceable(address.lat, address.lng, address.pincode)
        return bool(value)


class PaginatedAddressListSerializer(serializers.Serializer):
    """Standard page (02 §5): `?page=&page_size=`, default 20, max 100."""

    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = AddressSerializer(many=True)
