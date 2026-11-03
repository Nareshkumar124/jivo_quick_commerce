"""Refunds to the original payment (08 §4 rule 4). Phase 3 needs only the automatic full refund
of a capture that cannot become a sale (08 T3a): a late capture on a failed or cancelled order,
a second capture on an order that is already paid (PM decision, DL-45), or a capture whose amount
is not the order's `grand_total`. The full refund flow
(cancellations, partial refunds, `sync_refund_status`) is Phase 4.

`request_refund()` is idempotent on `idempotency_key` (one Refund row per key) and hands the
gateway call to the `payments.process_refund` task after commit, which is itself safe to retry:
it calls the gateway only while the refund has no gateway id yet.
"""

import logging
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.payments.models import Payment, Refund, RefundStatus

logger = logging.getLogger(__name__)

LATE_CAPTURE = "late_capture"  # T3a: captured after the order failed or was cancelled
DUPLICATE_CAPTURE = "duplicate_capture"  # a second capture on an order already paid
AMOUNT_MISMATCH = "amount_mismatch"  # captured amount is not the order's grand_total


def request_refund(payment: Payment, amount: Decimal, *, reason: str, key: str) -> Refund:
    refund, created = Refund.objects.get_or_create(
        idempotency_key=key,
        defaults={
            "payment": payment,
            "order_id": payment.order_id,
            "amount": amount,
            "reason": reason,
        },
    )
    if created:
        from apps.payments.tasks import process_refund

        refund_id = refund.pk
        transaction.on_commit(lambda: process_refund.delay(refund_id))
    return refund


GATEWAY_STATUS = {
    "processed": RefundStatus.PROCESSED,
    "failed": RefundStatus.FAILED,
    "pending": RefundStatus.PENDING,
    "created": RefundStatus.PENDING,
}


def record_refund_status(refund: Refund, gateway_status: str, gateway_refund_id: str = "") -> bool:
    """Apply what the gateway reports (task result or `refund.*` webhook). Returns True when the
    refund reached PROCESSED now. A late-capture refund also settles the order's
    `payment_status` (REFUNDED) and `amount_refunded`; a duplicate-capture or wrong-amount refund
    does not touch the order (its own charge is paid, or still due)."""
    from apps.orders.choices import PaymentStatus
    from apps.orders.models import Order

    status = GATEWAY_STATUS.get(gateway_status, RefundStatus.PENDING)
    with transaction.atomic():
        # Lock order (apps.orders.services): the order row first, then the refund.
        order = Order.objects.select_for_update().get(pk=refund.order_id)
        refund = Refund.objects.select_for_update().get(pk=refund.pk)
        if refund.status == RefundStatus.PROCESSED:
            return False
        if gateway_refund_id and not refund.gateway_refund_id:
            refund.gateway_refund_id = gateway_refund_id
        refund.status = status
        if status == RefundStatus.PROCESSED:
            refund.processed_at = timezone.now()
        refund.save(update_fields=["gateway_refund_id", "status", "processed_at", "updated_at"])
        if status == RefundStatus.PROCESSED and refund.reason == LATE_CAPTURE:
            order.amount_refunded = min(order.amount_refunded + refund.amount, order.grand_total)
            order.payment_status = PaymentStatus.REFUNDED
            order.save(update_fields=["amount_refunded", "payment_status", "updated_at"])
        if status == RefundStatus.FAILED:
            logger.error("Refund %s for order %s failed at the gateway", refund.pk, refund.order_id)
        return status == RefundStatus.PROCESSED
