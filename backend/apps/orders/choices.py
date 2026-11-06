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


class ActorType(models.TextChoices):
    """Who made a state change (07 §2.6 `OrderStatusHistory.actor_type`, `cancelled_by_type`)."""

    CUSTOMER = "customer", "Customer"
    STORE = "store", "Store staff"
    RIDER = "rider", "Rider"
    OPS = "ops", "Ops / support"
    SYSTEM = "system", "System"


class StaffCancelReason(models.TextChoices):
    """Phase 4 (08 T12): why the store, ops or support cancelled an order (reason required)."""

    ITEMS_UNAVAILABLE = "ITEMS_UNAVAILABLE", "Items are not available at the store"
    STORE_CLOSING = "STORE_CLOSING", "The store had to close"
    ADDRESS_ISSUE = "ADDRESS_ISSUE", "We could not deliver to this address"
    CUSTOMER_REQUEST = "CUSTOMER_REQUEST", "Cancelled at your request"
    SUSPECTED_FRAUD = "SUSPECTED_FRAUD", "The order could not be verified"
    NO_RIDER = "NO_RIDER", "No delivery partner was available"
    OTHER_STAFF = "OTHER_STAFF", "Cancelled by the store"


class OrderCancelReason(models.TextChoices):
    """Every cancellation reason an order can carry (`Order.cancellation.reason`): the customer's
    (`CancelReason`), the staff's (`StaffCancelReason`) and the system's."""

    CHANGE_PAYMENT_METHOD = (
        CancelReason.CHANGE_PAYMENT_METHOD.value,
        CancelReason.CHANGE_PAYMENT_METHOD.label,
    )
    PAYMENT_PROBLEM = CancelReason.PAYMENT_PROBLEM.value, CancelReason.PAYMENT_PROBLEM.label
    ORDERED_BY_MISTAKE = (
        CancelReason.ORDERED_BY_MISTAKE.value,
        CancelReason.ORDERED_BY_MISTAKE.label,
    )
    CHANGED_MIND = CancelReason.CHANGED_MIND.value, CancelReason.CHANGED_MIND.label
    DELIVERY_TOO_SLOW = CancelReason.DELIVERY_TOO_SLOW.value, CancelReason.DELIVERY_TOO_SLOW.label
    OTHER = CancelReason.OTHER.value, CancelReason.OTHER.label
    ITEMS_UNAVAILABLE = (
        StaffCancelReason.ITEMS_UNAVAILABLE.value,
        StaffCancelReason.ITEMS_UNAVAILABLE.label,
    )
    STORE_CLOSING = StaffCancelReason.STORE_CLOSING.value, StaffCancelReason.STORE_CLOSING.label
    ADDRESS_ISSUE = StaffCancelReason.ADDRESS_ISSUE.value, StaffCancelReason.ADDRESS_ISSUE.label
    CUSTOMER_REQUEST = (
        StaffCancelReason.CUSTOMER_REQUEST.value,
        StaffCancelReason.CUSTOMER_REQUEST.label,
    )
    SUSPECTED_FRAUD = (
        StaffCancelReason.SUSPECTED_FRAUD.value,
        StaffCancelReason.SUSPECTED_FRAUD.label,
    )
    NO_RIDER = StaffCancelReason.NO_RIDER.value, StaffCancelReason.NO_RIDER.label
    OTHER_STAFF = StaffCancelReason.OTHER_STAFF.value, StaffCancelReason.OTHER_STAFF.label


class OrderRefundReason(models.TextChoices):
    """Why money went back to the customer (`Order.refunds[].reason`), grouped for display."""

    ORDER_CANCELLED = "ORDER_CANCELLED", "Order cancelled"
    ITEMS_UNAVAILABLE = "ITEMS_UNAVAILABLE", "Items not available"
    DELIVERY_FAILED = "DELIVERY_FAILED", "Delivery unsuccessful"
    PAYMENT_ISSUE = "PAYMENT_ISSUE", "Extra or late payment returned"
    GOODWILL = "GOODWILL", "Refund from customer support"


class OrderRefundStatus(models.TextChoices):
    """A refund as the customer sees it. A refund the gateway refused is retried by ops, so it
    stays PENDING for the customer."""

    PENDING = "PENDING", "Refund in progress"
    PROCESSED = "PROCESSED", "Refunded"


class ReorderIssueReason(models.TextChoices):
    """Why a line of a past order could not be put back in the cart in full."""

    OUT_OF_STOCK = "OUT_OF_STOCK", "Out of stock"
    LIMITED_STOCK = "LIMITED_STOCK", "Only part of the quantity is available"
    NOT_AVAILABLE = "NOT_AVAILABLE", "No longer sold at this store"


# 08 §1 order of the store's work: the customer may cancel up to `CUSTOMER_CANCEL_UNTIL`.
STORE_FLOW = (
    OrderStatus.PLACED,
    OrderStatus.ACCEPTED,
    OrderStatus.PACKING,
    OrderStatus.PACKED,
)


def customer_cancellable() -> frozenset[str]:
    """08 §7: PAYMENT_PENDING plus the store states up to the setting `CUSTOMER_CANCEL_UNTIL`
    (default ACCEPTED). T11 covers PLACED/ACCEPTED only, so a later setting is capped there."""
    from django.conf import settings

    until = getattr(settings, "CUSTOMER_CANCEL_UNTIL", OrderStatus.ACCEPTED)
    allowed = {OrderStatus.PAYMENT_PENDING}
    for status in (OrderStatus.PLACED, OrderStatus.ACCEPTED):
        allowed.add(status)
        if status == until:
            break
    return frozenset(allowed)
