"""OpenAPI examples for the rider contract (Phase 5). The rider app builds its fakes from these,
and `tests/test_schema_examples.py` validates every one against its schema."""

LOCATION_SETTINGS = {
    "active_interval_seconds": 10,
    "idle_interval_seconds": 30,
    "active_sample_seconds": 5,
    "idle_sample_seconds": 30,
    "max_batch": 50,
}
SERVER_TIME = "2026-11-10T09:30:00.120000Z"

STORE = {"id": 1, "name": "Jivo Sector 14", "city": "Gurugram"}
STORES = {
    "results": [
        STORE,
        {"id": 2, "name": "Jivo DLF Phase 3", "city": "Gurugram"},
    ]
}

CASH_OK = {"cash_in_hand": "1250.00", "cash_limit": "5000.00", "limit_reached": False}
CASH_ZERO = {"cash_in_hand": "0.00", "cash_limit": "5000.00", "limit_reached": False}
CASH_LIMIT = {"cash_in_hand": "5120.00", "cash_limit": "5000.00", "limit_reached": True}
TODAY_ZERO = {
    "date": "2026-11-05",
    "orders_delivered": 0,
    "earnings": "0.00",
    "cash_in_hand": "0.00",
    "online_seconds": 0,
}
TODAY_ACTIVE = {
    "date": "2026-11-10",
    "orders_delivered": 4,
    "earnings": "212.00",
    "cash_in_hand": "1250.00",
    "online_seconds": 21600,
}

REGISTER_REQUEST = {
    "full_name": "Ravi Kumar",
    "dob": "1998-04-12",
    "emergency_contact_name": "Sunita Devi",
    "emergency_contact_phone": "+919812345670",
    "preferred_store_id": 1,
    "vehicle_type": "MOTORBIKE",
    "vehicle_number": "HR26DQ1234",
}
REGISTER_REQUEST_BICYCLE = {
    "full_name": "Amit Singh",
    "dob": "2001-09-30",
    "emergency_contact_name": "Rajesh Singh",
    "emergency_contact_phone": "+919899001122",
    "preferred_store_id": 1,
    "vehicle_type": "BICYCLE",
}

_PROFILE_BASE = {
    "id": 42,
    "phone": "+919811122233",
    "rejection_reason": "",
    "suspension_reason": "",
    "full_name": "Ravi Kumar",
    "dob": "1998-04-12",
    "emergency_contact_name": "Sunita Devi",
    "emergency_contact_phone": "+919812345670",
    "vehicle_type": "MOTORBIKE",
    "vehicle_number": "HR26DQ1234",
    "preferred_store": STORE,
    "rating_avg": None,
    "required_documents": ["PHOTO", "AADHAAR_FRONT", "AADHAAR_BACK", "PAN", "DL", "RC"],
    "is_online": False,
    "created_at": "2026-11-05T06:12:40.512000Z",
}
PHOTO_URL = (
    "https://jivo-media.s3.ap-south-1.amazonaws.com/kyc/42/photo-5f1c2a9be03d47a1c6e8b2f4.jpg"
    "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Expires=3600&X-Amz-Signature=3b1f0c"
)


def _doc(doc_type, status="PENDING", masked=None, note="", reviewed_at=None):
    return {
        "doc_type": doc_type,
        "status": status,
        "doc_number_masked": masked,
        "review_note": note,
        "uploaded_at": "2026-11-05T06:20:11.000000Z",
        "reviewed_at": reviewed_at,
    }


DOC_PHOTO = _doc("PHOTO")
DOC_AADHAAR_FRONT = _doc("AADHAAR_FRONT", masked="XXXX XXXX 1234")
DOC_AADHAAR_BACK = _doc("AADHAAR_BACK")
DOC_PAN = _doc("PAN", masked="ABXXXXXX4F")
DOC_DL = _doc("DL", masked="XXXXXXXXXXX2345")
DOC_RC = _doc("RC", masked="XXXXXX1234")
REVIEWED = "2026-11-05T11:02:00.000000Z"
DOC_DL_REJECTED = _doc(
    "DL",
    status="REJECTED",
    masked="XXXXXXXXXXX2345",
    note="The licence has expired. Upload your renewed licence.",
    reviewed_at=REVIEWED,
)
ALL_APPROVED = [
    _doc("PHOTO", "APPROVED", reviewed_at=REVIEWED),
    _doc("AADHAAR_FRONT", "APPROVED", "XXXX XXXX 1234", reviewed_at=REVIEWED),
    _doc("AADHAAR_BACK", "APPROVED", reviewed_at=REVIEWED),
    _doc("PAN", "APPROVED", "ABXXXXXX4F", reviewed_at=REVIEWED),
    _doc("DL", "APPROVED", "XXXXXXXXXXX2345", reviewed_at=REVIEWED),
    _doc("RC", "APPROVED", "XXXXXX1234", reviewed_at=REVIEWED),
]
BANK = {
    "holder_name": "Ravi Kumar",
    "account_number_masked": "XXXXXX6789",
    "ifsc": "HDFC0001234",
    "upi_id": "ravi.kumar@okhdfcbank",
    "updated_at": "2026-11-05T06:25:30.000000Z",
}
BANK_REQUEST = {
    "holder_name": "Ravi Kumar",
    "account_number": "50100123456789",
    "ifsc": "HDFC0001234",
    "upi_id": "ravi.kumar@okhdfcbank",
}

PROFILE_JUST_REGISTERED = {
    "today": TODAY_ZERO,
    **_PROFILE_BASE,
    "status": "PENDING_KYC",
    "home_store": None,
    "photo_url": None,
    "photo_url_expires_at": None,
    "documents": [],
    "missing_documents": ["PHOTO", "AADHAAR_FRONT", "AADHAAR_BACK", "PAN", "DL", "RC"],
    "bank_account": None,
    "ready_for_review": False,
    "cash": CASH_ZERO,
}
PROFILE_IN_REVIEW = {
    "today": TODAY_ZERO,
    **_PROFILE_BASE,
    "status": "PENDING_KYC",
    "home_store": None,
    "photo_url": PHOTO_URL,
    "photo_url_expires_at": "2026-11-05T07:25:30.000000Z",
    "documents": [DOC_PHOTO, DOC_AADHAAR_FRONT, DOC_AADHAAR_BACK, DOC_PAN, DOC_DL, DOC_RC],
    "missing_documents": [],
    "bank_account": BANK,
    "ready_for_review": True,
    "cash": CASH_ZERO,
}
PROFILE_REJECTED = {
    **PROFILE_IN_REVIEW,
    "status": "REJECTED",
    "rejection_reason": "Your PAN photo is not readable. Upload a clear photo.",
    "documents": [
        DOC_PHOTO,
        DOC_AADHAAR_FRONT,
        DOC_AADHAAR_BACK,
        _doc(
            "PAN",
            "REJECTED",
            "ABXXXXXX4F",
            note="Blurred photo. Take it again in good light.",
            reviewed_at=REVIEWED,
        ),
        DOC_DL,
        DOC_RC,
    ],
    "missing_documents": ["PAN"],
    "ready_for_review": False,
}
PROFILE_ACTIVE = {
    "today": TODAY_ACTIVE,
    **_PROFILE_BASE,
    "status": "ACTIVE",
    "home_store": {**STORE, "lat": 28.4718, "lng": 77.0436},
    "photo_url": PHOTO_URL,
    "photo_url_expires_at": "2026-11-10T10:30:00.000000Z",
    "rating_avg": "4.8",
    "documents": ALL_APPROVED,
    "missing_documents": [],
    "bank_account": BANK,
    "ready_for_review": False,
    "is_online": True,
    "cash": CASH_OK,
}
PROFILE_ACTIVE_DL_REJECTED = {
    **PROFILE_ACTIVE,
    "is_online": False,
    "documents": [*ALL_APPROVED[:4], DOC_DL_REJECTED, ALL_APPROVED[5]],
    "missing_documents": ["DL"],
}
PROFILE_PATCH_REQUEST = {"emergency_contact_name": "Sunita Kumari"}

DOCUMENT_UPLOADED = DOC_AADHAAR_FRONT
DOCUMENT_PHOTO_UPLOADED = DOC_PHOTO

# --------------------------------------------------------------------------- shift & location

SHIFT_STARTED = {
    "is_online": True,
    "shift": {
        "id": 311,
        "started_at": "2026-11-10T09:30:00.120000Z",
        "ended_at": None,
        "end_reason": None,
        "ended_by": None,
    },
    "prepaid_only": False,
    "cash": CASH_OK,
    "location": LOCATION_SETTINGS,
    "server_time": SERVER_TIME,
}
SHIFT_STARTED_PREPAID_ONLY = {**SHIFT_STARTED, "prepaid_only": True, "cash": CASH_LIMIT}
SHIFT_ENDED = {
    **SHIFT_STARTED,
    "is_online": False,
    "shift": {
        "id": 311,
        "started_at": "2026-11-10T03:30:00.000000Z",
        "ended_at": "2026-11-10T09:30:00.120000Z",
        "end_reason": "MANUAL",
        "ended_by": "rider",
    },
}
SHIFT_START_REQUEST = {"lat": 28.4595, "lng": 77.0266, "accuracy": 12.5}

LOCATIONS_REQUEST = {
    "points": [
        {
            "lat": 28.459512,
            "lng": 77.026631,
            "accuracy": 8.0,
            "speed": 6.2,
            "heading": 87.5,
            "recorded_at": "2026-11-10T09:29:50.000000Z",
            "is_mocked": False,
        },
        {
            "lat": 28.459601,
            "lng": 77.027210,
            "accuracy": 7.5,
            "speed": 6.4,
            "heading": 88.0,
            "recorded_at": "2026-11-10T09:29:55.000000Z",
            "is_mocked": False,
        },
    ]
}
LOCATIONS_RESULT = {
    "accepted": 2,
    "duplicates": 0,
    "rejected": 0,
    "location": LOCATION_SETTINGS,
    "server_time": SERVER_TIME,
}
LOCATIONS_RESULT_RESENT = {**LOCATIONS_RESULT, "accepted": 0, "duplicates": 2}

HEARTBEAT_IDLE = {
    "is_online": True,
    "pending_offer_id": None,
    "active_task_id": None,
    "shift": SHIFT_STARTED["shift"],
    "location": LOCATION_SETTINGS,
    "server_time": SERVER_TIME,
}
HEARTBEAT_OFFER = {**HEARTBEAT_IDLE, "pending_offer_id": 9001}
HEARTBEAT_OFFLINE = {
    **HEARTBEAT_IDLE,
    "is_online": False,
    "shift": {
        "id": 311,
        "started_at": "2026-11-10T03:30:00.000000Z",
        "ended_at": "2026-11-10T08:35:00.000000Z",
        "end_reason": "AUTO_OFFLINE",
        "ended_by": "system",
    },
}

# --------------------------------------------------------------------------- offers

OFFER = {
    "id": 9001,
    "task_id": 7001,
    "store_name": "Jivo Sector 14",
    "drop_locality": "Sector 21, Gurugram",
    "distance_km": "2.40",
    "payment_type": "COD",
    "cod_amount": "498.00",
    "estimated_payout": "42.00",
    "item_count": 3,
    "offered_at": "2026-11-10T09:30:00.000000Z",
    "expires_at": "2026-11-10T09:30:30.000000Z",
}
OFFER_PREPAID = {**OFFER, "payment_type": "PREPAID", "cod_amount": None}
CURRENT_OFFER = {"offer": OFFER, "server_time": SERVER_TIME}
CURRENT_OFFER_NONE = {"offer": None, "server_time": SERVER_TIME}
OFFER_REJECT_REQUEST = {"reason": "TOO_FAR"}

# --------------------------------------------------------------------------- task

_TASK_BASE = {
    "id": 7001,
    "order_id": 1203,
    "order_number": "JV-261110-001203",
    "payment_type": "COD",
    "cod_amount_due": "498.00",
    "cod_amount_previous": None,
    "store": {
        "id": 1,
        "name": "Jivo Sector 14",
        "address": "Plot 7, Sector 14, Gurugram",
        "phone": "+911244001122",
        "lat": 28.4718,
        "lng": 77.0436,
    },
    "customer_address": {
        "label": "home",
        "custom_label": "",
        "receiver_name": "Asha Verma",
        "receiver_phone": "+919876543210",
        "house": "Flat 402, Tower B",
        "building_street": "Sunshine Apartments, MG Road",
        "landmark": "Opposite City Mall",
        "area": "Sector 21",
        "city": "Gurugram",
        "state": "Haryana",
        "pincode": "122016",
        "lat": 28.5012,
        "lng": 77.0688,
    },
    "instructions": {"chips": ["DONT_RING_BELL"], "note": "Leave with the guard if I don't answer"},
    "items": [
        {"name": "Jivo Cold Pressed Canola Oil", "variant": "1 L", "quantity": 2},
        {"name": "Jivo Extra Light Olive Oil", "variant": "500 ml", "quantity": 1},
    ],
    "item_count": 3,
    "distance_km": "2.40",
    "estimated_payout": "42.00",
    "geofence": {"store_radius_m": 200, "customer_radius_m": 200},
    "delivery_otp": {"length": 4, "attempts_remaining": 5, "locked": False},
    "cod_qr": None,
    "assigned_at": "2026-11-10T09:30:12.000000Z",
    "arrived_store_at": None,
    "picked_up_at": None,
    "arrived_customer_at": None,
    "not_reachable_after": None,
    "delivered_at": None,
    "failed_at": None,
    "fail_reason": None,
    "returned_at": None,
    "earnings": None,
}
TASK_ASSIGNED = {
    **_TASK_BASE,
    "status": "ASSIGNED",
    "order_status": "PACKING",
    "ready_for_pickup": False,
}
TASK_AT_STORE_READY = {
    **TASK_ASSIGNED,
    "status": "AT_STORE",
    "order_status": "PACKED",
    "ready_for_pickup": True,
    "arrived_store_at": "2026-11-10T09:36:40.000000Z",
}
TASK_PICKED_UP = {
    **TASK_AT_STORE_READY,
    "status": "PICKED_UP",
    "order_status": "OUT_FOR_DELIVERY",
    "picked_up_at": "2026-11-10T09:38:05.000000Z",
}
TASK_AT_CUSTOMER = {
    **TASK_PICKED_UP,
    "status": "AT_CUSTOMER",
    "arrived_customer_at": "2026-11-10T09:49:30.000000Z",
    "not_reachable_after": "2026-11-10T09:59:30.000000Z",
}
COD_QR = {
    "qr_id": "qr_Nq7aB2cD3eF4gH",
    "image_url": "https://rzp.io/qr/qr_Nq7aB2cD3eF4gH.png",
    "amount": "498.00",
    "status": "PENDING",
    "expires_at": "2026-11-10T10:05:00.000000Z",
}
COD_QR_PAID = {**COD_QR, "status": "PAID"}
TASK_AT_CUSTOMER_QR = {**TASK_AT_CUSTOMER, "cod_qr": COD_QR}
TASK_OTP_WRONG_ONCE = {
    **TASK_AT_CUSTOMER,
    "delivery_otp": {"length": 4, "attempts_remaining": 4, "locked": False},
}
TASK_DELIVERED = {
    **TASK_AT_CUSTOMER,
    "status": "DELIVERED",
    "order_status": "DELIVERED",
    "delivered_at": "2026-11-10T09:51:02.000000Z",
    "earnings": {
        "total": "62.00",
        "lines": [
            {"type": "BASE", "amount": "30.00", "note": ""},
            {"type": "DISTANCE", "amount": "12.00", "note": "2.4 km"},
            {"type": "TIP", "amount": "20.00", "note": "Customer tip"},
        ],
    },
}
TASK_RETURNING = {
    **TASK_AT_CUSTOMER,
    "status": "RETURNING",
    "order_status": "DELIVERY_FAILED",
    "failed_at": "2026-11-10T10:00:15.000000Z",
    "fail_reason": "CUSTOMER_NOT_REACHABLE",
}
TASK_PREPAID_ASSIGNED = {**TASK_ASSIGNED, "payment_type": "PREPAID", "cod_amount_due": None}
TASK_COD_REDUCED = {
    **TASK_ASSIGNED,
    "cod_amount_due": "349.00",
    "cod_amount_previous": "498.00",
    "items": [{"name": "Jivo Cold Pressed Canola Oil", "variant": "1 L", "quantity": 1}],
    "item_count": 1,
}

CURRENT_TASK = {"task": TASK_AT_STORE_READY, "recent_task": None, "server_time": SERVER_TIME}
CURRENT_TASK_NONE = {"task": None, "recent_task": None, "server_time": SERVER_TIME}
CURRENT_TASK_JUST_CANCELLED = {
    "task": None,
    "recent_task": {
        "id": 7001,
        "order_number": "JV-261110-001203",
        "status": "CANCELLED",
        "ended_at": "2026-11-10T09:33:20.000000Z",
    },
    "server_time": SERVER_TIME,
}

ARRIVED_STORE_REQUEST = {"lat": 28.4719, "lng": 77.0437, "accuracy": 9.0}
ARRIVED_CUSTOMER_REQUEST = {"lat": 28.5011, "lng": 77.0689, "accuracy": 11.0}
ARRIVED_CUSTOMER_OVERRIDE_REQUEST = {
    "lat": 28.5032,
    "lng": 77.0711,
    "accuracy": 15.0,
    "override_reason": "Gated society: guard did not allow entry; waiting at gate 2",
}
PICKUP_REQUEST = {"order_code": "K7QX"}
PICKUP_QR_REQUEST = {"order_code": "JQC1:JV-261110-001203:K7QX"}
DELIVER_COD_CASH_REQUEST = {"otp": "4821", "cod": {"mode": "cash", "amount": "498.00"}}
DELIVER_COD_UPI_REQUEST = {"otp": "4821", "cod": {"mode": "upi", "amount": "498.00"}}
DELIVER_PREPAID_REQUEST = {"otp": "4821"}

# --------------------------------------------------------------------------- records

HISTORY = {
    "count": 128,
    "next": "https://api.jivo.in/api/v1/rider/tasks/history/?before_id=6990&page_size=2",
    "previous": None,
    "results": [
        {
            "task_id": 7001,
            "order_number": "JV-261110-001203",
            "status": "DELIVERED",
            "store_name": "Jivo Sector 14",
            "drop_locality": "Sector 21, Gurugram",
            "distance_km": "2.40",
            "payout": "62.00",
            "completed_at": "2026-11-10T09:51:02.000000Z",
        },
        {
            "task_id": 6990,
            "order_number": "JV-261110-001188",
            "status": "CANCELLED",
            "store_name": "Jivo Sector 14",
            "drop_locality": "Sector 15, Gurugram",
            "distance_km": None,
            "payout": None,
            "completed_at": "2026-11-10T08:12:44.000000Z",
        },
    ],
}
HISTORY_EMPTY = {"count": 0, "next": None, "previous": None, "results": []}

EARNINGS = {
    "from": "2026-11-10",
    "to": "2026-11-10",
    "total": "212.00",
    "orders_count": 4,
    "totals_by_type": {
        "BASE": "120.00",
        "DISTANCE": "52.00",
        "TIP": "40.00",
        "INCENTIVE": "20.00",
        "PENALTY": "-20.00",
    },
    "orders": [
        {
            "task_id": 7001,
            "order_number": "JV-261110-001203",
            "completed_at": "2026-11-10T09:51:02.000000Z",
            "total": "62.00",
            "lines": [
                {"type": "BASE", "amount": "30.00", "note": ""},
                {"type": "DISTANCE", "amount": "12.00", "note": "2.4 km"},
                {"type": "TIP", "amount": "20.00", "note": "Customer tip"},
            ],
        }
    ],
    "orders_truncated": False,
    "adjustments": [
        {
            "type": "INCENTIVE",
            "amount": "20.00",
            "note": "Peak hour bonus",
            "recorded_at": "2026-11-10T14:00:00.000000Z",
        },
        {
            "type": "PENALTY",
            "amount": "-20.00",
            "note": "Late return of items",
            "recorded_at": "2026-11-10T15:10:00.000000Z",
        },
    ],
}
EARNINGS_EMPTY = {
    "from": "2026-11-10",
    "to": "2026-11-10",
    "total": "0.00",
    "orders_count": 0,
    "totals_by_type": {
        "BASE": "0.00",
        "DISTANCE": "0.00",
        "TIP": "0.00",
        "INCENTIVE": "0.00",
        "PENALTY": "0.00",
    },
    "orders": [],
    "orders_truncated": False,
    "adjustments": [],
}

CASH_LEDGER = {
    "count": 57,
    "next": "https://api.jivo.in/api/v1/rider/cash/ledger/?before_id=880&page_size=2",
    "previous": None,
    "results": [
        {
            "id": 881,
            "entry_type": "COD_COLLECTED",
            "amount": "498.00",
            "balance_after": "1250.00",
            "order_number": "JV-261110-001203",
            "note": "",
            "recorded_at": "2026-11-10T09:51:02.000000Z",
        },
        {
            "id": 880,
            "entry_type": "DEPOSIT",
            "amount": "-1500.00",
            "balance_after": "752.00",
            "order_number": None,
            "note": "Deposited at Jivo Sector 14",
            "recorded_at": "2026-11-10T08:30:00.000000Z",
        },
    ],
}
CASH_LEDGER_EMPTY = HISTORY_EMPTY

PAYOUTS = {
    "count": 2,
    "next": None,
    "previous": None,
    "results": [
        {
            "id": 12,
            "period_start": "2026-11-03",
            "period_end": "2026-11-09",
            "amount": "4860.00",
            "status": "PENDING",
            "reference": None,
            "paid_at": None,
        },
        {
            "id": 11,
            "period_start": "2026-10-27",
            "period_end": "2026-11-02",
            "amount": "5212.00",
            "status": "PAID",
            "reference": "UTR2026110412345",
            "paid_at": "2026-11-04T19:00:00.000000Z",
        },
    ],
}
