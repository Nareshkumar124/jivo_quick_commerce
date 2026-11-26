"""Example payloads for the referral contract (06 §2.1 "Referral"). Since ADR 0002 the reward is
free cartons for each of the two customers, valid 30 days; since ADR 0003 their number is a setting
(`reward_quantity`, 2 on staging, like `welcome_reward_quantity`). `reward_amount`
is the old ₹ setting, kept for older apps and not given any more."""

SHARE = "Use my code {code} on the Jivo app and we both get 2 free cartons."

NEW_CUSTOMER = {
    "code": "K7M2PQ",
    "share_message": SHARE.format(code="K7M2PQ"),
    "is_enabled": True,
    "reward_type": "FREE_UNIT",
    "reward_quantity": 2,
    "reward_label": "2 free cartons",
    "welcome_reward_quantity": 2,
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
    "share_message": SHARE.format(code="XR4TNW"),
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
