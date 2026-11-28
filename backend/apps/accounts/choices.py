"""Enums shared by the Phase 1 API contract (published in the OpenAPI schema under the names in
SPECTACULAR_SETTINGS["ENUM_NAME_OVERRIDES"])."""

from django.db import models


class AppName(models.TextChoices):
    """Which app a request, OTP or device belongs to. Same values as the `X-App-Name` header."""

    CUSTOMER = "customer", "Customer app"
    RIDER = "rider", "Rider app"


class Platform(models.TextChoices):
    """Same values as the `X-Platform` header."""

    ANDROID = "android", "Android"
    IOS = "ios", "iOS"


class OtpPurpose(models.TextChoices):
    """Every purpose an `OTPRequest` can have. The public OTP request endpoints accept only the
    `RequestableOtpPurpose` subset; the others are issued by signed-in `/me/...` endpoints."""

    LOGIN = "login", "Log in or sign up"
    DELETE_ACCOUNT = "delete_account", "Confirm account deletion"
    ADD_PHONE = "add_phone", "Add a phone number to a signed-in account"
    VERIFY_EMAIL = "verify_email", "Verify the email address of a signed-in account"


class RequestableOtpPurpose(models.TextChoices):
    """The purposes the public `/auth/otp/request/` and `/auth/email-otp/request/` accept
    (published as `OtpPurposeEnum`, unchanged since Phase 1)."""

    LOGIN = "login", "Log in or sign up"
    DELETE_ACCOUNT = "delete_account", "Confirm account deletion"


class LoginMethod(models.TextChoices):
    """One way to sign in to an app (`GET /auth/methods/`)."""

    PHONE = "phone", "Phone number (SMS OTP)"
    EMAIL = "email", "Email address (email OTP)"


class LoginMethodSetting(models.TextChoices):
    """The admin switch per app (`cms.AppConfig.customer_login_methods` /
    `rider_login_methods`)."""

    PHONE = "phone", "Phone only"
    EMAIL = "email", "Email only"
    BOTH = "both", "Phone or email (the user picks)"


class RiderStatus(models.TextChoices):
    """Rider profile status (07 §2.8) plus NONE when the user has no rider profile yet."""

    NONE = "NONE", "No rider profile: show registration"
    PENDING_KYC = "PENDING_KYC", "Registered, waiting for KYC approval"
    ACTIVE = "ACTIVE", "Approved: can go online"
    REJECTED = "REJECTED", "KYC rejected: see the reason, re-submit"
    SUSPENDED = "SUSPENDED", "Suspended by ops"


class AddressLabel(models.TextChoices):
    HOME = "home", "Home"
    WORK = "work", "Work"
    OTHER = "other", "Other"
