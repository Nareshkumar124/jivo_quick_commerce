"""Store-reviewer logins by phone or email (D-15, owner-approved 2026-11-28).

Google Play / App Store reviewers must sign in to the production apps, where SMS OTP may not be
live and OTP_TEST_NUMBERS is refused. `settings.STORE_REVIEW_LOGINS` maps a few phones to a
fixed, non-trivial 6-digit code. For a listed phone, `otp.request_otp` stores that code (hashed)
and sends no SMS; `otp.verify_otp` then checks it like any other code.

Email entries (`reviewer@jivo.in:482913`, 2026-11-28) work the same on the email OTP path (no
email sent, any purpose, both apps), since production may offer email sign-in only. Email keys
are matched case-insensitively. All rate limits and the
attempt limit still apply. Empty (the default) turns the feature off.

Each reviewer request and verify writes an INFO audit line (masked phone, purpose, app); the code
is never logged.
"""

import logging

from django.conf import settings

from apps.notifications.sms import mask_phone

logger = logging.getLogger("apps.accounts.review_login")


def _logins() -> dict[str, str]:
    return getattr(settings, "STORE_REVIEW_LOGINS", None) or {}


def code_for(phone: str | None = None, email: str | None = None) -> str | None:
    """The fixed reviewer code for `phone` or `email`, or None if it is not a reviewer login."""
    if email:
        email = email.strip().lower()
        return next(
            (code for key, code in _logins().items() if "@" in key and key.lower() == email),
            None,
        )
    if phone:
        return _logins().get(phone)
    return None


def _mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    return f"{local[:1]}***@{domain}" if domain else "***"


def log_event(
    event: str,
    *,
    purpose: str,
    app: str | None,
    phone: str | None = None,
    email: str | None = None,
    outcome: str = "",
) -> None:
    who = f"email={_mask_email(email)}" if email else f"phone={mask_phone(phone or '')}"
    logger.info(
        "Store-review login %s: %s purpose=%s app=%s%s",
        event,
        who,
        purpose,
        app or "-",
        f" outcome={outcome}" if outcome else "",
    )
