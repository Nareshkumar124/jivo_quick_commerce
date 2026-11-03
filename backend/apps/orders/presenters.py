"""Orders as the API publishes them (`Order`, `OrderSummary`, `OrderPlacement`; 06 §2.6). Plain
dicts in the contract shapes, from orders loaded with `with_api_relations()`."""

import math
from datetime import datetime

from django.db.models import Prefetch, QuerySet
from django.utils import timezone

from apps.core.money import money_str
from apps.orders.choices import OrderStatus, PaymentMethod
from apps.orders.models import Order, OrderItem
from apps.payments.gateways import get_gateway, to_paise
from apps.payments.models import Payment, PaymentAttemptStatus

MERCHANT_NAME = "Jivo"
SUMMARY_IMAGES = 4


def with_api_relations(queryset: QuerySet[Order]) -> QuerySet[Order]:
    return queryset.select_related("store", "user").prefetch_related(
        Prefetch("items", queryset=OrderItem.objects.order_by("id"))
    )


def can_cancel(order: Order) -> bool:
    """08 §7, Phase 3 part: only an order awaiting payment (T5). Phase 4 adds PLACED/ACCEPTED."""
    return order.status == OrderStatus.PAYMENT_PENDING


def can_retry_payment(order: Order, now: datetime | None = None) -> bool:
    now = now or timezone.now()
    return (
        order.payment_method == PaymentMethod.ONLINE
        and order.status == OrderStatus.PAYMENT_PENDING
        and order.payment_expires_at is not None
        and now < order.payment_expires_at
    )


def bill_body(order: Order) -> dict:
    return {
        "mrp_total": money_str(order.mrp_total),
        "item_total": money_str(order.item_total),
        "product_discount": money_str(order.product_discount),
        "coupon_discount": money_str(order.coupon_discount),
        "delivery_fee": money_str(order.delivery_fee),
        "small_cart_fee": money_str(order.small_cart_fee),
        "handling_fee": money_str(order.handling_fee),
        "tip": money_str(order.tip),
        "grand_total": money_str(order.grand_total),
        "total_savings": money_str(order.product_discount + order.coupon_discount),
    }


def line_body(item: OrderItem) -> dict:
    return {
        "id": item.pk,
        "variant_id": item.variant_id,
        "product_id": item.product_id,
        "product_name": item.product_name,
        "variant_name": item.variant_name,
        "image": item.image,
        "mrp": money_str(item.mrp),
        "selling_price": money_str(item.selling_price),
        "quantity": item.quantity,
        "line_mrp_total": money_str(item.mrp * item.quantity),
        "line_total": money_str(item.line_total),
    }


def order_body(order: Order, now: datetime | None = None) -> dict:
    items = list(order.items.all())
    instructions = order.instructions or {}
    return {
        "id": order.pk,
        "order_number": order.order_number,
        "status": order.status,
        "payment_method": order.payment_method,
        "payment_status": order.payment_status,
        "store": {"id": order.store_id, "name": order.store.name},
        "items": [line_body(item) for item in items],
        "item_count": sum(item.quantity for item in items),
        "bill": bill_body(order),
        "coupon_code": order.coupon_code or None,
        "address": order.address_snapshot,
        "instructions": {
            "chips": list(instructions.get("chips", [])),
            "note": instructions.get("note", ""),
        },
        "created_at": order.created_at,
        "placed_at": order.placed_at,
        "payment_expires_at": order.payment_expires_at,
        "eta_at": order.eta_at,
        "can_cancel": can_cancel(order),
        "can_retry_payment": can_retry_payment(order, now),
    }


def summary_body(order: Order, now: datetime | None = None) -> dict:
    items = list(order.items.all())
    return {
        "id": order.pk,
        "order_number": order.order_number,
        "status": order.status,
        "payment_method": order.payment_method,
        "payment_status": order.payment_status,
        "store": {"id": order.store_id, "name": order.store.name},
        "item_count": sum(item.quantity for item in items),
        "images": [item.image for item in items if item.image][:SUMMARY_IMAGES],
        "grand_total": money_str(order.grand_total),
        "created_at": order.created_at,
        "placed_at": order.placed_at,
        "payment_expires_at": order.payment_expires_at,
        "eta_at": order.eta_at,
        "can_retry_payment": can_retry_payment(order, now),
    }


def checkout_body(
    order: Order, payment: Payment | None, now: datetime | None = None
) -> dict | None:
    """Razorpay checkout options, only while the order can still be paid with this payment."""
    now = now or timezone.now()
    if payment is None or payment.status != PaymentAttemptStatus.CREATED:
        return None
    if not can_retry_payment(order, now):
        return None
    user = order.user
    return {
        "key_id": get_gateway().key_id,
        "order_id": payment.gateway_order_id,
        "amount": to_paise(payment.amount),
        "currency": payment.currency,
        "name": MERCHANT_NAME,
        "description": f"Order {order.order_number}",
        "prefill": {
            "name": user.name or "",
            "contact": user.phone or "",
            "email": user.email or "",
        },
        "expires_at": order.payment_expires_at,
        "timeout_seconds": max(1, math.ceil((order.payment_expires_at - now).total_seconds())),
    }


def latest_open_payment(order: Order) -> Payment | None:
    return (
        order.payments.filter(status=PaymentAttemptStatus.CREATED).order_by("-created_at").first()
    )


def placement_body(order: Order, payment: Payment | None = None) -> dict:
    """`OrderPlacement`: the order and, while it awaits payment, its checkout options (the given
    payment, else its latest open one)."""
    if payment is None and order.status == OrderStatus.PAYMENT_PENDING:
        payment = latest_open_payment(order)
    return {"order": order_body(order), "razorpay": checkout_body(order, payment)}
