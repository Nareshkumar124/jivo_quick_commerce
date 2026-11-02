"""Phase 1 JWT session handling (06 §2.1, 09 §3.1, 02 §5)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import re
import time
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest

from conftest import login
from qa_support import (
    BASE_URL,
    QA_PHONES,
    APP_HEADERS,
    assert_error,
    bearer,
    db_query,
    describe,
    instance_commit,
    jwt_claims,
    profile,
    validate_response,
)


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _sign(payload: dict, key: str, alg: str = "HS256") -> str:
    header = _b64(json.dumps({"alg": alg, "typ": "JWT"}).encode())
    body = _b64(json.dumps(payload).encode())
    if alg == "none":
        return f"{header}.{body}."
    sig = hmac.new(key.encode(), f"{header}.{body}".encode(), hashlib.sha256).digest()
    return f"{header}.{body}.{_b64(sig)}"


def _dev_key() -> str:
    """The development-only fallback key, read from the commit under test (never stored in qa/)."""
    text = open(f"/tmp/jivo-qa-{instance_commit()}/backend/config/settings/local.py").read()
    return re.search(r'SECRET_KEY = SECRET_KEY or "([^"]+)"', text).group(1)


def _refresh(c: httpx.Client, token) -> httpx.Response:
    return c.post("/api/v1/auth/token/refresh/", json={"refresh": token})


@pytest.mark.smoke
def test_p1_tc24_refresh_rotation_and_reuse(api, user_a):
    """P1-TC-24 🔥 Refresh returns a new {access, refresh}; the used refresh token is revoked
    (reuse -> 401 TOKEN_INVALID); the new one works; the new access token works on /me/."""
    r = _refresh(api, user_a.refresh)
    assert r.status_code == 200, describe(r)
    validate_response(r, "auth_token_refresh")
    pair = r.json()
    assert pair["refresh"] != user_a.refresh and pair["access"] != user_a.access
    reuse = _refresh(api, user_a.refresh)
    err = assert_error(reuse, 401, "TOKEN_INVALID")
    validate_response(reuse, "auth_token_refresh")
    assert "blacklisted" in err["message"].lower()
    assert api.get("/api/v1/me/", headers=bearer(pair["access"])).status_code == 200
    assert _refresh(api, pair["refresh"]).status_code == 200


@pytest.mark.db
def test_p1_tc24b_rotated_tokens_are_tracked(api, user_a):
    """P1-TC-24b Every rotated refresh token is recorded as outstanding (so revoke-all on logout,
    deletion and block can reach it) and the used one is blacklisted."""
    r = _refresh(api, user_a.refresh)
    new_jti = jwt_claims(r.json()["refresh"])["jti"]
    old_jti = jwt_claims(user_a.refresh)["jti"]
    rows = db_query(
        "select o.jti, b.id is not null from token_blacklist_outstandingtoken o "
        "left join token_blacklist_blacklistedtoken b on b.token_id=o.id where o.jti in (%s, %s)",
        (new_jti, old_jti),
    )
    state = dict(rows)
    assert state == {old_jti: True, new_jti: False}, state




@pytest.mark.parametrize(
    "body,status,code",
    [
        ({}, 400, "VALIDATION_ERROR"),
        ({"refresh": ""}, 400, "VALIDATION_ERROR"),
        ({"refresh": None}, 400, "VALIDATION_ERROR"),
        ({"refresh": "garbage"}, 401, "TOKEN_INVALID"),
        ({"refresh": "a.b.c"}, 401, "TOKEN_INVALID"),
    ],
)
def test_p1_tc25_refresh_invalid_input(api, body, status, code):
    """P1-TC-25 Refresh input errors: missing/blank -> 400 VALIDATION_ERROR; garbage -> 401."""
    r = api.post("/api/v1/auth/token/refresh/", json=body)
    assert_error(r, status, code)
    validate_response(r, "auth_token_refresh")


def test_p1_tc25b_access_token_is_not_a_refresh_token(api, user_a):
    """P1-TC-25 An access token sent to /token/refresh/ -> 401 TOKEN_INVALID."""
    assert_error(_refresh(api, user_a.access), 401, "TOKEN_INVALID")


def test_p1_tc26_forged_and_tampered_tokens(api, user_a, user_b):
    """P1-TC-26 Tampered payload (user_id swapped, signature kept), alg=none, a wrong key and a
    refresh token used as Bearer all -> 401 TOKEN_INVALID on /me/."""
    head, _, sig = user_a.access.split(".")
    claims = jwt_claims(user_a.access)
    claims["user_id"] = str(user_b.user["id"])
    tampered = f"{head}.{_b64(json.dumps(claims).encode())}.{sig}"
    none_alg = _sign(claims, "", alg="none")
    wrong_key = _sign(claims, "qa-wrong-key-" + "x" * 40)
    for token in (tampered, none_alg, wrong_key, user_a.refresh, "garbage", "a.b.c"):
        r = api.get("/api/v1/me/", headers=bearer(token))
        assert_error(r, 401, "TOKEN_INVALID")
        validate_response(r, "me_retrieve")


def test_p1_tc26b_expired_access_token(api, user_a):
    """P1-TC-26 (local profile) An access token whose exp is in the past -> 401 TOKEN_INVALID.
    Minted with the development fallback key, which only local settings use."""
    if profile() != "local":
        pytest.skip("local profile only")
    claims = jwt_claims(user_a.access)
    now = int(time.time())
    claims.update(iat=now - 1000, exp=now - 100)
    r = api.get("/api/v1/me/", headers=bearer(_sign(claims, _dev_key())))
    assert_error(r, 401, "TOKEN_INVALID")  # message is simplejwt's generic "not valid" text
    # Control: the same key with a valid exp is accepted (local only) - the key is public.
    claims.update(iat=now, exp=now + 300)
    assert api.get("/api/v1/me/", headers=bearer(_sign(claims, _dev_key()))).status_code == 200


@pytest.mark.profile_staging
def test_p1_tc26c_dev_key_tokens_rejected_outside_local():
    """P1-TC-26c (staging profile) A token signed with the public development key is rejected:
    deployed settings require their own DJANGO_SECRET_KEY / JWT_SIGNING_KEY."""
    with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS) as c:
        s = login(QA_PHONES["d"])
        claims = jwt_claims(s.access)
        r = c.get("/api/v1/me/", headers=bearer(_sign(claims, _dev_key())))
        assert_error(r, 401, "TOKEN_INVALID")


def test_p1_tc27_lifetimes_and_app_claim(api, user_a):
    """P1-TC-27 Access lives 15 minutes and refresh 30 days; the app claim survives rotation."""
    access, refresh = jwt_claims(user_a.access), jwt_claims(user_a.refresh)
    assert access["exp"] - access["iat"] == 15 * 60
    assert refresh["exp"] - refresh["iat"] == 30 * 24 * 3600
    pair = _refresh(api, user_a.refresh).json()
    assert jwt_claims(pair["refresh"]).get("app") == "customer"
    assert jwt_claims(pair["access"]).get("app") == "customer"
    assert jwt_claims(pair["refresh"])["exp"] - jwt_claims(pair["refresh"])["iat"] == 30 * 24 * 3600


@pytest.mark.smoke
def test_p1_tc28_logout(api, user_a):
    """P1-TC-28 🔥 Logout -> 204 with no body; the refresh token is revoked; repeating is still
    204 (idempotent); no credentials -> 401 AUTH_REQUIRED; no refresh -> 400."""
    r = api.post("/api/v1/auth/logout/", json={"refresh": user_a.refresh}, headers=user_a.headers)
    assert r.status_code == 204 and r.content == b"", describe(r)
    validate_response(r, "auth_logout")
    assert_error(_refresh(api, user_a.refresh), 401, "TOKEN_INVALID")
    r = api.post("/api/v1/auth/logout/", json={"refresh": user_a.refresh}, headers=user_a.headers)
    assert r.status_code == 204
    r = api.post("/api/v1/auth/logout/", json={"refresh": "garbage"}, headers=user_a.headers)
    assert r.status_code == 204
    r = api.post("/api/v1/auth/logout/", json={"refresh": user_a.refresh})
    assert_error(r, 401, "AUTH_REQUIRED")
    r = api.post("/api/v1/auth/logout/", json={}, headers=user_a.headers)
    assert_error(r, 400, "VALIDATION_ERROR")
    validate_response(r, "auth_logout")


def test_p1_tc28b_access_token_after_logout(api, user_a):
    """P1-TC-28b Observation: the access token keeps working after logout until it expires
    (<= 15 min, stateless JWT). 06 §2.1 only promises refresh revocation on logout."""
    api.post("/api/v1/auth/logout/", json={"refresh": user_a.refresh}, headers=user_a.headers)
    assert api.get("/api/v1/me/", headers=user_a.headers).status_code == 200


def test_p1_tc29_logout_with_foreign_refresh(api, user_a, user_b):
    """P1-TC-29 A logging out with B's refresh token -> 204 and nothing happens to B's session."""
    r = api.post("/api/v1/auth/logout/", json={"refresh": user_b.refresh}, headers=user_a.headers)
    assert r.status_code == 204
    assert _refresh(api, user_b.refresh).status_code == 200


@pytest.mark.db
def test_p1_tc30_logout_deactivates_device(api, user_a):
    """P1-TC-30 Logout with fcm_token deactivates that device (no more pushes); another of the
    user's devices stays active; someone else's token is untouched."""
    tok1, tok2 = f"qa-fcm-logout-{time.time_ns()}", f"qa-fcm-keep-{time.time_ns()}"
    for tok in (tok1, tok2):
        r = api.post(
            "/api/v1/me/devices/",
            json={"fcm_token": tok, "app": "customer", "platform": "android", "app_version": "1.0.0"},
            headers=user_a.headers,
        )
        assert r.status_code == 200, describe(r)
    r = api.post(
        "/api/v1/auth/logout/", json={"refresh": user_a.refresh, "fcm_token": tok1}, headers=user_a.headers
    )
    assert r.status_code == 204
    state = dict(db_query("select fcm_token, is_active from accounts_device where fcm_token in (%s,%s)", (tok1, tok2)))
    assert state == {tok1: False, tok2: True}, state


def test_p1_tc31_authorization_header_variants(api, user_a):
    """P1-TC-31 No credentials -> 401 AUTH_REQUIRED with WWW-Authenticate; malformed Bearer
    headers -> 401 (never 500, never 200)."""
    r = api.get("/api/v1/me/")
    assert_error(r, 401, "AUTH_REQUIRED")
    assert r.headers.get("www-authenticate", "").startswith("Bearer")
    variants = {
        "Bearer": ("TOKEN_INVALID",),
        f"Bearer {user_a.access} extra": ("TOKEN_INVALID",),
        f"Token {user_a.access}": ("AUTH_REQUIRED",),
        f"bearer {user_a.access}": ("AUTH_REQUIRED", "TOKEN_INVALID"),
        f"JWT {user_a.access}": ("AUTH_REQUIRED",),
    }
    for header, codes in variants.items():
        r = api.get("/api/v1/me/", headers={"Authorization": header})
        assert r.status_code == 401, describe(r)
        assert r.json()["error"]["code"] in codes, describe(r)


def test_p1_tc31b_session_cookie_not_accepted_on_api(api):
    """P1-TC-31b The /api/v1/ API is JWT only (02 §5): a random sessionid cookie is ignored."""
    r = api.get("/api/v1/me/", headers={"Cookie": "sessionid=abc; csrftoken=x"})
    assert_error(r, 401, "AUTH_REQUIRED")


def test_p1_tc32_public_endpoints_ignore_bad_bearer(api):
    """P1-TC-32 Public endpoints never fail because of a stale or garbage Bearer token."""
    junk = {"Authorization": "Bearer stale.garbage.token"}
    assert api.get("/api/v1/config/app/", headers=junk).status_code == 200
    r = api.post(
        "/api/v1/auth/otp/request/", json={"phone": QA_PHONES["d"], "app": "customer"}, headers=junk
    )
    assert r.status_code == 200, describe(r)
    r = api.post("/api/v1/auth/token/refresh/", json={"refresh": "garbage"}, headers=junk)
    assert_error(r, 401, "TOKEN_INVALID")
