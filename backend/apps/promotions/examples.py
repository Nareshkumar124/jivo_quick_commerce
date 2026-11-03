"""Example payloads for the Phase 3 coupon contract, evaluated against `cart.examples.CART_READY`
(item total ₹783, of which ₹558 is cooking oil; JIVO50 applied). Savings are recomputed by
apps/cart/tests/test_contract.py.
"""

JIVO50_OFFER = {
    "code": "JIVO50",
    "title": "Flat ₹50 off",
    "description": "On orders of ₹299 or more.",
    "discount_type": "FLAT",
    "value": "50.00",
    "max_discount": None,
    "min_order_value": "299.00",
    "ends_at": "2026-12-31T18:29:59Z",
    "is_applied": True,
    "is_eligible": True,
    "savings": "50.00",
    "ineligible_reason": None,
    "message": None,
    "amount_to_unlock": None,
}
OILS15_OFFER = {
    "code": "OILS15",
    "title": "15% off cooking oils",
    "description": "On edible oils, up to ₹150.",
    "discount_type": "PERCENT",
    "value": "15.00",
    "max_discount": "150.00",
    "min_order_value": "0.00",
    "ends_at": None,
    "is_applied": False,
    "is_eligible": True,
    "savings": "83.70",  # 15% of the ₹558 of edible oils (category coupon)
    "ineligible_reason": None,
    "message": None,
    "amount_to_unlock": None,
}
JIVO10_OFFER = {
    "code": "JIVO10",
    "title": "10% off",
    "description": "On orders of ₹499 or more, up to ₹100.",
    "discount_type": "PERCENT",
    "value": "10.00",
    "max_discount": "100.00",
    "min_order_value": "499.00",
    "ends_at": "2026-11-30T18:29:59Z",
    "is_applied": False,
    "is_eligible": True,
    "savings": "78.30",
    "ineligible_reason": None,
    "message": None,
    "amount_to_unlock": None,
}
BIGSAVE200_OFFER = {
    "code": "BIGSAVE200",
    "title": "Flat ₹200 off",
    "description": "On orders of ₹1,499 or more.",
    "discount_type": "FLAT",
    "value": "200.00",
    "max_discount": None,
    "min_order_value": "1499.00",
    "ends_at": None,
    "is_applied": False,
    "is_eligible": False,
    "savings": None,
    "ineligible_reason": "MIN_ORDER_VALUE",
    "message": "Add items worth ₹716 more to unlock.",
    "amount_to_unlock": "716.00",
}
WELCOME100_OFFER = {
    "code": "WELCOME100",
    "title": "₹100 off your first order",
    "description": "On your first order of ₹399 or more.",
    "discount_type": "FLAT",
    "value": "100.00",
    "max_discount": None,
    "min_order_value": "399.00",
    "ends_at": None,
    "is_applied": False,
    "is_eligible": False,
    "savings": None,
    "ineligible_reason": "FIRST_ORDER_ONLY",
    "message": "Only for your first order.",
    "amount_to_unlock": None,
}
COUPON_LIST = {
    "results": [OILS15_OFFER, JIVO10_OFFER, JIVO50_OFFER, BIGSAVE200_OFFER, WELCOME100_OFFER]
}
COUPON_LIST_EMPTY = {"results": []}
