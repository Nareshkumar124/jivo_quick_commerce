"""Orders: placement (08 T1/T2), the state machine door `transition()`, payment capture (T3, T3a),
cancellation of an unpaid order (T5), payment-window expiry (T4) and payment retry.

**Lock order** (code review F2, one order for every path, so nothing deadlocks):
1. the `Order` row, 2. the customer's `Cart` row, 3. the `Coupon` row,
4. `StoreInventory` rows in variant-id order.
A path takes the locks it needs in this order and never goes back up:
- placement: cart, then (the gateway call), coupon, stock;
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
# `place_order()`. Phase 4 adds T6-T8a/T11/T12 and Phase 5 T9/T10/T13/T14, each with its own
# guards and side effects; anything not listed is refused.
ALLOWED_TRANSITIONS: dict[tuple[str, str], str] = {
    (OrderStatus.PAYMENT_PENDING, OrderStatus.PLACED): "T3",
    (OrderStatus.PAYMENT_PENDING, OrderStatus.PAYMENT_FAILED): "T4",
    (OrderStatus.PAYMENT_PENDING, OrderStatus.CANCELLED): "T5",
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
    the loser returns the winner's order."""
    fingerprint = request_fingerprint(store.pk, address_id, payment_method, expected_grand_total)
    order = _replay(user, idempotency_key, fingerprint)
    if order is not None:
        return Placement(order, created=False)
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
        return Placement(order, created=False)
    return Placement(order, created=created)


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
    gateway_order = None
    if online:
        try:
            gateway = get_gateway()
            gateway_order = gateway.create_order(
                amount_paise=to_paise(bill.grand_total),
                receipt=number,
                notes={"order_number": number},
            )
        except PaymentGatewayError as exc:
            logger.warning("Gateway order for %s failed: %s", number, exc)
            raise ApiError(ErrorCode.SERVICE_UNAVAILABLE, MSG_GATEWAY_DOWN) from exc
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
    if online:
        Payment.objects.create(
            order=order,
            gateway=gateway.code,
            gateway_order_id=gateway_order.id,
            amount=bill.grand_total,
            status=PaymentAttemptStatus.CREATED,
        )
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
    if online:
        events.emit(events.PAYMENT_PENDING, order.pk)
    else:
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
    from apps.orders.presenters import with_api_relations

    order = with_api_relations(own_orders(user)).filter(pk=order_id).first()
    if order is None:
        raise NotFound(MSG_NOT_FOUND)
    return order


# --------------------------------------------------------------------------- retry, cancel, expiry


def retry_payment(user, order_id: int, idempotency_key: str) -> tuple[Order, Payment]:
    """A new gateway order for an ONLINE order still awaiting payment, before its window ends by
    the **server's** clock (customer app review: never a second payment on a paid order). A
    repeat with the same key returns the same payment."""
    with transaction.atomic():
        order = own_orders(user).select_for_update().filter(pk=order_id).first()
        if order is None:
            raise NotFound(MSG_NOT_FOUND)
        if (
            order.status != OrderStatus.PAYMENT_PENDING
            or order.payment_method != PaymentMethod.ONLINE
        ):
            message = (
                MSG_ALREADY_PAID
                if order.payment_status == PaymentStatus.PAID
                else (
                    MSG_WINDOW_ENDED
                    if order.status == OrderStatus.PAYMENT_FAILED
                    else MSG_NOT_AWAITING
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
        existing = order.payments.filter(idempotency_key=idempotency_key).first()
        if existing is not None:
            return order, existing
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
        payment = Payment.objects.create(
            order=order,
            gateway=gateway.code,
            gateway_order_id=gateway_order.id,
            amount=order.grand_total,
            status=PaymentAttemptStatus.CREATED,
            idempotency_key=idempotency_key,
        )
        return order, payment


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
    """T5 (Phase 3): the customer gives up on an unpaid order. From Phase 4 also T11."""
    with transaction.atomic():
        order = own_orders(user).select_for_update().filter(pk=order_id).first()  # Lock 1
        if order is None:
            raise NotFound(MSG_NOT_FOUND)
        # A capture being refunded (e.g. a wrong amount) does not stop the cancellation.
        captured = order.payments.filter(
            status=PaymentAttemptStatus.CAPTURED, refunds__isnull=True
        ).exists()
        if order.status != OrderStatus.PAYMENT_PENDING or captured:
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
        order = _locked_order(order_id)
        if order.status != OrderStatus.PAYMENT_PENDING:
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
