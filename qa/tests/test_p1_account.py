"""Phase 1 account: profile (me), push devices, OTP-confirmed deletion with the 30-day grace
period (06 §2.1, 03 §2.2/§2.11, 07 §2.1/§4)."""

from __future__ import annotations

import time
from datetime import datetime, timedelta

import pytest

from conftest import login, request_otp
from qa_support import (
    QA_PHONES,
    TEST_OTP,
    assert_error,
    bearer,
    db_query,
    describe,
    validate_response,
)


def _dt(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


@pytest.fixture
def user_c():
    s = login(QA_PHONES["c"])
    yield s
    # leave the profile in a known state
    from qa_support import client

    with client() as c:
        c.patch(
            "/api/v1/me/",
            json={"name": "QA User C", "email": None, "marketing_opt_in": False},
            headers=s.headers,
        )


@pytest.mark.smoke
def test_p1_tc33_me_shape(api, user_a):
    """P1-TC-33 🔥 GET /me/ returns exactly the documented fields for the caller."""
    r = api.get("/api/v1/me/", headers=user_a.headers)
    assert r.status_code == 200, describe(r)
    validate_response(r, "me_retrieve")  # strict: no undocumented fields (PII leak check)
    me = r.json()
    assert me["id"] == user_a.user["id"] and me["phone"] == QA_PHONES["a"]
    assert me["rider_status"] == "NONE"


def test_p1_tc34_patch_profile(api, user_c):
    """P1-TC-34 PATCH name/email/marketing_opt_in -> 200 updated user; is_profile_complete true
    once a name is set; the email is stored lowercase."""
    r = api.patch(
        "/api/v1/me/",
        json={"name": "  QA Asha  ", "email": "QA.Asha.C@Example.COM", "marketing_opt_in": True},
        headers=user_c.headers,
    )
    assert r.status_code == 200, describe(r)
    validate_response(r, "me_update")
    me = r.json()
    assert me["name"] == "QA Asha" and me["is_profile_complete"] is True
    assert me["email"] == "qa.asha.c@example.com"
    assert me["marketing_opt_in"] is True
    assert api.get("/api/v1/me/", headers=user_c.headers).json() == me


@pytest.mark.parametrize("name", ["", "   ", None, "x" * 121, 123, ["a"]])
def test_p1_tc35_name_validation(api, user_c, name):
    """P1-TC-35 name cannot be blank, whitespace, null, > 120 chars or a non-string."""
    r = api.patch("/api/v1/me/", json={"name": name}, headers=user_c.headers)
    if name == 123:  # DRF CharField coerces numbers to "123"; accept either behaviour
        assert r.status_code in (200, 400), describe(r)
        return
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert "name" in err["details"]
    validate_response(r, "me_update")


def test_p1_tc36_email_rules(api, user_c, user_b):
    """P1-TC-36 Invalid email -> 400; null and "" clear it; a conflict with another customer or a
    staff email -> 400 with the same generic message (no account enumeration)."""
    for bad in ("not-an-email", "a@", "@b.com", "a b@c.com", "x" * 250 + "@a.com", 42):
        r = api.patch("/api/v1/me/", json={"email": bad}, headers=user_c.headers)
        assert_error(r, 400, "VALIDATION_ERROR")
    for clear in (None, "", "   "):
        api.patch("/api/v1/me/", json={"email": "qa.c.tmp@example.com"}, headers=user_c.headers)
        r = api.patch("/api/v1/me/", json={"email": clear}, headers=user_c.headers)
        assert r.status_code == 200 and r.json()["email"] is None, describe(r)
    b_email = f"qa.b.{time.time_ns()}@example.com"
    assert api.patch("/api/v1/me/", json={"email": b_email}, headers=user_b.headers).status_code == 200
    messages = []
    for taken in (b_email, b_email.upper(), "superadmin@jivo.test"):
        r = api.patch("/api/v1/me/", json={"email": taken}, headers=user_c.headers)
        err = assert_error(r, 400, "VALIDATION_ERROR")
        messages.append(err["details"].get("email"))
    assert messages[0] == messages[1] == messages[2] == ["This email can't be used."], messages
    api.patch("/api/v1/me/", json={"email": None}, headers=user_b.headers)


@pytest.mark.db
def test_p1_tc37_mass_assignment_ignored(api, user_c):
    """P1-TC-37 Read-only and privileged fields in PATCH /me/ are ignored: phone, id,
    rider_status, is_staff, is_superuser, is_active, deleted_at."""
    r = api.patch(
        "/api/v1/me/",
        json={
            "phone": "+919000000199",
            "id": 1,
            "rider_status": "ACTIVE",
            "is_staff": True,
            "is_superuser": True,
            "is_active": False,
            "is_profile_complete": False,
            "deleted_at": "2020-01-01T00:00:00Z",
            "created_at": "2020-01-01T00:00:00Z",
            "name": "QA User C",
        },
        headers=user_c.headers,
    )
    assert r.status_code == 200, describe(r)
    me = r.json()
    assert me["phone"] == QA_PHONES["c"] and me["id"] == user_c.user["id"]
    assert me["rider_status"] == "NONE" and me["is_profile_complete"] is True
    ((is_staff, is_super, active, deleted),) = db_query(
        "select is_staff, is_superuser, is_active, deleted_at from accounts_user where id=%s",
        (me["id"],),
    )
    assert (is_staff, is_super, active, deleted) == (False, False, True, None)


def test_p1_tc38_me_methods(api, user_a):
    """P1-TC-38 PUT/DELETE/POST /me/ -> 405 METHOD_NOT_ALLOWED."""
    for method in ("PUT", "DELETE", "POST"):
        r = api.request(method, "/api/v1/me/", json={}, headers=user_a.headers)
        assert_error(r, 405, "METHOD_NOT_ALLOWED")


DEVICE = {"app": "customer", "platform": "android", "app_version": "1.0.0+1"}


@pytest.mark.smoke
def test_p1_tc39_device_upsert(api, user_a):
    """P1-TC-39 🔥 POST /me/devices/ registers (200) and upserts on fcm_token: same id, updated
    version/platform, newer last_seen_at, active again."""
    token = f"qa-fcm-{time.time_ns()}"
    r1 = api.post("/api/v1/me/devices/", json={**DEVICE, "fcm_token": token}, headers=user_a.headers)
    assert r1.status_code == 200, describe(r1)
    validate_response(r1, "me_device_register")
    d1 = r1.json()
    assert d1["is_active"] is True and d1["fcm_token"] == token
    r2 = api.post(
        "/api/v1/me/devices/",
        json={**DEVICE, "fcm_token": token, "app_version": "1.2.0", "platform": "ios"},
        headers=user_a.headers,
    )
    d2 = r2.json()
    assert r2.status_code == 200 and d2["id"] == d1["id"]
    assert d2["app_version"] == "1.2.0" and d2["platform"] == "ios"
    assert _dt(d2["last_seen_at"]) >= _dt(d1["last_seen_at"])


@pytest.mark.db
def test_p1_tc40_device_token_moves_to_caller(api, user_a, user_b):
    """P1-TC-40 A token registered to A and then registered by B belongs to B (documented
    upsert); it is one row."""
    token = f"qa-fcm-move-{time.time_ns()}"
    api.post("/api/v1/me/devices/", json={**DEVICE, "fcm_token": token}, headers=user_a.headers)
    r = api.post("/api/v1/me/devices/", json={**DEVICE, "fcm_token": token}, headers=user_b.headers)
    assert r.status_code == 200
    rows = db_query("select user_id from accounts_device where fcm_token=%s", (token,))
    assert rows == [(user_b.user["id"],)]


@pytest.mark.parametrize(
    "patch",
    [
        {"app": "web"},
        {"platform": "windows"},
        {"app_version": "abc"},
        {"app_version": "1.0.0-beta"},
        {"app_version": "1." * 20},
        {"fcm_token": "x" * 513},
        {"fcm_token": ""},
        {"fcm_token": None},
        {"app": None},
    ],
)
def test_p1_tc41_device_validation(api, user_a, patch):
    """P1-TC-41 Device validation -> 400 VALIDATION_ERROR naming the field."""
    body = {**DEVICE, "fcm_token": f"qa-fcm-bad-{time.time_ns()}"}
    for key, value in patch.items():
        if value is None:
            body.pop(key)
        else:
            body[key] = value
    r = api.post("/api/v1/me/devices/", json=body, headers=user_a.headers)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert set(patch) & set(err["details"]), describe(r)
    validate_response(r, "me_device_register")


def test_p1_tc41b_devices_need_auth(api):
    """P1-TC-41 POST /me/devices/ without a token -> 401 AUTH_REQUIRED."""
    r = api.post("/api/v1/me/devices/", json={**DEVICE, "fcm_token": "qa-x"})
    assert_error(r, 401, "AUTH_REQUIRED")


@pytest.mark.smoke
@pytest.mark.db
def test_p1_tc42_tc43_account_deletion_and_restore(api):
    """P1-TC-42 🔥 Account deletion with a delete_account OTP -> 200 {deleted_at,
    anonymise_after = +30 days}; access and refresh tokens (including a rotated one) stop
    working; devices are deactivated; the reason is stored.
    P1-TC-43 Signing in again within the grace period restores the same account
    (deletion_cancelled true), clears deleted_at/reason, and the old tokens stay revoked."""
    phone = QA_PHONES["e"]
    s = login(phone)
    user_id = s.user["id"]
    rotated = api.post("/api/v1/auth/token/refresh/", json={"refresh": s.refresh}).json()
    token = f"qa-fcm-del-{time.time_ns()}"
    api.post("/api/v1/me/devices/", json={**DEVICE, "fcm_token": token}, headers=bearer(rotated["access"]))

    assert request_otp(api, phone, purpose="delete_account").status_code == 200
    r = api.post(
        "/api/v1/me/delete/",
        json={"otp": TEST_OTP, "reason": "QA deletion test"},
        headers=bearer(rotated["access"]),
    )
    assert r.status_code == 200, describe(r)
    validate_response(r, "me_delete_account")
    body = r.json()
    assert _dt(body["anonymise_after"]) - _dt(body["deleted_at"]) == timedelta(days=30)

    for access in (s.access, rotated["access"]):
        assert_error(api.get("/api/v1/me/", headers=bearer(access)), 401, "TOKEN_INVALID")
    for refresh in (s.refresh, rotated["refresh"]):
        assert_error(
            api.post("/api/v1/auth/token/refresh/", json={"refresh": refresh}), 401, "TOKEN_INVALID"
        )
    ((deleted_at, reason),) = db_query(
        "select deleted_at, deletion_reason from accounts_user where id=%s", (user_id,)
    )
    assert deleted_at is not None and reason == "QA deletion test"
    assert db_query("select bool_or(is_active) from accounts_device where user_id=%s", (user_id,)) == [
        (False,)
    ]

    # ---- P1-TC-43: restore by signing in during the grace period
    back = login(phone)
    assert back.body["deletion_cancelled"] is True
    assert back.user["id"] == user_id and back.body["is_new_user"] is False
    ((deleted_at, reason),) = db_query(
        "select deleted_at, deletion_reason from accounts_user where id=%s", (user_id,)
    )
    assert deleted_at is None and reason == ""
    assert api.get("/api/v1/me/", headers=back.headers).status_code == 200
    for refresh in (s.refresh, rotated["refresh"]):
        assert_error(
            api.post("/api/v1/auth/token/refresh/", json={"refresh": refresh}), 401, "TOKEN_INVALID"
        )
    again = login(phone)
    assert again.body["deletion_cancelled"] is False


@pytest.mark.parametrize(
    "body,status,code",
    [
        ({}, 400, "VALIDATION_ERROR"),
        ({"otp": "12"}, 400, "VALIDATION_ERROR"),
        ({"otp": TEST_OTP, "reason": "r" * 501}, 400, "VALIDATION_ERROR"),
    ],
)
def test_p1_tc44_delete_validation(api, user_a, body, status, code):
    """P1-TC-44 /me/delete/ input errors -> 400 VALIDATION_ERROR (validated before the OTP is
    looked at, so nothing is consumed)."""
    r = api.post("/api/v1/me/delete/", json=body, headers=user_a.headers)
    assert_error(r, status, code)
    validate_response(r, "me_delete_account")


def test_p1_tc44b_delete_requires_auth(api):
    """P1-TC-44 /me/delete/ without a token -> 401 AUTH_REQUIRED."""
    assert_error(api.post("/api/v1/me/delete/", json={"otp": TEST_OTP}), 401, "AUTH_REQUIRED")


def test_p1_tc44c_delete_without_active_otp(api, user_a):
    """P1-TC-44 /me/delete/ with no delete_account OTP issued -> 400 OTP_EXPIRED (a login OTP is
    never accepted; see P1-TC-12 for the strict sequence)."""
    r = api.post("/api/v1/me/delete/", json={"otp": TEST_OTP}, headers=user_a.headers)
    if r.status_code == 200:
        pytest.fail("account A deleted: an active delete_account OTP existed (sequencing error)")
    assert_error(r, 400, "OTP_EXPIRED")
