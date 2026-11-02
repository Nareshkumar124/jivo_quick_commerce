"""Phase 1 saved addresses (06 §2.2, 03 §2.4, 07 §2.1, 09 §3.2 IDOR)."""

from __future__ import annotations

import time
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest

from conftest import ADDRESS, login
from qa_support import (
    APP_HEADERS,
    BASE_URL,
    QA_PHONES,
    assert_error,
    db_query,
    describe,
    validate_response,
)

_BUG2 = pytest.mark.xfail(strict=True, reason="BUG-0002: validators accept non-ASCII digits")


def _list(api, session, **params):
    r = api.get("/api/v1/addresses/", params=params, headers=session.headers)
    assert r.status_code == 200, describe(r)
    validate_response(r, "addresses_list")
    return r.json()


def _all_ids(api, session) -> list[int]:
    return [a["id"] for a in _list(api, session, page_size=100)["results"]]


def _defaults(api, session) -> list[int]:
    return [a["id"] for a in _list(api, session, page_size=100)["results"] if a["is_default"]]


@pytest.fixture
def fresh_user():
    """User D with no live addresses (existing ones are soft-deleted through the API first)."""
    s = login(QA_PHONES["d"])
    with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS) as c:
        for address_id in [a["id"] for a in c.get("/api/v1/addresses/?page_size=100", headers=s.headers).json()["results"]]:
            c.delete(f"/api/v1/addresses/{address_id}/", headers=s.headers)
    return s


@pytest.mark.smoke
def test_p1_tc47_create_first_is_default(api, fresh_user, make_address):
    """P1-TC-47 🔥 POST /addresses/ -> 201; the user's first address is the default; receiver
    name/phone default to the user's own; lat/lng are JSON numbers."""
    me = api.get("/api/v1/me/", headers=fresh_user.headers).json()
    a1 = make_address(fresh_user)
    assert a1["is_default"] is True
    assert a1["receiver_phone"] == QA_PHONES["d"] and a1["receiver_name"] == me["name"]
    assert isinstance(a1["lat"], float) and isinstance(a1["lng"], float)
    a2 = make_address(fresh_user, label="work", receiver_name="QA Receiver", receiver_phone="+919000000199")
    assert a2["is_default"] is False
    assert a2["receiver_name"] == "QA Receiver" and a2["receiver_phone"] == "+919000000199"


def test_p1_tc47b_create_response_schema(api, user_a):
    """P1-TC-47 The 201 body matches the Address schema exactly."""
    r = api.post("/api/v1/addresses/", json=ADDRESS, headers=user_a.headers)
    assert r.status_code == 201, describe(r)
    validate_response(r, "addresses_create")
    api.delete(f"/api/v1/addresses/{r.json()['id']}/", headers=user_a.headers)


def test_p1_tc48_list_pagination_and_order(api, fresh_user, make_address):
    """P1-TC-48 List: {count, next, previous, results}; default first, then newest; page_size
    honoured and capped at 100; an out-of-range page -> 404 NOT_FOUND; page_size=0/abc -> 20."""
    ids = [make_address(fresh_user, house=f"QA {i}")["id"] for i in range(3)]
    body = _list(api, fresh_user)
    assert [a["id"] for a in body["results"]] == [ids[0], ids[2], ids[1]]
    assert body["count"] == 3 and body["next"] is None and body["previous"] is None
    page = _list(api, fresh_user, page_size=1)
    assert len(page["results"]) == 1 and page["next"] and page["previous"] is None
    page2 = _list(api, fresh_user, page_size=1, page=2)
    assert page2["previous"] and page2["results"][0]["id"] == ids[2]
    assert len(_list(api, fresh_user, page_size=1000)["results"]) == 3
    assert len(_list(api, fresh_user, page_size=0)["results"]) == 3
    assert len(_list(api, fresh_user, page_size="abc")["results"]) == 3
    for bad_page in (99, 0, -1, "abc"):
        r = api.get("/api/v1/addresses/", params={"page": bad_page}, headers=fresh_user.headers)
        assert_error(r, 404, "NOT_FOUND")


def test_p1_tc49_retrieve_and_patch(api, user_a, make_address):
    """P1-TC-49 GET own address -> 200; PATCH is partial (other fields unchanged); PUT -> 405."""
    a = make_address(user_a)
    r = api.get(f"/api/v1/addresses/{a['id']}/", headers=user_a.headers)
    assert r.status_code == 200 and r.json() == a
    validate_response(r, "addresses_retrieve")
    r = api.patch(
        f"/api/v1/addresses/{a['id']}/", json={"landmark": "QA Behind Market", "lat": 28.5}, headers=user_a.headers
    )
    assert r.status_code == 200, describe(r)
    validate_response(r, "addresses_update")
    b = r.json()
    assert b["landmark"] == "QA Behind Market" and b["lat"] == 28.5
    assert {k: v for k, v in b.items() if k not in ("landmark", "lat", "updated_at")} == {
        k: v for k, v in a.items() if k not in ("landmark", "lat", "updated_at")
    }
    r = api.put(f"/api/v1/addresses/{a['id']}/", json=ADDRESS, headers=user_a.headers)
    assert_error(r, 405, "METHOD_NOT_ALLOWED")


@pytest.mark.parametrize(
    "patch,field",
    [
        ({"label": None}, "label"),
        ({"label": "office"}, "label"),
        ({"house": None}, "house"),
        ({"house": ""}, "house"),
        ({"house": "h" * 121}, "house"),
        ({"building_street": "b" * 201}, "building_street"),
        ({"custom_label": "c" * 41}, "custom_label"),
        ({"landmark": "l" * 121}, "landmark"),
        ({"area": "a" * 121}, "area"),
        ({"city": None}, "city"),
        ({"city": "c" * 81}, "city"),
        ({"state": None}, "state"),
        ({"pincode": None}, "pincode"),
        ({"pincode": "12200"}, "pincode"),
        ({"pincode": "1220011"}, "pincode"),
        ({"pincode": "022001"}, "pincode"),
        ({"pincode": "12a001"}, "pincode"),
        ({"receiver_name": "r" * 121}, "receiver_name"),
        ({"receiver_phone": "12345"}, "receiver_phone"),
        ({"receiver_phone": "+14155550101"}, "receiver_phone"),
        ({"lat": None}, "lat"),
        ({"lng": None}, "lng"),
    ],
)
def test_p1_tc50_address_validation(api, user_a, patch, field):
    """P1-TC-50 Required fields, max lengths, label enum, 6-digit PIN, Indian receiver phone and
    the map pin (lat/lng required) -> 400 VALIDATION_ERROR naming the field."""
    body = dict(ADDRESS)
    for key, value in patch.items():
        if value is None:
            body.pop(key, None)
        else:
            body[key] = value
    r = api.post("/api/v1/addresses/", json=body, headers=user_a.headers)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert field in err["details"], describe(r)
    validate_response(r, "addresses_create")


@pytest.mark.parametrize(
    "coords",
    [
        {"lat": 90.000001},
        {"lat": -91},
        {"lng": 180.5},
        {"lng": -181},
        {"lat": "abc"},
        {"lat": "nan"},
        {"lat": "NaN"},
        {"lng": "nan"},
        {"lat": "inf"},
        {"lng": "-Infinity"},
        {"lat": "1e400"},
        {"lat": [28.4]},
    ],
)
def test_p1_tc51_coordinates_rejected(api, user_a, coords):
    """P1-TC-51 Out-of-range or non-finite coordinates -> 400 VALIDATION_ERROR, never a 500."""
    r = api.post("/api/v1/addresses/", json={**ADDRESS, **coords}, headers=user_a.headers)
    assert r.status_code != 500, describe(r)
    if r.status_code == 201:
        api.delete(f"/api/v1/addresses/{r.json()['id']}/", headers=user_a.headers)
    assert_error(r, 400, "VALIDATION_ERROR")


def test_p1_tc51c_boolean_coordinate_observation(api, user_a):
    """P1-TC-51 Observation OBS-03: a JSON boolean for lat is coerced to 1.0 (DRF FloatField),
    although the contract type is number. Recorded, not filed (P4)."""
    r = api.post("/api/v1/addresses/", json={**ADDRESS, "lat": True}, headers=user_a.headers)
    if r.status_code == 201:
        api.delete(f"/api/v1/addresses/{r.json()['id']}/", headers=user_a.headers)
    assert r.status_code in (201, 400), describe(r)


def test_p1_tc51b_coordinates_boundaries_and_rounding(api, user_a, make_address):
    """P1-TC-51 Boundary values are accepted; coordinates are stored to 6 decimal places and
    returned as numbers; numeric strings are accepted."""
    for lat, lng in ((90, 180), (-90, -180), (0, 0)):
        a = make_address(user_a, lat=lat, lng=lng)
        assert (a["lat"], a["lng"]) == (lat, lng)
    a = make_address(user_a, lat=28.12345678, lng="77.1234565")
    assert a["lat"] == 28.123457 and a["lng"] in (77.123457, 77.123456)
    ((lat_db,),) = db_query("select lat::text from accounts_address where id=%s", (a["id"],))
    assert lat_db == "28.123457"


@pytest.mark.parametrize(
    "patch",
    [
        pytest.param({"pincode": "1२२००१"}, marks=_BUG2),
        pytest.param({"pincode": "1２２００１"}, marks=_BUG2),  # ASCII first digit
        pytest.param({"receiver_phone": "+919०००००0199"}, marks=_BUG2),
    ],
)
def test_p1_tc52_unicode_digits_in_address(api, user_a, patch):
    """P1-TC-52 Non-ASCII digits in PIN code / receiver phone -> 400 (contract patterns are
    ASCII-only for the Dart client; PIN codes feed serviceability and GST invoices)."""
    r = api.post("/api/v1/addresses/", json={**ADDRESS, **patch}, headers=user_a.headers)
    if r.status_code == 201:
        api.delete(f"/api/v1/addresses/{r.json()['id']}/", headers=user_a.headers)
    assert r.status_code == 400, describe(r)


@pytest.mark.smoke
def test_p1_tc53_set_default(api, fresh_user, make_address):
    """P1-TC-53 🔥 set-default moves the default: exactly one default afterwards; repeating it is
    harmless."""
    a1, a2, a3 = (make_address(fresh_user) for _ in range(3))
    r = api.post(f"/api/v1/addresses/{a3['id']}/set-default/", headers=fresh_user.headers)
    assert r.status_code == 200 and r.json()["is_default"] is True, describe(r)
    validate_response(r, "addresses_set_default")
    assert _defaults(api, fresh_user) == [a3["id"]]
    assert _list(api, fresh_user)["results"][0]["id"] == a3["id"]
    r = api.post(f"/api/v1/addresses/{a3['id']}/set-default/", headers=fresh_user.headers)
    assert r.status_code == 200 and _defaults(api, fresh_user) == [a3["id"]]


def test_p1_tc54_soft_delete_and_default_promotion(api, fresh_user, make_address):
    """P1-TC-54 DELETE -> 204; a deleted address is 404 for get/patch/delete/set-default and not
    listed; deleting the default promotes the most recently updated remaining address; deleting
    a non-default keeps the default; deleting the last one leaves none."""
    a1, a2, a3 = (make_address(fresh_user, house=f"QA del {i}") for i in range(3))
    api.patch(f"/api/v1/addresses/{a2['id']}/", json={"landmark": "QA touched"}, headers=fresh_user.headers)
    r = api.delete(f"/api/v1/addresses/{a1['id']}/", headers=fresh_user.headers)
    assert r.status_code == 204 and r.content == b""
    validate_response(r, "addresses_delete")
    assert _defaults(api, fresh_user) == [a2["id"]], "most recently updated should be promoted"
    for method, path in (
        ("GET", f"/api/v1/addresses/{a1['id']}/"),
        ("PATCH", f"/api/v1/addresses/{a1['id']}/"),
        ("DELETE", f"/api/v1/addresses/{a1['id']}/"),
        ("POST", f"/api/v1/addresses/{a1['id']}/set-default/"),
    ):
        assert_error(api.request(method, path, json={}, headers=fresh_user.headers), 404, "NOT_FOUND")
    assert a1["id"] not in _all_ids(api, fresh_user)
    api.delete(f"/api/v1/addresses/{a3['id']}/", headers=fresh_user.headers)
    assert _defaults(api, fresh_user) == [a2["id"]]
    api.delete(f"/api/v1/addresses/{a2['id']}/", headers=fresh_user.headers)
    assert _list(api, fresh_user)["count"] == 0
    a4 = make_address(fresh_user)
    assert a4["is_default"] is True, "first address after deleting all should be default"


@pytest.mark.smoke
def test_p1_tc55_idor_addresses(api, user_a, user_b, make_address):
    """P1-TC-55 🔥 IDOR: user B reading, editing, deleting or defaulting user A's address gets 404
    NOT_FOUND (never 403/200), and A's address is unchanged; A's list never shows B's."""
    a = make_address(user_a, house="QA IDOR target")
    b = make_address(user_b, house="QA IDOR other")
    path = f"/api/v1/addresses/{a['id']}/"
    checks = [
        api.get(path, headers=user_b.headers),
        api.patch(path, json={"house": "pwned"}, headers=user_b.headers),
        api.delete(path, headers=user_b.headers),
        api.post(f"{path}set-default/", headers=user_b.headers),
    ]
    for r in checks:
        assert_error(r, 404, "NOT_FOUND")
    after = api.get(path, headers=user_a.headers)
    assert after.status_code == 200 and after.json() == a
    assert b["id"] not in _all_ids(api, user_a)
    assert a["id"] not in _all_ids(api, user_b)
    # Anonymous access to the same object -> 401, not 404/200.
    assert_error(api.get(path), 401, "AUTH_REQUIRED")


def test_p1_tc55b_nonexistent_and_malformed_ids(api, user_a):
    """P1-TC-55 Unknown ids -> 404 NOT_FOUND; non-integer ids do not route (404)."""
    for path in ("/api/v1/addresses/999999999/", "/api/v1/addresses/0/"):
        assert_error(api.get(path, headers=user_a.headers), 404, "NOT_FOUND")
    for path in ("/api/v1/addresses/-1/", "/api/v1/addresses/1.5/", "/api/v1/addresses/%27or1=1/"):
        assert api.get(path, headers=user_a.headers).status_code == 404


def test_p1_tc56_is_default_read_only(api, fresh_user, make_address):
    """P1-TC-56 is_default (and id/created_at) in a create or patch body is ignored."""
    a1 = make_address(fresh_user)
    a2 = make_address(fresh_user, is_default=True, id=1, created_at="2020-01-01T00:00:00Z")
    assert a2["is_default"] is False and a2["id"] != 1
    r = api.patch(f"/api/v1/addresses/{a2['id']}/", json={"is_default": True}, headers=fresh_user.headers)
    assert r.status_code == 200 and r.json()["is_default"] is False
    assert _defaults(api, fresh_user) == [a1["id"]]


@pytest.mark.db
@pytest.mark.xfail(strict=False, reason="BUG-0007: race can leave zero defaults (intermittent)")
def test_p1_tc57_concurrent_default_changes(api, fresh_user, make_address):
    """P1-TC-57 Ten concurrent set-default calls on different addresses (and a concurrent burst
    of creates for an address-less user) leave exactly one live default (07 §2.1)."""
    addrs = [make_address(fresh_user, house=f"QA conc {i}") for i in range(5)]

    def set_default(address_id):
        with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=60) as c:
            return c.post(f"/api/v1/addresses/{address_id}/set-default/", headers=fresh_user.headers).status_code

    with ThreadPoolExecutor(10) as pool:
        codes = list(pool.map(set_default, [a["id"] for a in addrs] * 2))
    assert set(codes) == {200}, codes
    assert len(_defaults(api, fresh_user)) == 1
    ((n,),) = db_query(
        "select count(*) from accounts_address where user_id=%s and is_default and not is_deleted",
        (fresh_user.user["id"],),
    )
    assert n == 1
    for a in addrs:
        api.delete(f"/api/v1/addresses/{a['id']}/", headers=fresh_user.headers)

    def create(i):
        with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=60) as c:
            r = c.post("/api/v1/addresses/", json={**ADDRESS, "house": f"QA race {i}"}, headers=fresh_user.headers)
            return r.status_code, r.json().get("id")

    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(create, range(8)))
    assert {code for code, _ in results} == {201}, results
    assert len(_defaults(api, fresh_user)) == 1
    for _, address_id in results:
        api.delete(f"/api/v1/addresses/{address_id}/", headers=fresh_user.headers)


def test_p1_tc48b_addresses_need_auth(api):
    """P1-TC-48 Every address operation without a token -> 401 AUTH_REQUIRED."""
    for method, path in (
        ("GET", "/api/v1/addresses/"),
        ("POST", "/api/v1/addresses/"),
        ("PATCH", "/api/v1/addresses/1/"),
        ("DELETE", "/api/v1/addresses/1/"),
        ("POST", "/api/v1/addresses/1/set-default/"),
    ):
        assert_error(api.request(method, path, json={}), 401, "AUTH_REQUIRED")


_ = time  # keep import for ad-hoc timing during investigations
