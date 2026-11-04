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
