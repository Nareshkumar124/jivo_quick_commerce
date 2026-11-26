"""Send one real OTP-format SMS through the configured SMS_BACKEND (D-02, e.g. BhashSMS).

    uv run python manage.py send_test_sms --to 9876543210
    uv run python manage.py send_test_sms --to +919876543210 --app rider

The text is the DLT OTP template (SMS_OTP_TEMPLATE with SMS_OTP_DLT_TEMPLATE_ID) with a random
6-digit code, so it checks the gateway login, the sender id and the DLT template match in one go.
Sent directly (no Celery); no OTP is stored and the code cannot be used to sign in. Prints only
success or failure and the gateway's message id or error label: never the password, the code or
the text. Refused in production unless --force.
"""

import re
import secrets

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.core.management.base import BaseCommand, CommandError

from apps.accounts.services import otp
from apps.notifications import sms

_TEN_DIGITS = re.compile(r"^[6-9][0-9]{9}$")


def _e164(value: str) -> str:
    digits = re.sub(r"[\s-]", "", value or "")
    if digits.startswith("+91"):
        digits = digits[3:]
    elif len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    if not _TEN_DIGITS.match(digits):
        raise CommandError("--to must be an Indian mobile number (10 digits, or +91 and 10).")
    return f"+91{digits}"


class Command(BaseCommand):
    help = "Send one real OTP-format test SMS through the configured SMS_BACKEND."

    def add_arguments(self, parser):
        parser.add_argument("--to", required=True, help="Mobile number: 10 digits or +91...")
        parser.add_argument(
            "--app",
            choices=("customer", "rider"),
            default="customer",
            help="Whose SMS Retriever hash fills {app_hash}, if the template has one.",
        )
        parser.add_argument("--force", action="store_true", help="Allow in production.")

    def handle(self, *args, **options):
        if settings.APP_ENVIRONMENT == "production" and not options["force"]:
            raise CommandError("Refused in production (it sends a real SMS). Use --force.")
        phone = _e164(options["to"])
        code = f"{secrets.randbelow(1_000_000):06d}"
        backend = settings.SMS_BACKEND.rsplit(".", 1)[-1]
        self.stdout.write(
            f"Sending a test OTP SMS to {sms.mask_phone(phone)} via {backend} "
            f"(DLT template {settings.SMS_OTP_DLT_TEMPLATE_ID or '-'}, "
            f"sender {settings.SMS_SENDER_ID or '-'})"
        )
        try:
            result = sms.send_sms(
                phone,
                otp.render_otp_sms(code, options["app"]),
                settings.SMS_OTP_DLT_TEMPLATE_ID,
                variables=otp.otp_sms_variables(code, options["app"]),
            )
        except (
            sms.SmsError,
            sms.SmsRejected,
            sms.SmsOutcomeUnknown,
            ImproperlyConfigured,
        ) as exc:
            raise CommandError(f"Failed ({type(exc).__name__}): {exc}") from None
        self.stdout.write(self.style.SUCCESS(f"Sent. Gateway message id: {result or '-'}"))
