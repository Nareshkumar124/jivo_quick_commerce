"""Example payloads for the Phase 1 contract. The apps build their fakes from these, so each one is
a complete, valid instance of its schema (checked by tests/test_schema_examples.py)."""

# Decodable JWTs (header + payload) with a fake signature. Payload: token_type, exp, iat, jti,
# user_id=42. They are examples only and never valid on any server.
ACCESS_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkzNjExODAwLCJpYXQiOjE3OTM2MTA5MDAsImp0aSI6IjZmMWMy"
    "YjllOGQ3YTRjNWI5ZTBmMWEyYjNjNGQ1ZTZmIiwidXNlcl9pZCI6NDJ9."
    "c2lnbmF0dXJlLWZvci1leGFtcGxlcy1vbmx5"
)
REFRESH_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc5NjIwMjkwMCwiaWF0IjoxNzkzNjEwOTAwLCJqdGkiOiIwYTli"
    "OGM3ZDZlNWY0YTNiMmMxZDBlOWY4YTdiNmM1ZCIsInVzZXJfaWQiOjQyfQ."
    "c2lnbmF0dXJlLWZvci1leGFtcGxlcy1vbmx5"
)
ROTATED_ACCESS_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkzNjEyNzAwLCJpYXQiOjE3OTM2MTE4MDAsImp0aSI6IjdlNmQ1"
    "YzRiM2EyZjFlMGQ5YzhiN2E2ZjVlNGQzYzJiIiwidXNlcl9pZCI6NDJ9."
    "c2lnbmF0dXJlLWZvci1leGFtcGxlcy1vbmx5"
)
ROTATED_REFRESH_TOKEN = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc5NjIwMzgwMCwiaWF0IjoxNzkzNjExODAwLCJqdGkiOiIxYjJj"
    "M2Q0ZTVmNmE3YjhjOWQwZTFmMmEzYjRjNWQ2ZSIsInVzZXJfaWQiOjQyfQ."
    "c2lnbmF0dXJlLWZvci1leGFtcGxlcy1vbmx5"
)

ME = {
    "id": 42,
    "phone": "+919876543210",
    "name": "Asha Verma",
    "email": "asha.verma@example.com",
    "marketing_opt_in": False,
    "is_profile_complete": True,
    "rider_status": "NONE",
    "created_at": "2026-10-20T06:30:00Z",
}
NEW_ME = {
    "id": 42,
    "phone": "+919876543210",
    "name": "",
    "email": None,
    "marketing_opt_in": False,
    "is_profile_complete": False,
    "rider_status": "NONE",
    "created_at": "2026-11-02T10:15:00Z",
}
RIDER_ME = {
    "id": 57,
    "phone": "+919811122233",
    "name": "Ravi Kumar",
    "email": None,
    "marketing_opt_in": False,
    "is_profile_complete": True,
    "rider_status": "PENDING_KYC",
    "created_at": "2026-10-28T04:00:00Z",
}

OTP_SENT = {"otp_length": 6, "expires_in_seconds": 300, "resend_after_seconds": 30}

SESSION_NEW_CUSTOMER = {
    "access": ACCESS_TOKEN,
    "refresh": REFRESH_TOKEN,
    "user": NEW_ME,
    "is_new_user": True,
    "rider_status": "NONE",
    "deletion_cancelled": False,
}
SESSION_RETURNING_CUSTOMER = {**SESSION_NEW_CUSTOMER, "user": ME, "is_new_user": False}
SESSION_RIDER_NO_PROFILE = {
    **SESSION_NEW_CUSTOMER,
    "user": {**NEW_ME, "phone": "+919811122233"},
}
SESSION_RIDER_PENDING_KYC = {
    **SESSION_NEW_CUSTOMER,
    "user": RIDER_ME,
    "is_new_user": False,
    "rider_status": "PENDING_KYC",
}

TOKEN_PAIR = {"access": ROTATED_ACCESS_TOKEN, "refresh": ROTATED_REFRESH_TOKEN}

ACCOUNT_DELETION = {
    "deleted_at": "2026-11-02T10:15:00Z",
    "anonymise_after": "2026-12-02T10:15:00Z",
}

DEVICE = {
    "id": 7,
    "fcm_token": "dQw4w9WgXcQ:APA91bHun4MxP5egoKMwt2KZFBaFUH-1RYqx",
    "app": "customer",
    "platform": "android",
    "app_version": "1.0.0+12",
    "is_active": True,
    "last_seen_at": "2026-11-02T10:15:00Z",
}

ADDRESS = {
    "id": 12,
    "label": "home",
    "custom_label": "",
    "receiver_name": "Asha Verma",
    "receiver_phone": "+919876543210",
    "house": "Flat 402, Tower B",
    "building_street": "Sunshine Apartments, MG Road",
    "landmark": "Opposite City Mall",
    "area": "Sector 14",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.4595,
    "lng": 77.0266,
    "is_default": True,
    "created_at": "2026-10-20T06:35:00Z",
    "updated_at": "2026-10-20T06:35:00Z",
}
ADDRESS_WORK = {
    **ADDRESS,
    "id": 13,
    "label": "other",
    "custom_label": "Mom's place",
    "receiver_name": "Sunita Verma",
    "receiver_phone": "+919812345678",
    "house": "House 18",
    "building_street": "Block C, Sushant Lok 1",
    "landmark": "",
    "area": "Sushant Lok",
    "lat": 28.4646,
    "lng": 77.0864,
    "is_default": False,
    "created_at": "2026-10-25T12:00:00Z",
    "updated_at": "2026-10-25T12:00:00Z",
}
ADDRESS_CREATE_REQUEST = {
    "label": "other",
    "custom_label": "Mom's place",
    "receiver_name": "Sunita Verma",
    "receiver_phone": "+919812345678",
    "house": "House 18",
    "building_street": "Block C, Sushant Lok 1",
    "area": "Sushant Lok",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.4646,
    "lng": 77.0864,
}
ADDRESS_PAGE = {"count": 2, "next": None, "previous": None, "results": [ADDRESS, ADDRESS_WORK]}
SESSION_DELETION_CANCELLED = {
    **SESSION_NEW_CUSTOMER,
    "user": ME,
    "is_new_user": False,
    "deletion_cancelled": True,
}
