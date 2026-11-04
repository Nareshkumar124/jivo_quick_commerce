import re

from django.conf import settings
from django.core.checks import Error, register

_PHONE = re.compile(r"^\+91[6-9][0-9]{9}$")
_CODE = re.compile(r"^[0-9]{6}$")


@register()
def check_otp_test_numbers(app_configs, **kwargs):
    """D-15: fixed-OTP numbers must be well formed and never exist in production."""
    errors = []
    numbers = getattr(settings, "OTP_TEST_NUMBERS", {})
    if numbers and settings.APP_ENVIRONMENT == "production":
        errors.append(Error("OTP_TEST_NUMBERS must be empty in production.", id="accounts.E001"))
    for phone, code in numbers.items():
        if not _PHONE.match(phone) or not _CODE.match(code):
            errors.append(
                Error(
                    f"OTP_TEST_NUMBERS entry for {phone[:6]}... is invalid "
                    "(use +91XXXXXXXXXX:6 digits).",
                    id="accounts.E002",
                )
            )
    return errors


@register()
def check_sms_backend(app_configs, **kwargs):
    """BUG-0005: deployed environments never use an SMS backend that logs or drops messages
    (the console backend writes OTP codes to the log, 09 §3.1/§3.3). Production never; staging
    only with SMS_CONSOLE_BACKEND_ALLOWED=true (explicit opt-in until D-02)."""
    from apps.notifications.sms import NON_DELIVERING_BACKENDS

    environment = settings.APP_ENVIRONMENT
    if environment not in ("staging", "production"):
        return []
    if settings.SMS_BACKEND not in NON_DELIVERING_BACKENDS:
        return []
    if environment == "staging" and getattr(settings, "SMS_CONSOLE_BACKEND_ALLOWED", False):
        return []
    return [
        Error(
            f"SMS_BACKEND {settings.SMS_BACKEND.rsplit('.', 1)[-1]} logs or drops messages and "
            f"is not allowed in {environment}.",
            hint=(
                "Set SMS_BACKEND to the gateway backend (D-02), or leave it unset to use "
                "UnconfiguredSmsBackend (sends fail loudly). Staging only: "
                "SMS_CONSOLE_BACKEND_ALLOWED=true."
            ),
            id="accounts.E003",
        )
    ]


@register()
def check_twilio_settings(app_configs, **kwargs):
    """D-02: the Twilio backend needs its credentials and a sender (a Messaging Service SID or
    a From number). Checked in every environment, so a misconfiguration fails at startup rather
    than on the first OTP."""
    from apps.notifications.sms import TWILIO_BACKEND

    if settings.SMS_BACKEND != TWILIO_BACKEND:
        return []
    missing = [
        name
        for name in ("TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN")
        if not getattr(settings, name, "")
    ]
    if not (
        getattr(settings, "TWILIO_MESSAGING_SERVICE_SID", "")
        or getattr(settings, "TWILIO_FROM_NUMBER", "")
    ):
        missing.append("TWILIO_MESSAGING_SERVICE_SID or TWILIO_FROM_NUMBER")
    if not missing:
        return []
    return [
        Error(
            f"SMS_BACKEND is TwilioSmsBackend but {', '.join(missing)} is not set.",
            hint="Set the TWILIO_* variables in the environment (backend/.env locally).",
            id="accounts.E004",
        )
    ]
