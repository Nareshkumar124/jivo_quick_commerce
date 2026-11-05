"""Delivery Celery tasks (06 §5). All idempotent and safe to retry."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="delivery.rider_heartbeat_check")
def rider_heartbeat_check() -> dict:
    """Beat, every 2 minutes: set offline the riders with no location for 10 minutes (04 §2.3)."""
    from apps.delivery.services.shifts import auto_offline_stale

    result = auto_offline_stale()
    if result["offline"] or result["on_task"]:
        logger.info("rider_heartbeat_check: %s", result)
    return result


@shared_task(name="delivery.purge_offboarded_kyc")
def purge_offboarded_kyc() -> int:
    """Beat, daily: delete KYC documents past their retention (D-14 default: 1 year)."""
    from apps.delivery.services.privacy import purge_offboarded_kyc as purge

    return purge()
