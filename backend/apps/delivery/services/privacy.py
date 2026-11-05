"""Rider personal data erasure (DPDP, 09 §4; 07 §4 retention; D-14 default ⚠).

- `scrub_rider(user)`: called by `accounts.services.auth.anonymise_user` in the same transaction.
  It blanks the rider's personal fields (name, date of birth, emergency contact, vehicle number,
  bank details), deletes the location history and the rider's simple_history rows (they copy the
  same fields; who approved or suspended stays in the audit log), ends any open shift, and sets
  `kyc_purge_after` = today + `KYC_RETENTION_DAYS` (365).
- `purge_offboarded_kyc()` (beat, daily): deletes the KYC document rows and their bucket files of
  riders whose `kyc_purge_after` has passed. Idempotent.

Earnings, cash ledger and task rows are kept without personal data (financial records, 07 §4).
"""

import logging
from datetime import timedelta

from django.conf import settings
from django.core.files.storage import default_storage
from django.db import transaction
from django.utils import timezone

from apps.delivery.choices import ShiftEndReason
from apps.delivery.models import Rider, RiderDocument, RiderLocation

logger = logging.getLogger(__name__)


def scrub_rider(user, now=None) -> bool:
    """Erase the rider profile's personal data of `user`. False when the user has no profile
    or it was already scrubbed. Call inside the caller's transaction."""
    from apps.delivery.services import shifts

    now = now or timezone.now()
    rider = Rider.objects.select_for_update().filter(user=user).first()
    if rider is None or rider.anonymised_at is not None:
        return False
    shifts.end_open_shift(rider, reason=ShiftEndReason.ADMIN, now=now)
    RiderLocation.objects.filter(rider=rider).delete()
    rider.history.all().delete()
    Rider.objects.filter(pk=rider.pk).update(
        full_name="",
        dob=None,
        emergency_contact_name="",
        emergency_contact_phone="",
        vehicle_number="",
        bank_account_name="",
        bank_account_number_encrypted="",
        bank_account_last4="",
        ifsc="",
        upi_id="",
        rejection_reason="",
        suspension_reason="",
        is_online=False,
        current_location=None,
        anonymised_at=now,
        kyc_purge_after=now.date() + timedelta(days=settings.KYC_RETENTION_DAYS),
        updated_at=now,
    )
    logger.info("Rider %s personal data erased (KYC purge scheduled)", rider.pk)
    return True


def purge_offboarded_kyc(today=None) -> int:
    """Delete the KYC documents (rows and files) of riders past `kyc_purge_after`. Returns the
    number of documents deleted."""
    today = today or timezone.localdate()
    due = RiderDocument.objects.filter(
        rider__kyc_purge_after__isnull=False, rider__kyc_purge_after__lte=today
    )
    deleted = 0
    for document_id in list(due.values_list("pk", flat=True)[:1000]):
        with transaction.atomic():
            document = (
                RiderDocument.objects.select_for_update(skip_locked=True)
                .filter(pk=document_id)
                .first()
            )
            if document is None:
                continue
            # The file first: if the bucket refuses, the row stays and the next run retries, so
            # no file is ever left without a row pointing at it.
            try:
                if document.file:
                    default_storage.delete(document.file.name)
            except Exception:
                logger.warning("KYC file of document %s not deleted; retrying later", document_id)
                continue
            document.delete()
            deleted += 1
    if deleted:
        logger.info("purge_offboarded_kyc: %s documents deleted", deleted)
    return deleted
