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
    LOGIN = "login", "Log in or sign up"
    DELETE_ACCOUNT = "delete_account", "Confirm account deletion"


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
