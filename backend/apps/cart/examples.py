"""Example payloads for the Phase 3 cart contract. The apps build their fakes from these, so each
one is a complete, valid instance of its schema (tests/test_schema_examples.py) and its money is
consistent with 08 §6.2 and the D-09 defaults (apps/cart/tests/test_contract.py recomputes every
bill): minimum order ₹99; delivery fee ₹25, free from ₹299; small-cart fee ₹15 below ₹149;
handling fee ₹0; COD up to ₹2,000. Thresholds compare against the item total before the coupon.

Store 1 is "Jivo Sector 14, Gurugram"; address 12 is serviceable, address 13 is not.
"""

from apps.accounts.examples import ADDRESS, ADDRESS_WORK
from apps.catalog import examples as cat
from apps.stores.examples import STORE_CLOSED_FOR_NIGHT, STORE_OPEN

# --------------------------------------------------------------------------- extra variants
# Two low-priced products, so the small-cart fee and the minimum order can be shown.

CHIA_IMAGE = cat.image("3a9c5e/chia-100g", "Jivo Chia Seeds 100 g pack")
FLAX_IMAGE = cat.image("71be0d/flax-200g", "Jivo Roasted Flax Seeds 200 g pack")
CHIA_100G = {
    "id": 3001,
    "name": "100 g",
    "mrp": "150.00",
    "selling_price": "119.00",
    "discount_amount": "31.00",
    "discount_percent": 20,
    "unit_price": {"amount": "119.00", "per": "100 g"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 5,
    "units_left": None,
    "max_qty_per_order": 5,
    "image": CHIA_IMAGE,
}
FLAX_200G = {
    "id": 3002,
    "name": "200 g",
    "mrp": "99.00",
    "selling_price": "79.00",
    "discount_amount": "20.00",
    "discount_percent": 20,
    "unit_price": {"amount": "39.50", "per": "100 g"},
    "stock_status": "IN_STOCK",
    "orderable_quantity": 5,
    "units_left": None,
    "max_qty_per_order": 5,
    "image": FLAX_IMAGE,
}


def product(card: dict) -> dict:
    return {key: card[key] for key in ("id", "slug", "name", "brand", "is_veg")}


CANOLA_PRODUCT = product(cat.CANOLA)
MUSTARD_PRODUCT = product(cat.MUSTARD)
WHEATGRASS_PRODUCT = product(cat.WHEATGRASS)
ALOE_PRODUCT = product(cat.ALOE)
CHIA_PRODUCT = {
    "id": 301,
    "slug": "jivo-chia-seeds",
    "name": "Jivo Chia Seeds",
    "brand": "Jivo",
    "is_veg": True,
}
FLAX_PRODUCT = {
    "id": 302,
    "slug": "jivo-roasted-flax-seeds",
    "name": "Jivo Roasted Flax Seeds",
    "brand": "Jivo",
    "is_veg": True,
}

# --------------------------------------------------------------------------- lines

LINE_CANOLA_1L_X2 = {
    "id": 501,
    "product": CANOLA_PRODUCT,
    "variant": cat.CANOLA_1L,
    "quantity": 2,
    "line_mrp_total": "698.00",
    "line_total": "558.00",
    "issue": None,
}
LINE_WHEATGRASS_X1 = {
    "id": 502,
    "product": WHEATGRASS_PRODUCT,
    "variant": cat.WHEATGRASS_500ML,
    "quantity": 1,
    "line_mrp_total": "250.00",
    "line_total": "225.00",
    "issue": None,
}
LINE_ALOE_X1 = {
    "id": 503,
    "product": ALOE_PRODUCT,
    "variant": cat.ALOE_1L,
    "quantity": 1,
    "line_mrp_total": "299.00",
    "line_total": "299.00",
    "issue": None,
}
LINE_CHIA_X1 = {
    "id": 504,
    "product": CHIA_PRODUCT,
    "variant": CHIA_100G,
    "quantity": 1,
    "line_mrp_total": "150.00",
    "line_total": "119.00",
    "issue": None,
}
LINE_FLAX_X1 = {
    "id": 505,
    "product": FLAX_PRODUCT,
    "variant": FLAX_200G,
    "quantity": 1,
    "line_mrp_total": "99.00",
    "line_total": "79.00",
    "issue": None,
}
LINE_CANOLA_5L_X3_LOW = {
    "id": 506,
    "product": CANOLA_PRODUCT,
    "variant": cat.CANOLA_5L,  # LOW_STOCK, orderable_quantity 2
    "quantity": 3,
    "line_mrp_total": "4950.00",
    "line_total": "3897.00",
    "issue": {"code": "QUANTITY_UNAVAILABLE", "message": "Only 2 left. Reduce the quantity to 2."},
}
LINE_MUSTARD_X1_OUT = {
    "id": 507,
    "product": MUSTARD_PRODUCT,
    "variant": cat.MUSTARD_1L,  # OUT_OF_STOCK
    "quantity": 1,
    "line_mrp_total": "210.00",
    "line_total": "189.00",
    "issue": {"code": "OUT_OF_STOCK", "message": "Out of stock. Remove it to continue."},
}

# --------------------------------------------------------------------------- pieces

NO_INSTRUCTIONS = {"chips": [], "note": ""}
INSTRUCTIONS = {
    "chips": ["DONT_RING_BELL", "LEAVE_AT_DOOR"],
    "note": "Please leave it with the guard if no one answers.",
}
ONLINE_OK = {"method": "ONLINE", "is_available": True, "unavailable_reason": None, "message": None}
COD_OK = {"method": "COD", "is_available": True, "unavailable_reason": None, "message": None}
COD_ABOVE_LIMIT = {
    "method": "COD",
    "is_available": False,
    "unavailable_reason": "ABOVE_LIMIT",
    "message": "Cash on delivery is available on orders up to ₹2,000.",
}
PAYMENT_METHODS = [ONLINE_OK, COD_OK]
READY = {"can_place_order": True, "blockers": []}


def blocked(code: str, message: str) -> dict:
    return {"can_place_order": False, "blockers": [{"code": code, "message": message}]}


def thresholds(amount_to_min_order=None, amount_to_free_delivery=None) -> dict:
    return {
        "min_order_value": "99.00",
        "amount_to_min_order": amount_to_min_order,
        "free_delivery_threshold": "299.00",
        "amount_to_free_delivery": amount_to_free_delivery,
    }


ZERO = "0.00"
EMPTY_BILL = {
    "mrp_total": ZERO,
    "item_total": ZERO,
    "product_discount": ZERO,
    "coupon_discount": ZERO,
    "delivery_fee": ZERO,
    "small_cart_fee": ZERO,
    "handling_fee": ZERO,
    "tip": ZERO,
    "grand_total": ZERO,
    "total_savings": ZERO,
}
JIVO50 = {
    "code": "JIVO50",
    "title": "Flat ₹50 off",
    "discount": "50.00",
    "is_applicable": True,
    "message": None,
    "amount_to_unlock": None,
}

# --------------------------------------------------------------------------- carts

CART_EMPTY = {
    "store": STORE_OPEN,
    "items": [],
    "item_count": 0,
    "coupon": None,
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "address": None,
    "bill": EMPTY_BILL,
    "thresholds": thresholds("99.00", "299.00"),
    "payment_methods": PAYMENT_METHODS,
    "checkout": blocked("CART_EMPTY", "Add items to your cart."),
}

# Canola 1 L x2 (₹558) + wheatgrass x1 (₹225) = ₹783; JIVO50 -₹50; free delivery; tip ₹20.
CART_READY = {
    "store": STORE_OPEN,
    "items": [LINE_CANOLA_1L_X2, LINE_WHEATGRASS_X1],
    "item_count": 3,
    "coupon": JIVO50,
    "tip": "20.00",
    "instructions": INSTRUCTIONS,
    "address": ADDRESS,
    "bill": {
        "mrp_total": "948.00",
        "item_total": "783.00",
        "product_discount": "165.00",
        "coupon_discount": "50.00",
        "delivery_fee": ZERO,
        "small_cart_fee": ZERO,
        "handling_fee": ZERO,
        "tip": "20.00",
        "grand_total": "753.00",
        "total_savings": "215.00",
    },
    "thresholds": thresholds(),
    "payment_methods": PAYMENT_METHODS,
    "checkout": READY,
}

# Thresholds use the item total before the coupon: ₹299 of items is free delivery, even though
# JIVO50 brings the amount to pay down to ₹249.
CART_COUPON_KEEPS_FREE_DELIVERY = {
    **CART_READY,
    "items": [LINE_ALOE_X1],
    "item_count": 1,
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "bill": {
        "mrp_total": "299.00",
        "item_total": "299.00",
        "product_discount": ZERO,
        "coupon_discount": "50.00",
        "delivery_fee": ZERO,
        "small_cart_fee": ZERO,
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "249.00",
        "total_savings": "50.00",
    },
}

# ₹119 of items: delivery fee ₹25 (below ₹299) and small-cart fee ₹15 (below ₹149).
CART_SMALL = {
    **CART_READY,
    "items": [LINE_CHIA_X1],
    "item_count": 1,
    "coupon": None,
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "bill": {
        "mrp_total": "150.00",
        "item_total": "119.00",
        "product_discount": "31.00",
        "coupon_discount": ZERO,
        "delivery_fee": "25.00",
        "small_cart_fee": "15.00",
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "159.00",
        "total_savings": "31.00",
    },
    "thresholds": thresholds(None, "180.00"),
}
CART_NO_ADDRESS = {
    **CART_SMALL,
    "address": None,
    "checkout": blocked("ADDRESS_REQUIRED", "Select a delivery address."),
}
CART_ADDRESS_NOT_SERVICEABLE = {
    **CART_SMALL,
    "address": ADDRESS_WORK,
    "checkout": blocked(
        "NOT_SERVICEABLE",
        "Jivo Sector 14, Gurugram does not deliver to this address. Choose another address.",
    ),
}

# ₹79 of items: below the ₹99 minimum.
CART_BELOW_MINIMUM = {
    **CART_SMALL,
    "items": [LINE_FLAX_X1],
    "bill": {
        "mrp_total": "99.00",
        "item_total": "79.00",
        "product_discount": "20.00",
        "coupon_discount": ZERO,
        "delivery_fee": "25.00",
        "small_cart_fee": "15.00",
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "119.00",
        "total_savings": "20.00",
    },
    "thresholds": thresholds("20.00", "220.00"),
    "checkout": blocked(
        "MIN_ORDER_NOT_MET", "Add items worth ₹20 more to place your order (minimum ₹99)."
    ),
}

# Stock changed after the items were added: the bill still shows the lines as they are, and
# checkout is blocked until each line is fixed. ₹4,086 is above the COD limit.
CART_STOCK_ISSUES = {
    **CART_READY,
    "items": [LINE_CANOLA_5L_X3_LOW, LINE_MUSTARD_X1_OUT],
    "item_count": 4,
    "coupon": None,
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "bill": {
        "mrp_total": "5160.00",
        "item_total": "4086.00",
        "product_discount": "1074.00",
        "coupon_discount": ZERO,
        "delivery_fee": ZERO,
        "small_cart_fee": ZERO,
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "4086.00",
        "total_savings": "1074.00",
    },
    "payment_methods": [ONLINE_OK, COD_ABOVE_LIMIT],
    "checkout": blocked(
        "STOCK_UNAVAILABLE",
        "Some items are out of stock or not available in the quantity you chose. Update them "
        "to continue.",
    ),
}

# Items were removed after JIVO50 (minimum ₹299) was applied: it stays on the cart, gives
# nothing and blocks checkout until it is removed or the cart qualifies again.
CART_COUPON_NOT_APPLICABLE = {
    **CART_READY,
    "items": [LINE_WHEATGRASS_X1],
    "item_count": 1,
    "coupon": {
        **JIVO50,
        "discount": ZERO,
        "is_applicable": False,
        "message": "Add items worth ₹74 more to use this coupon.",
        "amount_to_unlock": "74.00",
    },
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "bill": {
        "mrp_total": "250.00",
        "item_total": "225.00",
        "product_discount": "25.00",
        "coupon_discount": ZERO,
        "delivery_fee": "25.00",
        "small_cart_fee": ZERO,
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "250.00",
        "total_savings": "25.00",
    },
    "thresholds": thresholds(None, "74.00"),
    "checkout": blocked(
        "COUPON_NOT_ELIGIBLE", "Add items worth ₹74 more to use JIVO50, or remove the coupon."
    ),
}

CART_STORE_CLOSED = {
    **CART_READY,
    "store": STORE_CLOSED_FOR_NIGHT,
    "checkout": blocked("STORE_CLOSED", "The store is closed now. It opens at 7:00 AM."),
}

# The carts whose bills tests recompute from 08 §6.2.
ALL_CARTS = {
    "CART_EMPTY": CART_EMPTY,
    "CART_READY": CART_READY,
    "CART_COUPON_KEEPS_FREE_DELIVERY": CART_COUPON_KEEPS_FREE_DELIVERY,
    "CART_SMALL": CART_SMALL,
    "CART_NO_ADDRESS": CART_NO_ADDRESS,
    "CART_ADDRESS_NOT_SERVICEABLE": CART_ADDRESS_NOT_SERVICEABLE,
    "CART_BELOW_MINIMUM": CART_BELOW_MINIMUM,
    "CART_STOCK_ISSUES": CART_STOCK_ISSUES,
    "CART_COUPON_NOT_APPLICABLE": CART_COUPON_NOT_APPLICABLE,
    "CART_STORE_CLOSED": CART_STORE_CLOSED,
}

# --------------------------------------------------------------------------- requests

ITEM_ADD_REQUEST = {"variant_id": 1001, "quantity": 2}
ITEM_REMOVE_REQUEST = {"variant_id": 1001, "quantity": 0}
ITEM_UPDATE_REQUEST = {"quantity": 2}
CART_UPDATE_REQUEST = {"tip": "20.00", "instructions": INSTRUCTIONS, "address_id": 12}
CART_UPDATE_TIP_REQUEST = {"tip": "30.00"}
COUPON_APPLY_REQUEST = {"code": "jivo50"}

# --------------------------------------------------------------------------- error details

STOCK_UNAVAILABLE_DETAILS = {
    "items": [{"variant_id": 1002, "requested_quantity": 3, "orderable_quantity": 2}]
}
MAX_QTY_DETAILS = {"variant_id": 1002, "max_qty_per_order": 3}
