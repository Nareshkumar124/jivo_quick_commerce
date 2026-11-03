"""Example payloads for the Phase 3 order contract. The apps build their fakes from these, so each
one is a complete, valid instance of its schema (tests/test_schema_examples.py).

Both example orders are placed from `cart.examples.CART_READY` (₹753.00 to pay) at 06:30 UTC
(12:00 IST) on 3 Nov 2026. The online payment window is 15 minutes.
"""

from apps.accounts.examples import ADDRESS, ME
from apps.cart import examples as cart
from apps.catalog import examples as cat
from apps.payments.gateways import FAKE_KEY_ID

STORE = {"id": 1, "name": "Jivo Sector 14, Gurugram"}
ORDER_ADDRESS = {
    key: ADDRESS[key]
    for key in (
        "label",
        "custom_label",
        "receiver_name",
        "receiver_phone",
        "house",
        "building_street",
        "landmark",
        "area",
        "city",
        "state",
        "pincode",
        "lat",
        "lng",
    )
}
ORDER_LINES = [
    {
        "id": 9001,
        "variant_id": 1001,
        "product_id": 101,
        "product_name": "Jivo Cold Pressed Canola Oil",
        "variant_name": "1 L",
        "image": cat.CANOLA_1L_IMAGE,
        "mrp": "349.00",
        "selling_price": "279.00",
        "quantity": 2,
        "line_mrp_total": "698.00",
        "line_total": "558.00",
    },
    {
        "id": 9002,
        "variant_id": 2001,
        "product_id": 201,
        "product_name": "Jivo Wheatgrass Juice",
        "variant_name": "500 ml",
        "image": cat.WHEATGRASS_IMAGE,
        "mrp": "250.00",
        "selling_price": "225.00",
        "quantity": 1,
        "line_mrp_total": "250.00",
        "line_total": "225.00",
    },
]

PLACED_AT = "2026-11-03T06:30:00Z"
_ORDER = {
    "store": STORE,
    "items": ORDER_LINES,
    "item_count": 3,
    "bill": cart.CART_READY["bill"],
    "coupon_code": "JIVO50",
    "address": ORDER_ADDRESS,
    "instructions": cart.INSTRUCTIONS,
    "created_at": PLACED_AT,
}

ORDER_COD_PLACED = {
    "id": 5011,
    "order_number": "JV-261103-000122",
    "status": "PLACED",
    "payment_method": "COD",
    "payment_status": "COD_PENDING",
    **_ORDER,
    "placed_at": PLACED_AT,
    "payment_expires_at": None,
    "eta_at": "2026-11-03T06:44:00Z",
    "can_cancel": False,  # Phase 3: only unpaid orders; Phase 4 allows PLACED/ACCEPTED (08 §7)
    "can_retry_payment": False,
}
ORDER_ONLINE_PENDING = {
    "id": 5012,
    "order_number": "JV-261103-000123",
    "status": "PAYMENT_PENDING",
    "payment_method": "ONLINE",
    "payment_status": "PENDING",
    **_ORDER,
    "placed_at": None,
    "payment_expires_at": "2026-11-03T06:45:00Z",
    "eta_at": None,
    "can_cancel": True,
    "can_retry_payment": True,
}
# After `POST /payments/razorpay/verify/` (or the payment.captured webhook) at 06:32:10.
ORDER_ONLINE_PLACED = {
    **ORDER_ONLINE_PENDING,
    "status": "PLACED",
    "payment_status": "PAID",
    "placed_at": "2026-11-03T06:32:10Z",
    "payment_expires_at": None,
    "eta_at": "2026-11-03T06:46:00Z",
    "can_cancel": False,
    "can_retry_payment": False,
}
# T5: the customer gave up on paying ("Cancel order" on the payment-failed screen).
ORDER_PAYMENT_CANCELLED = {
    **ORDER_ONLINE_PENDING,
    "status": "CANCELLED",
    "payment_status": "FAILED",
    "payment_expires_at": None,
    "can_cancel": False,
    "can_retry_payment": False,
}

# --------------------------------------------------------------------------- checkout

GATEWAY_ORDER_ID = "order_Nq3uVxY7kL9pQe"
RAZORPAY_CHECKOUT = {
    "key_id": "rzp_test_Jv7x2QmP9kLs4T",
    "order_id": GATEWAY_ORDER_ID,
    "amount": 75300,
    "currency": "INR",
    "name": "Jivo",
    "description": "Order JV-261103-000123",
    "prefill": {"name": ME["name"], "contact": ME["phone"], "email": ME["email"]},
    "expires_at": "2026-11-03T06:45:00Z",
    "timeout_seconds": 900,
}
RAZORPAY_CHECKOUT_FAKE = {**RAZORPAY_CHECKOUT, "key_id": FAKE_KEY_ID}
# Retried at 06:36:00: a new Razorpay order; the payment window is not extended.
RAZORPAY_CHECKOUT_RETRY = {
    **RAZORPAY_CHECKOUT,
    "order_id": "order_Nq4BcD5eF6gH7i",
    "timeout_seconds": 540,
}

PLACEMENT_COD = {"order": ORDER_COD_PLACED, "razorpay": None}
PLACEMENT_ONLINE = {"order": ORDER_ONLINE_PENDING, "razorpay": RAZORPAY_CHECKOUT}
PLACEMENT_ONLINE_FAKE = {"order": ORDER_ONLINE_PENDING, "razorpay": RAZORPAY_CHECKOUT_FAKE}
PLACEMENT_RETRY = {"order": ORDER_ONLINE_PENDING, "razorpay": RAZORPAY_CHECKOUT_RETRY}
# A replay (same Idempotency-Key) after the payment went through: no checkout to open.
PLACEMENT_REPLAY_PAID = {"order": ORDER_ONLINE_PLACED, "razorpay": None}

ORDER_CREATE_ONLINE_REQUEST = {
    "address_id": 12,
    "payment_method": "ONLINE",
    "expected_grand_total": "753.00",
}
ORDER_CREATE_COD_REQUEST = {**ORDER_CREATE_ONLINE_REQUEST, "payment_method": "COD"}
ORDER_CANCEL_REQUEST = {"reason": "CHANGE_PAYMENT_METHOD"}
ORDER_CANCEL_OTHER_REQUEST = {"reason": "OTHER", "note": "Wrong address selected."}

# --------------------------------------------------------------------------- list


def summary(order: dict) -> dict:
    return {
        "id": order["id"],
        "order_number": order["order_number"],
        "status": order["status"],
        "payment_method": order["payment_method"],
        "payment_status": order["payment_status"],
        "store": order["store"],
        "item_count": order["item_count"],
        "images": [line["image"] for line in order["items"][:4] if line["image"]],
        "grand_total": order["bill"]["grand_total"],
        "created_at": order["created_at"],
        "placed_at": order["placed_at"],
        "payment_expires_at": order["payment_expires_at"],
        "eta_at": order["eta_at"],
        "can_retry_payment": order["can_retry_payment"],
    }


ORDERS_ACTIVE = {
    "count": 2,
    "next": None,
    "previous": None,
    "results": [summary(ORDER_ONLINE_PENDING), summary(ORDER_COD_PLACED)],
}
ORDERS_PAST = {
    "count": 1,
    "next": None,
    "previous": None,
    "results": [
        summary({**ORDER_PAYMENT_CANCELLED, "id": 4870, "order_number": "JV-261101-000057"})
    ],
}
ORDERS_EMPTY = {"count": 0, "next": None, "previous": None, "results": []}

# --------------------------------------------------------------------------- error details

PRICE_CHANGED_DETAILS = {"expected_grand_total": "753.00", "grand_total": "778.00"}
STOCK_UNAVAILABLE_DETAILS = {
    "items": [
        {"variant_id": 1002, "requested_quantity": 3, "orderable_quantity": 2},
        {"variant_id": 1004, "requested_quantity": 1, "orderable_quantity": 0},
    ]
}
MIN_ORDER_DETAILS = {
    "min_order_value": "99.00",
    "item_total": "79.00",
    "amount_to_min_order": "20.00",
}
COD_ABOVE_LIMIT_DETAILS = {"reason": "ABOVE_LIMIT", "cod_max_order_value": "2000.00"}
STORE_CLOSED_DETAILS = {"store_id": 1, "opens_at": "2026-11-03T01:30:00Z"}
