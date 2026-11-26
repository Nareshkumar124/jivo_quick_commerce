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
    "is_personal": False,
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
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
    "is_personal": False,
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
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
    "is_personal": False,
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
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
    "is_personal": False,
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
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
    "is_personal": False,
    "source": "NONE",
    "free_variant_id": None,
    "free_quantity": None,
}
REFERRAL_REWARD_OFFER = {
    "code": "REFK7M2PQ9X",
    "title": "₹90 off: referral reward",
    "description": "Your reward for inviting a friend. One use, only for you.",
    "discount_type": "FLAT",
    "value": "90.00",
    "max_discount": None,
    "min_order_value": "0.00",
    "ends_at": "2026-12-13T09:30:00Z",
    "is_applied": False,
    "is_eligible": True,
    "savings": "90.00",
    "ineligible_reason": None,
    "message": None,
    "amount_to_unlock": None,
    "is_personal": True,
    "source": "REFERRAL_REFERRER",
    "free_variant_id": None,
    "free_quantity": None,
}
# ADR 0002/0003: a free-carton reward of 2 cartons. It saves no money ("0.00"). The store has a
# fixed free size (1 L, variant 4001), so `free_variant_id` is pre-filled and the reward is
# applied without a size; the cart then shows its cartons in `free_lines` (source REWARD).
WELCOME_REWARD_OFFER = {
    "code": "WEL7K2M9QPX",
    "title": "2 free cartons: welcome reward",
    "description": "Welcome to Jivo: 2 free cartons with an order, only for you.",
    "discount_type": "FREE_UNIT",
    "value": "2.00",
    "max_discount": None,
    "min_order_value": "0.00",
    "ends_at": "2026-12-25T09:30:00Z",
    "is_applied": False,
    "is_eligible": True,
    "savings": "0.00",
    "ineligible_reason": None,
    "message": None,
    "amount_to_unlock": None,
    "is_personal": True,
    "source": "WELCOME",
    "free_variant_id": 4001,
    "free_quantity": 2,
}
COUPON_LIST = {
    "results": [
        REFERRAL_REWARD_OFFER,
        OILS15_OFFER,
        JIVO10_OFFER,
        JIVO50_OFFER,
        WELCOME_REWARD_OFFER,
        BIGSAVE200_OFFER,
        WELCOME100_OFFER,
    ]
}
COUPON_LIST_EMPTY = {"results": []}


# --------------------------------------------------------------------------- rewards (ADR 0002)

# ADR 0003: each reward has its own `quantity` (2 since the settings say 2) and the store's fixed
# free size (`free_variant`, 1 L): the app shows "2 free cartons · 1 L x 12 (carton)" and **Use**
# applies it without a size sheet.
FREE_VARIANT_1L = {"id": 4001, "name": "1 L x 12 (carton)", "product_name": "Jivo Water"}
REWARD_WELCOME = {
    "code": "WEL7K2M9QPX",
    "title": "2 free cartons: welcome reward",
    "quantity": 2,
    "free_variant": FREE_VARIANT_1L,
    "source": "WELCOME",
    "status": "AVAILABLE",
    "expires_at": "2026-12-25T09:30:00Z",
    "order_number": None,
}
REWARD_REFERRAL_CLAIMED = {
    "code": "REF4Q8N2KXW",
    "title": "2 free cartons: you invited a friend",
    "quantity": 2,
    "free_variant": FREE_VARIANT_1L,
    "source": "REFERRAL_REFERRER",
    "status": "CLAIMED",
    "expires_at": "2026-12-20T11:00:00Z",
    "order_number": "JV-261124-000318",
}
# A store without a fixed free size (ADR 0002): the customer picks the size.
REWARD_WELCOME_PICK_SIZE = {**REWARD_WELCOME, "free_variant": None}
REWARDS = {
    "available": [REWARD_WELCOME, REWARD_REFERRAL_CLAIMED],
    "history": [
        {
            "at": "2026-11-24T08:15:00Z",
            "kind": "CLAIMED",
            "title": "Referral reward: you invited a friend",
            "quantity": 2,
            "order_number": "JV-261124-000318",
        },
        {
            "at": "2026-11-22T12:40:00Z",
            "kind": "VOLUME_FREE",
            "title": "2 free cartons with your order",
            "quantity": 2,
            "order_number": "JV-261122-000287",
        },
        {
            "at": "2026-11-20T11:00:00Z",
            "kind": "EARNED",
            "title": "Referral reward: you invited a friend",
            "quantity": 2,
            "order_number": None,
        },
        {
            "at": "2026-11-18T09:30:00Z",
            "kind": "EARNED",
            "title": "Welcome reward",
            "quantity": 2,
            "order_number": None,
        },
    ],
}
REWARDS_NO_FIXED_SIZE = {"available": [REWARD_WELCOME_PICK_SIZE], "history": []}
REWARDS_EMPTY = {"available": [], "history": []}
