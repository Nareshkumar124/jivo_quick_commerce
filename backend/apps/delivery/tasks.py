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


# --------------------------------------------------------------------------- dispatch (5.3)


@shared_task(name="delivery.dispatch_order")
def dispatch_order(order_id: int) -> str:
    """06 §5: offer the order's task to the best rider (08 §5). Idempotent."""
    from apps.delivery.services.dispatch import dispatch_order as run

    return run(order_id)


@shared_task(name="delivery.expire_offer")
def expire_offer(offer_id: int) -> str:
    """06 §5 (countdown = offer timeout): expire a still-pending offer and re-dispatch."""
    from apps.delivery.services.dispatch import expire_offer as run

    return run(offer_id)


@shared_task(name="delivery.dispatch_sweep")
def dispatch_sweep() -> dict:
    """Beat, every 15 s: expire due offers, run due searches, resume UNASSIGNED tasks (the
    `unassigned_order_alert` of 06 §5 is raised by dispatch itself)."""
    from apps.delivery.services.dispatch import dispatch_sweep as run

    return run()
