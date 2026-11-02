"""Phase 1 OTP abuse limits (09 §3.1): 3 sends / phone / 10 min, 10 / phone / day, per-IP send
and verify limits, fail-closed. Runs only against the QA instance; each test starts and ends
with the QA instance's rate-limit counters cleared (QA Redis DB 5 only)."""

from __future__ import annotations

import math

import pytest

from conftest import request_otp, verify_otp
from qa_support import (
    NONTEST_PREFIX,
    QA_PHONES,
    assert_error,
    clear_rate_limits,
    describe,
    qa_redis,
    validate_response,
)

pytestmark = pytest.mark.limits


@pytest.fixture(autouse=True)
def _clean_counters():
    clear_rate_limits()
    yield
    clear_rate_limits()


def _assert_rate_limited(r, max_wait: int):
    err = assert_error(r, 429, "OTP_RATE_LIMITED")
    retry = err["details"].get("retry_after_seconds")
    assert isinstance(retry, int) and 0 < retry <= max_wait, describe(r)
    assert r.headers.get("Retry-After"), "Retry-After header missing"
    assert abs(int(r.headers["Retry-After"]) - retry) <= 1
    return err


@pytest.mark.smoke
def test_p1_tc14_send_limit_per_phone_10_min(api):
    """P1-TC-14 🔥 4th OTP send to one phone within 10 minutes -> 429 OTP_RATE_LIMITED with
    details.retry_after_seconds (<= 600) and Retry-After; the counter is per phone across apps
    and purposes (the 4th is a rider-app request)."""
    phone = f"{NONTEST_PREFIX}10"
    for app in ("customer", "customer", "rider"):
        r = request_otp(api, phone, app=app)
        assert r.status_code == 200, describe(r)
    r = request_otp(api, phone, app="rider")
    _assert_rate_limited(r, 600)
    validate_response(r, "auth_otp_request")
    # A different phone from the same client is unaffected.
    assert request_otp(api, f"{NONTEST_PREFIX}11").status_code == 200


@pytest.mark.profile_daylimit
def test_p1_tc15_send_limit_per_phone_per_day():
    """P1-TC-15 (daylimit profile: 10-minute cap raised to 50 so the day cap is reachable)
    11th send to one phone within 24 h -> 429 with retry_after_seconds <= 86400."""
    from qa_support import client

    with client() as api:
        phone = f"{NONTEST_PREFIX}12"
        for i in range(10):
            r = request_otp(api, phone)
            assert r.status_code == 200, f"send {i + 1}: {describe(r)}"
        r = request_otp(api, phone)
        err = _assert_rate_limited(r, 86400)
        assert err["details"]["retry_after_seconds"] > 600, "looks like a 10-minute window"


def test_p1_tc16_tc18_per_ip_send_limit_ignores_x_forwarded_for(api):
    """P1-TC-16 Per-IP send limit (30/hour): the 31st send from one client -> 429, across
    different phones. P1-TC-18: every request carries a different spoofed X-Forwarded-For; with
    NUM_PROXIES=0 it must be ignored, so the spoofing does not reset the per-IP counter."""
    sent = 0
    for i in range(30):
        phone = f"{NONTEST_PREFIX}{20 + i // 3:02d}"  # 3 sends per phone: never the phone limit
        r = request_otp(api, phone) if i % 2 else api.post(
            "/api/v1/auth/otp/request/",
            json={"phone": phone, "app": "customer"},
            headers={"X-Forwarded-For": f"203.0.113.{i + 1}", "X-Real-IP": f"198.51.100.{i + 1}"},
        )
        assert r.status_code == 200, f"send {i + 1}: {describe(r)}"
        sent += 1
    r = api.post(
        "/api/v1/auth/otp/request/",
        json={"phone": f"{NONTEST_PREFIX}40", "app": "customer"},
        headers={"X-Forwarded-For": "192.0.2.77"},
    )
    _assert_rate_limited(r, 3600)
    # Test numbers are exempt from the IP limit (D-15 integration runs keep working).
    assert request_otp(api, QA_PHONES["d"]).status_code == 200


def test_p1_tc17_per_ip_verify_limit(api):
    """P1-TC-17 Per-IP verify limit (60/hour): the 61st verify from one client -> 429
    OTP_RATE_LIMITED, whatever the phone (stops OTP guessing across many phones)."""
    for i in range(60):
        r = verify_otp(api, f"{NONTEST_PREFIX}{50 + i % 10:02d}", "000000")
        assert r.status_code == 400, f"verify {i + 1}: {describe(r)}"
        assert r.json()["error"]["code"] in ("OTP_EXPIRED", "OTP_INVALID")
    r = verify_otp(api, f"{NONTEST_PREFIX}60", "000000")
    _assert_rate_limited(r, 3600)
    validate_response(r, "auth_otp_verify")


def test_p1_tc20_rate_limit_keys_hold_no_pii(api):
    """P1-TC-20 Rate-limit counters in Redis are keyed by a hash: no phone number or IP address
    appears in any key (09 §3.3 PII minimisation)."""
    phone = f"{NONTEST_PREFIX}61"
    assert request_otp(api, phone).status_code == 200
    keys = [k.decode() for k in qa_redis().scan_iter(match="jqc:rl:*", count=500)]
    assert keys, "no rate-limit keys were written"
    for key in keys:
        assert phone not in key and phone[1:] not in key and "127.0.0.1" not in key, key
        assert key.split(":")[-1].isalnum()
    ttls = [qa_redis().ttl(k) for k in keys]
    assert all(0 < t <= 86400 for t in ttls)




def _ceil(x: float) -> int:
    return math.ceil(x)
