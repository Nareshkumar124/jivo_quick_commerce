import itertools
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


def _weak_code(code: str) -> bool:
    """Trivial codes a reviewer login must not use: one repeated digit, or a straight run up or
    down (123456, 654321, 012345, ...)."""
    if len(set(code)) == 1:
        return True
    steps = {int(b) - int(a) for a, b in itertools.pairwise(code)}
    return steps in ({1}, {-1})


@register()
def check_store_review_logins(app_configs, **kwargs):
    """D-15: store-reviewer logins (allowed in production) must be well formed, use a
    non-trivial 6-digit code, and not reuse a fixed-OTP test number."""
    errors = []
    logins = getattr(settings, "STORE_REVIEW_LOGINS", {}) or {}
    test_numbers = getattr(settings, "OTP_TEST_NUMBERS", {}) or {}
    for phone, code in logins.items():
        if not _PHONE.match(phone) or not _CODE.match(code) or _weak_code(code):
            reason = "invalid (use +91XXXXXXXXXX:6 digits, not a trivial code like 123456)"
        elif phone in test_numbers:
            reason = "also in OTP_TEST_NUMBERS (use a different number)"
        else:
            continue
        errors.append(
            Error(f"STORE_REVIEW_LOGINS entry for {phone[:6]}... is {reason}.", id="accounts.E011")
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


# Django's mail backends that never deliver: they log, store in memory or a file, or drop.
NON_DELIVERING_EMAIL_BACKENDS = frozenset(
    {
        "django.core.mail.backends.console.EmailBackend",
        "django.core.mail.backends.locmem.EmailBackend",
        "django.core.mail.backends.filebased.EmailBackend",
        "django.core.mail.backends.dummy.EmailBackend",
    }
)
SMTP_EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
_LOCAL_HOSTS = frozenset({"", "localhost", "127.0.0.1", "::1", "0.0.0.0"})  # noqa: S104 - compared, not bound


@register()
def check_email_delivery(app_configs, **kwargs):
    """2026-11-28 (email OTP review): email is a sign-in channel (login, verify-email and
    delete-account OTPs), so a deployed environment must really send mail.

    - accounts.E008 (production) / W002 (staging): `EMAIL_BACKEND` logs, stores or drops mail.
      Production is always an Error: the login switch lives in the database, so a check cannot
      tell whether email sign-in is on, and production must be able to turn it on at any time.
      Staging is a Warning (it may run without SMTP, using fixed-OTP test emails).
    - accounts.E009 (production) / W003 (staging): the SMTP backend points at this machine
      (`EMAIL_HOST` localhost: Mailpit in development, nothing in a container).
    - accounts.E010 (production): `DEFAULT_FROM_EMAIL` is the development default
      (`...@localhost`): providers reject or spam-folder such mail."""
    environment = settings.APP_ENVIRONMENT
    if environment not in ("staging", "production") or settings.DEBUG:
        return []
    production = environment == "production"
    problems = []
    backend = settings.EMAIL_BACKEND
    if backend in NON_DELIVERING_EMAIL_BACKENDS:
        problems.append(
            (Error if production else Warning)(
                f"EMAIL_BACKEND {backend.rsplit('.', 2)[-2]} does not send mail, but email "
                f"OTPs (sign-in, email verification, account deletion) need it in {environment}.",
                hint=(
                    "Set EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend and the "
                    "EMAIL_HOST / EMAIL_PORT / EMAIL_HOST_USER / EMAIL_HOST_PASSWORD / "
                    "EMAIL_USE_TLS variables of the mail provider."
                ),
                id="accounts.E008" if production else "accounts.W002",
            )
        )
    if backend == SMTP_EMAIL_BACKEND and (settings.EMAIL_HOST or "").strip().lower() in (
        _LOCAL_HOSTS
    ):
        problems.append(
            (Error if production else Warning)(
                f"EMAIL_HOST is {settings.EMAIL_HOST or 'empty'!r}: no mail server runs there "
                f"in {environment}, so email OTPs are never delivered.",
                hint="Set EMAIL_HOST (and EMAIL_PORT, EMAIL_USE_TLS) to the mail provider.",
                id="accounts.E009" if production else "accounts.W003",
            )
        )
    sender = (settings.DEFAULT_FROM_EMAIL or "").strip().lower().rstrip(">")
    if production and (not sender or sender.endswith("@localhost")):
        problems.append(
            Error(
                "DEFAULT_FROM_EMAIL is the development default (...@localhost).",
                hint=(
                    "Set DEFAULT_FROM_EMAIL to a real sender on a domain the mail provider may "
                    'send for, e.g. "Jivo Quick Commerce <noreply@jivo.in>".'
                ),
                id="accounts.E010",
            )
        )
    return problems
