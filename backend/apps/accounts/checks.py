import re

from django.conf import settings
from django.core.checks import Error, register

_PHONE = re.compile(r"^\+91[6-9]\d{9}$")
_CODE = re.compile(r"^\d{6}$")


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
