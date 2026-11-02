"""Phone OTP (09 §3.1): 6 digits, 5-minute expiry, stored as a keyed hash, at most 5 verify
attempts, 3 sends per phone per 10 minutes and 10 per day, plus per-IP limits.

Fixed-OTP test numbers (settings.OTP_TEST_NUMBERS, never in production, D-15) skip the send
limits and never send an SMS.
"""

import hashlib
import hmac
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.accounts.choices import OtpPurpose
from apps.accounts.models import OTPRequest, User
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError, OtpRateLimited
from apps.core.ratelimit import Limit, RateLimitUnavailable, hit

OTP_DIGITS = 6


def send_limits() -> list[Limit]:
    return [
        Limit("otp-send-phone-10m", settings.OTP_SEND_LIMIT_PER_10_MIN, 10 * 60),
        Limit("otp-send-phone-day", settings.OTP_SEND_LIMIT_PER_DAY, 24 * 60 * 60),
    ]


def ip_send_limit() -> Limit:
    return Limit("otp-send-ip-hour", settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR, 60 * 60)


def ip_verify_limit() -> Limit:
    return Limit("otp-verify-ip-hour", settings.OTP_VERIFY_LIMIT_PER_IP_PER_HOUR, 60 * 60)


def hash_code(phone: str, app: str, purpose: str, code: str) -> str:
    """HMAC-SHA256 keyed with SECRET_KEY: a database leak alone does not reveal codes."""
    message = f"{phone}|{app}|{purpose}|{code}".encode()
    return hmac.new(settings.SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()


def test_code_for(phone: str) -> str | None:
    return settings.OTP_TEST_NUMBERS.get(phone)


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


def request_otp(
    *, phone: str, app: str, purpose: str, ip: str | None, user_agent: str = ""
) -> dict:
    """Create an OTP and queue its SMS. The response never reveals whether the phone exists."""
    test_code = test_code_for(phone)
    if test_code is None:
        checks = [(limit, phone) for limit in send_limits()]
        if ip:
            checks.insert(0, (ip_send_limit(), ip))
        _enforce(checks)

    if (
        purpose == OtpPurpose.DELETE_ACCOUNT
        and not User.objects.filter(phone=phone, is_active=True).exists()
    ):
        return sent_response()  # same answer, nothing sent

    code = test_code or f"{secrets.randbelow(10**OTP_DIGITS):0{OTP_DIGITS}d}"
    now = timezone.now()
    with transaction.atomic():
        # A new OTP replaces any still-active one for the same phone, app and purpose.
        OTPRequest.objects.filter(
            phone=phone, app=app, purpose=purpose, verified_at__isnull=True, expires_at__gt=now
        ).update(expires_at=now)
        otp = OTPRequest.objects.create(
            phone=phone,
            app=app,
            purpose=purpose,
            code_hash=hash_code(phone, app, purpose, code),
            expires_at=now + timedelta(seconds=settings.OTP_TTL_SECONDS),
            ip=ip,
            user_agent=user_agent[:256],
        )
        if test_code is None:
            from apps.accounts.tasks import send_otp_sms

            transaction.on_commit(lambda: send_otp_sms.delay(otp.pk, code))
    return sent_response()


def verify_otp(
    *, phone: str, purpose: str, code: str, ip: str | None, app: str | None = None
) -> OTPRequest:
    """Consume the newest active OTP. Wrong codes count attempts; the attempt is committed even
    though the call fails."""
    if ip and test_code_for(phone) is None:  # test numbers: repeatable integration runs
        _enforce([(ip_verify_limit(), ip)])

    now = timezone.now()
    error: ApiError | None = None
    with transaction.atomic():
        candidates = OTPRequest.objects.select_for_update().filter(
            phone=phone, purpose=purpose, verified_at__isnull=True, expires_at__gt=now
        )
        if app:
            candidates = candidates.filter(app=app)
        otp = candidates.order_by("-created_at").first()
        if otp is None or otp.attempts >= settings.OTP_MAX_ATTEMPTS:
            error = ApiError(ErrorCode.OTP_EXPIRED)
        elif not hmac.compare_digest(otp.code_hash, hash_code(phone, otp.app, purpose, code)):
            otp.attempts += 1
            otp.save(update_fields=["attempts", "updated_at"])
            error = ApiError(
                ErrorCode.OTP_INVALID,
                details={"attempts_remaining": settings.OTP_MAX_ATTEMPTS - otp.attempts},
            )
        else:
            otp.verified_at = now
            otp.save(update_fields=["verified_at", "updated_at"])
    if error is not None:
        raise error
    return otp


def render_otp_sms(code: str, app: str) -> str:
    """The DLT-registered OTP template. `{app_hash}` enables Android SMS Retriever autofill."""
    app_hash = settings.SMS_RETRIEVER_APP_HASHES.get(app, "")
    return settings.SMS_OTP_TEMPLATE.format(otp=code, app_hash=app_hash).strip()


def purge_old_otp_requests() -> int:
    """07 §4: OTP requests are kept 30 days."""
    cutoff = timezone.now() - timedelta(days=settings.OTP_RETENTION_DAYS)
    deleted, _ = OTPRequest.objects.filter(created_at__lt=cutoff).delete()
    return deleted
