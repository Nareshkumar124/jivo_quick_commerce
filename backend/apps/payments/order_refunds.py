"""Order refunds (Phase 4, 08 §4 rule 4 and §6.4): cancellations (T11/T12), items found
unavailable (T8a), failed deliveries (T13, Phase 5) and manual refunds by staff (05 §3).

Built alongside `apps.payments.refunds` (the Phase 3 machinery for captures that cannot become a
sale): every refund here is a `Refund` row made by `refunds.request_refund()` and sent to the
gateway by the same `payments.process_refund` task, so retries and idempotency work the same way.

**The order's money** (T-402c):
- `Order.amount_paid` is what the customer paid for the order (the sale capture, T3). It does
  not change when T8a lowers `grand_total`.
- Refunds of an order never exceed `amount_paid`, and the refunds of one payment never exceed
  that payment's amount (`refundable()`); a refund the gateway refused (FAILED) still counts
  until it is retried, because ops will retry it (T-401c), never refund it twice.
- `Order.payment_status` follows 08 §4 rule 4: REFUND_PENDING while any order refund is not
  processed, then REFUNDED (everything paid is back) or PARTIALLY_REFUNDED; `amount_refunded`
  is the sum of the processed order refunds. Recomputed by `settle()` whenever a refund of an
  order reason is saved (signal below), so the gateway result, the webhook and
  `sync_refund_status` all settle the order the same way.

The automatic refunds of Phase 3 (`late_capture`, `duplicate_capture`, `amount_mismatch`) keep
their own rules in `apps.payments.refunds` (DL-45): they are not order refunds and are never
counted here.
"""

import logging
import re
from datetime import timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from celery import shared_task
from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import connection, transaction
from django.db.models import Q
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.utils import timezone

from apps.core import audit
from apps.core.money import money_str, round_money
from apps.payments.models import Payment, PaymentAttemptStatus, Refund, RefundStatus
from apps.payments.refunds import (
    AMOUNT_MISMATCH,
    DUPLICATE_CAPTURE,
    LATE_CAPTURE,
    record_refund_status,
    request_refund,
    retry_failed_refund,
)

logger = logging.getLogger(__name__)

ZERO = Decimal("0.00")

# Refund.reason values of order refunds (Phase 4).
CUSTOMER_CANCEL = "customer_cancel"  # T11
STAFF_CANCEL = "staff_cancel"  # T12
ITEM_UNAVAILABLE = "item_unavailable"  # T8a
DELIVERY_FAILED = "delivery_failed"  # T13 (Phase 5)
MANUAL = "manual"  # staff refund from the admin (05 §3 Refund)
ORDER_REASONS = frozenset(
    {CUSTOMER_CANCEL, STAFF_CANCEL, ITEM_UNAVAILABLE, DELIVERY_FAILED, MANUAL}
)

# The customer's view of a refund (`Order.refunds[].reason`).
PUBLIC_REASON = {
    CUSTOMER_CANCEL: "ORDER_CANCELLED",
    STAFF_CANCEL: "ORDER_CANCELLED",
    ITEM_UNAVAILABLE: "ITEMS_UNAVAILABLE",
    DELIVERY_FAILED: "DELIVERY_FAILED",
    MANUAL: "GOODWILL",
    LATE_CAPTURE: "PAYMENT_ISSUE",
    DUPLICATE_CAPTURE: "PAYMENT_ISSUE",
    AMOUNT_MISMATCH: "PAYMENT_ISSUE",
}

RETRY_SUFFIX = re.compile(r":retry-\d+$")

MSG_NOT_PAID = "This order has no online payment to refund."
MSG_ABOVE_REFUNDABLE = "At most {amount} can still be refunded on this order."
MSG_ABOVE_LIMIT = (
    "Support can refund at most {limit} in total on an order; {left} is left. "
    "Ask Finance for a larger refund."
)
MSG_ABOVE_DAILY_LIMIT = (
    "You can refund at most {limit} a day; {left} is left today. Ask Finance for more."
)
MSG_NO_PERMISSION = "You do not have permission to refund orders."
MSG_NOT_RETRYABLE = "Only a failed refund, or one stuck without a gateway answer, can be retried."
MSG_REFUND_NOT_FOUND = "Refund not found."


class RefundCapExceeded(ValidationError):
    pass


# --------------------------------------------------------------------------- reading


def _base_key(key: str) -> str:
    return RETRY_SUFFIX.sub("", key)


def live_refunds(refunds: list[Refund]) -> list[Refund]:
    """The refunds that stand: a FAILED refund that has been retried (`retry_failed_refund`
    makes a new row keyed `<key>:retry-N`) is replaced by its newest attempt."""
    newest: dict[str, Refund] = {}
    for refund in refunds:
        base = _base_key(refund.idempotency_key)
        best = newest.get(base)
        if best is None or (refund.created_at, refund.pk) > (best.created_at, best.pk):
            newest[base] = refund
    return [
        refund
        for refund in refunds
        if refund.status != RefundStatus.FAILED
        or newest[_base_key(refund.idempotency_key)] is refund
    ]


def customer_refunds(refunds: list[Refund]) -> list[dict]:
    """`Order.refunds[]`: the standing refunds; one the gateway refused is shown as PENDING (ops
    retry it, T-401c)."""
    return [
        {
            "id": refund.pk,
            "amount": money_str(refund.amount),
            "status": "PROCESSED" if refund.status == RefundStatus.PROCESSED else "PENDING",
            "reason": PUBLIC_REASON.get(refund.reason, "GOODWILL"),
            "created_at": refund.created_at,
            "processed_at": refund.processed_at,
        }
        for refund in sorted(live_refunds(refunds), key=lambda r: (r.created_at, r.pk))
    ]


def sale_payment(order) -> Payment | None:
    """The capture that paid for the order (T3). Captures refunded as not a sale (wrong amount,
    second capture, late capture) have a `capture:<payment id>` refund and are skipped."""
    not_sales = {
        key.removeprefix("capture:")
        for key in Refund.objects.filter(
            order=order, idempotency_key__startswith="capture:"
        ).values_list("idempotency_key", flat=True)
    }
    for payment in order.payments.filter(
        status=PaymentAttemptStatus.CAPTURED, gateway_payment_id__isnull=False
    ).order_by("captured_at", "pk"):
        if payment.gateway_payment_id not in not_sales:
            return payment
    return None


def _committed(refunds) -> Decimal:
    return sum((r.amount for r in live_refunds(list(refunds))), ZERO)


def refundable(order, payment: Payment | None = None) -> Decimal:
    """What can still be refunded on the order (T-402c): `amount_paid` minus the standing order
    refunds, and no more than its payment still holds."""
    payment = payment or sale_payment(order)
    if payment is None:
        return ZERO
    order_refunds = Refund.objects.filter(order=order, reason__in=ORDER_REASONS)
    by_order = order.amount_paid - _committed(order_refunds)
    by_payment = payment.amount - _committed(Refund.objects.filter(payment=payment))
    return max(min(by_order, by_payment), ZERO)


# --------------------------------------------------------------------------- refunding


def refund_order(
    order,
    amount: Decimal,
    *,
    reason: str,
    key: str,
    initiated_by=None,
    strict: bool = False,
) -> Refund | None:
    """Refund `amount` of an ONLINE order to its sale payment, after commit (the gateway call is
    the `process_refund` task, never inside this transaction). The caller holds the order row
    lock. Idempotent on `key`. Above what is refundable: capped (automatic refunds) or, with
    `strict`, refused (staff refunds). None when there is nothing to refund (COD, unpaid, 0)."""
    if not connection.in_atomic_block:
        raise RuntimeError("refund_order() runs inside the caller's transaction (order locked).")
    if reason not in ORDER_REASONS:
        raise ValueError(f"Not an order refund reason: {reason}")
    existing = Refund.objects.filter(idempotency_key=key).first()
    if existing is not None:
        return existing
    amount = round_money(amount)
    payment = sale_payment(order)
    if payment is None or amount <= ZERO:
        if strict:
            raise ValidationError(MSG_NOT_PAID)
        return None
    cap = refundable(order, payment)
    if amount > cap:
        if strict:
            raise RefundCapExceeded(MSG_ABOVE_REFUNDABLE.format(amount=f"₹{money_str(cap)}"))
        logger.warning("Refund of %s on order %s capped at %s", amount, order.order_number, cap)
        amount = cap
    if amount <= ZERO:
        return None
    refund = request_refund(payment, amount, reason=reason, key=key)
    if initiated_by is not None and refund.initiated_by_id is None:
        refund.initiated_by = initiated_by
        refund.save(update_fields=["initiated_by", "updated_at"])
    settle(order)
    return refund


def fully_refunded(order) -> bool:
    """Everything paid for the order is already being refunded (or was)."""
    if sale_payment(order) is None:
        return False
    order_refunds = Refund.objects.filter(order=order, reason__in=ORDER_REASONS)
    return _committed(order_refunds) >= order.amount_paid


def alert_if_not_refunded(order, refund: Refund | None, *, context: str) -> None:
    """P4 review Minor 2: a paid order that should be refunded must never end silently without
    a refund. When `refund_order` made none and the order is not already fully refunded (e.g.
    no sale payment found), log at ERROR and raise the ops alert `payment.refund_failed`."""
    from apps.orders import events

    if refund is not None or order.amount_paid <= ZERO or fully_refunded(order):
        return
    logger.error(
        "No refund made for paid order %s (%s): amount_paid %s, refundable %s",
        order.order_number,
        context,
        order.amount_paid,
        refundable(order),
    )
    events.emit(events.REFUND_FAILED, order.pk)


def settle(order) -> None:
    """Order `payment_status` and `amount_refunded` from its standing order refunds (08 §4 rule
    4). No-op for an order without order refunds. The caller holds the order row lock."""
    from apps.orders.choices import PaymentStatus

    refunds = live_refunds(list(Refund.objects.filter(order=order, reason__in=ORDER_REASONS)))
    if not refunds:
        return
    processed = sum((r.amount for r in refunds if r.status == RefundStatus.PROCESSED), ZERO)
    pending = any(r.status != RefundStatus.PROCESSED for r in refunds)
    if pending:
        status = PaymentStatus.REFUND_PENDING
    elif processed >= order.amount_paid:
        status = PaymentStatus.REFUNDED
    else:
        status = PaymentStatus.PARTIALLY_REFUNDED
    processed = min(processed, max(order.amount_paid, order.grand_total))
    if order.payment_status != status or order.amount_refunded != processed:
        order.payment_status = status
        order.amount_refunded = processed
        order.save(update_fields=["payment_status", "amount_refunded", "updated_at"])


@receiver(post_save, sender=Refund, dispatch_uid="payments.settle_order_refund")
def _settle_on_refund_change(sender, instance: Refund, **kwargs) -> None:
    """Any save of an order refund (created, processed, failed: by the task, the webhook or the
    sync job) settles its order under the order row lock (lock order: order, then refund)."""
    if instance.reason not in ORDER_REASONS:
        return
    from apps.orders.models import Order

    with transaction.atomic():
        order = Order.objects.select_for_update().get(pk=instance.order_id)
        settle(order)


# --------------------------------------------------------------------------- policy (08 §6.4)


def failed_delivery_refund(order, *, customer_fault: bool) -> Decimal:
    """08 §6.4 (D-10 defaults): a failed delivery refunds everything still refundable; when the
    customer was at fault (not reachable, refused) the delivery fee is kept if
    `REFUND_KEEP_DELIVERY_FEE_ON_CUSTOMER_FAULT` (default True). Used by T13 in Phase 5."""
    amount = refundable(order)
    if customer_fault and settings.REFUND_KEEP_DELIVERY_FEE_ON_CUSTOMER_FAULT:
        amount = max(amount - order.delivery_fee, ZERO)
    return amount


# --------------------------------------------------------------------------- staff (05 §3)


def _is_capped(user) -> bool:
    """DL-59: Super Admin and Finance refund without caps; anyone else allowed to refund
    (Support) is capped (`SUPPORT_REFUND_LIMIT` per order, `SUPPORT_REFUND_DAILY_LIMIT` a day)."""
    from apps.accounts import roles

    if user.is_superuser:
        return False
    return not user.groups.filter(name__in=[roles.SUPER_ADMIN, roles.FINANCE]).exists()


def _capped_staff_ids(user_ids) -> set[int]:
    from apps.accounts import roles
    from apps.accounts.models import User

    uncapped = User.objects.filter(pk__in=user_ids).filter(
        Q(is_superuser=True) | Q(groups__name__in=[roles.SUPER_ADMIN, roles.FINANCE])
    )
    return set(user_ids) - set(uncapped.values_list("pk", flat=True))


def support_refunded_on_order(order) -> Decimal:
    """Manual refunds standing on the order that capped staff (Support) issued (DL-59)."""
    manual = live_refunds(list(Refund.objects.filter(order=order, reason=MANUAL)))
    capped = _capped_staff_ids({r.initiated_by_id for r in manual if r.initiated_by_id})
    return sum((r.amount for r in manual if r.initiated_by_id in capped), ZERO)


def ist_day_start(now=None):
    """The start of the current IST day (`STAFF_TIME_ZONE`), as an aware datetime."""
    zone = ZoneInfo(settings.STAFF_TIME_ZONE)
    local = timezone.localtime(now or timezone.now(), zone)
    return local.replace(hour=0, minute=0, second=0, microsecond=0)


def refunded_today_by(user, now=None) -> Decimal:
    """Manual refunds standing that `user` issued since the start of the IST day (DL-59)."""
    refunds = Refund.objects.filter(
        reason=MANUAL, initiated_by=user, created_at__gte=ist_day_start(now)
    )
    return _committed(refunds)


def _check_caps(order, amount: Decimal, by) -> None:
    """DL-59, under the order lock and the refunder's user-row lock (so two refunds by one agent
    on two orders cannot both pass the daily cap)."""
    order_limit = round_money(settings.SUPPORT_REFUND_LIMIT)
    left = max(order_limit - support_refunded_on_order(order), ZERO)
    if amount > left:
        raise RefundCapExceeded(
            MSG_ABOVE_LIMIT.format(limit=f"₹{money_str(order_limit)}", left=f"₹{money_str(left)}")
        )
    daily_limit = round_money(settings.SUPPORT_REFUND_DAILY_LIMIT)
    left = max(daily_limit - refunded_today_by(by), ZERO)
    if amount > left:
        raise RefundCapExceeded(
            MSG_ABOVE_DAILY_LIMIT.format(
                limit=f"₹{money_str(daily_limit)}", left=f"₹{money_str(left)}"
            )
        )


def _alert_on_refund_volume(order, by) -> None:
    """DL-59: ops alert `payment.refund_volume_high` when one staff member has issued more than
    `REFUND_VOLUME_ALERT_PER_HOUR` manual refunds in the last hour; at most once per member per
    hour (a cache key; without Redis the alert is still raised)."""
    from django.core.cache import cache

    from apps.orders import events

    since = timezone.now() - timedelta(hours=1)
    count = Refund.objects.filter(reason=MANUAL, initiated_by=by, created_at__gte=since).count()
    if count <= settings.REFUND_VOLUME_ALERT_PER_HOUR:
        return
    try:
        first = cache.add(f"refund-volume-alert:{by.pk}", 1, timeout=60 * 60)
    except Exception:
        logger.warning("refund volume alert dedupe unavailable", exc_info=True)
        first = True
    if first:
        logger.error("Refund volume: staff %s issued %s refunds in the last hour", by.pk, count)
        events.emit(events.REFUND_VOLUME_HIGH, order.pk)


def can_refund(user) -> bool:
    from apps.accounts.roles import REFUND_ISSUE

    return bool(user and user.is_active and user.is_staff and user.has_perm(REFUND_ISSUE))


def staff_refund_orders(user):
    """Orders a refunder may act on: every store they may see (`stores_for`)."""
    from apps.orders.models import Order
    from apps.stores.services import stores_for

    return Order.objects.filter(store__in=stores_for(user))


def manual_refund(order_id: int, amount: Decimal, *, by, note: str = "") -> Refund:
    """A staff refund (full or partial) of an ONLINE order (05 §2 Orders "refund", §3 Refund).
    Super Admin and Finance: no cap. Support (DL-59): `SUPPORT_REFUND_LIMIT` in total per order
    and `SUPPORT_REFUND_DAILY_LIMIT` per IST day. Never more than is still refundable. Audited.
    Raises `PermissionDenied` or `ValidationError` (`RefundCapExceeded` above a cap)."""
    if not can_refund(by):
        raise PermissionDenied(MSG_NO_PERMISSION)
    from apps.accounts.models import User

    amount = round_money(Decimal(amount))
    if amount <= ZERO:
        raise ValidationError("Enter an amount above zero.")
    capped = _is_capped(by)
    with transaction.atomic():
        order = staff_refund_orders(by).select_for_update().filter(pk=order_id).first()
        if order is None:
            raise ValidationError("Order not found.")
        if capped:
            User.objects.select_for_update().filter(pk=by.pk).first()  # Lock: the refunder
            _check_caps(order, amount, by)
        number = Refund.objects.filter(order=order, reason=MANUAL).count() + 1
        refund = refund_order(
            order,
            amount,
            reason=MANUAL,
            key=f"manual:{order.pk}:{number}",
            initiated_by=by,
            strict=True,
        )
        audit.record(
            by,
            "refund.issue",
            order,
            {"refund_id": refund.pk, "amount": money_str(amount), "note_length": len(note or "")},
        )
        _alert_on_refund_volume(order, by)
    return refund


def retry_refund(refund_id: int, *, by) -> Refund:
    """T-401c, the ops retry hook: a FAILED refund gets a new attempt
    (`refunds.retry_failed_refund`, a new row and receipt); a PENDING refund the gateway never
    answered (no gateway id, older than `REFUND_STUCK_MINUTES`) is sent again (the task looks
    up an earlier refund by receipt first, so it never refunds twice). Audited."""
    if not can_refund(by):
        raise PermissionDenied(MSG_NO_PERMISSION)
    from apps.payments.tasks import process_refund

    with transaction.atomic():
        orders = staff_refund_orders(by)
        refund = Refund.objects.filter(pk=refund_id, order__in=orders).first()
        if refund is None:
            raise ValidationError(MSG_REFUND_NOT_FOUND)
        orders.select_for_update().filter(pk=refund.order_id).first()  # lock order: order first
        refund = Refund.objects.select_for_update().get(pk=refund.pk)
        stale = timezone.now() - timedelta(minutes=settings.REFUND_STUCK_MINUTES)
        if refund.status == RefundStatus.FAILED:
            if Refund.objects.filter(
                idempotency_key__startswith=f"{_base_key(refund.idempotency_key)}:retry-",
                created_at__gt=refund.created_at,
            ).exists():
                raise ValidationError("This refund has already been retried.")
            result = retry_failed_refund(refund, initiated_by=by)
        elif (
            refund.status == RefundStatus.PENDING
            and not refund.gateway_refund_id
            and refund.updated_at <= stale
        ):
            refund_pk = refund.pk
            transaction.on_commit(lambda: process_refund.delay(refund_pk))
            result = refund
        else:
            raise ValidationError(MSG_NOT_RETRYABLE)
        audit.record(
            by,
            "refund.retry",
            ("payments.refund", refund.pk),
            {"order_id": refund.order_id, "new_refund_id": result.pk},
        )
    return result


# --------------------------------------------------------------------------- sync (06 §5)


def sync_refund_status(now=None, limit: int = 200) -> dict:
    """06 §5 `sync_refund_status` (beat, every 30 min): refunds still PENDING.
    - With a gateway id: ask the gateway (outside any row lock) and record what it says.
    - Without one, older than `REFUND_STUCK_MINUTES`: the task never finished; send it again
      (`process_refund` adopts a refund the gateway already made for the receipt).
    Idempotent: `record_refund_status` ignores repeats."""
    from apps.payments.gateways import PaymentGatewayError, get_gateway
    from apps.payments.tasks import process_refund

    now = now or timezone.now()
    counts: dict[str, int] = {}

    def bump(name: str) -> None:
        counts[name] = counts.get(name, 0) + 1

    pending = list(
        Refund.objects.filter(status=RefundStatus.PENDING)
        .select_related("payment")
        .order_by("updated_at")[:limit]
    )
    gateway = get_gateway() if pending else None
    stale = now - timedelta(minutes=settings.REFUND_STUCK_MINUTES)
    for refund in pending:
        if not refund.gateway_refund_id:
            if refund.updated_at <= stale:
                process_refund.delay(refund.pk)
                bump("resent")
            else:
                bump("waiting")
            continue
        try:
            found = gateway.fetch_payment_refunds(refund.payment.gateway_payment_id)
        except PaymentGatewayError as exc:
            logger.warning("Refund %s status not synced: %s", refund.pk, exc)
            bump("error")
            continue
        match = next((item for item in found if item.id == refund.gateway_refund_id), None)
        if match is None:
            bump("unknown")
            continue
        if record_refund_status(refund, match.status, match.id):
            bump("processed")
        else:
            bump("unchanged")
    return counts


@shared_task(name="payments.sync_refund_status")
def sync_refund_status_task() -> dict:
    """06 §5, beat every 30 min. Lives here (not in `tasks.py`) to keep Phase 4 refund code
    apart from the Phase 3 refund task; registered when the app loads (`PaymentsConfig.ready`)."""
    return sync_refund_status()
