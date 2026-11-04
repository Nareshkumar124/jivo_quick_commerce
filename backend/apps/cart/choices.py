"""Cart enums (03 §2.8). Published in the OpenAPI contract (ENUM_NAME_OVERRIDES)."""

from django.db import models


class DeliveryInstructionChip(models.TextChoices):
    """03 §2.8 delivery instruction chips."""

    DONT_RING_BELL = "DONT_RING_BELL", "Don't ring the bell"
    LEAVE_AT_DOOR = "LEAVE_AT_DOOR", "Leave at the door"
    AVOID_CALLING = "AVOID_CALLING", "Avoid calling"


class CartLineIssueCode(models.TextChoices):
    """Why a line cannot be ordered as it is. The fix: set the line to the variant's
    `orderable_quantity` (remove it when that is 0)."""

    OUT_OF_STOCK = "OUT_OF_STOCK", "Out of stock: remove it to continue."
    QUANTITY_UNAVAILABLE = (
        "QUANTITY_UNAVAILABLE",
        "Not available in this quantity: reduce it to continue.",
    )


class CheckoutBlockerCode(models.TextChoices):
    """Why the cart cannot be ordered yet. Values that are also error codes (06 §6) are the
    error `POST /orders/` would return; the app can reuse its message for them."""

    CART_EMPTY = "CART_EMPTY", "Add items to your cart."
    ADDRESS_REQUIRED = "ADDRESS_REQUIRED", "Select a delivery address."
    NOT_SERVICEABLE = "NOT_SERVICEABLE", "We do not deliver to this address from this store."
    STORE_CLOSED = "STORE_CLOSED", "The store is not accepting orders right now."
    STOCK_UNAVAILABLE = "STOCK_UNAVAILABLE", "Some items are not available as chosen."
    MIN_ORDER_NOT_MET = "MIN_ORDER_NOT_MET", "The minimum order value is not met."
    COUPON_INVALID = "COUPON_INVALID", "The coupon is not valid."
    COUPON_EXPIRED = "COUPON_EXPIRED", "The coupon has expired."
    COUPON_NOT_ELIGIBLE = "COUPON_NOT_ELIGIBLE", "This cart is not eligible for the coupon."
    COUPON_USAGE_EXCEEDED = "COUPON_USAGE_EXCEEDED", "The coupon usage limit is reached."


class PaymentUnavailableReason(models.TextChoices):
    """Why a payment method cannot be used for this cart (COD rules, 08 T2)."""

    COD_DISABLED = "COD_DISABLED", "The store does not offer cash on delivery."
    ABOVE_LIMIT = "ABOVE_LIMIT", "The order is above the cash-on-delivery limit."
    NOT_ALLOWED = "NOT_ALLOWED", "Cash on delivery is not available for this account."
