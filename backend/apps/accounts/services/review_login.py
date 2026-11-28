"""Store-reviewer phone logins (D-15, owner-approved 2026-11-28).

Google Play / App Store reviewers must sign in to the production apps, where SMS OTP may not be
live and OTP_TEST_NUMBERS is refused. `settings.STORE_REVIEW_LOGINS` maps a few phones to a
fixed, non-trivial 6-digit code. For a listed phone, `otp.request_otp` stores that code (hashed)
and sends no SMS; `otp.verify_otp` then checks it like any other code. All rate limits and the
attempt limit still apply. Empty (the default) turns the feature off.

Each reviewer request and verify writes an INFO audit line (masked phone, purpose, app); the code
is never logged.
"""

import logging

from django.conf import settings

from apps.notifications.sms import mask_phone

logger = logging.getLogger("apps.accounts.review_login")


def code_for(phone: str) -> str | None:
    """The fixed reviewer code for `phone`, or None if it is not a reviewer login."""
    return (getattr(settings, "STORE_REVIEW_LOGINS", None) or {}).get(phone)


def log_event(event: str, *, phone: str, purpose: str, app: str | None, outcome: str = "") -> None:
    logger.info(
        "Store-review login %s: phone=%s purpose=%s app=%s%s",
        event,
        mask_phone(phone),
        purpose,
        app or "-",
        f" outcome={outcome}" if outcome else "",
    )
