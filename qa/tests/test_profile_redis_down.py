"""Redis outage (09 §2, 06 §2.1). Run with `qa/tools/instance.sh start redis-down`: every Redis URL
of the QA instance points at a closed port, the shared DB stays reachable."""

from __future__ import annotations

import pytest

from conftest import login, request_otp, verify_otp
from qa_support import NONTEST_PREFIX, QA_PHONES, assert_error, client, describe, validate_response

pytestmark = pytest.mark.profile_redis_down


def test_p0_tc03b_ready_reports_redis_error():
    """P0-TC-03b /health/ready -> 503 SERVICE_UNAVAILABLE with details.checks {database: ok,
    redis: error}; no driver error text in the body; /health/live still 200."""
    with client() as c:
        assert c.get("/health/live").status_code == 200
        r = c.get("/health/ready")
    err = assert_error(r, 503, "SERVICE_UNAVAILABLE")
    assert err["details"] == {"checks": {"database": "ok", "redis": "error"}}
    validate_response(r, "health_ready")
    for leak in ("Connection refused", "6399", "Error 111", "redis://"):
        assert leak not in r.text


def test_p1_tc63_config_falls_back_to_db():
    """P1-TC-63 config/app keeps working from the database while Redis is down."""
    with client() as c:
        r = c.get("/api/v1/config/app/")
    assert r.status_code == 200, describe(r)
    validate_response(r, "config_app")
    assert r.json()["min_supported_version"] is not None


def test_p1_tc63b_otp_fail_closed():
    """P1-TC-63 OTP send and verify for normal numbers fail closed: 503 SERVICE_UNAVAILABLE
    ("Sign-in is temporarily unavailable"), never an unthrottled send."""
    with client() as c:
        r = request_otp(c, f"{NONTEST_PREFIX}90")
        err = assert_error(r, 503, "SERVICE_UNAVAILABLE")
        assert "temporarily unavailable" in err["message"]
        validate_response(r, "auth_otp_request")
        r = verify_otp(c, f"{NONTEST_PREFIX}90", "000000")
        assert_error(r, 503, "SERVICE_UNAVAILABLE")


def test_p1_tc63c_test_numbers_and_session_keep_working():
    """P1-TC-63 Fixed-OTP test numbers still sign in (no counters); /me/, refresh and logout
    (DB only) keep working; the app guard does not 5xx without its cache."""
    s = login(QA_PHONES["d"])
    with client() as c:
        assert c.get("/api/v1/me/", headers=s.headers).status_code == 200
        r = c.post("/api/v1/auth/token/refresh/", json={"refresh": s.refresh})
        assert r.status_code == 200, describe(r)
        pair = r.json()
        r = c.post("/api/v1/auth/logout/", json={"refresh": pair["refresh"]}, headers={"Authorization": f"Bearer {pair['access']}"})
        assert r.status_code == 204
        r = c.get("/api/v1/addresses/", headers=s.headers)
        assert r.status_code == 200


def test_p2_tc12b_catalog_and_serviceability_without_redis():
    """P2-TC-12b Redis down (06 §2.3/§2.4): serviceability loads the store snapshot from PostGIS and
    still answers 200 (inside and outside); X-Store-Id is resolved from the database; home,
    categories, products, detail, search, suggest and collections are served from the database
    (200, schema-valid); an unknown store is still 404 STORE_NOT_FOUND; notify-me's throttle
    fails open (201, no 500)."""
    from qa_support import MUMBAI, STORE_HEADERS, STORE_POINT

    with client() as c:
        r = c.get("/api/v1/serviceability/", params={"lat": STORE_POINT[0], "lng": STORE_POINT[1]})
        assert r.status_code == 200 and r.json()["serviceable"] is True, describe(r)
        r = c.get("/api/v1/serviceability/", params={"lat": MUMBAI[0], "lng": MUMBAI[1]})
        assert r.status_code == 200 and r.json()["serviceable"] is False, describe(r)
        for op, path, params in [
            ("home_retrieve", "/api/v1/home/", {}),
            ("categories_list", "/api/v1/categories/", {}),
            ("products_list", "/api/v1/products/", {"sort": "price_asc"}),
            ("products_retrieve", "/api/v1/products/1/", {}),
            ("search_products", "/api/v1/search/", {"q": "oil"}),
            ("search_suggest", "/api/v1/search/suggest/", {}),
            ("collections_retrieve", "/api/v1/collections/bestsellers/", {}),
        ]:
            r = c.get(path, params=params, headers=STORE_HEADERS)
            assert r.status_code == 200, f"{op}: {describe(r)}"
            validate_response(r, op)
        r = c.get("/api/v1/categories/", headers={"X-Store-Id": "9999999"})
        assert_error(r, 404, "STORE_NOT_FOUND")
        r = c.post("/api/v1/serviceability/notify-me/", json={"lat": MUMBAI[0], "lng": MUMBAI[1], "phone": QA_PHONES["e"]})
        assert r.status_code == 201, describe(r)
