"""OTP by SMS (phone) or by email (09 §3.1): 6 digits, 5-minute expiry, stored as a keyed hash,
at most 5 verify attempts, 3 sends per phone / email per 10 minutes and 10 per day, plus per-IP
limits. Email OTPs (2026-11-28) follow exactly the same rules as phone OTPs.

Fixed-OTP test numbers and emails (settings.OTP_TEST_NUMBERS / OTP_TEST_EMAILS, never in
production, D-15) skip the send limits and never send an SMS or email.

Every function takes exactly one of `phone=` or `email=`.
"""

import hashlib
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.accounts.choices import OtpPurpose
from apps.accounts.managers import normalise_email
from apps.accounts.models import OTPRequest, User
from apps.accounts.services import review_login
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError, OtpRateLimited
from apps.core.ratelimit import Limit, RateLimitUnavailable, hit

OTP_DIGITS = 6


def send_limits() -> list[Limit]:
    return [
        Limit("otp-send-phone-10m", settings.OTP_SEND_LIMIT_PER_10_MIN, 10 * 60),
        Limit("otp-send-phone-day", settings.OTP_SEND_LIMIT_PER_DAY, 24 * 60 * 60),
    ]


def email_send_limits() -> list[Limit]:
    """The same numbers as the phone limits, counted per email address."""
    return [
        Limit("otp-send-email-10m", settings.OTP_SEND_LIMIT_PER_10_MIN, 10 * 60),
        Limit("otp-send-email-day", settings.OTP_SEND_LIMIT_PER_DAY, 24 * 60 * 60),
    ]


def ip_send_limit() -> Limit:
    return Limit("otp-send-ip-hour", settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR, 60 * 60)


def ip_verify_limit() -> Limit:
    return Limit("otp-verify-ip-hour", settings.OTP_VERIFY_LIMIT_PER_IP_PER_HOUR, 60 * 60)


def otp_hash_key() -> bytes:
    """T-814 (L3): `OTP_HASH_KEY`, or a key derived from SECRET_KEY under its own label (so the
    OTP hashes never use the raw SECRET_KEY, which also signs sessions)."""
    if settings.OTP_HASH_KEY:
        return settings.OTP_HASH_KEY.encode()
    return hmac.new(
        settings.SECRET_KEY.encode(), b"jivo-quick-commerce:otp-hash-key", hashlib.sha256
    ).digest()


def hash_code(phone: str, app: str, purpose: str, code: str) -> str:
    """HMAC-SHA256 keyed with `otp_hash_key()`: a database leak alone does not reveal codes.
    `phone` is the OTP's target: the phone, or `email_target(email)` for an email OTP."""
    message = f"{phone}|{app}|{purpose}|{code}".encode()
    return hmac.new(otp_hash_key(), message, hashlib.sha256).hexdigest()


def email_target(email: str) -> str:
    """The hashed identifier of an email OTP (prefixed, so it can never equal a phone)."""
    return f"email:{email}"


# T-814 (L4): requests whose client IP cannot be parsed share one IP bucket instead of skipping
# the per-IP limits.
UNKNOWN_IP = "unknown"


def test_code_for(phone: str) -> str | None:
    return settings.OTP_TEST_NUMBERS.get(phone)


def test_code_for_email(email: str) -> str | None:
    codes = {key.strip().lower(): value for key, value in settings.OTP_TEST_EMAILS.items()}
    return codes.get(email)


def sent_response() -> dict:
    return {
        "otp_length": OTP_DIGITS,
        "expires_in_seconds": settings.OTP_TTL_SECONDS,
        "resend_after_seconds": settings.OTP_RESEND_AFTER_SECONDS,
    }


OTP_UNAVAILABLE = "Sign-in is temporarily unavailable. Please try again in a minute."


def _enforce(limits_and_idents: list[tuple[Limit, str]]) -> None:
    """Fail-closed: without the Redis counters no OTP is sent or checked (503)."""
    for limit, ident in limits_and_idents:
        try:
            retry_after = hit(limit, ident)
        except RateLimitUnavailable as exc:
            raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, OTP_UNAVAILABLE) from exc
        if retry_after:
            raise OtpRateLimited(retry_after)


class _Target:
    """Where an OTP goes: a phone (SMS) or an email address."""

    def __init__(self, phone: str | None, email: str | None) -> None:
        if (phone is None) == (email is None):
            raise ValueError("Pass exactly one of phone= or email=.")
        self.phone = phone
        self.email = normalise_email(email) if email is not None else None
        if email is not None and not self.email:
            raise ValueError("email must not be blank.")

    @property
    def is_email(self) -> bool:
        return self.email is not None

    @property
    def hashed_id(self) -> str:
        return email_target(self.email) if self.is_email else self.phone

    @property
    def fields(self) -> dict:
        return {"email": self.email, "phone": ""} if self.is_email else {"phone": self.phone}

    def test_code(self) -> str | None:
        return test_code_for_email(self.email) if self.is_email else test_code_for(self.phone)

    def send_limits(self) -> list[tuple[Limit, str]]:
        if self.is_email:
            return [(limit, self.email) for limit in email_send_limits()]
        return [(limit, self.phone) for limit in send_limits()]

    def account_exists(self) -> bool:
        users = User.objects.filter(is_active=True)
        if self.is_email:
            return users.filter(email=self.email, email_verified_at__isnull=False).exists()
        return users.filter(phone=self.phone).exists()


def request_otp(
    *,
    app: str,
    purpose: str,
    ip: str | None,
    phone: str | None = None,
    email: str | None = None,
    user_agent: str = "",
) -> dict:
    """Create an OTP and queue its SMS or email. The response never reveals whether the phone
    or email has an account."""
    target = _Target(phone, email)
    test_code = target.test_code()
    if test_code is None:
        checks = [(ip_send_limit(), ip or UNKNOWN_IP)]
        checks += target.send_limits()
        _enforce(checks)

    if purpose == OtpPurpose.DELETE_ACCOUNT and not target.account_exists():
        return sent_response()  # same answer, nothing sent

    review_code = review_login.code_for(phone)
    code = test_code or review_code or f"{secrets.randbelow(10**OTP_DIGITS):0{OTP_DIGITS}d}"
    now = timezone.now()
    with transaction.atomic():
        # A new OTP replaces any still-active one for the same target, app and purpose.
        OTPRequest.objects.filter(
            **target.fields, app=app, purpose=purpose, verified_at__isnull=True, expires_at__gt=now
        ).update(expires_at=now)
        otp = OTPRequest.objects.create(
            **target.fields,
            app=app,
            purpose=purpose,
            code_hash=hash_code(target.hashed_id, app, purpose, code),
            expires_at=now + timedelta(seconds=settings.OTP_TTL_SECONDS),
            ip=ip,
            user_agent=user_agent[:256],
        )
        if review_code is not None:  # store reviewer: nothing sent
            review_login.log_event("request", phone=phone, purpose=purpose, app=app)
        elif test_code is None:
            from apps.accounts.tasks import send_otp_email, send_otp_sms

            task = send_otp_email if target.is_email else send_otp_sms
            transaction.on_commit(lambda: task.delay(otp.pk, code))
    return sent_response()


def newest_active_target(targets: list[dict], *, purpose: str) -> dict | None:
    """Of `targets` (`{"phone": ...}` / `{"email": ...}`), the one with the newest unused,
    unexpired OTP for `purpose`; None when none has one."""
    now = timezone.now()
    newest, newest_at = None, None
    for target in targets:
        fields = _Target(target.get("phone"), target.get("email")).fields
        created = (
            OTPRequest.objects.filter(
                **fields, purpose=purpose, verified_at__isnull=True, expires_at__gt=now
            )
            .order_by("-created_at")
            .values_list("created_at", flat=True)
            .first()
        )
        if created is not None and (newest_at is None or created > newest_at):
            newest, newest_at = target, created
    return newest


def verify_otp(
    *,
    purpose: str,
    code: str,
    ip: str | None,
    app: str | None = None,
    phone: str | None = None,
    email: str | None = None,
) -> OTPRequest:
    """Consume the newest active OTP. Wrong codes count attempts; the attempt is committed even
    though the call fails."""
    target = _Target(phone, email)
    if target.test_code() is None:  # test numbers / emails: repeatable integration runs
        _enforce([(ip_verify_limit(), ip or UNKNOWN_IP)])

    now = timezone.now()
    error: ApiError | None = None
    with transaction.atomic():
        candidates = OTPRequest.objects.select_for_update().filter(
            **target.fields, purpose=purpose, verified_at__isnull=True, expires_at__gt=now
        )
        if app:
            candidates = candidates.filter(app=app)
        otp = candidates.order_by("-created_at").first()
        if otp is None or otp.attempts >= settings.OTP_MAX_ATTEMPTS:
            error = ApiError(ErrorCode.OTP_EXPIRED)
        elif not hmac.compare_digest(
            otp.code_hash, hash_code(target.hashed_id, otp.app, purpose, code)
        ):
            otp.attempts += 1
            otp.save(update_fields=["attempts", "updated_at"])
            error = ApiError(
                ErrorCode.OTP_INVALID,
                details={"attempts_remaining": settings.OTP_MAX_ATTEMPTS - otp.attempts},
            )
        else:
            otp.verified_at = now
            otp.save(update_fields=["verified_at", "updated_at"])
    if review_login.code_for(phone) is not None:
        outcome = "failed" if error is not None else "ok"
        review_login.log_event("verify", phone=phone, purpose=purpose, app=app, outcome=outcome)
    if error is not None:
        raise error
    return otp


def otp_sms_variables(code: str, app: str) -> dict[str, str]:
    """The OTP template's variables (MSG91 flow `##otp##` / `##app_hash##`, T-815). `app_hash`
    is the Android SMS Retriever hash of the app that asked (blank if unset)."""
    return {"otp": code, "app_hash": settings.SMS_RETRIEVER_APP_HASHES.get(app, "")}


def render_otp_sms(code: str, app: str) -> str:
    """The DLT-registered OTP template. `{app_hash}` enables Android SMS Retriever autofill."""
    return settings.SMS_OTP_TEMPLATE.format(**otp_sms_variables(code, app)).strip()


_EMAIL_PURPOSE_TEXT = {
    OtpPurpose.LOGIN: "to sign in to Jivo",
    OtpPurpose.DELETE_ACCOUNT: "to confirm that you want to delete your Jivo account",
    OtpPurpose.VERIFY_EMAIL: "to verify this email address on your Jivo account",
}


def render_otp_email(code: str, purpose: str) -> tuple[str, str]:
    """`(subject, body)` of an OTP email. Plain text, no links (phishing-safe)."""
    minutes = settings.OTP_TTL_SECONDS // 60
    action = _EMAIL_PURPOSE_TEXT.get(purpose, _EMAIL_PURPOSE_TEXT[OtpPurpose.LOGIN])
    body = (
        f"Your Jivo verification code is {code}.\n\n"
        f"Use it {action}. It expires in {minutes} minutes.\n\n"
        "Do not share this code with anyone. Jivo will never ask you for it. "
        "If you did not ask for this code, you can ignore this email."
    )
    return settings.OTP_EMAIL_SUBJECT, body


def mask_email(email: str) -> str:
    """09 §3.3: never log full email addresses. "asha.verma@example.com" -> "a***@example.com"."""
    local, _, domain = email.partition("@")
    return f"{local[:1]}***@{domain}" if domain else "***"


def purge_old_otp_requests() -> int:
    """07 §4: OTP requests are kept 30 days."""
    cutoff = timezone.now() - timedelta(days=settings.OTP_RETENTION_DAYS)
    deleted, _ = OTPRequest.objects.filter(created_at__lt=cutoff).delete()
    return deleted
