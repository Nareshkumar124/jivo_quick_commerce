"""Order Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(name="orders.order_event")
def order_event(event: str, order_id: int) -> str:
    """Domain event handler (`apps.orders.events`). Phase 3 records it; later phases notify."""
    if event == "payment.late_capture":
        logger.error("Ops alert: %s on order %s (automatic full refund requested)", event, order_id)
    else:
        logger.info("Order event %s: order %s", event, order_id)
    return event


@shared_task(name="orders.expire_unpaid_orders")
def expire_unpaid_orders() -> dict:
    """06 §5, beat every minute: online orders past their payment window are failed (T4) after
    asking the gateway, or placed if a capture is found (08 §4 rule 3)."""
    from apps.orders.services import expire_unpaid_orders as run

    return run()
