"""Payment Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task
from django.db import transaction

from apps.payments.gateways import (
    GatewayRefund,
    GatewayUnavailable,
    PaymentGatewayRejected,
    get_gateway,
    refund_receipt,
    to_paise,
)
from apps.payments.models import Refund, RefundStatus
from apps.payments.refunds import record_refund_status

logger = logging.getLogger(__name__)


@shared_task(
    name="payments.process_refund",
    autoretry_for=(GatewayUnavailable,),
    retry_backoff=30,
    retry_backoff_max=1800,
    max_retries=8,
)
def process_refund(refund_id: int) -> str:
    """06 §5 `process_refund` (Phase 3: automatic T3a refunds). Safe to redeliver (code review
    M1): under the order and refund row locks it re-checks that the refund is still PENDING
    without a gateway id, then calls the gateway once with `receipt` = the refund key.
    - Timeout / 5xx (`GatewayUnavailable`): nothing is recorded, the task retries with the same
      receipt; if the first call did refund, the gateway answers "Duplicate receipt" and the
      existing refund is looked up and recorded.
    - Other 4xx: not retried; the refund is FAILED and ops are alerted (`payment.refund_failed`).
    """
    from apps.orders.models import Order

    order_id = Refund.objects.filter(pk=refund_id).values_list("order_id", flat=True).first()
    if order_id is None:
        return "skipped"
    with transaction.atomic():
        Order.objects.select_for_update().filter(pk=order_id).first()  # lock order: order first
        refund = Refund.objects.select_for_update().select_related("payment").get(pk=refund_id)
        if refund.status != RefundStatus.PENDING:
            return "skipped"
        if refund.gateway_refund_id:
            return "waiting"
        gateway, receipt = get_gateway(), refund_receipt(refund.idempotency_key)
        try:
            result = gateway.refund(
                payment_id=refund.payment.gateway_payment_id,
                amount_paise=to_paise(refund.amount),
                notes={"order_id": str(refund.order_id), "reason": refund.reason},
                receipt=receipt,
            )
        except PaymentGatewayRejected as exc:
            result = _made_before(gateway, refund, receipt) if exc.already_done else None
            if result is None:
                logger.error("Refund %s refused by the gateway: %s", refund.pk, exc)
                record_refund_status(refund, "failed")
                return "rejected"
        record_refund_status(refund, result.status, result.id)
        logger.info("Refund %s for order %s: gateway %s", refund.pk, refund.order_id, result.status)
        return result.status


def _made_before(gateway, refund: Refund, receipt: str) -> GatewayRefund | None:
    """The refund the gateway already made for this receipt (an earlier attempt whose answer was
    lost), else, for a fully refunded payment, a refund of the same amount."""
    try:
        found = gateway.fetch_payment_refunds(refund.payment.gateway_payment_id)
    except PaymentGatewayRejected:
        return None
    same_receipt = [item for item in found if item.receipt == receipt]
    if same_receipt:
        return same_receipt[0]
    amount = to_paise(refund.amount)
    taken = set(
        Refund.objects.exclude(pk=refund.pk)
        .exclude(gateway_refund_id="")
        .values_list("gateway_refund_id", flat=True)
    )
    same_amount = [i for i in found if i.amount_paise == amount and i.id not in taken]
    return same_amount[0] if same_amount else None
