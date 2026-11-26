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
    "min_qty_per_order": 1,
    "price_tiers": [],
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
    "min_qty_per_order": 1,
    "price_tiers": [],
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
    "price_per_unit": cat.CANOLA_1L["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "698.00",
    "line_total": "558.00",
    "issue": None,
}
LINE_WHEATGRASS_X1 = {
    "id": 502,
    "product": WHEATGRASS_PRODUCT,
    "variant": cat.WHEATGRASS_500ML,
    "quantity": 1,
    "price_per_unit": cat.WHEATGRASS_500ML["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "250.00",
    "line_total": "225.00",
    "issue": None,
}
LINE_ALOE_X1 = {
    "id": 503,
    "product": ALOE_PRODUCT,
    "variant": cat.ALOE_1L,
    "quantity": 1,
    "price_per_unit": cat.ALOE_1L["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "299.00",
    "line_total": "299.00",
    "issue": None,
}
LINE_CHIA_X1 = {
    "id": 504,
    "product": CHIA_PRODUCT,
    "variant": CHIA_100G,
    "quantity": 1,
    "price_per_unit": CHIA_100G["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "150.00",
    "line_total": "119.00",
    "issue": None,
}
LINE_FLAX_X1 = {
    "id": 505,
    "product": FLAX_PRODUCT,
    "variant": FLAX_200G,
    "quantity": 1,
    "price_per_unit": FLAX_200G["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "99.00",
    "line_total": "79.00",
    "issue": None,
}
LINE_CANOLA_5L_X3_LOW = {
    "id": 506,
    "product": CANOLA_PRODUCT,
    "variant": cat.CANOLA_5L,  # LOW_STOCK, orderable_quantity 2
    "quantity": 3,
    "price_per_unit": cat.CANOLA_5L["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "4950.00",
    "line_total": "3897.00",
    "issue": {"code": "QUANTITY_UNAVAILABLE", "message": "Only 2 left. Reduce the quantity to 2."},
}
LINE_MUSTARD_X1_OUT = {
    "id": 507,
    "product": MUSTARD_PRODUCT,
    "variant": cat.MUSTARD_1L,  # OUT_OF_STOCK
    "quantity": 1,
    "price_per_unit": cat.MUSTARD_1L["selling_price"],
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
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
        "min_order_units": 0,
        "units_to_min_order": None,
        "order_unit_label": "items",
        "tier_units": 0,
        "next_price_tier": None,
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
    "free_items_value": ZERO,
}
JIVO50 = {
    "code": "JIVO50",
    "title": "Flat ₹50 off",
    "discount_type": "FLAT",
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
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
    "free_lines": [],
    "free_offer": None,
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
        "free_items_value": ZERO,
    },
    "free_lines": [],
    "free_offer": None,
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
        "free_items_value": ZERO,
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
        "free_items_value": ZERO,
    },
    "thresholds": thresholds(None, "180.00"),
}
# API request #56: chia was ₹129 when the customer added it and is ₹119 now. Display only: the
# bill is CART_SMALL's (today's price); the flag clears on the line's next quantity set.
CART_PRICE_CHANGED = {
    **CART_SMALL,
    "items": [{**LINE_CHIA_X1, "previous_selling_price": "129.00"}],
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
        "free_items_value": ZERO,
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
        "free_items_value": ZERO,
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
        "free_items_value": ZERO,
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

# ------------------------------------------------------------------- free cartons (ADR 0002)
# Jivo Water by the carton: flat rates (MRP = selling price), minimum 5 paid cartons, volume
# offer 1 free for every 10 paid. 1 L x8 (₹880) + 500 ml x4 (₹560) = 12 paid cartons, ₹1,440.
# Volume offer: 12 // 10 = 1 free carton of the cheapest size (1 L, ₹110). The welcome reward
# is applied with the 500 ml size picked: 1 more free carton (MRP ₹140). Free cartons cost ₹0:
# `free_items_value` ₹250 is only in `total_savings`.

WATER_IMAGE = cat.image("5d2f8a/jivo-water", "Jivo Water carton")
WATER_PRODUCT = {
    "id": 401,
    "slug": "jivo-water",
    "name": "Jivo Water",
    "brand": "Jivo",
    "is_veg": True,
}


def water_variant(variant_id: int, name: str, price: str, per: str, unit: str) -> dict:
    return {
        "id": variant_id,
        "name": name,
        "mrp": price,
        "selling_price": price,
        "discount_amount": "0.00",
        "discount_percent": 0,
        "unit_price": {"amount": unit, "per": per},
        "stock_status": "IN_STOCK",
        "orderable_quantity": 50,
        "units_left": None,
        "max_qty_per_order": 50,
        "min_qty_per_order": 1,
        "price_tiers": [],
        "image": WATER_IMAGE,
    }


WATER_1L = water_variant(4001, "1 L x 12 (carton)", "110.00", "1 L", "9.17")
WATER_500ML = water_variant(4002, "500 ml x 24 (carton)", "140.00", "1 L", "11.67")
LINE_WATER_1L_X8 = {
    "id": 511,
    "product": WATER_PRODUCT,
    "variant": WATER_1L,
    "quantity": 8,
    "price_per_unit": "110.00",
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "880.00",
    "line_total": "880.00",
    "issue": None,
}
LINE_WATER_500ML_X4 = {
    "id": 512,
    "product": WATER_PRODUCT,
    "variant": WATER_500ML,
    "quantity": 4,
    "price_per_unit": "140.00",
    "previous_selling_price": None,
    "price_tier": None,
    "next_tier_price": None,
    "line_mrp_total": "560.00",
    "line_total": "560.00",
    "issue": None,
}
FREE_WATER_1L_VOLUME = {
    "product": WATER_PRODUCT,
    "variant": WATER_1L,
    "quantity": 1,
    "mrp": "110.00",
    "value": "110.00",
    "source": "VOLUME_OFFER",
}
FREE_WATER_500ML_REWARD = {
    "product": WATER_PRODUCT,
    "variant": WATER_500ML,
    "quantity": 1,
    "mrp": "140.00",
    "value": "140.00",
    "source": "REWARD",
}
WELCOME_REWARD_APPLIED = {
    "code": "WEL7K2M9QPX",
    "title": "1 free carton: welcome reward",
    "discount_type": "FREE_UNIT",
    "source": "WELCOME",
    "free_variant_id": 4002,
    "free_quantity": 1,
    "discount": ZERO,
    "is_applicable": True,
    "message": None,
    "amount_to_unlock": None,
}
FREE_OFFER_12 = {
    "every": 10,
    "paid_units": 12,
    "free_units": 1,
    "units_to_next_free": 8,
    "message": "Add 8 more cartons to get 1 more free",
    "notice": None,
    "free_variant": None,  # ADR 0002 store: no fixed free size (the cheapest size in the cart)
}
CART_FREE_CARTONS = {
    **CART_READY,
    "items": [LINE_WATER_1L_X8, LINE_WATER_500ML_X4],
    "item_count": 12,
    "coupon": WELCOME_REWARD_APPLIED,
    "tip": ZERO,
    "instructions": NO_INSTRUCTIONS,
    "bill": {
        "mrp_total": "1440.00",
        "item_total": "1440.00",
        "product_discount": ZERO,
        "coupon_discount": ZERO,
        "delivery_fee": ZERO,
        "small_cart_fee": ZERO,
        "handling_fee": ZERO,
        "tip": ZERO,
        "grand_total": "1440.00",
        "total_savings": "250.00",
        "free_items_value": "250.00",
    },
    "free_lines": [FREE_WATER_1L_VOLUME, FREE_WATER_500ML_REWARD],
    "free_offer": FREE_OFFER_12,
    "thresholds": {
        **thresholds(),
        "min_order_units": 5,
        "order_unit_label": "cartons",
    },
}
# 10 cartons of 1 L earn 1 free 1 L carton, but the store has only the 10 paid ones: no free
# carton is given and the cart says so (a notice, not a blocker).
CART_FREE_CARTON_NO_STOCK = {
    **CART_FREE_CARTONS,
    "items": [
        {
            **LINE_WATER_1L_X8,
            "variant": {
                **WATER_1L,
                "orderable_quantity": 10,
                "stock_status": "LOW_STOCK",
                "units_left": 10,
            },
            "quantity": 10,
            "line_mrp_total": "1100.00",
            "line_total": "1100.00",
        }
    ],
    "item_count": 10,
    "coupon": None,
    "bill": {
        **CART_FREE_CARTONS["bill"],
        "mrp_total": "1100.00",
        "item_total": "1100.00",
        "grand_total": "1100.00",
        "total_savings": ZERO,
        "free_items_value": ZERO,
    },
    "free_lines": [],
    "free_offer": {
        "every": 10,
        "paid_units": 10,
        "free_units": 1,
        "units_to_next_free": 10,
        "message": "Add 10 more cartons to get 1 more free",
        "notice": "Your free carton is out of stock right now, so it is not added.",
        "free_variant": None,
    },
}

# ADR 0003: the store's fixed free size is the 1 L carton (`free_offer.free_variant`), so every
# free carton is 1 L whatever the paid sizes. The same 12 paid cartons (1 L x8 + 500 ml x4) earn
# 1 free 1 L carton (volume offer), and the welcome reward, applied without a size, adds its
# 2 free 1 L cartons. `free_items_value` = 3 x ₹110 = ₹330.
FREE_VARIANT_1L = {"id": 4001, "name": "1 L x 12 (carton)", "product_name": "Jivo Water"}
FREE_WATER_1L_REWARD_X2 = {
    "product": WATER_PRODUCT,
    "variant": WATER_1L,
    "quantity": 2,
    "mrp": "110.00",
    "value": "220.00",
    "source": "REWARD",
}
WELCOME_REWARD_X2_APPLIED = {
    **WELCOME_REWARD_APPLIED,
    "title": "2 free cartons: welcome reward",
    "free_variant_id": 4001,
    "free_quantity": 2,
}
CART_FREE_CARTONS_FIXED_SIZE = {
    **CART_FREE_CARTONS,
    "coupon": WELCOME_REWARD_X2_APPLIED,
    "bill": {
        **CART_FREE_CARTONS["bill"],
        "total_savings": "330.00",
        "free_items_value": "330.00",
    },
    "free_lines": [FREE_WATER_1L_VOLUME, FREE_WATER_1L_REWARD_X2],
    "free_offer": {**FREE_OFFER_12, "free_variant": FREE_VARIANT_1L},
}

# The carts whose bills tests recompute from 08 §6.2.
ALL_CARTS = {
    "CART_EMPTY": CART_EMPTY,
    "CART_READY": CART_READY,
    "CART_COUPON_KEEPS_FREE_DELIVERY": CART_COUPON_KEEPS_FREE_DELIVERY,
    "CART_SMALL": CART_SMALL,
    "CART_PRICE_CHANGED": CART_PRICE_CHANGED,
    "CART_NO_ADDRESS": CART_NO_ADDRESS,
    "CART_ADDRESS_NOT_SERVICEABLE": CART_ADDRESS_NOT_SERVICEABLE,
    "CART_BELOW_MINIMUM": CART_BELOW_MINIMUM,
    "CART_STOCK_ISSUES": CART_STOCK_ISSUES,
    "CART_COUPON_NOT_APPLICABLE": CART_COUPON_NOT_APPLICABLE,
    "CART_STORE_CLOSED": CART_STORE_CLOSED,
    "CART_FREE_CARTONS": CART_FREE_CARTONS,
    "CART_FREE_CARTON_NO_STOCK": CART_FREE_CARTON_NO_STOCK,
    "CART_FREE_CARTONS_FIXED_SIZE": CART_FREE_CARTONS_FIXED_SIZE,
}

# --------------------------------------------------------------------------- requests

ITEM_ADD_REQUEST = {"variant_id": 1001, "quantity": 2}
ITEM_REMOVE_REQUEST = {"variant_id": 1001, "quantity": 0}
ITEM_UPDATE_REQUEST = {"quantity": 2}
CART_UPDATE_REQUEST = {"tip": "20.00", "instructions": INSTRUCTIONS, "address_id": 12}
CART_UPDATE_TIP_REQUEST = {"tip": "30.00"}
COUPON_APPLY_REQUEST = {"code": "jivo50"}
COUPON_APPLY_REWARD_REQUEST = {"code": "WEL7K2M9QPX", "free_variant_id": 4002}
# ADR 0003: the store has a fixed free size, so the reward is applied without a size.
COUPON_APPLY_REWARD_FIXED_SIZE_REQUEST = {"code": "WEL7K2M9QPX"}

# --------------------------------------------------------------------------- error details

STOCK_UNAVAILABLE_DETAILS = {
    "items": [{"variant_id": 1002, "requested_quantity": 3, "orderable_quantity": 2}]
}
MAX_QTY_DETAILS = {"variant_id": 1002, "max_qty_per_order": 3}
MIN_QTY_DETAILS = {"variant_id": 1002, "min_qty_per_order": 2}
