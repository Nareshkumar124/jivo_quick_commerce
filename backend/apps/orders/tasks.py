"""Order Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task
from django.conf import settings

logger = logging.getLogger(__name__)


@shared_task(name="orders.order_event")
def order_event(event: str, order_id: int) -> str:
    """Domain event handler (`apps.orders.events`). Phase 4: a PLACED order schedules its
    auto-accept (stores with auto-accept) and its acceptance SLA check; ops alerts are logged
    at ERROR. Phase 6 adds push, SMS and WebSocket notifications here."""
    from apps.orders import events

    if event in events.OPS_ALERTS:
        logger.error("Ops alert: %s on order %s", event, order_id)
    else:
        logger.info("Order event %s: order %s", event, order_id)
    if event == events.PLACED:
        schedule_acceptance(order_id)
    # Phase 5 (08 §2.1): dispatch starts at DISPATCH_TRIGGER (ACCEPTED by default, or PLACED).
    trigger = {"ACCEPTED": events.ACCEPTED, "PLACED": events.PLACED}.get(
        settings.DISPATCH_TRIGGER, events.ACCEPTED
    )
    if event == trigger:
        from apps.delivery.tasks import dispatch_order

        dispatch_order.delay(order_id)
    if event == events.PACKED:
        from apps.delivery.services.dispatch import order_packed

        order_packed(order_id)
    return event


def schedule_acceptance(order_id: int) -> None:
    from apps.orders.models import Order

    auto = (
        Order.objects.filter(pk=order_id)
        .values_list("store__auto_accept_orders", flat=True)
        .first()
    )
    if auto:
        auto_accept_order.apply_async((order_id,), countdown=settings.AUTO_ACCEPT_DELAY_SECONDS)
    store_acceptance_sla_alert.apply_async(
        (order_id,), countdown=settings.STORE_ACCEPTANCE_SLA_SECONDS
    )


@shared_task(name="orders.expire_unpaid_orders")
def expire_unpaid_orders() -> dict:
    """06 §5, beat every minute: online orders past their payment window are failed (T4) after
    asking the gateway, or placed if a capture is found (08 §4 rule 3)."""
    from apps.orders.services import expire_unpaid_orders as run

    return run()


@shared_task(name="orders.auto_accept_order")
def auto_accept_order(order_id: int) -> str:
    """06 §5 `auto_accept_orders` (countdown): T6 by the system for an auto-accept store."""
    from apps.orders.store_ops import auto_accept

    return auto_accept(order_id)


@shared_task(name="orders.auto_accept_orders")
def auto_accept_orders() -> dict:
    """Beat, every minute: auto-accepts missed by their countdown, and acceptance SLA alerts."""
    from apps.orders.store_ops import sweep_placed_orders

    return sweep_placed_orders()


@shared_task(name="orders.store_acceptance_sla_alert")
def store_acceptance_sla_alert(order_id: int) -> str:
    """06 §5 (countdown = SLA): alert ops once if the store has not accepted in time."""
    from apps.orders.store_ops import acceptance_sla_alert

    return acceptance_sla_alert(order_id)


@shared_task(name="orders.generate_invoice")
def generate_invoice(order_id: int) -> str:
    """06 §5: the GST invoice of a delivered order (T10 from Phase 5; on demand in Phase 4)."""
    from apps.orders import invoices
    from apps.orders.models import Order

    order = Order.objects.filter(pk=order_id).first()
    if order is None or not invoices.is_invoiceable(order):
        return "skipped"
    invoice = invoices.ensure_invoice(order_id)
    try:
        invoices.ensure_pdf(invoice)
    except invoices.InvoiceRenderingUnavailable as exc:
        logger.error("Invoice %s not rendered: %s", invoice.invoice_number, exc)
        return "not_rendered"
    return "done"
