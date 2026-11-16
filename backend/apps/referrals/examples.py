"""Example payloads for the referral contract (06 §2.1 "Referral"). Default settings: ₹90 off,
30 days, no minimum."""

NEW_CUSTOMER = {
    "code": "K7M2PQ",
    "share_message": "Use my code K7M2PQ on the Jivo app and we both get ₹90 off.",
    "is_enabled": True,
    "reward_amount": "90.00",
    "reward_validity_days": 30,
    "reward_min_order_value": "0.00",
    "can_apply_code": True,
    "referred_by": None,
    "friends_joined": 0,
    "friends_rewarded": 0,
}
JOINED_PENDING = {
    **NEW_CUSTOMER,
    "can_apply_code": False,
    "referred_by": {
        "code_masked": "AB**7P",
        "status": "PENDING",
        "applied_at": "2026-11-13T08:15:00Z",
    },
}
REFERRER_WITH_FRIENDS = {
    **NEW_CUSTOMER,
    "code": "XR4TNW",
    "share_message": "Use my code XR4TNW on the Jivo app and we both get ₹90 off.",
    "can_apply_code": False,
    "referred_by": {
        "code_masked": "AB**7P",
        "status": "REWARDED",
        "applied_at": "2026-10-02T11:40:00Z",
    },
    "friends_joined": 3,
    "friends_rewarded": 1,
}
PAUSED = {**NEW_CUSTOMER, "is_enabled": False, "can_apply_code": False}

APPLY_REQUEST = {"code": "ab3k 7p"}
