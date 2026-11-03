"""BUG-0006 verification / P1-TC-95: staff session policy (05 §5: "Session timeout 8 hours (store
staff) / 2 hours idle (admin roles)", 09 §3.1).

- Default profile: the session cookie set at login expires at login + 2 h for admin roles (Super
  Admin) and at login + 8 h for store-only staff (Store Staff).
- shortsession profile (idle 90 s, absolute 180 s; the app refreshes "last seen" at most once a
  minute): an idle admin is signed out after the idle limit; an active admin stays signed in until
  the absolute limit; store staff have no idle limit but hit the absolute one.

One successful login per account per run; the seeded password is never printed (a failed login is
not retried, so no account can be locked).
"""

from __future__ import annotations

import time

import httpx
import pytest

from qa_support import BASE_URL
from test_p1_staff import _post_login, _staff_password

pytestmark = pytest.mark.limits


def _login(username: str) -> httpx.Client:
    c = httpx.Client(base_url=BASE_URL, timeout=30)
    r = _post_login(c, username, _staff_password())
    if not (r.status_code == 302 and r.headers.get("location") == "/admin/"):
        c.close()
        pytest.fail(f"{username} login failed: {r.status_code} (not retried, to avoid lockout)")
    return c


def _cookie_expires(c: httpx.Client) -> float:
    cookie = next(k for k in c.cookies.jar if k.name == "sessionid")
    assert cookie.expires is not None, "session cookie must carry an expiry"
    return cookie.expires


def _signed_in(c: httpx.Client) -> bool:
    r = c.get("/admin/")
    if r.status_code == 200:
        return True
    assert r.status_code == 302 and r.headers["location"].startswith("/admin/login/"), r.status_code
    return False


def test_p1_tc95_cookie_expiry_per_role():
    """P1-TC-95 (default profile) Cookie expiry at login: Super Admin (admin role, 2 h idle) about
    now + 7200 s; Store Staff (store-only, 8 h absolute) about now + 28800 s."""
    t0 = time.time()
    admin = _login("superadmin@jivo.test")
    staff = _login("store.staff@jivo.test")
    try:
        assert abs(_cookie_expires(admin) - (t0 + 7200)) < 120, _cookie_expires(admin) - t0
        assert abs(_cookie_expires(staff) - (t0 + 28800)) < 120, _cookie_expires(staff) - t0
        assert _signed_in(admin) and _signed_in(staff)
    finally:
        admin.close()
        staff.close()


@pytest.mark.profile_shortsession
def test_p1_tc95b_idle_and_absolute_limits():
    """P1-TC-95 (shortsession: idle 90 s, absolute 180 s) Timeline from login:
    - Super Admin idle: signed in at 0 s, signed out at 95 s (idle limit).
    - Ops (admin role) active: requests at 65 s and 140 s keep the session; signed out at 185 s
      (absolute limit, despite activity).
    - Store Staff idle: still signed in at 95 s and 140 s (no idle limit); signed out at 185 s.
    Cookie expiry at login: admin roles +90 s, store staff +180 s."""
    t0 = time.time()
    admin = _login("superadmin@jivo.test")
    ops = _login("ops@jivo.test")
    staff = _login("store.staff@jivo.test")
    log = []

    def at(seconds: float) -> None:
        delay = t0 + seconds - time.time()
        if delay > 0:
            time.sleep(delay)

    try:
        assert abs(_cookie_expires(admin) - (t0 + 90)) < 15
        assert abs(_cookie_expires(staff) - (t0 + 180)) < 15
        assert _signed_in(admin) and _signed_in(ops) and _signed_in(staff)
        at(65)
        log.append(("65s ops", _signed_in(ops)))
        at(95)
        log.append(("95s admin(idle)", _signed_in(admin)))
        log.append(("95s staff(idle)", _signed_in(staff)))
        at(140)
        log.append(("140s ops", _signed_in(ops)))
        log.append(("140s staff", _signed_in(staff)))
        at(185)
        log.append(("185s ops", _signed_in(ops)))
        log.append(("185s staff", _signed_in(staff)))
        print(log)
        assert log == [
            ("65s ops", True),
            ("95s admin(idle)", False),
            ("95s staff(idle)", True),
            ("140s ops", True),
            ("140s staff", True),
            ("185s ops", False),
            ("185s staff", False),
        ]
    finally:
        for c in (admin, ops, staff):
            c.close()
