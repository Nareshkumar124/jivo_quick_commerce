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
