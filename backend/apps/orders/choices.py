"""Order enums (07 §2.6, 08 §1). Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class OrderStatus(models.TextChoices):
    """08 §1. Labels are the customer-facing texts; the apps map statuses to their own text."""

    PAYMENT_PENDING = "PAYMENT_PENDING", "Completing payment…"
    PLACED = "PLACED", "Order placed"
    ACCEPTED = "ACCEPTED", "Order confirmed"
    PACKING = "PACKING", "Packing your order"
    PACKED = "PACKED", "Packed, rider on the way to store"
    OUT_FOR_DELIVERY = "OUT_FOR_DELIVERY", "On the way"
    DELIVERED = "DELIVERED", "Delivered"
    CANCELLED = "CANCELLED", "Cancelled"
    PAYMENT_FAILED = "PAYMENT_FAILED", "Payment failed"
    DELIVERY_FAILED = "DELIVERY_FAILED", "Delivery unsuccessful"
    RETURNED = "RETURNED", "Delivery unsuccessful"


# 08 §1 "Terminal?" column. Everything else is active (`GET /orders/?status=active`).
TERMINAL_STATUSES = frozenset(
    {
        OrderStatus.DELIVERED,
        OrderStatus.CANCELLED,
        OrderStatus.PAYMENT_FAILED,
        OrderStatus.RETURNED,
    }
)
ACTIVE_STATUSES = frozenset(set(OrderStatus) - TERMINAL_STATUSES)


class PaymentMethod(models.TextChoices):
    ONLINE = "ONLINE", "Pay online"
    COD = "COD", "Cash on delivery"


class PaymentStatus(models.TextChoices):
    """07 §2.6 `payment_status`."""

    PENDING = "PENDING", "Awaiting payment"
    PAID = "PAID", "Paid"
    FAILED = "FAILED", "Not paid"
    REFUND_PENDING = "REFUND_PENDING", "Refund in progress"
    REFUNDED = "REFUNDED", "Refunded"
    PARTIALLY_REFUNDED = "PARTIALLY_REFUNDED", "Partially refunded"
    COD_PENDING = "COD_PENDING", "Pay on delivery"
    COD_COLLECTED = "COD_COLLECTED", "Paid on delivery"


class OrderListStatus(models.TextChoices):
    """The `status` filter of `GET /orders/`."""

    ACTIVE = "active", "Active (not finished yet)"
    PAST = "past", "Past (delivered, cancelled, failed or returned)"


class CancelReason(models.TextChoices):
    """Customer cancellation reasons (03 §2.10 reason picker)."""

    CHANGE_PAYMENT_METHOD = "CHANGE_PAYMENT_METHOD", "I want to pay another way"
    PAYMENT_PROBLEM = "PAYMENT_PROBLEM", "The payment did not work"
    ORDERED_BY_MISTAKE = "ORDERED_BY_MISTAKE", "I ordered by mistake"
    CHANGED_MIND = "CHANGED_MIND", "I changed my mind"
    DELIVERY_TOO_SLOW = "DELIVERY_TOO_SLOW", "Delivery is taking too long"
    OTHER = "OTHER", "Other"
