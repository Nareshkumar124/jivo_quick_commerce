"""Refunds to the original payment (08 §4 rule 4). Phase 3 needs only the automatic full refund
of a capture that cannot become a sale (08 T3a): a late capture on a failed or cancelled order,
a second capture on an order that is already paid (PM decision, DL-45), or a capture whose amount
is not the order's `grand_total`. The full refund flow
(cancellations, partial refunds, `sync_refund_status`) is Phase 4.

`request_refund()` is idempotent on `idempotency_key` (one Refund row per key) and hands the
gateway call to the `payments.process_refund` task after commit. The task is safe to redeliver
and to retry (code review M1 and its fix review): it locks the refund, calls the gateway only
while the refund has no gateway id, and first looks the payment's refunds up at the gateway,
adopting one whose `receipt` is this refund's key, so a lost answer never refunds twice. The
POST also sends that `receipt`; Razorpay's docs say a repeated refund receipt is refused
("Duplicate receipt"), which is only a fallback here (assumed; confirm in Razorpay test mode).

A refund that ends FAILED raises the `payment.refund_failed` ops alert. `retry_failed_refund()`
is the hook for a manual retry (the Phase 4 ops screen calls it).
"""

import logging
import re
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from apps.payments.models import Payment, Refund, RefundStatus

logger = logging.getLogger(__name__)

LATE_CAPTURE = "late_capture"  # T3a: captured after the order failed or was cancelled
DUPLICATE_CAPTURE = "duplicate_capture"  # a second capture on an order already paid
RETRY_SUFFIX = re.compile(r":retry-(\d+)$")
AMOUNT_MISMATCH = "amount_mismatch"  # captured amount is not the order's grand_total
# A COD UPI QR payment that was not needed (cash taken, delivery failed, wrong amount; P5 5.4).
COD_QR_UNUSED = "cod_qr_unused"


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
        if refund.status == RefundStatus.FAILED and status == RefundStatus.PENDING:
            return False  # a late "pending" never reopens a failed refund (R2b-fix Minor 4)
        became_failed = status == RefundStatus.FAILED and refund.status != RefundStatus.FAILED
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
        if became_failed:  # alert once, on the change to FAILED
            from apps.orders import events

            logger.error("Refund %s for order %s failed at the gateway", refund.pk, refund.order_id)
            events.emit(events.REFUND_FAILED, refund.order_id)
        return status == RefundStatus.PROCESSED


def retry_failed_refund(refund: Refund, *, initiated_by=None) -> Refund:
    """Manual retry of a FAILED refund (Phase 4 ops screen). A new Refund row with its own key
    (so the gateway sees a new receipt); the failed one stays as the record of the attempt."""
    if refund.status != RefundStatus.FAILED:
        raise ValueError("Only a failed refund can be retried.")
    # Retrying a retry numbers from the original key, so keys never grow (R2b-fix Minor 6).
    base = RETRY_SUFFIX.sub("", refund.idempotency_key)
    taken = Refund.objects.filter(idempotency_key__startswith=f"{base}:retry-").values_list(
        "idempotency_key", flat=True
    )
    numbers = [int(m.group(1)) for k in taken if (m := RETRY_SUFFIX.search(k))]
    key = f"{base}:retry-{max(numbers, default=0) + 1}"
    retry = request_refund(refund.payment, refund.amount, reason=refund.reason, key=key)
    if initiated_by is not None and retry.initiated_by_id is None:
        retry.initiated_by = initiated_by
        retry.save(update_fields=["initiated_by", "updated_at"])
    return retry
