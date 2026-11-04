"""Admin helpers for the Phase 3 admin cases: seeded staff session login (password from
backend/.env SEED_DEMO_STAFF_PASSWORD, never printed; one attempt per login, so no lockout) and
QA-owned coupons created/changed through the admin form as Super Admin.

QA coupons use the code prefix `QAP3` and are created hidden (`is_visible` off), so they never
show in the customer app's coupon sheet on the user's phone. They are switched off at the end.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import httpx
import pytest
from dotenv import dotenv_values

from qa_support import BASE_URL, backend_env_file, db_query

IST = ZoneInfo("Asia/Kolkata")
ROLES = {
    "Super Admin": "superadmin@jivo.test",
    "Ops / Dispatch": "ops@jivo.test",
    "Store Manager": "store.manager@jivo.test",
    "Store Staff": "store.staff@jivo.test",
    "Catalog Manager": "catalog@jivo.test",
    "Support": "support@jivo.test",
    "Finance": "finance@jivo.test",
}
_CSRF = re.compile(r'name="csrfmiddlewaretoken" value="([^"]+)"')


def staff_password() -> str:
    pw = dotenv_values(backend_env_file(".env")).get("SEED_DEMO_STAFF_PASSWORD")
    if not pw:
        pytest.skip("SEED_DEMO_STAFF_PASSWORD not set")
    return pw


def staff_login(email: str) -> httpx.Client:
    c = httpx.Client(base_url=BASE_URL, timeout=30)
    token = _CSRF.search(c.get("/admin/login/").text).group(1)
    r = c.post(
        "/admin/login/?next=/admin/",
        data={"username": email, "password": staff_password(), "csrfmiddlewaretoken": token, "next": "/admin/"},
        headers={"Referer": f"{BASE_URL}/admin/login/"},
    )
    if not (r.status_code == 302 and r.headers.get("location") == "/admin/"):
        c.close()
        pytest.fail(f"staff login failed for a seeded role: {r.status_code} (not retried, to avoid lockout)")
    return c


def csrf(c: httpx.Client, path: str) -> str:
    r = c.get(path)
    assert r.status_code == 200, (path, r.status_code)
    return _CSRF.search(r.text).group(1)


def _dt(value: datetime | None) -> tuple[str, str]:
    if value is None:
        return "", ""
    local = value.astimezone(IST)
    return local.strftime("%Y-%m-%d"), local.strftime("%H:%M:%S")


def coupon_form(code: str, **overrides) -> dict:
    data = {
        "code": code,
        "title": f"QA {code}",
        "description": "QA-owned test coupon (hidden)",
        "is_active": True,
        "is_visible": False,
        "discount_type": "FLAT",
        "value": "10.00",
        "max_discount": "",
        "min_order_value": "0.00",
        "starts_at": None,
        "ends_at": None,
        "usage_limit_total": "",
        "usage_limit_per_user": "1",
        "first_order_only": False,
    }
    data.update(overrides)
    form = {}
    for key, value in data.items():
        if key in ("starts_at", "ends_at"):
            form[f"{key}_0"], form[f"{key}_1"] = _dt(value)
        elif isinstance(value, bool):
            if value:
                form[key] = "on"
        else:
            form[key] = value
    return form


def save_coupon(c: httpx.Client, code: str, **overrides) -> int:
    """Create (or, when it exists, change) QA coupon `code` through the admin form."""
    row = db_query("select id from promotions_coupon where code=%s", (code,))
    path = f"/admin/promotions/coupon/{row[0][0]}/change/" if row else "/admin/promotions/coupon/add/"
    form = coupon_form(code, **overrides)
    form["csrfmiddlewaretoken"] = csrf(c, path)
    form["_save"] = "Save"
    r = c.post(path, data=form, headers={"Referer": f"{BASE_URL}{path}"})
    assert r.status_code == 302, f"coupon form rejected: {r.status_code} {re.findall(r'errorlist[^>]*>(.*?)</ul>', r.text, re.S)[:3]}"
    return db_query("select id from promotions_coupon where code=%s", (code,))[0][0]


def past(minutes: int = 60) -> datetime:
    return datetime.now(IST) - timedelta(minutes=minutes)


def future(minutes: int = 60 * 24) -> datetime:
    return datetime.now(IST) + timedelta(minutes=minutes)
