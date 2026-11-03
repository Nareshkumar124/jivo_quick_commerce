"""Phase 1 OTP sign-in (06 §2.1, 09 §3.1, 03 §2.2, 04 §2.1)."""

from __future__ import annotations

import re

import pytest

from conftest import TERMS_VERSION, login, request_otp, verify_otp
from qa_support import (
    QA_PHONES,
    RIDER_HEADERS,
    TEST_OTP,
    assert_error,
    client,
    db_query,
    describe,
    jwt_claims,
    validate_response,
)

# BUG-0002 (non-ASCII digits) verified fixed in QA run 2 (0b801d1): plain regression cases now.
_BUG2 = ()

OTP_SENT = {"otp_length": 6, "expires_in_seconds": 300, "resend_after_seconds": 30}


@pytest.mark.smoke
def test_p1_tc01_otp_request_happy_path(api):
    """P1-TC-01 🔥 POST /auth/otp/request/ for a valid phone -> 200 {6, 300, 30}."""
    r = request_otp(api, QA_PHONES["a"])
    assert r.status_code == 200, describe(r)
    assert r.json() == OTP_SENT
    validate_response(r, "auth_otp_request")
    r = request_otp(api, QA_PHONES["a"], purpose="login")
    assert r.json() == OTP_SENT


def test_p1_tc02_no_account_enumeration(api, nontest_phone):
    """P1-TC-02 The OTP-request answer is identical for an unknown phone, a known phone and a
    delete_account request for a phone with no account; the latter stores no OTP row."""
    known = request_otp(api, QA_PHONES["a"])
    unknown_phone = nontest_phone()
    unknown = request_otp(api, unknown_phone)
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json() == OTP_SENT
    ghost = "+919999900199"  # never used to sign in by QA
    before = db_query(
        "select count(*) from accounts_otprequest where phone=%s and purpose='delete_account'",
        (ghost,),
    )[0][0]
    r = request_otp(api, ghost, purpose="delete_account")
    assert r.status_code == 200 and r.json() == OTP_SENT, describe(r)
    after = db_query(
        "select count(*) from accounts_otprequest where phone=%s and purpose='delete_account'",
        (ghost,),
    )[0][0]
    assert after == before, "a delete_account OTP was stored for a phone with no account"


@pytest.mark.parametrize(
    "phone",
    [
        "9000000101",  # no country code
        "919000000101",  # no plus
        "+91 9000000101",  # space
        "+91-9000000101",
        "+9190000001011",  # 11 digits
        "+91900000010",  # 9 digits
        "+915000000101",  # starts with 5
        "+919000000l01",  # letter l
        "+14155550101",  # not India
        "",
        " ",
        "+91" + "9" * 200,
    ],
)
def test_p1_tc03_otp_request_invalid_phone(api, phone):
    """P1-TC-03 Invalid phone formats -> 400 VALIDATION_ERROR on details.phone."""
    r = request_otp(api, phone)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert "phone" in err["details"], describe(r)
    validate_response(r, "auth_otp_request")


@pytest.mark.parametrize(
    "phone",
    [
        "+91९९९९९०००९९",  # Devanagari digits
        "+91９９９９９０００９９",  # full-width digits
        "+91٩٩٩٩٩٠٠٠٩٩",  # Arabic-Indic digits
        pytest.param("+919999900０99", marks=_BUG2),  # ASCII first digit, then full-width
        pytest.param("+919999900१98", marks=_BUG2),  # ASCII first digit, then Devanagari
    ],
)
def test_p1_tc04_otp_request_unicode_digits_rejected(api, phone):
    """P1-TC-04 Non-ASCII digits are not a valid E.164 phone (the contract pattern
    ^\\+91[6-9]\\d{9}$ is ASCII-only in Dart/JS clients) -> 400, never an OTP row."""
    r = request_otp(api, phone)
    assert r.status_code == 400, describe(r)
    assert_error(r, 400, "VALIDATION_ERROR")


@pytest.mark.parametrize(
    "body",
    [
        {"phone": "+919000000101"},
        {"app": "customer"},
        {"phone": "+919000000101", "app": "admin"},
        {"phone": "+919000000101", "app": "Customer"},
        {"phone": "+919000000101", "app": "customer", "purpose": "reset"},
        {"phone": 919000000101, "app": "customer"},
        {"phone": None, "app": "customer"},
        {"phone": ["+919000000101"], "app": "customer"},
        [],
        "x",
    ],
)
def test_p1_tc05_otp_request_invalid_body(api, body):
    """P1-TC-05 Missing/invalid app, purpose or phone types -> 400 VALIDATION_ERROR."""
    r = api.post("/api/v1/auth/otp/request/", json=body)
    assert_error(r, 400, "VALIDATION_ERROR")


@pytest.mark.smoke
def test_p1_tc06_otp_verify_session_shape(api):
    """P1-TC-06 🔥 Verify returns {access, refresh, user, is_new_user, rider_status,
    deletion_cancelled}; rider_status NONE; tokens are JWTs with the customer app claim."""
    s = login(QA_PHONES["a"])
    body = s.body
    assert set(body) == {"access", "refresh", "user", "is_new_user", "rider_status", "deletion_cancelled"}
    assert body["rider_status"] == "NONE"
    assert body["deletion_cancelled"] is False
    assert body["user"]["phone"] == QA_PHONES["a"]
    assert body["user"]["rider_status"] == "NONE"
    access, refresh = jwt_claims(s.access), jwt_claims(s.refresh)
    assert access["token_type"] == "access" and refresh["token_type"] == "refresh"
    assert str(access["user_id"]) == str(body["user"]["id"])
    assert refresh.get("app") == "customer" and access.get("app") == "customer"


def test_p1_tc06b_new_user_flag(api):
    """P1-TC-06 is_new_user is true only for the verification that created the account. Uses a
    fresh fixed-OTP phone if one has never signed in; otherwise checks the returning flag."""
    rows = db_query("select count(*) from accounts_user where phone=%s", (QA_PHONES["d"],))
    first = login(QA_PHONES["d"])
    if rows[0][0] == 0:
        assert first.body["is_new_user"] is True
        assert first.body["user"]["is_profile_complete"] is False
    second = login(QA_PHONES["d"])
    assert second.body["is_new_user"] is False
    assert second.user["id"] == first.user["id"]


def test_p1_tc07_returning_user(api, user_a):
    """P1-TC-07 A returning user gets is_new_user false and the same user id."""
    again = login(QA_PHONES["a"])
    assert again.body["is_new_user"] is False
    assert again.user["id"] == user_a.user["id"]
    validate_response_from_body = again.body  # noqa: F841 - shape checked in TC-06


@pytest.mark.smoke
def test_p1_tc08_wrong_otp_attempts_then_locked(api):
    """P1-TC-08 🔥 Wrong code -> OTP_INVALID with attempts_remaining 4..0; then OTP_EXPIRED,
    even for the correct code (5 attempts per OTP)."""
    phone = QA_PHONES["c"]
    assert request_otp(api, phone).status_code == 200
    for remaining in (4, 3, 2, 1, 0):
        r = verify_otp(api, phone, "000000")
        err = assert_error(r, 400, "OTP_INVALID")
        assert err["details"] == {"attempts_remaining": remaining}, describe(r)
        validate_response(r, "auth_otp_verify")
    r = verify_otp(api, phone, "000001")
    assert_error(r, 400, "OTP_EXPIRED")
    r = verify_otp(api, phone, TEST_OTP)
    assert_error(r, 400, "OTP_EXPIRED")


def test_p1_tc09_otp_single_use(api):
    """P1-TC-09 A verified OTP cannot be used again."""
    phone = QA_PHONES["c"]
    assert request_otp(api, phone).status_code == 200
    assert verify_otp(api, phone).status_code == 200
    assert_error(verify_otp(api, phone), 400, "OTP_EXPIRED")


@pytest.mark.db
def test_p1_tc10_new_otp_supersedes_previous(api):
    """P1-TC-10 A new OTP for the same phone+app+purpose expires the previous one: after one
    successful verify, the older OTP (same fixed code) is not usable; DB shows the older row's
    expires_at moved to the time the new one was issued."""
    phone = QA_PHONES["c"]
    assert request_otp(api, phone).status_code == 200
    assert request_otp(api, phone).status_code == 200
    rows = db_query(
        "select id, created_at, expires_at, verified_at from accounts_otprequest "
        "where phone=%s and app='customer' and purpose='login' order by created_at desc limit 2",
        (phone,),
    )
    newest, older = rows
    assert older[2] <= newest[1] + (newest[1] - newest[1]).__class__(seconds=1), (
        "older OTP still active after a new one was issued"
    )
    assert (newest[2] - newest[1]).total_seconds() == pytest.approx(300, abs=2)
    assert verify_otp(api, phone).status_code == 200
    assert_error(verify_otp(api, phone), 400, "OTP_EXPIRED")


def test_p1_tc11_app_must_match(api):
    """P1-TC-11 An OTP requested for app=customer cannot be verified with app=rider (and the
    body app is authoritative over X-App-Name)."""
    phone = QA_PHONES["c"]
    assert request_otp(api, phone, app="customer").status_code == 200
    with client(RIDER_HEADERS) as rider:
        r = verify_otp(rider, phone, TEST_OTP, app="rider")
        assert_error(r, 400, "OTP_EXPIRED")
        # Body says customer while the header says rider: the body wins.
        r = verify_otp(rider, phone, TEST_OTP, app="customer")
        assert r.status_code == 200, describe(r)
        assert jwt_claims(r.json()["refresh"])["app"] == "customer"


def test_p1_tc12_purpose_isolation(api):
    """P1-TC-12 A delete_account OTP never signs in, and a login OTP never deletes an account.
    Strictly sequenced so that no OTP of the other purpose is active at each check."""
    phone = QA_PHONES["c"]
    s = login(phone)  # consumes any active login OTP
    # 1) delete_account OTP active, no login OTP active -> login verify fails.
    assert request_otp(api, phone, purpose="delete_account").status_code == 200
    assert_error(verify_otp(api, phone), 400, "OTP_EXPIRED")
    # Burn the delete OTP with 5 wrong codes (also checks /me/delete attempt counting).
    for remaining in (4, 3, 2, 1, 0):
        r = api.post("/api/v1/me/delete/", json={"otp": "000000"}, headers=s.headers)
        err = assert_error(r, 400, "OTP_INVALID")
        assert err["details"]["attempts_remaining"] == remaining
    # 2) login OTP active, no delete OTP active -> /me/delete with the login code fails.
    assert request_otp(api, phone).status_code == 200
    r = api.post("/api/v1/me/delete/", json={"otp": TEST_OTP}, headers=s.headers)
    assert_error(r, 400, "OTP_EXPIRED")
    assert api.get("/api/v1/me/", headers=s.headers).status_code == 200  # not deleted
    # The login OTP was not consumed by the failed delete call.
    assert verify_otp(api, phone).status_code == 200


@pytest.mark.parametrize(
    "patch",
    [
        {"otp": "12345"},
        {"otp": "1234567"},
        {"otp": "12345a"},
        pytest.param({"otp": "１２３４５６"}, marks=_BUG2),
        {"otp": 123456},
        {"otp": None},
        {"terms_version": None},
        {"terms_version": "x" * 33},
        {"app": "web"},
        {"phone": "+91123"},
    ],
)
def test_p1_tc13_verify_validation(api, patch):
    """P1-TC-13 Verify input validation -> 400 VALIDATION_ERROR (no attempt consumed)."""
    body = {"phone": QA_PHONES["c"], "otp": TEST_OTP, "app": "customer", "terms_version": TERMS_VERSION}
    for key, value in patch.items():
        if value is None:
            body.pop(key)
        else:
            body[key] = value
    r = api.post("/api/v1/auth/otp/verify/", json=body)
    if patch.get("otp") == 123456:  # a JSON number is coerced to "123456" by DRF CharField
        assert r.status_code in (200, 400), describe(r)
        return
    assert_error(r, 400, "VALIDATION_ERROR")


@pytest.mark.smoke
def test_p1_tc21_rider_app_login(api):
    """P1-TC-21 🔥 Rider-app login (X-App-Name: rider, app=rider) -> rider_status NONE (no rider
    profile until Phase 5), the token app claim is rider."""
    s = login(QA_PHONES["c"], app="rider")
    assert s.body["rider_status"] == "NONE"
    assert s.user["rider_status"] == "NONE"
    assert jwt_claims(s.refresh)["app"] == "rider"
    with client(RIDER_HEADERS) as rider:
        r = rider.get("/api/v1/me/", headers=s.headers)
        assert r.status_code == 200 and r.json()["rider_status"] == "NONE"
        validate_response(r, "me_retrieve")


@pytest.mark.db
def test_p1_tc22_terms_consent_recorded(api):
    """P1-TC-22 terms_version is stored with the acceptance time and updated when it changes."""
    phone = QA_PHONES["d"]
    with client() as c:
        assert request_otp(c, phone).status_code == 200
        r = c.post(
            "/api/v1/auth/otp/verify/",
            json={"phone": phone, "otp": TEST_OTP, "app": "customer", "terms_version": "qa-2026-v2"},
        )
        assert r.status_code == 200, describe(r)
    (v1, t1), = db_query(
        "select terms_version, terms_accepted_at from accounts_user where phone=%s", (phone,)
    )
    assert v1 == "qa-2026-v2" and t1 is not None
    login(phone)  # back to the real version
    (v2, t2), = db_query(
        "select terms_version, terms_accepted_at from accounts_user where phone=%s", (phone,)
    )
    assert v2 == TERMS_VERSION and t2 > t1
    login(phone)  # unchanged version: timestamp not bumped
    (v3, t3), = db_query(
        "select terms_version, terms_accepted_at from accounts_user where phone=%s", (phone,)
    )
    assert v3 == TERMS_VERSION and t3 == t2


def test_p1_tc19a_test_numbers_skip_send_limits(api):
    """P1-TC-19 Fixed-OTP test numbers skip the send limits (6 sends in a row all 200)."""
    for _ in range(6):
        r = request_otp(api, QA_PHONES["d"])
        assert r.status_code == 200, describe(r)
    assert verify_otp(api, QA_PHONES["d"]).status_code == 200


_E164 = re.compile(r"^\+91[6-9]\d{9}$")
