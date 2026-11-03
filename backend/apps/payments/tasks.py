"""Payment Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task

from apps.payments.gateways import PaymentGatewayError, get_gateway, to_paise
from apps.payments.models import Refund, RefundStatus
from apps.payments.refunds import record_refund_status

logger = logging.getLogger(__name__)


@shared_task(
    name="payments.process_refund",
    autoretry_for=(PaymentGatewayError,),
    retry_backoff=30,
    retry_backoff_max=1800,
    max_retries=8,
)
def process_refund(refund_id: int) -> str:
    """06 §5 `process_refund` (Phase 3: automatic T3a refunds). Calls the gateway once per
    refund: a refund that already has a gateway id is only waiting for `refund.processed`."""
    refund = Refund.objects.select_related("payment").filter(pk=refund_id).first()
    if refund is None or refund.status != RefundStatus.PENDING:
        return "skipped"
    if refund.gateway_refund_id:
        return "waiting"
    result = get_gateway().refund(
        payment_id=refund.payment.gateway_payment_id,
        amount_paise=to_paise(refund.amount),
        notes={"order_id": str(refund.order_id), "reason": refund.reason},
    )
    record_refund_status(refund, result.status, result.id)
    logger.info("Refund %s for order %s: gateway %s", refund.pk, refund.order_id, result.status)
    return result.status
