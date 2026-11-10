"""Phase 2: serviceability, notify-me and address serviceability (06 §2.3, 03 §2.3/§2.4, 07 §2.2).

Oracles are independent of the implementation: PostGIS `ST_Contains` (read-only SQL) for
point-in-polygon, and the 08 §8 / 06 §2.3 ETA formula computed here from the store row.

Shared-DB discipline: notify-me writes rows (it is the feature), so these tests send only a
handful of requests, with QA numbers or no phone, at random unserviced points. The throttle test
re-uses one lead (deduplicated) so it adds no rows. Throttle counters live in the QA Redis DB.
"""

from __future__ import annotations

import math
import random

import pytest

from conftest import login
from qa_support import (
    MUMBAI,
    QA_PHONES,
    STORE_POINT,
    assert_error,
    bearer,
    clear_catalog_cache,
    clear_throttle,
    db_query,
    describe,
    validate_response,
)

SVC = "/api/v1/serviceability/"
NOTIFY = "/api/v1/serviceability/notify-me/"


def _check(api, lat, lng, **kw):
    return api.get(SVC, params={"lat": lat, "lng": lng}, **kw)


def _store_row():
    ((prep, lat, lng, name, active),) = db_query(
        "select avg_prep_minutes, ST_Y(location), ST_X(location), name, is_active "
        "from stores_darkstore where id = 1"
    )
    return prep, lat, lng, name, active


def _haversine_km(lat1, lng1, lat2, lng2):
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp, dl = p2 - p1, math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * 6371.0088 * math.asin(math.sqrt(a))


def _expected_eta(prep, km):
    # 06 §2.3 / 08 §8: prep + rider wait (3) + km x road factor (1.3) / 20 km/h x 60 + buffer (2)
    return max(1, math.ceil(prep + 3 + km * 1.3 / 20 * 60 + 2))


# --------------------------------------------------------------------------- check


@pytest.mark.smoke
def test_p2_tc01_inside_service_area(api):
    """P2-TC-01 🔥 A point inside the seeded Gurugram polygon (the store's own location, during
    opening hours 07:00-23:00 IST): 200, serviceable, store {id, name, is_open, opens_at:null},
    eta_minutes = prep + 3 + 0 + 2, message null. Strict schema."""
    r = _check(api, *STORE_POINT)
    assert r.status_code == 200, describe(r)
    validate_response(r, "serviceability_check")
    body = r.json()
    prep, _, _, name, _ = _store_row()
    assert body["serviceable"] is True
    assert body["store"]["id"] == 1 and body["store"]["name"] == name
    if body["store"]["is_open"]:  # 07:00-23:00 IST (closed-hours cases: test_p2_clock.py)
        assert body["store"]["opens_at"] is None
        assert body["eta_minutes"] == _expected_eta(prep, 0) == 13
        assert body["message"] is None


@pytest.mark.smoke
@pytest.mark.parametrize(
    "point",
    [MUMBAI, (28.42, 77.04), (28.51, 77.04), (28.47, 76.99), (28.47, 77.09), (0, 0), (-33.86, 151.2)],
    ids=["mumbai", "south", "north", "west", "east", "null-island", "sydney"],
)
def test_p2_tc02_outside_service_area(api, point):
    """P2-TC-02 🔥 Points outside every active service area (Mumbai, just outside each side of the
    Gurugram polygon, 0,0, Sydney): 200 (never NOT_SERVICEABLE), serviceable false, store null,
    eta null, a message."""
    r = _check(api, *point)
    assert r.status_code == 200, describe(r)
    validate_response(r, "serviceability_check")
    body = r.json()
    assert body == {
        "serviceable": False,
        "store": None,
        "eta_minutes": None,
        "message": body["message"],
    }
    assert isinstance(body["message"], str) and body["message"]


@pytest.mark.db
def test_p2_tc03_matches_postgis_point_in_polygon(api):
    """P2-TC-03 A 13x13 grid over (and around) the store polygon: the API's `serviceable` equals
    PostGIS ST_Contains on the active stores' service_area for every point (oracle: read-only
    SQL). The API runs GEOS in-process on a cached snapshot, so this checks the snapshot too."""
    clear_catalog_cache()
    ((xmin, ymin, xmax, ymax),) = db_query(
        "select ST_XMin(e), ST_YMin(e), ST_XMax(e), ST_YMax(e) from "
        "(select ST_Extent(service_area)::geometry e from stores_darkstore where is_active) s"
    )
    pad = 0.01
    steps = 13
    lngs = [xmin - pad + (xmax - xmin + 2 * pad) * i / (steps - 1) + 0.000137 for i in range(steps)]
    lats = [ymin - pad + (ymax - ymin + 2 * pad) * i / (steps - 1) + 0.000113 for i in range(steps)]
    points = [(round(lat, 6), round(lng, 6)) for lat in lats for lng in lngs]
    values = ",".join(f"({lng}, {lat})" for lat, lng in points)
    expected = {
        (round(float(y), 6), round(float(x), 6)): inside
        for x, y, inside in db_query(
            f"select x, y, exists(select 1 from stores_darkstore where is_active and "
            f"ST_Contains(service_area, ST_SetSRID(ST_MakePoint(x, y), 4326))) "
            f"from (values {values}) as p(x, y)"
        )
    }
    mismatches, inside = [], 0
    for lat, lng in points:
        r = _check(api, lat, lng)
        assert r.status_code == 200, describe(r)
        inside += expected[(lat, lng)]
        if r.json()["serviceable"] != expected[(lat, lng)]:
            mismatches.append((lat, lng, expected[(lat, lng)]))
    assert 0 < inside < steps * steps, "grid must cover both inside and outside points"
    assert mismatches == []


@pytest.mark.db
def test_p2_tc04_eta_formula(api):
    """P2-TC-04 ETA (06 §2.3, 08 §8) at 3 points inside the area, computed independently from the
    store row: ceil(prep + 3 + km x 1.3 / 20 x 60 + 2). Null when closed (see clock tests)."""
    prep, slat, slng, _, _ = _store_row()
    for lat, lng in [(slat, slng), (28.445, 77.044), (28.485, 77.06)]:
        ((inside,),) = db_query(
            "select ST_Contains(service_area, ST_SetSRID(ST_MakePoint(%s, %s), 4326)) "
            "from stores_darkstore where id = 1",
            (lng, lat),
        )
        assert inside, (lat, lng)
        body = _check(api, lat, lng).json()
        if not body["store"]["is_open"]:
            pytest.skip("store closed right now (outside 07:00-23:00 IST)")
        assert body["eta_minutes"] == _expected_eta(prep, _haversine_km(lat, lng, slat, slng)), (
            lat,
            lng,
            body,
        )


@pytest.mark.parametrize(
    "params, field",
    [
        ({}, "lat"),
        ({"lat": "28.47"}, "lng"),
        ({"lng": "77.04"}, "lat"),
        ({"lat": "", "lng": ""}, "lat"),
        ({"lat": "abc", "lng": "77"}, "lat"),
        ({"lat": "90.000001", "lng": "77"}, "lat"),
        ({"lat": "-90.5", "lng": "77"}, "lat"),
        ({"lat": "28", "lng": "180.000001"}, "lng"),
        ({"lat": "28", "lng": "-181"}, "lng"),
        ({"lat": "nan", "lng": "77"}, "lat"),
        ({"lat": "NaN", "lng": "77"}, "lat"),
        ({"lat": "28", "lng": "inf"}, "lng"),
        ({"lat": "-Infinity", "lng": "77"}, "lat"),
        ({"lat": "1e400", "lng": "77"}, "lat"),
        ({"lat": "0x1c", "lng": "77"}, "lat"),
        ({"lat": "28.4\x00", "lng": "77"}, "lat"),
        ({"lat": "1" * 400, "lng": "77"}, "lat"),
    ],
)
def test_p2_tc05_check_validation(api, params, field):
    """P2-TC-05 Missing, blank, non-numeric, out-of-range, NaN/inf/overflow, hex, NUL and huge
    coordinates: 400 VALIDATION_ERROR naming the field, never 500."""
    r = api.get(SVC, params=params)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert field in err["details"], describe(r)
    validate_response(r, "serviceability_check")


@pytest.mark.parametrize("lat, lng", [(90, 180), (-90, -180), (0, 0), ("28.471e0", "7.7044e1")])
def test_p2_tc05b_check_boundaries_accepted(api, lat, lng):
    """P2-TC-05 Boundary and exponent forms are valid numbers: 200."""
    r = _check(api, lat, lng)
    assert r.status_code == 200, describe(r)


def test_p2_tc06_non_ascii_digits_in_coordinates(api):
    """P2-TC-06 (observation OBS-09) Devanagari / full-width digits in lat/lng are parsed by
    Python float() to the same number, so the answer equals the ASCII one. Recorded, not a bug:
    nothing is stored and the value is normalised. Re-check if coordinates are ever stored as text."""
    ascii_body = _check(api, *STORE_POINT).json()
    for lat, lng in [("२८.४७१", "७७.०४४"), ("２８.４７１", "７７.０４４")]:
        r = _check(api, lat, lng)
        assert r.status_code in (200, 400), describe(r)
        if r.status_code == 200:
            assert r.json()["serviceable"] == ascii_body["serviceable"]


def test_p2_tc07_public_and_methods(api):
    """P2-TC-07 Public: a garbage or expired-looking Bearer is ignored (200). Other methods: 405."""
    r = _check(api, *STORE_POINT, headers=bearer("garbage.token.value"))
    assert r.status_code == 200, describe(r)
    for method in ("POST", "PUT", "PATCH", "DELETE"):
        r = api.request(method, SVC, params={"lat": 28.47, "lng": 77.04})
        assert_error(r, 405, "METHOD_NOT_ALLOWED")


# --------------------------------------------------------------------------- notify-me


def _random_unserviced_point():
    """A random point around Mumbai (never serviceable): each run creates fresh leads."""
    return round(MUMBAI[0] + random.uniform(-0.2, 0.2), 6), round(MUMBAI[1] + random.uniform(-0.2, 0.2), 6)


@pytest.fixture
def no_notify_throttle():
    clear_throttle("notify_me")
    yield
    clear_throttle("notify_me")


@pytest.mark.smoke
@pytest.mark.db
def test_p2_tc15_notify_me_anonymous(api, no_notify_throttle):
    """P2-TC-15 🔥 Anonymous notify-me with a phone and address text: 201 {id, lat, lng, phone,
    address_text (trimmed), created_at}; the row is stored with the point and no user."""
    lat, lng = _random_unserviced_point()
    body = {"lat": lat, "lng": lng, "phone": QA_PHONES["d"], "address_text": "  QA lead, Andheri  "}
    r = api.post(NOTIFY, json=body)
    assert r.status_code == 201, describe(r)
    validate_response(r, "serviceability_notify_me")
    data = r.json()
    assert data["phone"] == QA_PHONES["d"] and data["address_text"] == "QA lead, Andheri"
    assert abs(data["lat"] - lat) < 1e-6 and abs(data["lng"] - lng) < 1e-6
    ((user_id, phone, y, x),) = db_query(
        "select user_id, phone, ST_Y(location), ST_X(location) from stores_serviceabilityrequest "
        "where id = %s",
        (data["id"],),
    )
    assert user_id is None and phone == QA_PHONES["d"]
    assert abs(y - lat) < 1e-6 and abs(x - lng) < 1e-6


@pytest.mark.db
def test_p2_tc16_notify_me_signed_in(api, no_notify_throttle):
    """P2-TC-16 Signed in, no phone: the lead is linked to the user and phone defaults to theirs.
    A sent but invalid token: 401 TOKEN_INVALID (never silently anonymous)."""
    s = login(QA_PHONES["d"])
    lat, lng = _random_unserviced_point()
    r = api.post(NOTIFY, json={"lat": lat, "lng": lng}, headers=s.headers)
    assert r.status_code == 201, describe(r)
    validate_response(r, "serviceability_notify_me")
    assert r.json()["phone"] == QA_PHONES["d"]
    ((user_id,),) = db_query(
        "select user_id from stores_serviceabilityrequest where id = %s", (r.json()["id"],)
    )
    assert user_id == s.user["id"]
    r = api.post(NOTIFY, json={"lat": lat, "lng": lng}, headers=bearer("eyJhbGciOiJIUzI1NiJ9.e30.x"))
    assert_error(r, 401, "TOKEN_INVALID")


@pytest.mark.parametrize(
    "patch, field",
    [
        ({"lat": None}, "lat"),
        ({"lat": "x"}, "lat"),
        ({"lat": 91}, "lat"),
        ({"lng": -180.5}, "lng"),
        ({"lat": "NaN"}, "lat"),
        ({"phone": "9876543210"}, "phone"),
        ({"phone": "+915876543210"}, "phone"),
        ({"phone": "+91900000०104"}, "phone"),  # BUG-0002 class: non-ASCII digit
        ({"phone": "+９１9000000104"}, "phone"),
        ({"phone": "+919000000104\n"}, None),  # trimmed by the CharField: accepted (see below)
        ({"address_text": "x" * 501}, "address_text"),
    ],
)
def test_p2_tc17_notify_me_validation(api, no_notify_throttle, patch, field):
    """P2-TC-17 Invalid lat/lng/phone/address_text: 400 VALIDATION_ERROR naming the field. A
    non-ASCII digit in the phone is refused (BUG-0002 class). A trailing newline is trimmed by
    DRF before validation, so the stored phone is clean."""
    body = {"lat": MUMBAI[0], "lng": MUMBAI[1], "phone": QA_PHONES["d"], **patch}
    r = api.post(NOTIFY, json=body)
    if field is None:
        assert r.status_code == 201, describe(r)
        assert r.json()["phone"] == QA_PHONES["d"]
        return
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert field in err["details"], describe(r)


@pytest.mark.db
def test_p2_tc18_notify_me_dedupe(api, no_notify_throttle):
    """P2-TC-18 Anonymous repeats are never merged (06 §2.3 after the BUG-0008 fix, verified
    2026-11-09): a repeat within 24 h and 100 m gets a lead of its own that echoes only its own
    values; a point 1 km away is a new lead too. (Signed-in merging: P2-TC-18b.)"""
    lat, lng = _random_unserviced_point()
    phone = QA_PHONES["e"]
    first = api.post(NOTIFY, json={"lat": lat, "lng": lng, "phone": phone, "address_text": "QA first"})
    assert first.status_code == 201, describe(first)
    near = api.post(  # ~50 m north, different text
        NOTIFY, json={"lat": lat + 0.00045, "lng": lng, "phone": phone, "address_text": "QA second"}
    )
    assert near.status_code == 201, describe(near)
    assert near.json()["id"] != first.json()["id"]  # BUG-0008: an anonymous repeat is never merged
    assert near.json()["address_text"] == "QA second"  # echoes only the caller's own values
    far = api.post(NOTIFY, json={"lat": lat + 0.009, "lng": lng, "phone": phone})  # ~1 km
    assert far.status_code == 201 and far.json()["id"] != first.json()["id"]
    (( n,),) = db_query(
        "select count(*) from stores_serviceabilityrequest where phone = %s and "
        "created_at > now() - interval '5 minutes' and ST_DWithin(location, "
        "ST_SetSRID(ST_MakePoint(%s, %s), 4326), 0.02)",
        (phone, lng, lat),
    )
    assert n == 3


@pytest.mark.db
def test_p2_tc18b_notify_me_signed_in_merge(api, no_notify_throttle):
    """P2-TC-18b A signed-in user's repeat within 24 h and 100 m merges into their own lead (same id)."""
    lat, lng = _random_unserviced_point()
    s = login(QA_PHONES["d"])
    first = api.post(NOTIFY, json={"lat": lat, "lng": lng, "phone": QA_PHONES["d"]}, headers=s.headers)
    near = api.post(NOTIFY, json={"lat": lat + 0.00045, "lng": lng, "phone": QA_PHONES["d"]}, headers=s.headers)
    assert first.status_code == 201 and near.status_code == 201, describe(near)
    assert near.json()["id"] == first.json()["id"]


@pytest.mark.limits
def test_p2_tc19_notify_me_throttle(api, no_notify_throttle):
    """P2-TC-19 Throttle NOTIFY_ME_RATE (10/hour per IP when anonymous): the 11th request is
    429 RATE_LIMITED with details.retry_after_seconds and Retry-After. All requests repeat one
    deduplicated lead, so no extra rows are written."""
    lat, lng = _random_unserviced_point()
    body = {"lat": lat, "lng": lng, "phone": QA_PHONES["e"]}
    codes = [api.post(NOTIFY, json=body).status_code for _ in range(10)]
    assert codes == [201] * 10, codes
    r = api.post(NOTIFY, json=body)
    err = assert_error(r, 429, "RATE_LIMITED")
    assert 0 < err["details"]["retry_after_seconds"] <= 3600
    assert int(r.headers["Retry-After"]) == err["details"]["retry_after_seconds"]
    validate_response(r, "serviceability_notify_me")
    # a signed-in user has their own bucket (per user, not per IP)
    s = login(QA_PHONES["d"])
    r = api.post(NOTIFY, json=body, headers=s.headers)
    assert r.status_code == 201, describe(r)


# --------------------------------------------------------------------------- addresses


@pytest.mark.smoke
def test_p2_tc20_address_is_serviceable(api, user_b, make_address):
    """P2-TC-20 🔥 Addresses gain read-only `is_serviceable` (06 §2.3): inside the polygon true,
    Mumbai false; saving an unserviceable address is allowed (03 §2.4). A sent value is ignored."""
    inside = make_address(user_b, lat=STORE_POINT[0], lng=STORE_POINT[1])
    outside = make_address(user_b, lat=MUMBAI[0], lng=MUMBAI[1], city="Mumbai", pincode="400001", is_serviceable=True)
    assert inside["is_serviceable"] is True
    assert outside["is_serviceable"] is False
    listed = {a["id"]: a["is_serviceable"] for a in api.get("/api/v1/addresses/", headers=user_b.headers).json()["results"]}
    assert listed[inside["id"]] is True and listed[outside["id"]] is False
    # moving the pin re-computes it
    r = api.patch(f"/api/v1/addresses/{outside['id']}/", json={"lat": STORE_POINT[0], "lng": STORE_POINT[1]}, headers=user_b.headers)
    assert r.status_code == 200 and r.json()["is_serviceable"] is True, describe(r)
    validate_response(r, "addresses_update")
