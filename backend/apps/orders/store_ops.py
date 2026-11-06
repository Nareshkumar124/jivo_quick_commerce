"""Store and ops actions on orders (Phase 4): what the packing console (05 §1.3), the live board
(05 §1.2) and the Orders admin (05 §2) call. Each one:

- checks the caller's permission (05 §3 role matrix, `apps.accounts.roles`) and fetches the
  order **inside the caller's store scope** (`stores_for`), locked; an order outside the scope
  is "not found", never fetched first and checked after;
- changes state only through `orders.services.transition()` (08 §2);
- writes the audit log (05 §5) in the same transaction;
- emits its domain event (notifications after commit, 08 §9).

Errors (for the admin's messages): `django.core.exceptions.PermissionDenied` (role),
`django.core.exceptions.ValidationError` (bad input, order or line not found) and
`apps.core.exceptions.ApiError` with `INVALID_STATE_TRANSITION` (the order is not in a state
that allows the action; `.message` is readable).

System actions (auto-accept, the acceptance SLA alert) are here too.
"""

import logging
import secrets
from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.accounts import roles
from apps.cart import services as cart_services
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.money import money_str
from apps.inventory import services as inventory
from apps.orders import events
from apps.orders.choices import ActorType, OrderStatus, PaymentMethod, StaffCancelReason
from apps.orders.models import Order, OrderItem
from apps.orders.services import cancel_active, transition
from apps.stores.services import stores_for

logger = logging.getLogger(__name__)

PICKUP_CODE_ALPHABET = "ACDEFGHJKLMNPQRTUVWXY34679"  # no 0/O, 1/I, 2/Z, 5/S, 8/B look-alikes
PICKUP_CODE_TRIES = 20

MSG_NO_PERMISSION = "You do not have permission to do this."
MSG_ORDER_NOT_FOUND = "Order not found."
MSG_LINE_NOT_FOUND = "This item is not part of the order."
MSG_STATE = {
    "accept": "Only a newly placed order can be accepted.",
    "start_packing": "Accept the order before packing it.",
    "unavailable": "Items can be marked unavailable only while the order is accepted or packing.",
    "packed": "Only an order being packed can be marked packed.",
    "cancel": "This order can no longer be cancelled here.",
}

# 08 T12: who may cancel, and until when (05 §3 "Cancel order": store manager and support
# "before pickup"; every state T12 allows is before pickup).
STAFF_CANCELLABLE = frozenset(
    {OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PACKING, OrderStatus.PACKED}
)


# --------------------------------------------------------------------------- scope and roles


def staff_orders(user):
    """Orders a staff user may see: those of their stores (05 §3, `stores_for`)."""
    return Order.objects.filter(store__in=stores_for(user))


def actor_type_for(user) -> str:
    """`store` for store roles (Store Manager / Store Staff), `ops` for everyone else."""
    if user.is_superuser:
        return ActorType.OPS
    groups = set(user.groups.values_list("name", flat=True))
    return ActorType.STORE if groups & roles.STORE_SCOPED_ROLES else ActorType.OPS


def can_process(user) -> bool:
    """Packing console (05 §3): Super Admin, Ops, Store Manager (own), Store Staff (own)."""
    return _has(user, roles.ORDER_PROCESS)


def can_cancel(user) -> bool:
    """Cancel order (05 §3): Super Admin, Ops, Store Manager (own), Support."""
    return _has(user, roles.ORDER_CANCEL)


def _has(user, perm: str) -> bool:
    return bool(user and user.is_active and user.is_staff and user.has_perm(perm))


def _locked(user, order_id: int, perm: str) -> Order:
    if not _has(user, perm):
        raise PermissionDenied(MSG_NO_PERMISSION)
    order = (
        staff_orders(user)
        .select_for_update(of=("self",))
        .select_related("store")
        .filter(pk=order_id)
        .first()
    )
    if order is None:
        raise ValidationError(MSG_ORDER_NOT_FOUND)
    return order


def _state_error(order: Order, action: str) -> ApiError:
    return ApiError(
        ErrorCode.INVALID_STATE_TRANSITION, MSG_STATE[action], details={"status": order.status}
    )


# --------------------------------------------------------------------------- T6 accept


def _new_pickup_code(order: Order) -> str:
    """4 characters, unique among the store's active orders (DB constraint). Tried under a
    savepoint, so a clash just picks another code."""
    for _ in range(PICKUP_CODE_TRIES):
        code = "".join(secrets.choice(PICKUP_CODE_ALPHABET) for _ in range(4))
        try:
            with transaction.atomic():
                Order.objects.filter(pk=order.pk).update(pickup_code=code)
        except IntegrityError:
            continue
        return code
    raise RuntimeError(f"No free pickup code for store {order.store_id}")  # pragma: no cover


def _accept(order: Order, *, actor, actor_type: str, note: str) -> Order:
    if order.status != OrderStatus.PLACED:
        raise _state_error(order, "accept")
    transition(order, OrderStatus.ACCEPTED, actor=actor, actor_type=actor_type, note=note)
    if not order.pickup_code:
        order.pickup_code = _new_pickup_code(order)
    events.emit(events.ACCEPTED, order.pk)
    return order


def accept_order(order_id: int, *, by) -> Order:
    """08 T6: the store accepts a PLACED order. A 4-character pickup code is assigned for the
    order slip (the rider confirms pickup with it, T9)."""
    with transaction.atomic():
        order = _locked(by, order_id, roles.ORDER_PROCESS)
        _accept(order, actor=by, actor_type=actor_type_for(by), note="T6: accepted by the store")
        audit.record(by, "order.accept", order, {"status": OrderStatus.ACCEPTED})
    return order


def auto_accept(order_id: int, now=None) -> str:
    """08 T6 by the system for a store with `auto_accept_orders` (06 §5 `auto_accept_orders`).
    `accepted`, or `skipped` (not PLACED any more, store setting off, not due yet). Idempotent."""
    now = now or timezone.now()
    with transaction.atomic():
        order = (
            Order.objects.select_for_update(of=("self",), skip_locked=True)
            .select_related("store")
            .filter(pk=order_id)
            .first()
        )
        if order is None or order.status != OrderStatus.PLACED:
            return "skipped"
        if not order.store.auto_accept_orders:
            return "skipped"
        due = (order.placed_at or now) + timedelta(seconds=settings.AUTO_ACCEPT_DELAY_SECONDS)
        if due > now:
            return "skipped"
        _accept(order, actor=None, actor_type=ActorType.SYSTEM, note="T6: auto-accepted")
    return "accepted"


# --------------------------------------------------------------------------- acceptance SLA


def _sla_key(order_id: int) -> str:
    return f"orders:acceptance_sla_alerted:{order_id}"


def acceptance_sla_alert(order_id: int, now=None) -> str:
    """06 §5 `store_acceptance_sla_alert` (08 §9: store re-alert, ops alert): a PLACED order
    not accepted within `STORE_ACCEPTANCE_SLA_SECONDS`. `alerted`, `not_due`, `skipped` (no
    longer PLACED) or `already` (alerted before: one alert per order, kept in Redis)."""
    from django.core.cache import cache

    now = now or timezone.now()
    order = Order.objects.filter(pk=order_id).only("status", "placed_at").first()
    if order is None or order.status != OrderStatus.PLACED or order.placed_at is None:
        return "skipped"
    if order.placed_at + timedelta(seconds=settings.STORE_ACCEPTANCE_SLA_SECONDS) > now:
        return "not_due"
    try:
        first = cache.add(_sla_key(order_id), "1", 24 * 60 * 60)
    except Exception:  # Redis down: alert anyway (a repeat alert beats a missed one)
        first = True
    if not first:
        return "already"
    logger.error("Ops alert: order %s not accepted within the SLA", order_id)
    events.emit(events.ACCEPTANCE_SLA_BREACHED, order_id)
    return "alerted"


def sweep_placed_orders(now=None, limit: int = 500) -> dict:
    """Beat, every minute: auto-accepts and SLA alerts their countdown tasks missed (a worker
    restart, a lost message). Each check is idempotent."""
    now = now or timezone.now()
    counts: dict[str, int] = {}
    placed = Order.objects.filter(status=OrderStatus.PLACED).order_by("placed_at")
    for order_id, auto in placed.values_list("pk", "store__auto_accept_orders")[:limit]:
        outcome = auto_accept(order_id, now) if auto else "manual"
        if outcome != "accepted":
            outcome = acceptance_sla_alert(order_id, now)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


# --------------------------------------------------------------------------- T7 / T8


def start_packing(order_id: int, *, by) -> Order:
    """08 T7: ACCEPTED -> PACKING (customer label update only)."""
    with transaction.atomic():
        order = _locked(by, order_id, roles.ORDER_PROCESS)
        if order.status != OrderStatus.ACCEPTED:
            raise _state_error(order, "start_packing")
        transition(
            order,
            OrderStatus.PACKING,
            actor=by,
            actor_type=actor_type_for(by),
            note="T7: packing started",
        )
        audit.record(by, "order.start_packing", order, {"status": OrderStatus.PACKING})
        events.emit(events.PACKING, order.pk)
    return order


def mark_packed(order_id: int, *, by) -> Order:
    """08 T8: PACKING -> PACKED. Guards: lines not picked must have been marked unavailable
    first (the console's pick list); at least one unit remains (always true: removing the last
    units cancels the order). The order slip shows `pickup_code`; the rider is told "Order
    ready" and dispatch priority is raised from Phase 5 (event `order.packed`)."""
    with transaction.atomic():
        order = _locked(by, order_id, roles.ORDER_PROCESS)
        if order.status != OrderStatus.PACKING:
            raise _state_error(order, "packed")
        transition(
            order,
            OrderStatus.PACKED,
            actor=by,
            actor_type=actor_type_for(by),
            note="T8: packed",
        )
        if not order.pickup_code:  # accepted before Phase 4 codes existed
            order.pickup_code = _new_pickup_code(order)
        audit.record(by, "order.packed", order, {"status": OrderStatus.PACKED})
        events.emit(events.PACKED, order.pk)
    return order


# --------------------------------------------------------------------------- T8a


def mark_item_unavailable(order_id: int, item_id: int, *, unavailable: int, by) -> Order:
    """08 T8a (05 §1.3 "Item unavailable"): set how many units of a line the store cannot
    supply (`unavailable` = the line's total unavailable units; it can only grow, and the same
    value again changes nothing). Allowed while ACCEPTED or PACKING.

    - The removed units' reservation is released (08 §6.1).
    - The bill is recomputed by `compute_bill()` (08 §6.3): the order's prices, the original
      coupon discount kept but capped at the new item total, each fee recalculated but never
      above what it was, the tip unchanged. The amount payable never increases.
    - ONLINE: the difference is refunded to the original payment; COD: the new grand total is
      what the rider collects.
    - Nothing left: the whole order is cancelled instead (T12, reason ITEMS_UNAVAILABLE, full
      refund), and the line keeps its quantities.
    """
    from apps.payments import order_refunds

    with transaction.atomic():
        order = _locked(by, order_id, roles.ORDER_PROCESS)
        if order.status not in (OrderStatus.ACCEPTED, OrderStatus.PACKING):
            raise _state_error(order, "unavailable")
        items = {
            item.pk: item
            for item in OrderItem.objects.select_for_update()
            .select_related("product")
            .filter(order=order)
            .order_by("pk")
        }
        item = items.get(item_id)
        if item is None:
            raise ValidationError(MSG_LINE_NOT_FOUND)
        if (
            isinstance(unavailable, bool)
            or not isinstance(unavailable, int)
            or not 0 <= unavailable <= item.quantity
        ):
            raise ValidationError(f"Enter a number of units from 0 to {item.quantity}.")
        if unavailable < item.quantity_unavailable:
            raise ValidationError(
                "Units already marked unavailable cannot be added back "
                f"(already {item.quantity_unavailable})."
            )
        if unavailable == item.quantity_unavailable:
            return order
        delta = unavailable - item.quantity_unavailable
        left = sum(
            i.quantity - (unavailable if i.pk == item.pk else i.quantity_unavailable)
            for i in items.values()
        )
        actor_type = actor_type_for(by)
        if left == 0:
            cancel_active(
                order,
                actor=by,
                actor_type=actor_type,
                reason=StaffCancelReason.ITEMS_UNAVAILABLE,
                note="T8a: no items left",
            )
            audit.record(
                by,
                "order.cancel",
                order,
                {"reason": StaffCancelReason.ITEMS_UNAVAILABLE, "via": "items_unavailable"},
            )
            return order
        item.quantity_unavailable = unavailable
        item.line_total = item.selling_price * (item.quantity - unavailable)
        item.save(update_fields=["quantity_unavailable", "line_total", "updated_at"])
        inventory.release_units(order, item.variant_id, delta)
        old_total = order.grand_total
        bill = recompute_bill(order, list(items.values()))
        for field in (
            "mrp_total",
            "item_total",
            "product_discount",
            "coupon_discount",
            "delivery_fee",
            "small_cart_fee",
            "handling_fee",
            "tip",
            "grand_total",
        ):
            setattr(order, field, getattr(bill, field))
        order.save(
            update_fields=[
                "mrp_total",
                "item_total",
                "product_discount",
                "coupon_discount",
                "delivery_fee",
                "small_cart_fee",
                "handling_fee",
                "tip",
                "grand_total",
                "updated_at",
            ]
        )
        difference = old_total - order.grand_total
        refund = None
        if order.payment_method == PaymentMethod.ONLINE and difference > 0:
            refund = order_refunds.refund_order(
                order,
                difference,
                reason=order_refunds.ITEM_UNAVAILABLE,
                key=f"t8a:{order.pk}:{item.pk}:{unavailable}",
            )
            order_refunds.alert_if_not_refunded(order, refund, context="T8a")
        if order.payment_method == PaymentMethod.COD and difference > 0:
            # Phase 5: the rider collects the new amount ("collect ₹X, was ₹Y") and is told.
            from apps.delivery.services.dispatch import cod_amount_changed

            cod_amount_changed(order, old_total)
        audit.record(
            by,
            "order.items_unavailable",
            order,
            {
                "item_id": item.pk,
                "quantity_unavailable": unavailable,
                "grand_total": [money_str(old_total), money_str(order.grand_total)],
                "refund_id": refund.pk if refund else None,
            },
        )
        events.emit(events.ITEMS_ADJUSTED, order.pk)
    return order


def recompute_bill(order: Order, items: list[OrderItem]):
    """08 §6.3 through `compute_bill()` (the only money function): the units still coming at
    the order's own prices, the order's coupon discount kept (capped), fees capped at the
    order's current fees, the same tip."""
    lines = [
        cart_services.BillLine(
            variant_id=item.variant_id,
            category_id=item.product.category_id,
            mrp=item.mrp,
            selling_price=item.selling_price,
            quantity=item.quantity - item.quantity_unavailable,
        )
        for item in items
        if item.quantity > item.quantity_unavailable
    ]
    return cart_services.compute_bill(
        lines,
        cart_services.pricing_rules(order.store_id),
        tip=order.tip,
        fixed_coupon_discount=order.coupon_discount,
        fee_caps=cart_services.Bill(
            delivery_fee=order.delivery_fee,
            small_cart_fee=order.small_cart_fee,
            handling_fee=order.handling_fee,
        ),
    )


# --------------------------------------------------------------------------- T12 cancel


def cancel_by_staff(order_id: int, *, by, reason: str, note: str = "") -> Order:
    """08 T12: the store manager (own stores), ops or support cancels with a reason (required,
    `StaffCancelReason`), before pickup (PLACED, ACCEPTED, PACKING or PACKED). Same side effects
    as T11 (stock released, coupon back, full refund of what is still paid online). Audited."""
    if reason not in StaffCancelReason.values:
        raise ValidationError("Choose a cancellation reason.")
    with transaction.atomic():
        order = _locked(by, order_id, roles.ORDER_CANCEL)
        if order.status not in STAFF_CANCELLABLE:
            raise _state_error(order, "cancel")
        before = order.status
        cancel_active(order, actor=by, actor_type=actor_type_for(by), reason=reason, note=note)
        audit.record(
            by,
            "order.cancel",
            order,
            {
                "status": [before, OrderStatus.CANCELLED],
                "reason": reason,
                "note_length": len(note or ""),
            },
        )
    return order


# --------------------------------------------------------------------------- T14 return


MSG_RETURN_STATE = "Only an order whose delivery failed can be received back."
MSG_RETURN_UNITS = "Damaged units must be between 0 and the units on the order line."


def receive_return(
    order_id: int, *, by, damaged: dict[int, int] | None = None, ip: str | None = None
) -> Order:
    """08 T14 (05 §1.3 "receiving returns"): the rider is at the store with the items of a
    failed delivery (the staff confirm it by doing this). `damaged` maps order line ids to the
    units that came back damaged (default none). Good units go back on the shelf
    (`StockMovement(RETURN)`, `on_hand += qty`); damaged units are recorded (RETURN then DAMAGE,
    `on_hand` unchanged). The order RETURNED, the task RETURNED, the rider freed. COD: nothing
    to collect. DL-61 (a): `delivery.dispatch_order` (Super Admin, Ops, Store Manager own
    stores; not Store Staff or Support) in the store scope; audited."""
    from apps.delivery.choices import DeliveryTaskStatus
    from apps.delivery.models import DeliveryTask

    damaged = dict(damaged or {})
    now = timezone.now()
    with transaction.atomic():
        order = _locked(by, order_id, roles.RIDER_DISPATCH[0])
        task = DeliveryTask.objects.select_for_update(of=("self",)).filter(order=order).first()
        if (
            order.status != OrderStatus.DELIVERY_FAILED
            or task is None
            or task.status != DeliveryTaskStatus.RETURNING
        ):
            raise _state_error_message(order, MSG_RETURN_STATE)
        items = {item.pk: item for item in order.items.all()}
        if set(damaged) - set(items):
            raise ValidationError(MSG_LINE_NOT_FOUND)
        returns = []
        for item in items.values():
            units = item.quantity - item.quantity_unavailable
            bad = damaged.get(item.pk, 0)
            if not isinstance(bad, int) or isinstance(bad, bool) or not 0 <= bad <= units:
                raise ValidationError(MSG_RETURN_UNITS)
            returns.append((item.variant_id, units - bad, bad))
        inventory.receive_returned_units(order, returns, actor=by)
        transition(
            order,
            OrderStatus.RETURNED,
            actor=by,
            actor_type=actor_type_for(by),
            note="T14: items received back at the store",
            now=now,
        )
        task.status = DeliveryTaskStatus.RETURNED
        task.returned_at = now
        task.ended_at = now
        task.save(update_fields=["status", "returned_at", "ended_at", "updated_at"])
        audit.record(
            by,
            "order.return_received",
            order,
            {"damaged": {str(k): v for k, v in damaged.items() if v}},
            ip=ip,
        )
        events.emit(events.RETURNED, order.pk)
    return order


def _state_error_message(order: Order, message: str) -> ApiError:
    return ApiError(ErrorCode.INVALID_STATE_TRANSITION, message, details={"status": order.status})


def refundable_amount(order: Order) -> Decimal:
    """For the admin's refund form: what can still be refunded on the order."""
    from apps.payments import order_refunds

    return order_refunds.refundable(order)
