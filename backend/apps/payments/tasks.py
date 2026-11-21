"""Payment Celery tasks. All idempotent and safe to retry."""

import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.db import transaction
from django.utils import timezone

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
    """06 §5 `process_refund` (Phase 3: automatic T3a refunds). Safe to redeliver and retry (code
    review M1 and its fix review, Major 2). Under the order and refund row locks, briefly, it
    re-checks that the refund is still PENDING without a gateway id (`_claim`); then, with no
    lock held (T-403c):
    1. looks the payment's refunds up at the gateway (`fetch_payment_refunds`) and adopts one
       whose `receipt` is this refund's key: the primary guard, so an earlier attempt whose
       answer was lost (timeout, worker crash) is never repeated. Done on every run, not only on
       Celery retries, because a redelivered task after a crash starts at retry 0;
    2. otherwise POSTs the refund with that `receipt`.
    - Timeout / 5xx (`GatewayUnavailable`, on either call): nothing is recorded; the task
      retries and step 1 finds a refund the lost call made.
    - "Duplicate receipt" / "fully refunded already" 4xx: Razorpay's docs say a repeated refund
      receipt is refused (assumed; confirm in Razorpay test mode), so this is a fallback: the
      refunds are looked up again (`_made_before`).
    - Other 4xx (refund auto-retry, 2026-11-21): Razorpay has refused valid refunds ("invalid
      request sent") and accepted them later, so the refund stays PENDING and this task runs
      again after each of `REFUND_REFUSAL_RETRY_DELAYS_SECONDS` in turn (`Refund.next_attempt_at`
      and `gateway_refusals`), each run starting with the lookup above. Refused after the last
      delay, or refused for good (`PaymentGatewayRejected.permanent`: the amount): the refund is
      FAILED and ops are alerted (`payment.refund_failed`). A run that starts before its
      `next_attempt_at` (a redelivery, an older scheduled run) does nothing ("scheduled").
    """
    with _exclusive(refund_id) as mine:
        if not mine:  # another worker is sending this refund right now (a redelivery)
            return "skipped"
        return _process(refund_id)


# pg advisory lock namespace for refunds being sent (any constant; 0x4A51 = "JQ").
REFUND_LOCK_NAMESPACE = 0x4A51


class _exclusive:
    """One worker at a time per refund, without holding any row lock across the gateway call
    (T-403c): a PostgreSQL session-level advisory lock, tried without waiting and released at
    the end (or when the worker's connection closes, e.g. a crash)."""

    def __init__(self, refund_id: int) -> None:
        self.refund_id, self.acquired = refund_id, False

    def __enter__(self) -> bool:
        from django.db import connection

        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT pg_try_advisory_lock(%s, %s)", [REFUND_LOCK_NAMESPACE, self.refund_id]
            )
            self.acquired = bool(cursor.fetchone()[0])
        return self.acquired

    def __exit__(self, *exc) -> None:
        if self.acquired:
            from django.db import connection

            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT pg_advisory_unlock(%s, %s)", [REFUND_LOCK_NAMESPACE, self.refund_id]
                )


def _process(refund_id: int) -> str:
    claimed = _claim(refund_id)
    if isinstance(claimed, str):
        return claimed
    refund = claimed
    # T-403c (P4 review Major 1): the gateway calls run outside any transaction, so no Order or
    # Refund row lock is held while Razorpay answers. A concurrent run of the same refund is
    # covered by the lookup by receipt (and the gateway refusing a repeated receipt), and
    # `record_refund_status` re-locks and re-checks the refund before recording anything.
    gateway, receipt = get_gateway(), refund_receipt(refund.idempotency_key)
    result = _same_receipt(_gateway_refunds(gateway, refund), receipt)
    if result is None:
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
                return _refused(refund, exc)
    record_refund_status(refund, result.status, result.id)
    logger.info("Refund %s for order %s: gateway %s", refund.pk, refund.order_id, result.status)
    return result.status


def _claim(refund_id: int) -> Refund | str:
    """Under the order and refund row locks (lock order: order first), only briefly: the refund
    if it is still PENDING without a gateway id, else why it is skipped."""
    from apps.orders.models import Order

    order_id = Refund.objects.filter(pk=refund_id).values_list("order_id", flat=True).first()
    if order_id is None:
        return "skipped"
    with transaction.atomic():
        Order.objects.select_for_update().filter(pk=order_id).first()
        refund = Refund.objects.select_for_update().select_related("payment").get(pk=refund_id)
        if refund.status != RefundStatus.PENDING:
            return "skipped"
        if refund.gateway_refund_id:
            return "waiting"
        if refund.next_attempt_at and refund.next_attempt_at > timezone.now() + EARLY_SLACK:
            return "scheduled"  # a refusal retry is due later; that run sends it
        return refund


# A scheduled refusal retry that starts this much before `next_attempt_at` (clock skew) still runs.
EARLY_SLACK = timedelta(seconds=30)


def _refused(refund: Refund, exc: PaymentGatewayRejected) -> str:
    """The refund POST was refused (4xx) and no earlier refund was found for it: schedule the next
    try, or fail the refund (ops alert) when it is a final refusal or the tries are used up."""
    from apps.orders.models import Order

    delays = settings.REFUND_REFUSAL_RETRY_DELAYS_SECONDS
    with transaction.atomic():
        Order.objects.select_for_update().filter(pk=refund.order_id).first()  # order first
        refund = Refund.objects.select_for_update().get(pk=refund.pk)
        if refund.status != RefundStatus.PENDING or refund.gateway_refund_id:
            return "skipped"  # a webhook recorded it meanwhile
        refund.gateway_refusals += 1
        final = exc.already_done or exc.permanent or refund.gateway_refusals > len(delays)
        delay = 0 if final else delays[refund.gateway_refusals - 1]
        refund.next_attempt_at = None if final else timezone.now() + timedelta(seconds=delay)
        refund.save(update_fields=["gateway_refusals", "next_attempt_at", "updated_at"])
        (logger.error if final else logger.warning)(
            "Refund %s refused by the gateway: %s (%s); refusal %s, %s",
            refund.pk,
            exc,
            exc.description,
            refund.gateway_refusals,
            "failing it" if final else f"trying again in {delay} s",
        )
        if final:
            record_refund_status(refund, "failed")
            return "rejected"
        refund_id = refund.pk
        transaction.on_commit(lambda: process_refund.apply_async((refund_id,), countdown=delay))
    return "retry_scheduled"


def _gateway_refunds(gateway, refund: Refund) -> list[GatewayRefund]:
    """The payment's refunds at the gateway; [] if it refuses the lookup (4xx). A timeout or 5xx
    propagates, so the task retries rather than risk a second refund."""
    try:
        return gateway.fetch_payment_refunds(refund.payment.gateway_payment_id)
    except PaymentGatewayRejected:
        return []


def _same_receipt(found: list[GatewayRefund], receipt: str) -> GatewayRefund | None:
    return next((item for item in found if item.receipt == receipt), None)


def _made_before(gateway, refund: Refund, receipt: str) -> GatewayRefund | None:
    """After a "duplicate receipt" / "fully refunded already" refusal: the refund the gateway made
    for this receipt, else, only when this is the payment's sole Refund, one of the same amount
    (e.g. made from the Dashboard). With other Refund rows on the payment a same-amount refund
    could be theirs, so nothing is adopted and the refund fails for ops (R2b-fix Minor 5)."""
    found = _gateway_refunds(gateway, refund)
    if (match := _same_receipt(found, receipt)) is not None:
        return match
    if Refund.objects.filter(payment_id=refund.payment_id).exclude(pk=refund.pk).exists():
        logger.warning(
            "Refund %s: payment %s has other refunds; no same-amount refund adopted",
            refund.pk,
            refund.payment.gateway_payment_id,
        )
        return None
    amount = to_paise(refund.amount)
    return next((item for item in found if item.amount_paise == amount), None)
