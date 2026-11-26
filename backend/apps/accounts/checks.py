import re

from django.conf import settings
from django.core.checks import Error, Warning, register

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


@register()
def check_msg91_settings(app_configs, **kwargs):
    """T-815 (D-02): the MSG91 backend needs its auth key and a flow for the OTP DLT template
    (an Error, in every environment, so it fails at startup rather than on the first OTP).
    Notification events whose DLT template has no flow get a Warning: their SMS would fail."""
    from apps.notifications.sms import MSG91_BACKEND

    if settings.SMS_BACKEND != MSG91_BACKEND:
        return []
    flows = getattr(settings, "MSG91_FLOW_IDS", {}) or {}
    otp_dlt = getattr(settings, "SMS_OTP_DLT_TEMPLATE_ID", "")
    missing = []
    if not getattr(settings, "MSG91_AUTH_KEY", ""):
        missing.append("MSG91_AUTH_KEY")
    if not otp_dlt:
        missing.append("SMS_OTP_DLT_TEMPLATE_ID")
    elif not flows.get(otp_dlt):
        missing.append("a MSG91_FLOW_IDS entry for SMS_OTP_DLT_TEMPLATE_ID")
    errors = []
    if missing:
        errors.append(
            Error(
                f"SMS_BACKEND is Msg91SmsBackend but {', '.join(missing)} is not set.",
                hint=(
                    "Set MSG91_AUTH_KEY and MSG91_FLOW_IDS (dlt_template_id:msg91_flow_id,...) "
                    "in the environment (backend/.env locally)."
                ),
                id="accounts.E007",
            )
        )
    unmapped = sorted(
        event
        for event, dlt_id in (getattr(settings, "SMS_DLT_TEMPLATE_IDS", {}) or {}).items()
        if dlt_id and not flows.get(dlt_id)
    )
    if unmapped:
        errors.append(
            Warning(
                f"No MSG91 flow for the DLT template of: {', '.join(unmapped)}. "
                "Their SMS will fail (the push and inbox entry still go out).",
                hint="Add each DLT id from SMS_DLT_TEMPLATE_IDS to MSG91_FLOW_IDS.",
                id="accounts.W001",
            )
        )
    return errors


@register()
def check_bhashsms_settings(app_configs, **kwargs):
    """D-02 (BhashSMS, the chosen gateway): the BhashSMS backend needs its login, the DLT sender
    id, the OTP DLT template id (E008), an http(s) API URL without a query and a GET/POST method
    (E009). Errors in every environment, so a misconfiguration fails at startup rather than on
    the first OTP. W002: a plain-http URL in production sends the password unencrypted (the
    proven default until BhashSMS confirms https for the account)."""
    from apps.notifications.sms import BHASHSMS_BACKEND, BHASHSMS_HTTP_METHODS

    if settings.SMS_BACKEND != BHASHSMS_BACKEND:
        return []
    names = ("BHASHSMS_USER", "BHASHSMS_PASSWORD", "SMS_SENDER_ID", "SMS_OTP_DLT_TEMPLATE_ID")
    missing = [name for name in names if not getattr(settings, name, "")]
    errors = []
    if missing:
        errors.append(
            Error(
                f"SMS_BACKEND is BhashSmsBackend but {', '.join(missing)} is not set.",
                hint="Set the BHASHSMS_* and SMS_* variables in the environment (backend/.env).",
                id="accounts.E008",
            )
        )
    url = getattr(settings, "BHASHSMS_API_URL", "")
    if url and (not url.startswith(("http://", "https://")) or "?" in url):
        errors.append(
            Error(
                "BHASHSMS_API_URL must be an http:// or https:// URL without a query string.",
                id="accounts.E009",
            )
        )
    method = (getattr(settings, "BHASHSMS_HTTP_METHOD", "") or "GET").upper()
    if method not in BHASHSMS_HTTP_METHODS:
        errors.append(Error("BHASHSMS_HTTP_METHOD must be GET or POST.", id="accounts.E009"))
    if url.startswith("http://") and settings.APP_ENVIRONMENT == "production":
        errors.append(
            Warning(
                "BHASHSMS_API_URL is plain http: the BhashSMS password and OTP text travel "
                "unencrypted.",
                hint="Switch to https (and BHASHSMS_HTTP_METHOD=POST) once BhashSMS confirms it.",
                id="accounts.W002",
            )
        )
    return errors


@register()
def check_signing_keys(app_configs, **kwargs):
    """T-814 (L3): deployed environments sign JWTs with their own `JWT_SIGNING_KEY`, never with
    `DJANGO_SECRET_KEY` (a leak of one must not forge the other), and an explicit `OTP_HASH_KEY`
    must differ from both."""
    if settings.APP_ENVIRONMENT not in ("staging", "production"):
        return []
    errors = []
    secret = settings.SECRET_KEY
    jwt_key = settings.SIMPLE_JWT.get("SIGNING_KEY") or ""
    if not jwt_key or jwt_key == secret or len(jwt_key) < 50:
        errors.append(
            Error(
                "JWT_SIGNING_KEY must be set to its own value (at least 50 characters), "
                "different from DJANGO_SECRET_KEY.",
                id="accounts.E005",
            )
        )
    otp_key = getattr(settings, "OTP_HASH_KEY", "")
    if otp_key and (otp_key in (secret, jwt_key) or len(otp_key) < 32):
        errors.append(
            Error(
                "OTP_HASH_KEY, when set, must be at least 32 characters and differ from "
                "DJANGO_SECRET_KEY and JWT_SIGNING_KEY (leave it empty to derive one).",
                id="accounts.E006",
            )
        )
    return errors
