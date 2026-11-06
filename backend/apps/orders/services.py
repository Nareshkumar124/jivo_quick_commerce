"""Orders: placement (08 T1/T2), the state machine door `transition()`, payment capture (T3, T3a),
cancellation of an unpaid order (T5), payment-window expiry (T4) and payment retry.

**Lock order** (code review F2, one order for every path, so nothing deadlocks):
1. the `Order` row, 2. the customer's `Cart` row, 3. the `Coupon` row,
4. `StoreInventory` rows in variant-id order.
A path takes the locks it needs in this order and never goes back up:
- placement: cart, coupon, stock (then commit); the gateway call holds no lock (T-814, M6);
  then the order again, to attach the payment attempt;
- capture (T3): order, then cart (to remove the ordered lines);
- cancel (T5) and expiry (T4): order, then stock.

Side effects (notifications from Phase 4/6, refunds) run after commit (`events.emit`,
`payments.refunds.request_refund`).
"""

import hashlib
import json
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.contrib.gis.geos import Point
from django.db import IntegrityError, connection, transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound, ValidationError

from apps.accounts.serializers import AddressSerializer
from apps.cart import services as cart_services
from apps.cart.choices import PaymentUnavailableReason
from apps.cart.models import Cart, CartItem
from apps.cms.models import AppConfig
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.idempotency import IDEMPOTENCY_HEADER, KEY_REUSED
from apps.core.money import money_str, rupees
from apps.inventory import services as inventory
from apps.orders import events
from apps.orders.choices import ActorType, CancelReason, OrderStatus, PaymentMethod, PaymentStatus
from apps.orders.models import Order, OrderItem, OrderStatusHistory
from apps.orders.serializers import ORDER_ADDRESS_FIELDS
from apps.payments.gateways import PaymentGatewayError, get_gateway, to_paise
from apps.payments.models import Payment, PaymentAttemptStatus
from apps.payments.refunds import (
    AMOUNT_MISMATCH,
    DUPLICATE_CAPTURE,
    LATE_CAPTURE,
    request_refund,
)
from apps.promotions import services as promotions
from apps.stores.services import (
    StoreArea,
    eta_minutes,
    haversine_km,
    status_message,
    store_status,
)

logger = logging.getLogger(__name__)

MSG_NOT_FOUND = "Order not found."
MSG_EMPTY_CART = "Your cart is empty."
MSG_PENDING = "You have an order awaiting payment. Complete or cancel it first."
MSG_GATEWAY_DOWN = (
    "Online payment is temporarily unavailable. Try again, or choose cash on delivery."
)
MSG_NOT_CANCELLABLE = "This order can no longer be cancelled. Contact support for help."
MSG_WINDOW_ENDED = "The payment window has ended. Place the order again."
MSG_ALREADY_PAID = "This order is already paid."
MSG_NOT_AWAITING = "This order is no longer awaiting payment."

# --------------------------------------------------------------------------- the state machine

# 08 §2, the transitions built so far. Creation (T1 -> PAYMENT_PENDING, T2 -> PLACED) is
# `place_order()`. Phase 4: T6-T8 and the cancellations T11/T12 (`apps.orders.store_ops` for
# the store's moves; T8a changes items, not the status). Phase 5 adds T9/T10/T13/T14. Each
# caller runs its own guards and side effects; anything not listed is refused.
ALLOWED_TRANSITIONS: dict[tuple[str, str], str] = {
    (OrderStatus.PAYMENT_PENDING, OrderStatus.PLACED): "T3",
    (OrderStatus.PAYMENT_PENDING, OrderStatus.PAYMENT_FAILED): "T4",
    (OrderStatus.PAYMENT_PENDING, OrderStatus.CANCELLED): "T5",
    (OrderStatus.PLACED, OrderStatus.ACCEPTED): "T6",
    (OrderStatus.ACCEPTED, OrderStatus.PACKING): "T7",
    (OrderStatus.PACKING, OrderStatus.PACKED): "T8",
    (OrderStatus.PLACED, OrderStatus.CANCELLED): "T11/T12",
    (OrderStatus.ACCEPTED, OrderStatus.CANCELLED): "T11/T12",
    (OrderStatus.PACKING, OrderStatus.CANCELLED): "T12",
    (OrderStatus.PACKED, OrderStatus.CANCELLED): "T12",
    # Phase 5 (apps.delivery.services.tasks; T14 in apps.orders.store_ops.receive_return)
    (OrderStatus.PACKED, OrderStatus.OUT_FOR_DELIVERY): "T9",
    (OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERED): "T10",
    (OrderStatus.OUT_FOR_DELIVERY, OrderStatus.DELIVERY_FAILED): "T13",
    (OrderStatus.DELIVERY_FAILED, OrderStatus.RETURNED): "T14",
}
TIMESTAMP_FIELDS = {
    OrderStatus.PLACED: "placed_at",
    OrderStatus.ACCEPTED: "accepted_at",
    OrderStatus.PACKING: "packing_started_at",
    OrderStatus.PACKED: "packed_at",
    OrderStatus.OUT_FOR_DELIVERY: "picked_up_at",
    OrderStatus.DELIVERED: "delivered_at",
    OrderStatus.CANCELLED: "cancelled_at",
    OrderStatus.PAYMENT_FAILED: "payment_failed_at",
    OrderStatus.DELIVERY_FAILED: "delivery_failed_at",
    OrderStatus.RETURNED: "returned_at",
}


def transition(
    order: Order,
    to_status: str,
    *,
    actor=None,
    actor_type: str,
    note: str = "",
    now: datetime | None = None,
    **changes,
) -> Order:
    """The only way an order's status changes (08 §2). Validates the move, sets the state's
    timestamp and any `changes` (e.g. `payment_status`), and writes one append-only
    `OrderStatusHistory` row. Anything not in `ALLOWED_TRANSITIONS`: 409
    `INVALID_STATE_TRANSITION`. The caller holds the order row lock (`select_for_update`) in its
    transaction and runs the move's side effects."""
    if not connection.in_atomic_block:
        raise RuntimeError("transition() runs inside the caller's transaction (order row locked).")
    from_status = order.status
    if (from_status, to_status) not in ALLOWED_TRANSITIONS:
        raise ApiError(ErrorCode.INVALID_STATE_TRANSITION, details={"status": from_status})
    now = now or timezone.now()
    order.status = to_status
    stamp = TIMESTAMP_FIELDS[to_status]
    setattr(order, stamp, now)
    for field, value in changes.items():
        setattr(order, field, value)
    order.save(update_fields=["status", stamp, *changes, "updated_at"])
    OrderStatusHistory.objects.create(
        order=order,
        from_status=from_status,
        to_status=to_status,
        actor=actor,
        actor_type=actor_type,
        note=note,
    )
    return order


# --------------------------------------------------------------------------- placement (T1/T2)


@dataclass(frozen=True, slots=True)
class Placement:
    order: Order
    created: bool  # False: a replay of the same Idempotency-Key (200 instead of 201)


def request_fingerprint(store_id: int, address_id: int, payment_method: str, total) -> str:
    """What makes two placement requests "the same" for the Idempotency-Key."""
    data = {
        "store_id": store_id,
        "address_id": address_id,
        "payment_method": payment_method,
        "expected_grand_total": money_str(total),
    }
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def _replay(user, key: str, fingerprint: str) -> Order | None:
    """The order placed earlier with this key; the same key with another body: 400 (DL-44)."""
    order = Order.objects.filter(user=user, idempotency_key=key).first()
    if order is not None and order.request_fingerprint != fingerprint:
        raise ValidationError({IDEMPOTENCY_HEADER: [KEY_REUSED]})
    return order


def place_order(
    user,
    store: StoreArea,
    *,
    address_id: int,
    payment_method: str,
    expected_grand_total: Decimal,
    idempotency_key: str,
    client_app_version: str = "",
    client_platform: str = "",
) -> Placement:
    """08 T1 (ONLINE -> PAYMENT_PENDING) / T2 (COD -> PLACED) from the customer's cart.

    Only a successful placement is remembered under its Idempotency-Key: a repeat returns that
    order. Two concurrent requests with one key race on the unique (user, key) constraint and
    the loser returns the winner's order.

    T-814 (M6): an ONLINE order is created, its stock reserved and its coupon held in one
    transaction that commits **before** the gateway is called, so a slow gateway holds no cart,
    coupon or stock lock. The payment attempt is attached afterwards under the order lock
    (`_start_payment`). If the gateway call fails, the order is ended (T4: reservation and
    coupon hold released) and its Idempotency-Key is freed, so the app's retry starts afresh.
    An order left without an attempt (a crash in between) is completed by a replay of its key
    or failed by `expire_unpaid_orders` when its payment window ends, never left reserved."""
    fingerprint = request_fingerprint(store.pk, address_id, payment_method, expected_grand_total)
    order = _replay(user, idempotency_key, fingerprint)
    if order is not None:
        return Placement(_start_payment(order), created=False)
    try:
        with transaction.atomic():
            order, created = _place(
                user,
                store,
                address_id=address_id,
                payment_method=payment_method,
                expected_grand_total=expected_grand_total,
                key=idempotency_key,
                fingerprint=fingerprint,
                client=(client_app_version or "", client_platform or ""),
            )
    except IntegrityError:
        order = _replay(user, idempotency_key, fingerprint)
        if order is None:
            raise
        created = False
    return Placement(_start_payment(order, end_on_failure=created), created=created)


def _awaits_first_attempt(order: Order) -> bool:
    return (
        order.payment_method == PaymentMethod.ONLINE
        and order.status == OrderStatus.PAYMENT_PENDING
        and not order.payments.exists()
    )


def _start_payment(order: Order, *, end_on_failure: bool = False) -> Order:
    """T-814 (M6): the gateway order of an ONLINE order placed without one yet, created outside
    any row lock and attached under the order lock (a capture, cancel, expiry or concurrent
    replay in between wins; its extra gateway order is never paid and simply lapses). No-op
    for COD and for orders that already have an attempt. On a gateway failure: 503
    `SERVICE_UNAVAILABLE`; with `end_on_failure` (the request that created the order) the
    order is ended first (`_end_unstarted`)."""
    if not _awaits_first_attempt(order):
        return order
    if order.payment_expires_at is None or order.payment_expires_at <= timezone.now():
        # A stale replay after the payment window: no gateway call; the order is left as it is
        # for `expire_unpaid_orders` to fail (T4) and the response shows no payment to open.
        return order
    try:
        gateway = get_gateway()
        gateway_order = gateway.create_order(
            amount_paise=to_paise(order.grand_total),
            receipt=order.order_number,
            notes={"order_number": order.order_number},
        )
    except PaymentGatewayError as exc:
        logger.warning("Gateway order for %s failed: %s", order.order_number, exc)
        if end_on_failure and not _end_unstarted(order.pk):
            return Order.objects.get(pk=order.pk)  # a concurrent replay attached an attempt
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_GATEWAY_DOWN) from exc
    with transaction.atomic():
        order = _locked_order(order.pk)
        if not _awaits_first_attempt(order):
            return order
        Payment.objects.create(
            order=order,
            gateway=gateway.code,
            gateway_order_id=gateway_order.id,
            amount=order.grand_total,
            status=PaymentAttemptStatus.CREATED,
        )
        events.emit(events.PAYMENT_PENDING, order.pk)
    return order


def _end_unstarted(order_id: int) -> bool:
    """The gateway could not start the payment of a new ONLINE order: T4 by the system, which
    releases its reservation and coupon hold, and its Idempotency-Key is freed (renamed to a
    value no client key can take) so the app's retry with the same key places afresh. False
    when the order got an attempt (or moved on) meanwhile and is left as it is."""
    with transaction.atomic():
        order = _locked_order(order_id)
        if not _awaits_first_attempt(order):
            return False
        _end_unpaid(
            order,
            OrderStatus.PAYMENT_FAILED,
            actor=None,
            actor_type=ActorType.SYSTEM,
            note="T4: the payment could not be started (gateway unavailable)",
            idempotency_key=f"gateway-down:{order.pk}",
        )
    return True


def _next_order_id() -> int:
    """The order's primary key, allocated first so the order number can be built from it
    (`JV-YYMMDD-NNNNNN`, the IST date and the id): unique, no extra sequence or table."""
    with connection.cursor() as cursor:
        cursor.execute("SELECT nextval(pg_get_serial_sequence('orders_order', 'id'))")
        return cursor.fetchone()[0]


def order_number(order_id: int, now: datetime) -> str:
    local = now.astimezone(ZoneInfo(settings.STORE_TIME_ZONE))
    return f"JV-{local:%y%m%d}-{order_id:06d}"


def _eta_at(store, lat: float, lng: float, start: datetime) -> datetime:
    """08 §8 at placement: prep + typical rider wait + travel (straight line x road factor)."""
    distance = haversine_km(store.lat, store.lng, lat, lng)
    return start + timedelta(minutes=eta_minutes(store, distance))


def _store_point(store) -> StoreArea:
    """A `StoreArea`-like view of a `DarkStore` (avg prep and coordinates) for `_eta_at`."""
    if isinstance(store, StoreArea):
        return store
    return StoreArea(
        pk=store.pk,
        name=store.name,
        is_accepting_orders=store.is_accepting_orders,
        avg_prep_minutes=store.avg_prep_minutes,
        priority=store.priority,
        lat=store.location.y,
        lng=store.location.x,
        area=None,
        windows=(),
    )


def _check_cart(state, *, user, payment_method: str, expected: Decimal) -> None:
    """The 08 T1/T2 guards on the priced cart (the cart's checkout blockers, as errors)."""
    if not state.lines:
        raise ValidationError({"non_field_errors": [MSG_EMPTY_CART]})
    short = [
        {
            "variant_id": line.variant.pk,
            "requested_quantity": line.item.quantity,
            "orderable_quantity": line.summary["orderable_quantity"],
        }
        for line in state.lines
        if line.issue
    ]
    if short:
        raise ApiError(ErrorCode.STOCK_UNAVAILABLE, details={"items": short})
    rules, total = state.rules, state.bill.item_total
    if total < rules.min_order_value:
        missing = rules.min_order_value - total
        raise ApiError(
            ErrorCode.MIN_ORDER_NOT_MET,
            f"Add items worth {rupees(missing)} more to place your order "
            f"(minimum {rupees(rules.min_order_value)}).",
            details={
                "min_order_value": money_str(rules.min_order_value),
                "item_total": money_str(total),
                "amount_to_min_order": money_str(missing),
            },
        )
    if state.coupon_check is not None and not state.coupon_check.ok:
        raise state.coupon_check.as_error()
    cart_services.ensure_expected_total(state.bill, expected)
    if payment_method == PaymentMethod.COD:
        cod = cart_services.cod_unavailable(rules, user, state.bill.grand_total)
        if cod is not None:
            details = {"reason": str(cod[0])}
            if cod[0] == PaymentUnavailableReason.ABOVE_LIMIT:
                details["cod_max_order_value"] = money_str(rules.cod_max_order_value)
            raise ApiError(ErrorCode.COD_NOT_AVAILABLE, cod[1], details=details)


def address_snapshot(address) -> dict:
    data = AddressSerializer(address).data
    return {field: data[field] for field in ORDER_ADDRESS_FIELDS}


def _place(
    user,
    store: StoreArea,
    *,
    address_id: int,
    payment_method: str,
    expected_grand_total: Decimal,
    key: str,
    fingerprint: str,
    client: tuple[str, str],
) -> tuple[Order, bool]:
    # Lock 1: the customer's cart row. Serialises this customer's placements, so the replay and
    # pending-order checks below cannot race another request of theirs.
    cart = (
        Cart.objects.select_for_update(of=("self",))
        .select_related("coupon", "address")
        .filter(user=user)
    )
    cart = cart.first()
    if cart is None:
        raise ValidationError({"non_field_errors": [MSG_EMPTY_CART]})
    replay = _replay(user, key, fingerprint)
    if replay is not None:
        return replay, False
    pending = (
        Order.objects.filter(user=user, status=OrderStatus.PAYMENT_PENDING)
        .values_list("pk", flat=True)
        .first()
    )
    if pending is not None:
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION, MSG_PENDING, details={"pending_order_id": pending}
        )
    address = cart_services.resolve_address(user, address_id)
    if not cart_services.serves(store, address):
        raise ApiError(
            ErrorCode.NOT_SERVICEABLE,
            cart_services.MSG_ADDRESS_NOT_SERVED,
            details={"address_id": address.pk},
        )
    now = timezone.now()
    status = store_status(store, now)
    if not status.is_open:
        raise ApiError(
            ErrorCode.STORE_CLOSED,
            status_message(status, now),
            details={"store_id": store.pk, "opens_at": status.opens_at},
        )
    if cart.store_id != store.pk:
        cart.store_id = store.pk
        cart.save(update_fields=["store", "updated_at"])
    state = cart_services.evaluate(cart, store, user, now=now)
    _check_cart(state, user=user, payment_method=payment_method, expected=expected_grand_total)

    bill, online = state.bill, payment_method == PaymentMethod.ONLINE
    order_id = _next_order_id()
    number = order_number(order_id, now)
    expires_at = now + timedelta(minutes=AppConfig.load().payment_window_minutes)
    coupon = state.coupon_check.coupon if state.coupon_check is not None else None
    lat, lng = float(address.lat), float(address.lng)
    order = Order.objects.create(
        id=order_id,
        order_number=number,
        user=user,
        store_id=store.pk,
        address_snapshot=address_snapshot(address),
        delivery_location=Point(lng, lat, srid=4326),
        status=OrderStatus.PAYMENT_PENDING if online else OrderStatus.PLACED,
        payment_method=payment_method,
        payment_status=PaymentStatus.PENDING if online else PaymentStatus.COD_PENDING,
        mrp_total=bill.mrp_total,
        item_total=bill.item_total,
        product_discount=bill.product_discount,
        coupon_discount=bill.coupon_discount,
        delivery_fee=bill.delivery_fee,
        small_cart_fee=bill.small_cart_fee,
        handling_fee=bill.handling_fee,
        tip=bill.tip,
        grand_total=bill.grand_total,
        coupon=coupon,
        coupon_code=coupon.code if coupon else "",
        instructions=cart.instructions or {},
        payment_expires_at=expires_at if online else None,
        placed_at=None if online else now,
        eta_at=None if online else _eta_at(store, lat, lng, now),
        idempotency_key=key,
        request_fingerprint=fingerprint,
        client_app_version=client[0][:32],
        client_platform=client[1][:16],
    )
    OrderStatusHistory.objects.create(
        order=order,
        from_status="",
        to_status=order.status,
        actor=user,
        actor_type=ActorType.CUSTOMER,
        note="T1: awaiting online payment" if online else "T2: cash on delivery",
    )
    OrderItem.objects.bulk_create(_order_items(order, state.lines))
    if coupon is not None:  # Lock 2: the coupon row (re-checks its limits)
        use = promotions.hold_coupon if online else promotions.apply_coupon_now
        use(order, coupon, bill.coupon_discount)
    inventory.reserve(  # Lock 3: stock rows, variant-id order
        order,
        store.pk,
        [
            inventory.ReservationLine(
                line.variant.pk, line.item.quantity, line.variant.max_qty_per_order
            )
            for line in state.lines
        ],
        expires_at=expires_at if online else None,
    )
    if not online:  # ONLINE: the payment attempt and its event follow commit (_start_payment)
        _clear_ordered_lines(cart, order)
        events.emit(events.PLACED, order.pk)
    return order, True


def _order_items(order: Order, lines) -> list[OrderItem]:
    items = []
    for line in lines:
        variant, product, bill_line = line.variant, line.variant.product, line.bill_line
        items.append(
            OrderItem(
                order=order,
                variant=variant,
                product=product,
                product_name=product.name,
                variant_name=variant.name,
                sku=variant.sku,
                hsn_code=product.hsn_code or "",
                gst_rate=product.gst_rate or Decimal("0.00"),
                image=line.summary["image"],
                mrp=variant.mrp,
                selling_price=bill_line.selling_price,
                quantity=bill_line.quantity,
                line_total=bill_line.line_total,
            )
        )
    return items


def _clear_ordered_lines(cart: Cart, order: Order) -> None:
    """T2/T3 "cart cleared" (PM decision): remove the lines that were ordered, keep anything the
    customer added since, and drop the coupon (it now belongs to the order)."""
    ordered = order.items.values_list("variant_id", flat=True)
    CartItem.objects.filter(cart=cart, variant_id__in=ordered).delete()
    if cart.coupon_id is not None:
        cart.coupon = None
        cart.save(update_fields=["coupon", "updated_at"])


# --------------------------------------------------------------------------- payment capture


def _locked_order(order_id: int) -> Order:
    return Order.objects.select_for_update().get(pk=order_id)


def _capture_row(order: Order, gateway_order_id: str, payment_id: str) -> tuple[Payment, bool]:
    """The Payment row for this capture, and whether it was already recorded (idempotency)."""
    existing = Payment.objects.filter(gateway_payment_id=payment_id).first()
    if existing is not None:
        return existing, existing.status == PaymentAttemptStatus.CAPTURED
    payment = order.payments.filter(gateway_order_id=gateway_order_id).first()
    if payment is None or payment.gateway_payment_id:
        # A second capture on one gateway order (or an unknown one): keep it on its own row.
        payment = Payment(
            order=order,
            gateway=get_gateway().code,
            amount=order.grand_total,
            status=PaymentAttemptStatus.CREATED,
            raw={"gateway_order_id": gateway_order_id},
        )
    return payment, False


def _record_capture(payment: Payment, payment_id: str, *, method: str, raw, amount=None) -> None:
    payment.gateway_payment_id = payment_id
    payment.status = PaymentAttemptStatus.CAPTURED
    payment.method = (method or payment.method or "")[:20]
    payment.captured_at = timezone.now()
    if amount is not None:
        payment.amount = amount
    if raw:
        payment.raw = {**(payment.raw or {}), **raw}
    payment.save()


@dataclass(frozen=True, slots=True)
class CaptureResult:
    order: Order
    outcome: str  # "placed", "already", "late_capture", "duplicate", "amount_mismatch"


def capture_payment(
    order_id: int,
    *,
    gateway_order_id: str,
    payment_id: str,
    amount_paise: int | None = None,
    method: str = "",
    raw: dict | None = None,
    actor=None,
    actor_type: str = ActorType.SYSTEM,
) -> CaptureResult:
    """The server's decision on a captured payment, whichever of verify, the webhook or the
    expiry job reports it first; a repeat is a no-op (08 §4 rules 1-2).
    - PAYMENT_PENDING -> PLACED (T3): payment CAPTURED, PAID, the reservation stops expiring,
      the coupon is used, the ordered lines leave the cart, ETA set.
    - Order already failed or cancelled (T3a): not revived; the capture is refunded in full.
    - Order already paid with another payment: that extra capture is refunded (DL-45)."""
    with transaction.atomic():
        order = _locked_order(order_id)  # Lock 1: order
        payment, already = _capture_row(order, gateway_order_id, payment_id)
        if already:
            return CaptureResult(order, "already")
        amount = Decimal(amount_paise) / 100 if amount_paise is not None else None
        if amount_paise is not None and amount_paise != to_paise(order.grand_total):
            # Never a sale: the order is not placed (it keeps waiting for a correct payment until
            # its window ends) and the money is refunded in full, like T3a (advisor, R2b).
            _record_capture(payment, payment_id, method=method, raw=raw or {}, amount=amount)
            request_refund(payment, amount, reason=AMOUNT_MISMATCH, key=f"capture:{payment_id}")
            logger.error(
                "Captured %s paise on order %s, which is due %s: not placed, refunded",
                amount_paise,
                order.order_number,
                order.grand_total,
            )
            events.emit(events.LATE_CAPTURE, order.pk)
            return CaptureResult(order, "amount_mismatch")
        _record_capture(payment, payment_id, method=method, raw=raw or {}, amount=amount)
        if order.status == OrderStatus.PAYMENT_PENDING:
            now = timezone.now()
            transition(
                order,
                OrderStatus.PLACED,
                actor=actor,
                actor_type=actor_type,
                note=f"T3: payment {payment_id} captured",
                now=now,
                payment_status=PaymentStatus.PAID,
                amount_paid=order.grand_total,
                payment_expires_at=None,
                eta_at=_eta_at(
                    _store_point(order.store),
                    order.delivery_location.y,
                    order.delivery_location.x,
                    now,
                ),
            )
            inventory.clear_reservation_expiry(order)
            promotions.confirm_coupon(order)
            cart = Cart.objects.select_for_update().filter(user_id=order.user_id).first()  # Lock 2
            if cart is not None:
                _clear_ordered_lines(cart, order)
            events.emit(events.PLACED, order.pk)
            return CaptureResult(order, "placed")
        if order.status in (OrderStatus.PAYMENT_FAILED, OrderStatus.CANCELLED):
            request_refund(
                payment, payment.amount, reason=LATE_CAPTURE, key=f"capture:{payment_id}"
            )
            order.payment_status = PaymentStatus.REFUND_PENDING
            order.save(update_fields=["payment_status", "updated_at"])
            events.emit(events.LATE_CAPTURE, order.pk)
            return CaptureResult(order, "late_capture")
        request_refund(
            payment, payment.amount, reason=DUPLICATE_CAPTURE, key=f"capture:{payment_id}"
        )
        logger.warning("Second capture %s on paid order %s refunded", payment_id, order.pk)
        return CaptureResult(order, "duplicate")


def mark_payment_failed(gateway_order_id: str, *, error_code: str, error_description: str, raw):
    """`payment.failed`: that attempt failed. The order keeps waiting until its window ends (the
    customer may retry); T4 is the expiry job's decision. Under the order lock, and only while
    the attempt is still CREATED, so a capture is never overwritten (code review Minor 4)."""
    order_id = (
        Payment.objects.filter(gateway_order_id=gateway_order_id)
        .values_list("order_id", flat=True)
        .first()
    )
    if order_id is None:
        return False
    with transaction.atomic():
        _locked_order(order_id)  # lock order: the order row first, then its payments
        changed = Payment.objects.filter(
            gateway_order_id=gateway_order_id, status=PaymentAttemptStatus.CREATED
        ).update(
            status=PaymentAttemptStatus.FAILED,
            error_code=(error_code or "")[:64],
            error_description=(error_description or "")[:255],
            raw=raw or {},
            updated_at=timezone.now(),
        )
    return bool(changed)


# --------------------------------------------------------------------------- reads


def own_orders(user):
    return Order.objects.filter(user=user)


def get_own_order(user, order_id: int) -> Order:
    from apps.orders.presenters import with_detail_relations

    order = with_detail_relations(own_orders(user)).filter(pk=order_id).first()
    if order is None:
        raise NotFound(MSG_NOT_FOUND)
    return order


# --------------------------------------------------------------------------- retry, cancel, expiry


def retry_payment(user, order_id: int, idempotency_key: str) -> tuple[Order, Payment]:
    """A new gateway order for an ONLINE order still awaiting payment, before its window ends by
    the **server's** clock (customer app review: never a second payment on a paid order). A
    repeat with the same key returns the same payment."""
    order = own_orders(user).filter(pk=order_id).first()
    if order is None:
        raise NotFound(MSG_NOT_FOUND)
    _check_retryable(order)
    existing = order.payments.filter(idempotency_key=idempotency_key).first()
    if existing is not None:
        return order, existing
    # T-403c: the gateway call runs outside any row lock; the order is re-checked under its lock
    # before the attempt is recorded (a capture or expiry in between wins).
    try:
        gateway = get_gateway()
        gateway_order = gateway.create_order(
            amount_paise=to_paise(order.grand_total),
            receipt=order.order_number,
            notes={"order_number": order.order_number, "retry": idempotency_key},
        )
    except PaymentGatewayError as exc:
        logger.warning("Retry gateway order for %s failed: %s", order.order_number, exc)
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_GATEWAY_DOWN) from exc
    with transaction.atomic():
        order = own_orders(user).select_for_update().get(pk=order.pk)
        _check_retryable(order)
        existing = order.payments.filter(idempotency_key=idempotency_key).first()
        if existing is not None:  # a concurrent repeat with the same key won
            return order, existing
        payment = Payment.objects.create(
            order=order,
            gateway=gateway.code,
            gateway_order_id=gateway_order.id,
            amount=order.grand_total,
            status=PaymentAttemptStatus.CREATED,
            idempotency_key=idempotency_key,
        )
        return order, payment


def _check_retryable(order: Order) -> None:
    if order.status != OrderStatus.PAYMENT_PENDING or order.payment_method != PaymentMethod.ONLINE:
        message = (
            MSG_ALREADY_PAID
            if order.payment_status == PaymentStatus.PAID
            else (
                MSG_WINDOW_ENDED if order.status == OrderStatus.PAYMENT_FAILED else MSG_NOT_AWAITING
            )
        )
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION, message, details={"status": order.status}
        )
    if order.payment_expires_at is None or timezone.now() >= order.payment_expires_at:
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION,
            MSG_WINDOW_ENDED,
            details={"status": order.status},
        )


def _end_unpaid(order: Order, to_status: str, *, actor, actor_type, note: str, **changes) -> None:
    """T4/T5 side effects: stock and coupon hold released, open payment attempts closed; the
    cart is left as it is so the customer can try again."""
    transition(
        order,
        to_status,
        actor=actor,
        actor_type=actor_type,
        note=note,
        payment_status=PaymentStatus.FAILED,
        payment_expires_at=None,
        **changes,
    )
    inventory.release_reservations(order)  # Lock: stock rows, variant-id order
    promotions.release_coupon(order)
    order.payments.filter(status=PaymentAttemptStatus.CREATED).update(
        status=PaymentAttemptStatus.FAILED, error_description=note[:255]
    )


def cancel_order(user, order_id: int, *, reason: str, note: str = "") -> Order:
    """The customer cancels (08 §7): T5 for an unpaid order, T11 for a PLACED or ACCEPTED one
    (`CUSTOMER_CANCEL_UNTIL`). Anything later: 409, "Contact support"."""
    from apps.orders.choices import customer_cancellable

    with transaction.atomic():
        order = own_orders(user).select_for_update().filter(pk=order_id).first()  # Lock 1
        if order is None:
            raise NotFound(MSG_NOT_FOUND)
        if order.status != OrderStatus.PAYMENT_PENDING:
            if order.status not in customer_cancellable():
                raise ApiError(
                    ErrorCode.INVALID_STATE_TRANSITION,
                    MSG_NOT_CANCELLABLE,
                    details={"status": order.status},
                )
            cancel_active(
                order,
                actor=user,
                actor_type=ActorType.CUSTOMER,
                reason=reason if reason in CancelReason.values else CancelReason.OTHER,
                note=note,
            )
            return order
        # A capture being refunded (e.g. a wrong amount) does not stop the cancellation.
        captured = order.payments.filter(
            status=PaymentAttemptStatus.CAPTURED, refunds__isnull=True
        ).exists()
        if captured:
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                MSG_NOT_CANCELLABLE,
                details={"status": order.status},
            )
        _end_unpaid(
            order,
            OrderStatus.CANCELLED,
            actor=user,
            actor_type=ActorType.CUSTOMER,
            note=f"T5: cancelled by the customer ({reason})",
            cancel_reason=reason if reason in CancelReason.values else CancelReason.OTHER,
            cancel_note=(note or "")[:250],
            cancelled_by_type=ActorType.CUSTOMER,
        )
        events.emit(events.CANCELLED, order.pk)
    return order


def expire_order(order_id: int, now: datetime | None = None) -> str:
    """T4 for one order: `placed` (a capture was found after all), `failed`, `skipped` (not due
    any more) or `error` (the gateway could not be asked: retried on the next run)."""
    now = now or timezone.now()
    order = Order.objects.filter(pk=order_id).first()
    if order is None or order.status != OrderStatus.PAYMENT_PENDING:
        return "skipped"
    if order.payment_expires_at is None or order.payment_expires_at > now:
        return "skipped"
    gateway, due = get_gateway(), to_paise(order.grand_total)
    for payment in order.payments.exclude(gateway_order_id=""):
        try:
            found = gateway.fetch_order_payments(payment.gateway_order_id)
        except PaymentGatewayError as exc:
            logger.warning("Expiry of %s postponed: %s", order.order_number, exc)
            return "error"
        for captured in (p for p in found if p.status == "captured"):
            result = capture_payment(
                order.pk,
                gateway_order_id=payment.gateway_order_id,
                payment_id=captured.id,
                amount_paise=captured.amount_paise,
                method=captured.method,
                raw=captured.raw,
            )
            if result.outcome == "placed" or (
                result.outcome == "already" and captured.amount_paise == due
            ):
                return "placed"
            # A capture of the wrong amount is refunded (capture_payment) and never places the
            # order, so it must not keep the order waiting: carry on to T4.
    with transaction.atomic():
        # T-403c: an order another worker holds (a capture or cancel in flight) is left for
        # the next run instead of waiting on its lock.
        order = Order.objects.select_for_update(skip_locked=True).filter(pk=order_id).first()
        if order is None or order.status != OrderStatus.PAYMENT_PENDING:
            return "skipped"
        _end_unpaid(
            order,
            OrderStatus.PAYMENT_FAILED,
            actor=None,
            actor_type=ActorType.SYSTEM,
            note="T4: payment window ended without a captured payment",
        )
        events.emit(events.PAYMENT_FAILED, order.pk)
    return "failed"


def expire_unpaid_orders(now: datetime | None = None, limit: int = 200) -> dict:
    """06 §5 `expire_unpaid_orders` (beat, every minute). Idempotent: each order is re-checked
    under its row lock, so overlapping runs cannot fail an order twice."""
    now = now or timezone.now()
    with _run_lock("orders:expire_unpaid_orders") as acquired:
        if not acquired:
            return {"locked": 1}
        return _expire_due(now, limit)


EXPIRY_LOCK_SECONDS = 5 * 60


class _run_lock:
    """T-403c: one `expire_unpaid_orders` run at a time (beat every minute; a slow gateway can
    make a run longer than that). A Redis `add` with a timeout, so a crashed run frees the lock.
    If Redis is down the run goes ahead: every order is re-checked under its row lock anyway."""

    def __init__(self, key: str) -> None:
        self.key, self.acquired = key, False

    def __enter__(self) -> bool:
        from django.core.cache import cache

        try:
            self.acquired = cache.add(self.key, "1", EXPIRY_LOCK_SECONDS)
        except Exception:
            logger.warning("expire_unpaid_orders: lock unavailable, running without it")
            return True
        return self.acquired

    def __exit__(self, *exc) -> None:
        if self.acquired:
            from django.core.cache import cache

            try:
                cache.delete(self.key)
            except Exception:
                logger.warning("expire_unpaid_orders: lock not released (expires by itself)")


def _expire_due(now: datetime, limit: int) -> dict:
    due = (
        Order.objects.filter(status=OrderStatus.PAYMENT_PENDING, payment_expires_at__lte=now)
        .order_by("payment_expires_at")
        .values_list("pk", flat=True)[:limit]
    )
    counts: dict[str, int] = {}
    for order_id in list(due):
        outcome = expire_order(order_id, now)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


# --------------------------------------------------------------------------- reorder (P4)


def reorder(user, store: StoreArea, order_id: int) -> tuple[list[dict], int]:
    """`POST /orders/{id}/reorder/` (06 §2.6): put the order's lines back in the cart at the
    store in `X-Store-Id`, as far as they can be ordered now. Idempotent: a line's quantity is
    raised to the ordered units (capped by `orderable_quantity`), never added on top, so a
    retried request changes nothing. Returns the lines that could not be added in full, and
    `added_count`: how many of the order's lines now have at least one unit in the cart."""
    from apps.inventory.services import availability
    from apps.orders.choices import ReorderIssueReason

    order = own_orders(user).prefetch_related("items").filter(pk=order_id).first()
    if order is None:
        raise NotFound(MSG_NOT_FOUND)
    items = list(order.items.all())
    cart = cart_services.get_cart(user, store)
    variants = cart_services.store_variants(
        store.pk, [item.variant_id for item in items], with_images=False
    )
    issues, added = [], 0
    with transaction.atomic():
        cart = Cart.objects.select_for_update().get(pk=cart.pk)
        lines = {line.variant_id: line for line in cart.items.all()}
        for item in items:
            wanted = item.quantity - item.quantity_unavailable
            if wanted <= 0:  # the store could not supply this line at all: nothing to reorder
                continue
            variant = variants.get(item.variant_id)
            sellable = (
                variant is not None
                and variant.inv_id is not None
                and cart_services.is_sellable(variant)
            )
            orderable = 0
            if sellable:
                orderable = availability(
                    on_hand=variant.inv_on_hand,
                    reserved=variant.inv_reserved,
                    is_available=variant.inv_is_available,
                    max_qty_per_order=variant.max_qty_per_order,
                ).orderable_quantity
            line = lines.get(item.variant_id)
            current = line.quantity if line is not None else 0
            target = max(current, min(wanted, orderable))
            added += target > 0
            if target > current:
                if line is None:
                    CartItem.objects.create(cart=cart, variant_id=item.variant_id, quantity=target)
                else:
                    line.quantity = target
                    line.save(update_fields=["quantity", "updated_at"])
            if orderable < wanted:
                reason = (
                    ReorderIssueReason.NOT_AVAILABLE
                    if not sellable
                    else (
                        ReorderIssueReason.OUT_OF_STOCK
                        if orderable == 0
                        else ReorderIssueReason.LIMITED_STOCK
                    )
                )
                issues.append(
                    {
                        "variant_id": item.variant_id,
                        "product_name": item.product_name,
                        "variant_name": item.variant_name,
                        "requested_quantity": wanted,
                        "added_quantity": target,
                        "reason": reason,
                    }
                )
    return issues, added


# --------------------------------------------------------------------------- invoice (P4)

MSG_INVOICE_NOT_READY = "The invoice is available once the order is delivered."
MSG_INVOICE_UNAVAILABLE = "The invoice cannot be created right now. Try again in a few minutes."


def invoice_link(user, order_id: int) -> dict:
    """`GET /orders/{id}/invoice/`: the invoice of the caller's delivered order, made and
    rendered on the first request (06 §5 `generate_invoice` on demand)."""
    from apps.orders import invoices

    order = own_orders(user).filter(pk=order_id).first()
    if order is None:
        raise NotFound(MSG_NOT_FOUND)
    if not invoices.is_invoiceable(order):
        raise ApiError(
            ErrorCode.INVALID_STATE_TRANSITION,
            MSG_INVOICE_NOT_READY,
            details={"status": order.status},
        )
    invoice = invoices.ensure_invoice(order.pk)
    try:
        invoice = invoices.ensure_pdf(invoice)
    except invoices.InvoiceRenderingUnavailable as exc:
        logger.error("Invoice %s not rendered: %s", invoice.invoice_number, exc)
        raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_INVOICE_UNAVAILABLE) from exc
    return invoices.signed_link(invoice)


# --------------------------------------------------------------------------- T11 / T12 (P4)


def cancel_active(order: Order, *, actor, actor_type: str, reason: str, note: str = "") -> None:
    """08 T11 (customer) / T12 (store, ops, support) side effects, for an order past payment and
    before pickup. The caller holds the order row lock and has checked who may cancel.
    - the reservation is released (stock is still only reserved before T9, so a PACKED order's
      items go back on the shelf without a stock movement);
    - the coupon redemption is reversed (the coupon can be used again);
    - ONLINE: everything still refundable is refunded to the original payment (08 §6.4: full
      refund; after a T8a partial refund, the rest), `payment_status` REFUND_PENDING;
      COD: nothing is due, `payment_status` FAILED ("Not paid");
    - the delivery task is cancelled: a pending offer withdrawn, the assigned rider freed and
      told (Phase 5, `delivery.services.dispatch.withdraw_for_order`).
    Raises `INVALID_STATE_TRANSITION` from any other state."""
    from apps.delivery.services.dispatch import withdraw_for_order
    from apps.payments import order_refunds

    staff = actor_type != ActorType.CUSTOMER
    label = "T12" if staff else "T11"
    changes = {
        "cancel_reason": reason,
        "cancel_note": (note or "")[:250],
        "cancelled_by_type": actor_type,
    }
    if order.payment_method == PaymentMethod.COD:
        changes["payment_status"] = PaymentStatus.FAILED
    transition(
        order,
        OrderStatus.CANCELLED,
        actor=actor,
        actor_type=actor_type,
        note=f"{label}: cancelled by {actor_type} ({reason})",
        **changes,
    )
    withdraw_for_order(order)  # Lock: the delivery task (after the order), then offers
    inventory.release_reservations(order)  # Lock: stock rows, variant-id order
    promotions.reverse_coupon(order)
    promotions.release_coupon(order)
    if order.payment_method == PaymentMethod.ONLINE:
        refund = order_refunds.refund_order(
            order,
            order_refunds.refundable(order),
            reason=order_refunds.STAFF_CANCEL if staff else order_refunds.CUSTOMER_CANCEL,
            key=f"cancel:{order.pk}",
            initiated_by=actor if staff else None,
        )
        order_refunds.alert_if_not_refunded(order, refund, context=f"{label} cancel")
    events.emit(events.CANCELLED, order.pk)
