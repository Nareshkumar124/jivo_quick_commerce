"""Payment confirmation (06 §2.6, 08 §4): the checkout callback's verify and the gateway webhook.

Both end in `orders.services.capture_payment()`, which makes the decision once: whichever
arrives first places the order (T3), the second is a no-op, and a capture that cannot become a
sale is refunded (T3a). The app's callback is never trusted alone: verify needs a valid signature
for one of this order's gateway orders.
"""

import logging
import re
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.orders import services as orders
from apps.orders.choices import ActorType, OrderStatus
from apps.payments.choices import WebhookResult
from apps.payments.gateways import get_gateway, refund_receipt
from apps.payments.models import Payment, PaymentWebhookEvent, Refund, RefundStatus
from apps.payments.refunds import record_refund_status
from apps.payments.serializers import RAZORPAY_ORDER_ID_PATTERN, RAZORPAY_PAYMENT_ID_PATTERN

logger = logging.getLogger(__name__)

MSG_NOT_AWAITING = (
    "This order is no longer awaiting payment. Any amount debited will be refunded automatically."
)


def verify_payment(
    user, *, order_id: int, razorpay_order_id: str, razorpay_payment_id: str, signature: str
):
    """`POST /payments/razorpay/verify/`: 200 with the PLACED order (also on a repeat, or after
    the webhook got there first). 404 for another user's order; 400
    `PAYMENT_VERIFICATION_FAILED` for a bad signature or a gateway order that is not this
    order's; 409 when the order already failed or was cancelled (refunded automatically)."""
    order = orders.own_orders(user).filter(pk=order_id).first()
    if order is None:
        raise NotFound(orders.MSG_NOT_FOUND)
    if not order.payments.filter(gateway_order_id=razorpay_order_id).exists():
        raise ApiError(ErrorCode.PAYMENT_VERIFICATION_FAILED)
    if not get_gateway().verify_payment_signature(
        order_id=razorpay_order_id, payment_id=razorpay_payment_id, signature=signature
    ):
        raise ApiError(ErrorCode.PAYMENT_VERIFICATION_FAILED)
    # A valid signature is treated as a capture of the full amount (code review Minor 5, PM
    # decision): every gateway order is created for exactly the order's grand_total and with
    # automatic capture (`gateways.AUTO_CAPTURE`). The webhook still checks the captured amount.
    result = orders.capture_payment(
        order.pk,
        gateway_order_id=razorpay_order_id,
        payment_id=razorpay_payment_id,
        actor=user,
        actor_type=ActorType.CUSTOMER,
    )
    if result.order.status in (OrderStatus.PAYMENT_FAILED, OrderStatus.CANCELLED):
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION,
            MSG_NOT_AWAITING,
            details={"status": result.order.status},
        )
    return orders.get_own_order(user, order.pk)


def handle_webhook(event_id: str, event: dict) -> str:
    """One signed gateway event, processed once per `event_id` (08 §4 rule 2). Runs in one
    transaction with the event row: if processing fails, nothing is stored and the gateway's
    retry processes it again."""
    with transaction.atomic():
        stored, created = PaymentWebhookEvent.objects.select_for_update().get_or_create(
            event_id=event_id,
            defaults={"event_type": str(event.get("event", ""))[:64], "payload": event},
        )
        if not created and stored.processed_at is not None:
            return WebhookResult.DUPLICATE
        try:
            result = _dispatch(event)
        except (KeyError, TypeError, ValueError) as exc:
            logger.warning("Malformed %s webhook %s: %s", event.get("event"), event_id, exc)
            stored.error = f"malformed: {type(exc).__name__}"
            result = WebhookResult.IGNORED
        stored.processed_at = timezone.now()
        stored.save(update_fields=["processed_at", "error"])
        return result


class WebhookRetryLater(Exception):
    """The event cannot be applied yet and must not be stored as processed: the view answers
    503 so the gateway retries it (code review R2b-fix Major 1)."""


def _entity(event: dict, name: str) -> dict:
    return event["payload"][name]["entity"]


def _gateway_id(value, pattern: str) -> str:
    """A Razorpay id from a webhook, checked like the verify endpoint's (BUG-0009): an id that
    does not fit the stored fields (`gateway_payment_id`, the refund key `capture:<payment id>`,
    64 characters each) is malformed, so the event is ignored instead of failing with a 500."""
    if not isinstance(value, str) or not re.fullmatch(pattern, value):
        raise ValueError("not a Razorpay id")
    return value


def _dispatch(event: dict) -> str:
    kind = event.get("event")
    if kind == "payment.captured":
        entity = _entity(event, "payment")
        gateway_order_id = _gateway_id(entity["order_id"], RAZORPAY_ORDER_ID_PATTERN)
        payment_id = _gateway_id(entity["id"], RAZORPAY_PAYMENT_ID_PATTERN)
        payment = Payment.objects.filter(gateway_order_id=gateway_order_id).first()
        if payment is None:
            logger.warning("payment.captured for unknown gateway order %s", gateway_order_id)
            return WebhookResult.IGNORED
        orders.capture_payment(
            payment.order_id,
            gateway_order_id=gateway_order_id,
            payment_id=payment_id,
            amount_paise=int(entity["amount"]),
            method=entity.get("method") or "",
            raw=entity,
        )
        return WebhookResult.PROCESSED
    if kind == "payment.failed":
        entity = _entity(event, "payment")
        changed = orders.mark_payment_failed(
            _gateway_id(entity["order_id"], RAZORPAY_ORDER_ID_PATTERN),
            error_code=entity.get("error_code") or "",
            error_description=entity.get("error_description") or "",
            raw=entity,
        )
        return WebhookResult.PROCESSED if changed else WebhookResult.IGNORED
    if kind in ("refund.processed", "refund.failed"):
        entity = _entity(event, "refund")
        gateway_refund_id = str(entity["id"])
        refund = Refund.objects.filter(gateway_refund_id=gateway_refund_id).first()
        if refund is None:
            refund = _refund_by_receipt(entity)
        if refund is None:
            return WebhookResult.IGNORED
        record_refund_status(refund, kind.split(".", 1)[1], gateway_refund_id)
        return WebhookResult.PROCESSED
    return WebhookResult.IGNORED


def _refund_by_receipt(entity: dict) -> Refund | None:
    """A `refund.*` event for a refund whose gateway id is not stored yet: `process_refund` may
    still be in its gateway call (code review R2b-fix Major 1). Matched by the payment and the
    refund `receipt` (= `refund_receipt(idempotency_key)`), never by amount. If nothing matches
    while a refund of that payment is still PENDING without a gateway id and younger than
    `REFUND_WEBHOOK_RETRY_WINDOW_SECONDS` (so `process_refund` may still record it), the event is
    answered 503 (`WebhookRetryLater`), not stored, so the gateway's retry finds the id recorded.
    Past that window the event is ignored with a warning, so the 503 is never unbounded."""
    payment_id = entity.get("payment_id")
    if not isinstance(payment_id, str) or not re.fullmatch(RAZORPAY_PAYMENT_ID_PATTERN, payment_id):
        return None
    candidates = list(Refund.objects.filter(payment__gateway_payment_id=payment_id))
    receipt = entity.get("receipt") or ""
    for refund in candidates:
        if receipt and refund_receipt(refund.idempotency_key) == receipt:
            if refund.gateway_refund_id and refund.gateway_refund_id != str(entity["id"]):
                logger.warning(
                    "Refund event %s has the receipt of refund %s (gateway id %s): ignored",
                    entity["id"],
                    refund.pk,
                    refund.gateway_refund_id,
                )
                return None
            return refund
    unrecorded = [
        r for r in candidates if r.status == RefundStatus.PENDING and not r.gateway_refund_id
    ]
    since = timezone.now() - timedelta(seconds=settings.REFUND_WEBHOOK_RETRY_WINDOW_SECONDS)
    if any(r.created_at >= since for r in unrecorded):
        raise WebhookRetryLater(f"refund {entity['id']} not recorded yet")
    if unrecorded:
        # Bounded (fix review): past the window `process_refund` is no longer running, so a retry
        # cannot help (a Dashboard refund without a receipt, or a task that gave up).
        logger.warning(
            "Refund event %s for payment %s matches no refund; refunds %s are pending past the "
            "retry window: ignored",
            entity["id"],
            payment_id,
            [r.pk for r in unrecorded],
        )
    return None
