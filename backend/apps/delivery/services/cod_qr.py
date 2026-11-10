"""COD by UPI QR (06 §3 `cod-qr`, api-requests #16, 08 T10; slice 5.4).

- `get_or_create(user, task_id)`: the rider's COD task at the customer gets one open QR (Razorpay
  QR Codes: `upi_qr`, single use, fixed amount) for exactly the order's `grand_total` (the amount
  due, from the server-side order). A repeat returns the same QR; an expired one is replaced.
  Off (`COD_UPI_QR_ENABLED`) or with no gateway keys: 503 `SERVICE_UNAVAILABLE` (take cash).
  The gateway call runs outside any row lock.
- **The server confirms payment** (`record_credit`): the signed webhook `qr_code.credited`, or a
  gateway lookup (`refresh`) when the rider delivers with UPI or asks for the QR again (a missed
  webhook). The QR becomes PAID only when it is open, the amount is the QR's amount and the
  order's `grand_total`, and the order is still out for delivery with the rider at the customer.
- **Any other credit is refunded in full** automatically to the UPI payment (reason
  `cod_qr_unused`, key `codqr:<payment id>`) and ops are alerted (`COD_QR_REFUNDED`): a payment on
  a QR closed because cash was taken, on an expired QR, of a wrong amount, or after the delivery
  failed (08 §6.4 COD: nothing due, so money received is returned; ⚠ PM default).
- Delivering with cash while a QR is PENDING closes it (CANCELLED); with a PAID QR, cash is
  refused (the customer already paid; deliver with UPI). A failed delivery (T13) closes a PENDING
  QR and refunds a PAID one.
- Closing at the gateway is the idempotent Celery task `delivery.close_cod_qr` (after commit).
"""

import logging
from datetime import datetime, timedelta
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import money_str
from apps.delivery import hooks
from apps.delivery.choices import CodQrStatus
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import CodQr, DeliveryTask
from apps.orders.choices import OrderStatus, PaymentMethod
from apps.orders.models import Order

logger = logging.getLogger(__name__)

MSG_UNAVAILABLE = "UPI QR is not available right now: collect cash."
MSG_PREPAID = "This order is prepaid: there is nothing to collect."
MSG_NOT_AT_CUSTOMER = "Mark arrived at the customer first."
OPEN = (CodQrStatus.PENDING, CodQrStatus.PAID)


def available() -> bool:
    from apps.payments.gateways import get_gateway

    if not settings.COD_UPI_QR_ENABLED:
        return False
    try:
        return get_gateway().qr_available
    except Exception:
        logger.exception("COD QR: the payment gateway cannot be loaded")
        return False


def current(task: DeliveryTask) -> CodQr | None:
    """The task's open QR (PENDING or PAID), else its newest one."""
    qrs = list(CodQr.objects.filter(task=task).order_by("-created_at", "-pk"))
    return next((qr for qr in qrs if qr.status in OPEN), qrs[0] if qrs else None)


def display_status(qr: CodQr, now: datetime | None = None) -> str:
    now = now or timezone.now()
    if qr.status == CodQrStatus.PENDING and qr.expires_at <= now:
        return CodQrStatus.EXPIRED
    return qr.status


def body(qr: CodQr | None, now: datetime | None = None) -> dict | None:
    if qr is None:
        return None
    return {
        "qr_id": qr.gateway_qr_id,
        "image_url": qr.image_url,
        "amount": money_str(qr.amount),
        "status": display_status(qr, now),
        "expires_at": qr.expires_at,
    }


def _state_error(message: str, task: DeliveryTask, order: Order) -> ApiError:
    return ApiError(
        ErrorCode.INVALID_STATE_TRANSITION,
        message,
        details={"status": task.status, "order_status": order.status},
    )


def _check_task(task: DeliveryTask, order: Order) -> None:
    if order.payment_method != PaymentMethod.COD:
        raise _state_error(MSG_PREPAID, task, order)
    if task.status != TS.AT_CUSTOMER or order.status != OrderStatus.OUT_FOR_DELIVERY:
        raise _state_error(MSG_NOT_AT_CUSTOMER, task, order)


def _close_later(gateway_qr_id: str) -> None:
    from apps.delivery.tasks import close_cod_qr

    transaction.on_commit(lambda: close_cod_qr.delay(gateway_qr_id))


def close(qr: CodQr, now: datetime, status: str = CodQrStatus.CANCELLED) -> None:
    """Close a PENDING QR (caller holds the task lock): no further payment is expected on it."""
    if qr.status != CodQrStatus.PENDING:
        return
    qr.status = status
    qr.closed_at = now
    qr.save(update_fields=["status", "closed_at"])
    _close_later(qr.gateway_qr_id)


# --------------------------------------------------------------------------- rider


def get_or_create(user, task_id: int, now: datetime | None = None) -> CodQr:
    from apps.delivery.services.riders import require_rider
    from apps.delivery.services.tasks import MSG_TASK_NOT_FOUND, lock_task
    from apps.payments.gateways import PaymentGatewayError, get_gateway, to_paise

    now = now or timezone.now()
    rider = require_rider(user, active=True)
    task = DeliveryTask.objects.select_related("order").filter(pk=task_id, rider=rider).first()
    if task is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TASK_NOT_FOUND)
    _check_task(task, task.order)
    existing = current(task)
    if existing is not None and existing.status == CodQrStatus.PENDING:
        refresh(existing)
        existing.refresh_from_db()
    if existing is not None and existing.status == CodQrStatus.PAID:
        return existing
    if (
        existing is not None
        and existing.status == CodQrStatus.PENDING
        and existing.expires_at > now
        and existing.amount == task.order.grand_total
    ):
        return existing
    if not available():
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_UNAVAILABLE)
    amount = task.order.grand_total
    expires_at = now + timedelta(seconds=settings.COD_QR_EXPIRY_SECONDS)
    try:
        made = get_gateway().create_qr_code(
            amount_paise=to_paise(amount),
            close_by=int(expires_at.timestamp()),
            description=f"Jivo order {task.order.order_number}",
            notes={"order_number": task.order.order_number, "task_id": str(task.pk)},
        )
    except PaymentGatewayError:
        logger.warning("COD QR for task %s: gateway unavailable", task.pk, exc_info=True)
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_UNAVAILABLE) from None
    with transaction.atomic():
        _rider, order, task = lock_task(user, task_id)
        _check_task(task, order)
        open_qrs = list(CodQr.objects.select_for_update().filter(task=task, status__in=OPEN))
        for qr in open_qrs:
            usable = qr.status == CodQrStatus.PAID or (
                qr.expires_at > now and qr.amount == order.grand_total
            )
            if usable:  # made meanwhile by another request: keep it, drop ours
                _close_later(made.id)
                return qr
            close(qr, now, CodQrStatus.EXPIRED if qr.expires_at <= now else CodQrStatus.CANCELLED)
        if order.grand_total != amount:  # cannot happen after pickup; never show a wrong QR
            _close_later(made.id)
            raise _state_error("The amount due changed: try again.", task, order)
        return CodQr.objects.create(
            task=task,
            order=order,
            gateway_qr_id=made.id,
            image_url=made.image_url,
            amount=amount,
            status=CodQrStatus.PENDING,
            expires_at=expires_at,
        )


def refresh(qr: CodQr) -> None:
    """Missed-webhook lookup (outside any row lock): apply captured payments the gateway reports
    on a PENDING QR. Best effort: a gateway error leaves the QR as it is."""
    from apps.payments.gateways import PaymentGatewayError, get_gateway

    if qr.status != CodQrStatus.PENDING:
        return
    try:
        payments = get_gateway().fetch_qr_payments(qr.gateway_qr_id)
    except PaymentGatewayError:
        logger.warning("COD QR %s: payment lookup failed", qr.gateway_qr_id, exc_info=True)
        return
    for payment in payments:
        if payment.status == "captured":
            record_credit(
                qr.gateway_qr_id,
                payment_id=payment.id,
                amount_paise=payment.amount_paise,
                method=payment.method,
                raw=payment.raw,
            )


def refresh_for_rider(rider, task_id: int) -> None:
    task = DeliveryTask.objects.filter(pk=task_id, rider=rider).first()
    if task is None:
        return
    qr = CodQr.objects.filter(task=task, status=CodQrStatus.PENDING).first()
    if qr is not None:
        refresh(qr)


# --------------------------------------------------------------------------- confirmation


def record_credit(
    gateway_qr_id: str,
    *,
    payment_id: str,
    amount_paise: int,
    method: str = "upi",
    raw: dict | None = None,
    now: datetime | None = None,
) -> str:
    """A payment on a QR, reported by the signed webhook or the gateway lookup. Idempotent on the
    payment id. Returns "paid", "refunded", "duplicate" or "unknown"."""
    from apps.payments.models import Gateway, Payment, PaymentAttemptStatus
    from apps.payments.refunds import COD_QR_UNUSED, request_refund

    now = now or timezone.now()
    probe = CodQr.objects.filter(gateway_qr_id=gateway_qr_id).values("order_id", "task_id").first()
    if probe is None:
        logger.warning("Credit on unknown QR %s ignored", gateway_qr_id)
        return "unknown"
    if amount_paise <= 0:
        raise ValueError("amount must be positive")
    amount = (Decimal(amount_paise) / 100).quantize(Decimal("0.01"))
    with transaction.atomic():
        order = Order.objects.select_for_update(of=("self",)).get(pk=probe["order_id"])
        task = DeliveryTask.objects.select_for_update(of=("self",)).get(pk=probe["task_id"])
        qr = CodQr.objects.select_for_update().get(gateway_qr_id=gateway_qr_id)
        if Payment.objects.filter(gateway_payment_id=payment_id).exists():
            return "duplicate"
        payment = Payment.objects.create(
            order=order,
            gateway=Gateway.RAZORPAY_QR,
            gateway_order_id=(
                ""
                if Payment.objects.filter(gateway_order_id=gateway_qr_id).exists()
                else gateway_qr_id
            ),
            gateway_payment_id=payment_id,
            amount=amount,
            status=PaymentAttemptStatus.CAPTURED,
            method=(method or "upi")[:20],
            raw=raw or {},
            captured_at=now,
        )
        accepted = (
            qr.status == CodQrStatus.PENDING
            and amount == qr.amount
            and amount == order.grand_total
            and order.payment_method == PaymentMethod.COD
            and order.status == OrderStatus.OUT_FOR_DELIVERY
            and task.status == TS.AT_CUSTOMER
        )
        if accepted:
            qr.status = CodQrStatus.PAID
            qr.paid_at = now
            qr.payment = payment
            qr.save(update_fields=["status", "paid_at", "payment"])
            logger.info("COD QR %s paid for order %s", gateway_qr_id, order.order_number)
            return "paid"
        request_refund(payment, amount, reason=COD_QR_UNUSED, key=f"codqr:{payment_id}")
        close(qr, now)
        data = {
            "order_id": order.pk,
            "order_number": order.order_number,
            "qr_id": gateway_qr_id,
            "amount": money_str(amount),
        }
        transaction.on_commit(lambda: hooks.ops_alert("COD_QR_REFUNDED", data))
        logger.warning("COD QR %s credit on order %s refunded", gateway_qr_id, order.order_number)
        return "refunded"


# --------------------------------------------------------------------------- task hooks


def paid_qr(task: DeliveryTask) -> CodQr | None:
    """The task's PAID QR, locked (the caller holds the order and task locks)."""
    return CodQr.objects.select_for_update().filter(task=task, status=CodQrStatus.PAID).first()


def close_open(task: DeliveryTask, now: datetime) -> None:
    for qr in CodQr.objects.select_for_update().filter(task=task, status=CodQrStatus.PENDING):
        close(qr, now)


def on_delivery_failed(task: DeliveryTask, order: Order, now: datetime) -> None:
    """T13: close a PENDING QR; refund a PAID one in full (nothing is due on a failed COD
    delivery, 08 §6.4)."""
    from apps.payments.refunds import COD_QR_UNUSED, request_refund

    close_open(task, now)
    qr = paid_qr(task)
    if qr is None or qr.payment is None:
        return
    payment = qr.payment
    request_refund(
        payment, payment.amount, reason=COD_QR_UNUSED, key=f"codqr:{payment.gateway_payment_id}"
    )
    data = {
        "order_id": order.pk,
        "order_number": order.order_number,
        "qr_id": qr.gateway_qr_id,
        "amount": money_str(payment.amount),
    }
    transaction.on_commit(lambda: hooks.ops_alert("COD_QR_REFUNDED", data))
