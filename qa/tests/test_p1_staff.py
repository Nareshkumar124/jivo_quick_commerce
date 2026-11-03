"""Phase 1 staff: session login, django-axes lockout, role groups, Customers block/unblock
(05 §2/§3, 09 §3.1). The per-role admin page matrix is deferred to QA run 2 (admin UI in flux).

Lockout tests use NON-EXISTENT usernames only, so no real staff account is ever locked. The
seeded staff password is read from backend/.env (SEED_DEMO_STAFF_PASSWORD) and never printed;
a staff login is attempted at most once per test so a wrong value cannot lock the account."""

from __future__ import annotations

import re
import time

import httpx
import pytest
from dotenv import dotenv_values

from conftest import login
from qa_support import (
    backend_env_file,
    APP_HEADERS,
    BASE_URL,
    QA_PHONES,
    REPO,
    TEST_OTP,
    assert_error,
    db_query,
    describe,
)

SUPERADMIN = "superadmin@jivo.test"


def _csrf(c: httpx.Client) -> str:
    r = c.get("/admin/login/")
    assert r.status_code == 200
    return re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', r.text).group(1)


def _post_login(c: httpx.Client, username: str, password: str) -> httpx.Response:
    token = _csrf(c)
    return c.post(
        "/admin/login/?next=/admin/",
        data={"username": username, "password": password, "csrfmiddlewaretoken": token, "next": "/admin/"},
        headers={"Referer": f"{BASE_URL}/admin/login/"},
    )


def _staff_password() -> str:
    pw = dotenv_values(backend_env_file(".env")).get("SEED_DEMO_STAFF_PASSWORD")
    if not pw:
        pytest.skip("SEED_DEMO_STAFF_PASSWORD not set")
    return pw


@pytest.fixture(scope="module")
def admin_session():
    """A Super Admin session on the QA instance (one login attempt only)."""
    c = httpx.Client(base_url=BASE_URL, timeout=30)
    r = _post_login(c, SUPERADMIN, _staff_password())
    if not (r.status_code == 302 and r.headers.get("location") == "/admin/"):
        c.close()
        pytest.fail(f"Super Admin login failed: {r.status_code} (not retried, to avoid lockout)")
    yield c
    c.close()


@pytest.mark.smoke
def test_p1_tc64_staff_session_login(admin_session):
    """P1-TC-64 🔥 A seeded staff user signs in to /admin/ with email + password (session); the
    session cookie is HttpOnly; it is NOT accepted by the JWT-only /api/v1/ API."""
    r = admin_session.get("/admin/")
    assert r.status_code == 200 and "Jivo" in r.text
    cookie = next(c for c in admin_session.cookies.jar if c.name == "sessionid")
    assert cookie.has_nonstandard_attr("HttpOnly") or cookie._rest.get("HttpOnly") is not None
    r = admin_session.get("/api/v1/me/", headers=APP_HEADERS)
    assert_error(r, 401, "AUTH_REQUIRED")


def test_p1_tc68_admin_login_csrf():
    """P1-TC-68 POST /admin/login/ without a CSRF token -> 403 (CSRF protection on the panel)."""
    with httpx.Client(base_url=BASE_URL) as c:
        r = c.post("/admin/login/", data={"username": "qa-nobody@nowhere.test", "password": "x"})
        assert r.status_code == 403, describe(r)


@pytest.mark.limits
def test_p1_tc65_axes_lockout_nonexistent_usernames():
    """P1-TC-65 django-axes: 5 failed logins for one username from one IP lock that
    username+IP; the lock is case-insensitive; another username from the same IP is not locked.
    Non-existent usernames only."""
    user = f"qa-lockout-{time.time_ns()}@nowhere.test"
    statuses = []
    with httpx.Client(base_url=BASE_URL, timeout=30) as c:
        for _ in range(6):
            statuses.append(_post_login(c, user, "wrong-password-123").status_code)
        locked_upper = _post_login(c, user.upper(), "wrong-password-123")
        other = _post_login(c, f"qa-other-{time.time_ns()}@nowhere.test", "wrong-password-123")
    assert statuses[:4] == [200, 200, 200, 200], statuses  # form re-rendered with an error
    assert statuses[5] in (403, 429), statuses
    assert locked_upper.status_code == statuses[5], "lockout should be case-insensitive"
    assert other.status_code == 200, "another username must not be locked"
    rows = db_query(
        "select failures_since_start from axes_accessattempt where username=%s", (user.lower(),)
    )
    assert rows and rows[0][0] >= 5, rows


@pytest.mark.db
def test_p1_tc66_role_groups():
    """P1-TC-66 The seven role Groups exist; Phase 1 grants: Super Admin all accounts/auth/cms
    permissions, Ops and Support view+change customer, the rest nothing yet."""
    rows = db_query(
        "select g.name, coalesce(string_agg(ct.app_label||'.'||p.codename, ',' order by p.codename), '') "
        "from auth_group g left join auth_group_permissions gp on gp.group_id=g.id "
        "left join auth_permission p on p.id=gp.permission_id "
        "left join django_content_type ct on ct.id=p.content_type_id group by g.name"
    )
    perms = {name: set(filter(None, joined.split(","))) for name, joined in rows}
    expected = {"Super Admin", "Ops / Dispatch", "Store Manager", "Store Staff", "Catalog Manager", "Support", "Finance"}
    assert expected <= set(perms), set(perms)
    care = {"accounts.view_customer", "accounts.change_customer"}
    assert perms["Ops / Dispatch"] >= care and perms["Support"] >= care
    assert {"accounts.change_user", "cms.change_appconfig", "auth.change_group"} <= perms["Super Admin"]
    # Phase 1 only: other roles must not hold accounts/cms/auth permissions.
    for role in ("Store Manager", "Store Staff", "Catalog Manager", "Finance"):
        p1 = {p for p in perms[role] if p.split(".")[0] in ("accounts", "cms", "auth")}
        assert not p1, f"{role}: {p1}"
    assert not {p for p in perms["Ops / Dispatch"] | perms["Support"] if p.endswith("_user")}


def test_p1_tc67_admin_role_matrix():
    """P1-TC-67 Admin pages per role (05 §3, P1 rows)."""
    pytest.skip("⏭ Deferred to QA run 2: admin-panel-dev is reworking the admin UI right now.")


@pytest.mark.db
def test_p1_tc23_tc71_block_and_unblock_customer(admin_session, api):
    """P1-TC-71 Customers admin 'Block' deactivates the customer and revokes their refresh
    tokens; P1-TC-23 a blocked customer's OTP verify -> 403 PERMISSION_DENIED; 'Unblock'
    restores sign-in. Target: QA user D only."""
    s = login(QA_PHONES["d"])
    user_id = s.user["id"]

    def action(name: str) -> None:
        page = admin_session.get("/admin/accounts/customer/")
        assert page.status_code == 200, page.status_code
        token = re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', page.text).group(1)
        r = admin_session.post(
            "/admin/accounts/customer/",
            data={"action": name, "_selected_action": [str(user_id)], "csrfmiddlewaretoken": token, "index": "0"},
            headers={"Referer": f"{BASE_URL}/admin/accounts/customer/"},
        )
        assert r.status_code in (200, 302), r.status_code

    try:
        action("block")
        assert db_query("select is_active from accounts_user where id=%s", (user_id,)) == [(False,)]
        r = api.post("/api/v1/auth/token/refresh/", json={"refresh": s.refresh})
        assert_error(r, 401, "TOKEN_INVALID")
        assert api.post("/api/v1/auth/otp/request/", json={"phone": QA_PHONES["d"], "app": "customer"}).status_code == 200
        r = api.post(
            "/api/v1/auth/otp/verify/",
            json={"phone": QA_PHONES["d"], "otp": TEST_OTP, "app": "customer", "terms_version": "2026-11-01"},
        )
        err = assert_error(r, 403, "PERMISSION_DENIED")
        assert "deactivated" in err["message"].lower()
        # Observation: the blocked user's existing access token (<= 15 min) is also refused.
        r = api.get("/api/v1/me/", headers=s.headers)
        assert r.status_code == 401, describe(r)
    finally:
        action("unblock")
    assert db_query("select is_active from accounts_user where id=%s", (user_id,)) == [(True,)]
    assert login(QA_PHONES["d"]).user["id"] == user_id
