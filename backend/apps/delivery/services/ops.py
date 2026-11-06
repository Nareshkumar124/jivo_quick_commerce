"""Ops actions on a delivery (05 §1.4; slice 5.4), for the Ops Console and the admin.

Permission (DL-61 a): `delivery.dispatch_order`: Super Admin, Ops/Dispatch, Store Manager for
their own stores; not Store Staff, Support or Finance. Every action finds the order in the
user's stores (`staff_orders`), locks the order then the task,
re-checks the state, changes it through the delivery/order services and is audited.

- `unlock_pickup`: after `PICKUP_CODE_MAX_ATTEMPTS` wrong order codes (423), give the rider new
  tries (the code is unchanged; the store reads it from the label).
- `unlock_delivery_otp`: after 5 wrong delivery OTPs (423), give the rider 5 new tries with the
  same OTP (the customer still has it on order detail).
- `confirm_delivery`: ops check the OTP the customer reads to them (a call) and complete T10
  for the rider, e.g. when the rider's app cannot. COD: the server's amount due; `cod_mode`
  cash (into the rider's cash in hand) or upi (the task's QR must be PAID). A wrong OTP is
  refused and audited (no lock: staff are accountable).
- `fail_delivery`: ops mark T13 (e.g. a wrong address resolved with the customer), without the
  rider's 10-minute wait; refunds as for the rider (08 §6.4).
- T14 (receiving the return) stays `orders.store_ops.receive_return` (same permission, DL-61).
- `lift_cod_block`: DL-61 (d) ops lift a customer's automatic COD block (`delivery.lift_cod_block`:
  Super Admin, Ops); only refusals after the lift count again.
- Read side: `rider_board` (05 §1.4 rider list/map, polled until P6) and `assignable_riders`
  (manual dispatch: idle riders of the order's store with their distance).
"""

import secrets
from datetime import datetime

from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.utils import timezone

from apps.accounts.choices import RiderStatus
from apps.core import audit
from apps.core.crypto import decrypt
from apps.core.money import money_str
from apps.delivery import hooks
from apps.delivery.choices import CodMode, DeliveryFailReason
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import RIDER_BUSY_STATUSES, DeliveryTask, Rider
from apps.delivery.services import cod_qr, dispatch, tasks
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod
from apps.stores.services import stores_for

MSG_TASK = "This order has no delivery in that state."
MSG_NOT_LOCKED = "Nothing is locked."
MSG_OTP = "The OTP does not match."
MSG_COD_MODE = "Choose how the customer paid: cash or UPI."
MSG_UPI_NOT_PAID = "The UPI payment is not confirmed yet."
MSG_PAID_BY_UPI = "The customer already paid by UPI: choose UPI."
MSG_NOTE = "Enter a note."


def _locked(by, order_id: int):
    order = dispatch._ops_order(by, order_id)
    task = DeliveryTask.objects.select_for_update(of=("self",)).filter(order=order).first()
    if task is None:
        raise ValidationError(MSG_TASK)
    return order, task


def _tell_rider(task: DeliveryTask, order) -> None:
    """Ops changed the rider's task: `task.updated` (STATUS_CHANGED) and the push."""
    hooks.task_updated(
        task,
        order,
        "STATUS_CHANGED",
        push_event="rider.task_updated",
        push_data={
            "task_id": task.pk,
            "order_number": order.order_number,
            "ref": f"{task.pk}:{task.status}:{timezone.now().isoformat()}",
        },
    )


def unlock_pickup(order_id: int, *, by, ip: str | None = None) -> DeliveryTask:
    with transaction.atomic():
        order, task = _locked(by, order_id)
        if task.status != TS.AT_STORE:
            raise ValidationError(MSG_TASK)
        if task.pickup_locked_at is None and task.pickup_attempts == 0:
            raise ValidationError(MSG_NOT_LOCKED)
        task.pickup_attempts = 0
        task.pickup_locked_at = None
        task.save(update_fields=["pickup_attempts", "pickup_locked_at", "updated_at"])
        audit.record(by, "delivery.unlock_pickup", order, {"task": task.pk}, ip=ip)
        _tell_rider(task, order)
    return task


def unlock_delivery_otp(order_id: int, *, by, ip: str | None = None) -> DeliveryTask:
    with transaction.atomic():
        order, task = _locked(by, order_id)
        if task.status != TS.AT_CUSTOMER:
            raise ValidationError(MSG_TASK)
        if task.otp_locked_at is None and task.otp_attempts == 0:
            raise ValidationError(MSG_NOT_LOCKED)
        task.otp_attempts = 0
        task.otp_locked_at = None
        task.save(update_fields=["otp_attempts", "otp_locked_at", "updated_at"])
        audit.record(by, "delivery.unlock_delivery_otp", order, {"task": task.pk}, ip=ip)
        _tell_rider(task, order)
    return task


def confirm_delivery(
    order_id: int, *, otp: str, cod_mode: str | None = None, by, ip: str | None = None
) -> DeliveryTask:
    now = timezone.now()
    with transaction.atomic():
        order, task = _locked(by, order_id)
        if task.status != TS.AT_CUSTOMER or task.rider_id is None:
            raise ValidationError(MSG_TASK)
        cod = None
        if order.payment_method == PaymentMethod.COD:
            if cod_mode not in CodMode.values:
                raise ValidationError(MSG_COD_MODE)
            paid = cod_qr.paid_qr(task)
            if cod_mode == CodMode.UPI and (paid is None or paid.amount != order.grand_total):
                raise ValidationError(MSG_UPI_NOT_PAID)
            if cod_mode == CodMode.CASH and paid is not None:
                raise ValidationError(MSG_PAID_BY_UPI)
            cod = {"mode": cod_mode, "amount": order.grand_total}
        expected = decrypt(task.delivery_otp_encrypted)
        given = (otp or "").strip()
        if not (given.isascii() and expected and secrets.compare_digest(given, expected)):
            audit.record(by, "delivery.ops_otp_wrong", order, {"task": task.pk}, ip=ip)
            wrong = True
        else:
            wrong = False
            rider = Rider.objects.select_related("user").get(pk=task.rider_id)
            tasks._complete(
                rider,
                order,
                task,
                cod,
                now,
                actor=by,
                actor_type=ActorType.OPS,
                note="T10: delivered (OTP verified by ops)",
            )
            audit.record(
                by,
                "delivery.ops_confirm_delivery",
                order,
                {"task": task.pk, "cod": cod_mode},
                ip=ip,
            )
            _tell_rider(task, order)
    if wrong:  # raised after commit, so the audit entry stays
        raise ValidationError(MSG_OTP)
    return task


def fail_delivery(
    order_id: int, *, reason: str, note: str = "", by, ip: str | None = None
) -> DeliveryTask:
    if reason not in DeliveryFailReason.values:
        raise ValidationError("Choose a reason.")
    note = " ".join((note or "").split())[:300]
    if not note:
        raise ValidationError(MSG_NOTE)
    now = timezone.now()
    with transaction.atomic():
        order, task = _locked(by, order_id)
        if task.status not in (TS.PICKED_UP, TS.AT_CUSTOMER) or (
            order.status != OrderStatus.OUT_FOR_DELIVERY
        ):
            raise ValidationError(MSG_TASK)
        tasks.fail_locked(
            order,
            task,
            reason=reason,
            note=note,
            actor=by,
            actor_type=ActorType.OPS,
            now=now,
        )
        hooks.task_updated(
            task,
            order,
            "STATUS_CHANGED",
            push_event="rider.return_to_store",
            push_data={
                "task_id": task.pk,
                "order_number": order.order_number,
                "store_name": order.store.name,
            },
        )
        audit.record(
            by,
            "delivery.ops_fail_delivery",
            order,
            {"task": task.pk, "reason": reason, "note_length": len(note)},
            ip=ip,
        )
    return task


# --------------------------------------------------------------------------- read side


def _state(rider: Rider, task: DeliveryTask | None) -> str:
    if not rider.is_online and task is None:
        return "offline"
    if task is None:
        return "idle"
    return {
        TS.ASSIGNED: "to_store",
        TS.AT_STORE: "at_store",
        TS.PICKED_UP: "delivering",
        TS.AT_CUSTOMER: "delivering",
        TS.FAILED: "returning",
        TS.RETURNING: "returning",
    }.get(task.status, "idle")


def rider_board(user, store_id: int | None = None, now: datetime | None = None) -> list[dict]:
    """05 §1.4 side list / map: ACTIVE riders of the user's stores (online, or on a task), with
    state (idle / to_store / at_store / delivering / returning / offline), current task, cash
    in hand and last ping age. Needs `delivery.dispatch_order` or `delivery.view_rider`."""
    if not (dispatch.can_dispatch(user) or user.has_perm("delivery.view_rider")):
        raise PermissionDenied(dispatch.MSG_NO_PERMISSION)
    now = now or timezone.now()
    riders = Rider.objects.filter(
        status=RiderStatus.ACTIVE, home_store__in=stores_for(user)
    ).select_related("home_store")
    if store_id is not None:
        riders = riders.filter(home_store_id=store_id)
    riders = list(riders)
    active = {
        task.rider_id: task
        for task in DeliveryTask.objects.filter(
            rider__in=riders, status__in=RIDER_BUSY_STATUSES
        ).select_related("order")
    }
    board = []
    for rider in riders:
        task = active.get(rider.pk)
        if not rider.is_online and task is None:
            continue
        received = rider.last_location_received_at
        point = rider.current_location
        board.append(
            {
                "rider_id": rider.pk,
                "name": rider.full_name,
                "store_id": rider.home_store_id,
                "state": _state(rider, task),
                "is_online": rider.is_online,
                "lat": point.y if point else None,
                "lng": point.x if point else None,
                "last_ping_age_seconds": (
                    int((now - received).total_seconds()) if received else None
                ),
                "cash_in_hand": money_str(rider.cash_in_hand),
                "cash_limit": money_str(rider.cash_limit),
                "cash_limit_reached": rider.cash_limit_reached,
                "task": (
                    {
                        "task_id": task.pk,
                        "order_id": task.order_id,
                        "order_number": task.order.order_number,
                        "status": task.status,
                        "pickup_locked": task.pickup_locked_at is not None,
                        "otp_locked": task.otp_locked_at is not None,
                    }
                    if task
                    else None
                ),
            }
        )
    return board


def assignable_riders(order_id: int, *, by) -> list[dict]:
    """Manual dispatch (05 §1.4): idle online riders of the order's store, nearest first, with
    their distance to the store and whether the cash limit allows this order (COD)."""
    from apps.orders.store_ops import staff_orders

    if not dispatch.can_dispatch(by):
        raise PermissionDenied(dispatch.MSG_NO_PERMISSION)
    order = staff_orders(by).select_related("store").filter(pk=order_id).first()
    if order is None:
        raise ValidationError(dispatch.MSG_ORDER_NOT_FOUND)
    from django.contrib.gis.db.models.functions import Distance
    from django.db.models import Exists, OuterRef

    busy = DeliveryTask.objects.filter(rider=OuterRef("pk"), status__in=RIDER_BUSY_STATUSES)
    riders = (
        Rider.objects.filter(
            status=RiderStatus.ACTIVE,
            is_online=True,
            home_store_id=order.store_id,
            current_location__isnull=False,
        )
        .exclude(Exists(busy))
        .annotate(distance=Distance("current_location", order.store.location))
        .order_by("distance", "pk")
    )
    cod = order.payment_method == PaymentMethod.COD
    return [
        {
            "rider_id": rider.pk,
            "name": rider.full_name,
            "distance_m": round(rider.distance.m),
            "cash_in_hand": money_str(rider.cash_in_hand),
            "within_cash_limit": (not cod)
            or rider.cash_in_hand + order.grand_total <= rider.cash_limit,
        }
        for rider in riders
    ]


# --------------------------------------------------------------------------- COD block (DL-61 d)


LIFT_PERMISSION = "delivery.lift_cod_block"


def lift_cod_block(user_id: int, *, by, ip: str | None = None) -> bool:
    """Let a customer pay cash on delivery again. Returns whether anything changed. Audited."""
    from apps.accounts.models import User

    if not (by and by.is_active and by.is_staff and by.has_perm(LIFT_PERMISSION)):
        raise PermissionDenied(dispatch.MSG_NO_PERMISSION)
    with transaction.atomic():
        customer = User.objects.select_for_update().filter(pk=user_id, is_staff=False).first()
        if customer is None:
            raise ValidationError("Customer not found.")
        if not customer.cod_blocked:
            return False
        customer.cod_blocked = False
        customer.cod_block_lifted_at = timezone.now()
        customer.save(update_fields=["cod_blocked", "cod_block_lifted_at", "updated_at"])
        audit.record(by, "accounts.cod_block_lifted", customer, {}, ip=ip)
    return True
