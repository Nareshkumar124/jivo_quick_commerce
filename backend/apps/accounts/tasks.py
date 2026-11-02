"""Accounts Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task
from django.conf import settings
from django.utils import timezone

from apps.accounts.models import OTPRequest
from apps.accounts.services import auth, otp
from apps.notifications.sms import SmsError, mask_phone, send_sms

logger = logging.getLogger(__name__)


@shared_task(
    name="accounts.send_otp_sms",
    autoretry_for=(SmsError,),
    retry_backoff=2,
    max_retries=3,
)
def send_otp_sms(otp_request_id: int, code: str) -> str:
    """06 §5. Skips OTPs already sent, used or expired, so a retry never double-sends."""
    request = OTPRequest.objects.filter(pk=otp_request_id).first()
    now = timezone.now()
    if request is None or request.sms_sent_at or request.verified_at or request.expires_at <= now:
        return "skipped"
    send_sms(
        request.phone,
        otp.render_otp_sms(code, request.app),
        settings.SMS_OTP_DLT_TEMPLATE_ID,
    )
    OTPRequest.objects.filter(pk=request.pk, sms_sent_at__isnull=True).update(sms_sent_at=now)
    logger.info("OTP SMS sent: otp_request=%s phone=%s", request.pk, mask_phone(request.phone))
    return "sent"


@shared_task(name="accounts.anonymise_deleted_accounts")
def anonymise_deleted_accounts() -> int:
    """06 §5, beat daily: anonymise accounts past the deletion grace period."""
    count = auth.anonymise_due_accounts()
    logger.info("Anonymised %s deleted account(s)", count)
    return count


@shared_task(name="accounts.purge_old_otp_requests")
def purge_old_otp_requests() -> int:
    """07 §4, beat daily: OTP requests are kept 30 days."""
    return otp.purge_old_otp_requests()
