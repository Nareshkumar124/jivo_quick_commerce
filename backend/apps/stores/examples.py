"""Example payloads for the Phase 2 serviceability contract. The apps build their fakes from these,
so each one is a complete, valid instance of its schema (checked by tests/test_schema_examples.py).

Times are UTC. The closed-store examples are taken at 23:30 IST (18:00 UTC) on 2 Nov 2026; the
store opens at 7:00 AM IST = 01:30 UTC the next day.
"""

STORE_OPEN = {"id": 1, "name": "Jivo Sector 14, Gurugram", "is_open": True, "opens_at": None}
STORE_CLOSED_FOR_NIGHT = {**STORE_OPEN, "is_open": False, "opens_at": "2026-11-03T01:30:00Z"}
STORE_PAUSED = {**STORE_OPEN, "is_open": False, "opens_at": None}

SERVICEABLE = {"serviceable": True, "store": STORE_OPEN, "eta_minutes": 14, "message": None}
SERVICEABLE_STORE_CLOSED = {
    "serviceable": True,
    "store": STORE_CLOSED_FOR_NIGHT,
    "eta_minutes": None,
    "message": "The store is closed now. It opens at 7:00 AM.",
}
SERVICEABLE_STORE_PAUSED = {
    "serviceable": True,
    "store": STORE_PAUSED,
    "eta_minutes": None,
    "message": "The store is not taking orders right now. Please check back soon.",
}
NOT_SERVICEABLE = {
    "serviceable": False,
    "store": None,
    "eta_minutes": None,
    "message": "We're not in your area yet. Tap Notify me and we'll tell you when we arrive.",
}

NOTIFY_ME_REQUEST = {
    "lat": 28.6692,
    "lng": 77.4538,
    "address_text": "Raj Nagar Extension, Ghaziabad, Uttar Pradesh 201017",
}
NOTIFY_ME_ANONYMOUS_REQUEST = {**NOTIFY_ME_REQUEST, "phone": "+919876543210"}
NOTIFY_ME = {
    "id": 301,
    **NOTIFY_ME_REQUEST,
    "phone": "+919876543210",
    "created_at": "2026-11-02T10:15:00Z",
}
