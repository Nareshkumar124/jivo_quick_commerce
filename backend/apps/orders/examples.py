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
        "quantity_unavailable": 0,
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
        "quantity_unavailable": 0,
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
    # Phase 4 (additive)
    "cancellation": None,
    "amount_refunded": "0.00",
    "refunds": [],
    "can_download_invoice": False,
}


def step(status: str, title: str, at: str) -> dict:
    return {"status": status, "title": title, "at": at}


PENDING_STEP = step("PAYMENT_PENDING", "Completing payment…", PLACED_AT)

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
    "can_cancel": True,  # 08 §7: PLACED and ACCEPTED too (Phase 4)
    "can_retry_payment": False,
    "timeline": [step("PLACED", "Order placed", PLACED_AT)],
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
    "timeline": [PENDING_STEP],
}
# After `POST /payments/razorpay/verify/` (or the payment.captured webhook) at 06:32:10.
ORDER_ONLINE_PLACED = {
    **ORDER_ONLINE_PENDING,
    "status": "PLACED",
    "payment_status": "PAID",
    "placed_at": "2026-11-03T06:32:10Z",
    "payment_expires_at": None,
    "eta_at": "2026-11-03T06:46:00Z",
    "can_cancel": True,
    "can_retry_payment": False,
    "timeline": [PENDING_STEP, step("PLACED", "Order placed", "2026-11-03T06:32:10Z")],
}
# T5: the customer gave up on paying ("Cancel order" on the payment-failed screen).
ORDER_PAYMENT_CANCELLED = {
    **ORDER_ONLINE_PENDING,
    "status": "CANCELLED",
    "payment_status": "FAILED",
    "payment_expires_at": None,
    "can_cancel": False,
    "can_retry_payment": False,
    "timeline": [PENDING_STEP, step("CANCELLED", "Cancelled", "2026-11-03T06:40:00Z")],
    "cancellation": {
        "reason": "CHANGE_PAYMENT_METHOD",
        "message": "I want to pay another way",
        "cancelled_by": "customer",
        "cancelled_at": "2026-11-03T06:40:00Z",
    },
}

# --------------------------------------------------------------------------- Phase 4 states

# T6: the store accepted the paid order at 06:32:40.
ORDER_ACCEPTED = {
    **ORDER_ONLINE_PLACED,
    "status": "ACCEPTED",
    "timeline": [
        *ORDER_ONLINE_PLACED["timeline"],
        step("ACCEPTED", "Order confirmed", "2026-11-03T06:32:40Z"),
    ],
}
# T7 + T8a: while packing (06:33:30) the store found only one 1 L canola (06:34:05). The bill is
# recomputed (08 §6.3): items ₹504, JIVO50 kept (₹50), delivery still free, tip ₹20 -> ₹474.
# The difference (₹753 - ₹474 = ₹279) is being refunded to the original payment.
ORDER_ITEM_UNAVAILABLE = {
    **ORDER_ACCEPTED,
    "status": "PACKING",
    "payment_status": "REFUND_PENDING",
    "items": [
        {
            **ORDER_LINES[0],
            "quantity_unavailable": 1,
            "line_mrp_total": "349.00",
            "line_total": "279.00",
        },
        ORDER_LINES[1],
    ],
    "item_count": 2,
    "bill": {
        "mrp_total": "599.00",
        "item_total": "504.00",
        "product_discount": "95.00",
        "coupon_discount": "50.00",
        "delivery_fee": "0.00",
        "small_cart_fee": "0.00",
        "handling_fee": "0.00",
        "tip": "20.00",
        "grand_total": "474.00",
        "total_savings": "145.00",
    },
    "can_cancel": False,
    "timeline": [
        *ORDER_ACCEPTED["timeline"],
        step("PACKING", "Packing your order", "2026-11-03T06:33:30Z"),
    ],
    "refunds": [
        {
            "id": 7101,
            "amount": "279.00",
            "status": "PENDING",
            "reason": "ITEMS_UNAVAILABLE",
            "created_at": "2026-11-03T06:34:05Z",
            "processed_at": None,
        }
    ],
}
# T11: the customer cancelled the accepted order at 06:35:00; the full ₹753 was refunded.
ORDER_CANCELLED_REFUNDED = {
    **ORDER_ACCEPTED,
    "status": "CANCELLED",
    "payment_status": "REFUNDED",
    "can_cancel": False,
    "timeline": [
        *ORDER_ACCEPTED["timeline"],
        step("CANCELLED", "Cancelled", "2026-11-03T06:35:00Z"),
    ],
    "cancellation": {
        "reason": "CHANGED_MIND",
        "message": "I changed my mind",
        "cancelled_by": "customer",
        "cancelled_at": "2026-11-03T06:35:00Z",
    },
    "amount_refunded": "753.00",
    "refunds": [
        {
            "id": 7102,
            "amount": "753.00",
            "status": "PROCESSED",
            "reason": "ORDER_CANCELLED",
            "created_at": "2026-11-03T06:35:00Z",
            "processed_at": "2026-11-03T06:35:04Z",
        }
    ],
}
# T12: the store cancelled a COD order (nothing was due, nothing to refund).
ORDER_CANCELLED_BY_STORE = {
    **ORDER_COD_PLACED,
    "status": "CANCELLED",
    "payment_status": "FAILED",
    "can_cancel": False,
    "timeline": [
        *ORDER_COD_PLACED["timeline"],
        step("CANCELLED", "Cancelled", "2026-11-03T06:31:30Z"),
    ],
    "cancellation": {
        "reason": "ITEMS_UNAVAILABLE",
        "message": "Items are not available at the store",
        "cancelled_by": "store",
        "cancelled_at": "2026-11-03T06:31:30Z",
    },
}
# Delivered (T9/T10 arrive in Phase 5): the GST invoice can be downloaded.
ORDER_DELIVERED = {
    **ORDER_COD_PLACED,
    "status": "DELIVERED",
    "payment_status": "COD_COLLECTED",
    "can_cancel": False,
    "can_download_invoice": True,
    "timeline": [
        *ORDER_COD_PLACED["timeline"],
        step("ACCEPTED", "Order confirmed", "2026-11-03T06:30:20Z"),
        step("PACKING", "Packing your order", "2026-11-03T06:31:00Z"),
        step("PACKED", "Packed, rider on the way to store", "2026-11-03T06:34:00Z"),
        step("OUT_FOR_DELIVERY", "On the way", "2026-11-03T06:35:30Z"),
        step("DELIVERED", "Delivered", "2026-11-03T06:43:10Z"),
    ],
}
PHASE4_ORDERS = (
    ORDER_ACCEPTED,
    ORDER_ITEM_UNAVAILABLE,
    ORDER_CANCELLED_REFUNDED,
    ORDER_CANCELLED_BY_STORE,
    ORDER_DELIVERED,
)
ORDER_CANCEL_CHANGED_MIND_REQUEST = {"reason": "CHANGED_MIND"}

INVOICE = {
    "invoice_number": "GGN01/26-27/000122",
    "issued_at": "2026-11-03T06:43:10Z",
    "url": (
        "https://media.jivo.example/jivo-media/invoices/1/GGN01-26-27-000122.pdf"
        "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=600&X-Amz-Signature=3b1f0c"
    ),
    "expires_at": "2026-11-03T07:00:00Z",
}

REORDER_ALL_ADDED = {"cart": cart.CART_READY, "added_count": 2, "unavailable": []}
# A past order of canola 1 L x 2, wheatgrass x 1 and chia x 2: the first two are back in the
# cart (CART_READY), chia is out of stock.
REORDER_SOME_UNAVAILABLE = {
    "cart": cart.CART_READY,
    "added_count": 2,
    "unavailable": [
        {
            "variant_id": 3001,
            "product_name": "Jivo Chia Seeds",
            "variant_name": "100 g",
            "requested_quantity": 2,
            "added_quantity": 0,
            "reason": "OUT_OF_STOCK",
        },
    ],
}

# --------------------------------------------------------------------------- checkout

GATEWAY_ORDER_ID = "order_Nq3uVxY7kL9pQe"
RAZORPAY_CHECKOUT = {
    "key_id": "rzp_test_EXAMPLEEXAMPLE",
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
    "count": 2,
    "next": None,
    "previous": None,
    "results": [
        summary({**ORDER_DELIVERED, "id": 4901, "order_number": "JV-261102-000088"}),
        summary({**ORDER_PAYMENT_CANCELLED, "id": 4870, "order_number": "JV-261101-000057"}),
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


# --------------------------------------------------------------------------- tracking (Phase 5)

_TRACK = {
    "order_id": 1203,
    "order_number": "JV-261110-001203",
    "store": {"id": 1, "name": "Jivo Sector 14", "lat": 28.4718, "lng": 77.0436},
    "destination": {"lat": 28.5012, "lng": 77.0688},
    "server_time": "2026-11-10T09:45:00.000000Z",
}
TRACK_PACKING = {
    **_TRACK,
    "status": "PACKING",
    "eta_at": "2026-11-10T09:58:00Z",
    "live_eta_at": "2026-11-10T09:57:00Z",
    "live_eta_minutes": 12,
    "rider": {
        "name": "Ravi K.",
        "phone": None,
        "photo": (
            "https://jivo-media.s3.ap-south-1.amazonaws.com/kyc/42/photo-5f1c2a9be03d47a1.jpg"
            "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=3600&X-Amz-Signature=3b1f0c"
        ),
        "lat": 28.4702,
        "lng": 77.0411,
        "updated_at": "2026-11-10T09:44:55Z",
    },
    "delivery_otp": None,
    "task_status": "ASSIGNED",
}
TRACK_NO_RIDER = {
    **TRACK_PACKING,
    "status": "ACCEPTED",
    "rider": None,
    "task_status": "SEARCHING",
    "live_eta_at": "2026-11-10T10:00:00Z",
    "live_eta_minutes": 15,
}
TRACK_OUT_FOR_DELIVERY = {
    **TRACK_PACKING,
    "status": "OUT_FOR_DELIVERY",
    "rider": {
        **TRACK_PACKING["rider"],
        "phone": "+919811122233",
        "lat": 28.4890,
        "lng": 77.0570,
    },
    "delivery_otp": "4821",
    "task_status": "PICKED_UP",
    "live_eta_at": "2026-11-10T09:52:00Z",
    "live_eta_minutes": 7,
}
TRACK_DELIVERED = {
    **TRACK_PACKING,
    "status": "DELIVERED",
    "eta_at": None,
    "live_eta_at": None,
    "live_eta_minutes": None,
    "rider": None,
    "task_status": "DELIVERED",
}
