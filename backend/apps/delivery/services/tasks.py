"""The rider's delivery task (06 §3, 04 §2.5-2.6, 08 T9/T10/T13; slice 5.3).

Every action finds the task in the caller's own tasks (another rider's id: 404), then locks the
Order row and the task (the global lock order: order, task, offers, rider) and re-checks the
state. Order states change only through `orders.services.transition()`.

- arrived-store: ASSIGNED -> AT_STORE within the store geofence (200 m + accuracy, max +50 m).
- pickup (T9): AT_STORE and the order PACKED, with the 4-character code or the bag QR
  `JQC1:<order_number>:<code>`. Commits the stock (`on_hand -= qty`, `StockMovement(SALE)`),
  generates the 4-digit delivery OTP, order OUT_FOR_DELIVERY, task PICKED_UP.
- arrived-customer: PICKED_UP -> AT_CUSTOMER within the drop geofence, or with an override
  reason (logged for ops).
- deliver (T10): AT_CUSTOMER; the COD collection is checked first (exact amount; no OTP attempt
  used on a mismatch), then the OTP: 5 wrong tries lock it (423); only ops can help then (the
  rider cannot reset it, and no COD path skips it).
- fail (T13): PICKED_UP/AT_CUSTOMER -> order DELIVERY_FAILED, task RETURNING; refunds per 08
  §6.4. The store receives the items with `orders.store_ops.receive_return` (T14).
"""

import logging
import re
import secrets
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.core.files.base import ContentFile
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import User
from apps.core.crypto import decrypt, encrypt
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.delivery import hooks
from apps.delivery.choices import CashEntryType, CodMode, DeliveryFailReason
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import RIDER_BUSY_STATUSES, DeliveryTask, Rider
from apps.delivery.services import cod_qr, earnings
from apps.delivery.services.cash import record_cash
from apps.delivery.services.riders import require_rider
from apps.delivery.services.shifts import distance_m
from apps.inventory import services as inventory
from apps.orders import events
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.models import Order
from apps.orders.services import transition

logger = logging.getLogger(__name__)

MSG_TASK_NOT_FOUND = "Task not found."
MSG_NOT_HEADING = "This task is not heading to the store."
MSG_NOT_AT_STORE = "Mark arrived at the store first."
MSG_NOT_PACKED = "The order is not packed yet."
MSG_NOT_PICKED = "Pick up the order first."
MSG_NOT_AT_CUSTOMER = "Mark arrived at the customer first."
MSG_NOT_OUT = "This order is not out for delivery."
MSG_WAIT = "Wait 10 minutes at the drop location first."
MSG_UPI_NOT_PAID = "The UPI payment is not confirmed yet."
MSG_COD_REQUIRED = "Collect the payment: send `cod` for this cash-on-delivery order."
MSG_PREPAID = "This order is prepaid: there is nothing to collect."
MSG_PAID_BY_UPI = "The customer has already paid by UPI: deliver with `cod.mode` = upi."
QR_PATTERN = re.compile(r"^JQC1:(?P<number>[A-Z0-9-]{1,40}):(?P<code>[A-Z0-9]{4})$")
CODE_PATTERN = re.compile(r"^[A-Za-z0-9]{4}$")
CUSTOMER_FAULT_REASONS = frozenset(
    {DeliveryFailReason.CUSTOMER_NOT_REACHABLE, DeliveryFailReason.CUSTOMER_REFUSED}
)


# --------------------------------------------------------------------------- lookup


def active_task(rider: Rider) -> DeliveryTask | None:
    return (
        DeliveryTask.objects.select_related("order__store", "store")
        .filter(rider=rider, status__in=RIDER_BUSY_STATUSES)
        .first()
    )


def recent_task(rider: Rider, now=None) -> DeliveryTask | None:
    now = now or timezone.now()
    since = now - timedelta(seconds=settings.RIDER_RECENT_TASK_SECONDS)
    return (
        DeliveryTask.objects.select_related("order")
        .filter(
            rider=rider,
            status__in=[TS.DELIVERED, TS.RETURNED, TS.CANCELLED],
            ended_at__gte=since,
        )
        .order_by("-ended_at")
        .first()
    )


def _locked(user, task_id: int) -> tuple[Rider, Order, DeliveryTask]:
    """The caller's task (404 otherwise), locked in the global order (order, then task)."""
    rider = require_rider(user, active=True)
    probe = DeliveryTask.objects.filter(pk=task_id, rider=rider).values("order_id").first()
    if probe is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TASK_NOT_FOUND)
    order = (
        Order.objects.select_for_update(of=("self",))
        .select_related("store", "user")
        .get(pk=probe["order_id"])
    )
    task = DeliveryTask.objects.select_for_update(of=("self",)).get(pk=task_id)
    if task.rider_id != rider.pk:  # reassigned between the lookup and the lock
        raise ApiError(ErrorCode.NOT_FOUND, MSG_TASK_NOT_FOUND)
    return rider, order, task


lock_task = _locked  # for the other delivery services (cod_qr)


def _state(message: str, task: DeliveryTask, order: Order, **extra) -> ApiError:
    return ApiError(
        ErrorCode.INVALID_STATE_TRANSITION,
        message,
        details={"status": task.status, "order_status": order.status, **extra},
    )


def _geofence(lat, lng, accuracy, target_lat, target_lng, radius: int) -> tuple[int, int]:
    """`(distance_m, effective_radius_m)`; inside when distance <= radius."""
    slack = min(accuracy or 0, settings.RIDER_GEOFENCE_MAX_ACCURACY_SLACK_M)
    return distance_m(lat, lng, target_lat, target_lng), round(radius + slack)


def _outside(distance: int, radius: int, place: str) -> ApiError:
    return ApiError(
        ErrorCode.OUTSIDE_GEOFENCE,
        f"You are {distance} m from the {place}. Arrive within {radius} m.",
        details={"distance_m": distance, "radius_m": radius},
    )


def _after_commit(func, *args) -> None:
    transaction.on_commit(lambda: func(*args))


# --------------------------------------------------------------------------- store


def arrived_store(user, task_id: int, *, lat, lng, accuracy=None, now=None) -> DeliveryTask:
    now = now or timezone.now()
    with transaction.atomic():
        _rider, order, task = _locked(user, task_id)
        if task.status == TS.AT_STORE:
            return task
        if task.status != TS.ASSIGNED:
            raise _state(MSG_NOT_HEADING, task, order)
        store = order.store
        distance, radius = _geofence(
            lat, lng, accuracy, store.location.y, store.location.x, settings.RIDER_STORE_GEOFENCE_M
        )
        if distance > radius:
            raise _outside(distance, radius, "store")
        task.status = TS.AT_STORE
        task.arrived_store_at = now
        task.save(update_fields=["status", "arrived_store_at", "updated_at"])
    return task


def code_format_ok(submitted: str) -> bool:
    """ASCII only: the 4-character code, or the bag QR `JQC1:<order_number>:<code>`. Checked
    before any case folding (non-ASCII `upper()` maps the dotless i to "I", the long s to "S")."""
    value = (submitted or "").strip()
    return value.isascii() and bool(CODE_PATTERN.match(value) or QR_PATTERN.match(value.upper()))


def _code_matches(order: Order, submitted: str) -> bool:
    if not code_format_ok(submitted):
        return False
    value = submitted.strip().upper()
    match = QR_PATTERN.match(value)
    if match:
        if match["number"] != order.order_number.upper():
            return False
        value = match["code"]
    expected = (order.pickup_code or "").upper()
    return bool(expected) and secrets.compare_digest(
        value.encode("ascii"), expected.encode("ascii")
    )


def pickup_attempts_remaining(task: DeliveryTask) -> int:
    return max(settings.PICKUP_CODE_MAX_ATTEMPTS - task.pickup_attempts, 0)


def pickup(user, task_id: int, *, order_code: str, now=None) -> DeliveryTask:
    """08 T9. A wrong code counts (after commit); after `PICKUP_CODE_MAX_ATTEMPTS` wrong codes
    the pickup is locked (423 `PICKUP_CODE_LOCKED`, ops alerted; ops reassign or, from slice
    5.4, unlock)."""
    now = now or timezone.now()
    wrong = None
    with transaction.atomic():
        rider, order, task = _locked(user, task_id)
        if task.status == TS.PICKED_UP:
            return task
        if task.status != TS.AT_STORE:
            raise _state(MSG_NOT_AT_STORE, task, order)
        if order.status != OrderStatus.PACKED:
            raise _state(MSG_NOT_PACKED, task, order)
        if task.pickup_locked_at is not None:
            raise ApiError(ErrorCode.PICKUP_CODE_LOCKED, details={"attempts_remaining": 0})
        if not _code_matches(order, order_code):
            task.pickup_attempts += 1
            if task.pickup_attempts >= settings.PICKUP_CODE_MAX_ATTEMPTS:
                task.pickup_locked_at = now
            task.save(update_fields=["pickup_attempts", "pickup_locked_at", "updated_at"])
            wrong = task
        else:
            _commit_pickup(rider, order, task, now)
    if wrong is not None:  # raised after commit, so the attempt counts
        if wrong.pickup_locked_at is not None:
            hooks.ops_alert(
                "PICKUP_CODE_LOCKED",
                {"order_id": order.pk, "order_number": order.order_number, "task_id": wrong.pk},
            )
            raise ApiError(ErrorCode.PICKUP_CODE_LOCKED, details={"attempts_remaining": 0})
        raise ApiError(
            ErrorCode.PICKUP_CODE_INVALID,
            details={"attempts_remaining": pickup_attempts_remaining(wrong)},
        )
    logger.info("Order %s picked up by rider %s", order.pk, rider.pk)
    return task


def _commit_pickup(rider: Rider, order: Order, task: DeliveryTask, now) -> None:
    """T9 under the order and task locks."""
    transition(
        order,
        OrderStatus.OUT_FOR_DELIVERY,
        actor=rider.user,
        actor_type=ActorType.RIDER,
        note="T9: picked up by the rider",
        now=now,
    )
    if not inventory.commit_reservations(order, actor=rider.user) and order.items.exists():
        # No ACTIVE reservation to commit: the stock ledger would miss this sale.
        logger.warning("Order %s picked up with no active stock reservation", order.pk)
        data = {"order_id": order.pk, "order_number": order.order_number}
        _after_commit(hooks.ops_alert, "STOCK_NOT_COMMITTED", data)
    digits = settings.DELIVERY_OTP_LENGTH
    otp = f"{secrets.randbelow(10**digits):0{digits}d}"
    task.delivery_otp_encrypted = encrypt(otp)
    task.otp_attempts = 0
    task.otp_locked_at = None
    task.status = TS.PICKED_UP
    task.picked_up_at = now
    task.save()
    earnings.record_trip_earnings(task, now)  # DL-61 (c): earned at pickup
    # 08 §9 T9: push (+SMS) with the OTP, through the P6 notifications (deduplicated per order).
    extra = {"rider_name": rider.user.name or "Your rider", "otp": otp}
    transaction.on_commit(lambda: hooks.notify_order(order, "order.out_for_delivery", **extra))


# --------------------------------------------------------------------------- customer


def arrived_customer(
    user, task_id: int, *, lat, lng, accuracy=None, override_reason: str = "", now=None
) -> DeliveryTask:
    now = now or timezone.now()
    with transaction.atomic():
        rider, order, task = _locked(user, task_id)
        if task.status == TS.AT_CUSTOMER:
            return task
        if task.status != TS.PICKED_UP:
            raise _state(MSG_NOT_PICKED, task, order)
        drop = order.delivery_location
        distance, radius = _geofence(
            lat, lng, accuracy, drop.y, drop.x, settings.RIDER_CUSTOMER_GEOFENCE_M
        )
        override = " ".join((override_reason or "").split())
        if distance > radius and not override:
            raise _outside(distance, radius, "drop location")
        task.status = TS.AT_CUSTOMER
        task.arrived_customer_at = now
        task.arrival_override_reason = override if distance > radius else ""
        task.save(
            update_fields=["status", "arrived_customer_at", "arrival_override_reason", "updated_at"]
        )
        if task.arrival_override_reason:
            logger.warning(
                "Rider %s marked arrival %s m from order %s's pin (override)",
                rider.pk,
                distance,
                order.pk,
            )
            alert = {
                "order_id": order.pk,
                "order_number": order.order_number,
                "task_id": task.pk,
                "rider_id": rider.pk,
                "store_id": order.store_id,
                "distance_m": round(distance),
                "reason": task.arrival_override_reason,
            }
            _after_commit(hooks.ops_alert, "ARRIVAL_GEOFENCE_OVERRIDE", alert)
        rider_name = rider.user.name or "Your rider"
        transaction.on_commit(
            lambda: hooks.notify_order(order, "order.rider_arrived", rider_name=rider_name)
        )
    return task


def not_reachable_after(task: DeliveryTask):
    if task.arrived_customer_at is None:
        return None
    return task.arrived_customer_at + timedelta(seconds=settings.RIDER_NOT_REACHABLE_WAIT_SECONDS)


def otp_attempts_remaining(task: DeliveryTask) -> int:
    return max(settings.DELIVERY_OTP_MAX_ATTEMPTS - task.otp_attempts, 0)


def _check_collection(order: Order, task: DeliveryTask, cod: dict | None) -> None:
    """The COD collection, before the OTP (a mismatch uses no OTP attempt). The amount always
    comes from the order: `cod.amount` must equal it; UPI needs the task's QR PAID (confirmed by
    the server) for that amount; cash is refused once the customer paid the QR."""
    if order.payment_method != PaymentMethod.COD:
        if cod:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"cod": [MSG_PREPAID]})
        return
    if not cod:
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"cod": [MSG_COD_REQUIRED]})
    if Decimal(cod["amount"]) != order.grand_total:
        raise ApiError(
            ErrorCode.VALIDATION_ERROR,
            details={
                "cod": {"amount": [f"Collect exactly ₹{order.grand_total}."]},
                "amount_due": str(order.grand_total),
            },
        )
    paid = cod_qr.paid_qr(task)
    if cod["mode"] == CodMode.UPI:
        if paid is None or paid.amount != order.grand_total:
            raise ApiError(ErrorCode.VALIDATION_ERROR, details={"cod": [MSG_UPI_NOT_PAID]})
    elif paid is not None:
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"cod": [MSG_PAID_BY_UPI]})


def deliver(user, task_id: int, *, otp: str, cod: dict | None = None, now=None) -> DeliveryTask:
    """08 T10."""
    now = now or timezone.now()
    failure = None
    if cod and cod.get("mode") == CodMode.UPI:
        # A missed webhook: ask the gateway first (outside the row locks).
        cod_qr.refresh_for_rider(require_rider(user, active=True), task_id)
    with transaction.atomic():
        rider, order, task = _locked(user, task_id)
        if task.status == TS.DELIVERED:
            return task
        if task.status != TS.AT_CUSTOMER:
            raise _state(MSG_NOT_AT_CUSTOMER, task, order)
        if task.otp_locked_at is not None:
            raise ApiError(ErrorCode.DELIVERY_OTP_LOCKED, details={"attempts_remaining": 0})
        _check_collection(order, task, cod)
        if not secrets.compare_digest(otp, decrypt(task.delivery_otp_encrypted)):
            task.otp_attempts += 1
            if task.otp_attempts >= settings.DELIVERY_OTP_MAX_ATTEMPTS:
                task.otp_locked_at = now
            task.save(update_fields=["otp_attempts", "otp_locked_at", "updated_at"])
            failure = task  # raised after commit, so the attempt counts
        else:
            _complete(rider, order, task, cod, now)
    if failure is not None:
        if failure.otp_locked_at is not None:
            hooks.ops_alert(
                "DELIVERY_OTP_LOCKED",
                {"order_id": order.pk, "order_number": order.order_number, "task_id": task.pk},
            )
            raise ApiError(ErrorCode.DELIVERY_OTP_LOCKED, details={"attempts_remaining": 0})
        raise ApiError(
            ErrorCode.DELIVERY_OTP_INVALID,
            details={"attempts_remaining": otp_attempts_remaining(failure)},
        )
    logger.info("Order %s delivered by rider %s", order.pk, rider.pk)
    return task


def _complete(
    rider: Rider,
    order: Order,
    task: DeliveryTask,
    cod: dict | None,
    now,
    *,
    actor=None,
    actor_type: str = ActorType.RIDER,
    note: str = "T10: delivered (OTP)",
) -> None:
    """T10 under the order and task locks: order DELIVERED (COD: COD_COLLECTED), task DELIVERED,
    cash in hand (+), the tip (the per-delivery fee was earned at pickup), the invoice (after
    commit)."""
    changes = {}
    if order.payment_method == PaymentMethod.COD:
        changes["payment_status"] = PaymentStatus.COD_COLLECTED
    transition(
        order,
        OrderStatus.DELIVERED,
        actor=actor or rider.user,
        actor_type=actor_type,
        note=note,
        now=now,
        **changes,
    )
    task.status = TS.DELIVERED
    task.delivered_at = now
    task.ended_at = now
    task.save()
    if order.payment_method == PaymentMethod.COD and cod and cod["mode"] == CodMode.CASH:
        cod_qr.close_open(task, now)
        record_cash(rider, order.grand_total, CashEntryType.COD_COLLECTED, order=order)
    earnings.record_tip(task, order, now)
    events.emit(events.DELIVERED, order.pk)

    def invoice() -> None:
        from apps.orders.tasks import generate_invoice

        generate_invoice.delay(order.pk)

    transaction.on_commit(invoice)


# --------------------------------------------------------------------------- failure (T13)


def fail(
    user,
    task_id: int,
    *,
    reason: str,
    note: str = "",
    call_attempts: int | None = None,
    photo=None,
    now=None,
) -> DeliveryTask:
    """08 T13: the order DELIVERY_FAILED and the task RETURNING (FAILED recorded as `failed_at`).
    Refunds (08 §6.4, D-10 defaults): ONLINE refunds what is still refundable, keeping the
    delivery fee when the customer was at fault (not reachable, refused); COD: nothing due
    (`payment_status` FAILED). Repeated refused COD orders block COD for the customer."""
    now = now or timezone.now()
    with transaction.atomic():
        rider, order, task = _locked(user, task_id)
        if task.status in (TS.FAILED, TS.RETURNING):
            return task
        if task.status not in (TS.PICKED_UP, TS.AT_CUSTOMER):
            raise _state(MSG_NOT_OUT, task, order)
        if reason == DeliveryFailReason.CUSTOMER_NOT_REACHABLE:
            ready_at = not_reachable_after(task)
            if ready_at is None or now < ready_at:
                raise _state(
                    MSG_WAIT,
                    task,
                    order,
                    reason="WAIT_NOT_ELAPSED",
                    not_reachable_after=ready_at.isoformat() if ready_at else None,
                )
        fail_locked(
            order,
            task,
            reason=reason,
            note=note,
            call_attempts=call_attempts,
            photo=photo,
            actor=rider.user,
            actor_type=ActorType.RIDER,
            now=now,
        )
    logger.warning("Order %s delivery failed (%s), rider %s returning", order.pk, reason, rider.pk)
    return task


def fail_locked(
    order: Order,
    task: DeliveryTask,
    *,
    reason: str,
    note: str = "",
    call_attempts: int | None = None,
    photo=None,
    actor,
    actor_type: str,
    now,
) -> None:
    """T13 under the order and task locks (the rider's `fail`, or ops). Refunds per 08 §6.4;
    COD: nothing due, a PENDING UPI QR is closed and a PAID one refunded."""
    from apps.payments import order_refunds

    changes = {}
    if order.payment_method == PaymentMethod.COD:
        changes["payment_status"] = PaymentStatus.FAILED
    transition(
        order,
        OrderStatus.DELIVERY_FAILED,
        actor=actor,
        actor_type=actor_type,
        note=f"T13: delivery failed ({reason})",
        now=now,
        **changes,
    )
    task.status = TS.RETURNING
    task.failed_at = now
    task.fail_reason = reason
    task.fail_note = (note or "").strip()[:300]
    task.fail_call_attempts = call_attempts
    if photo is not None:
        task.fail_photo.save(
            f"task-{task.pk}-{secrets.token_hex(8)}.jpg", _image(photo), save=False
        )
    task.save()
    if order.payment_method == PaymentMethod.ONLINE:
        amount = order_refunds.failed_delivery_refund(
            order, customer_fault=reason in CUSTOMER_FAULT_REASONS
        )
        refund = order_refunds.refund_order(
            order, amount, reason=order_refunds.DELIVERY_FAILED, key=f"failed:{order.pk}"
        )
        order_refunds.alert_if_not_refunded(order, refund, context="T13")
    else:
        cod_qr.on_delivery_failed(task, order, now)
        if reason == DeliveryFailReason.CUSTOMER_REFUSED:
            _maybe_block_cod(order)
    events.emit(events.DELIVERY_FAILED, order.pk)


def _image(photo) -> ContentFile:
    """The optional failure photo, re-encoded as JPEG without metadata (EXIF, GPS)."""
    from apps.delivery.services.riders import _clean_image

    return _clean_image(photo)


def _maybe_block_cod(order: Order) -> None:
    """08 §6.4 / DL-61 (d): after `COD_BLOCK_AFTER_REFUSALS` (2) refused COD deliveries the
    customer may pay online only. Counted over the customer's refused COD deliveries since ops
    last lifted the block (`User.cod_block_lifted_at`), this one included."""
    limit = settings.COD_BLOCK_AFTER_REFUSALS
    if limit <= 0:
        return
    refused = DeliveryTask.objects.filter(
        order__user_id=order.user_id,
        order__payment_method=PaymentMethod.COD,
        fail_reason=DeliveryFailReason.CUSTOMER_REFUSED,
    )
    lifted_at = User.objects.filter(pk=order.user_id).values_list("cod_block_lifted_at", flat=True)
    lifted_at = lifted_at.first()
    if lifted_at is not None:
        refused = refused.filter(failed_at__gt=lifted_at)
    refused = refused.count()
    if refused >= limit:
        changed = User.objects.filter(pk=order.user_id, cod_blocked=False).update(
            cod_blocked=True, updated_at=timezone.now()
        )
        if changed:
            logger.warning(
                "Customer %s COD-blocked after %s refused deliveries", order.user_id, refused
            )


# --------------------------------------------------------------------------- tracking


def delivery_otp(task: DeliveryTask | None, order: Order) -> str | None:
    """The OTP for the order's owner, only while OUT_FOR_DELIVERY (DL-56)."""
    if task is None or order.status != OrderStatus.OUT_FOR_DELIVERY:
        return None
    return decrypt(task.delivery_otp_encrypted) or None
