"""Phase 4 Ops Console client (stage 2): a seeded staff user's browser session against the real
console URLs (`apps/ops_console/urls.py`), posting like HTMX does: `HX-Request: true` and the
CSRF token in `X-CSRFToken` (the page's `hx-headers`). Form fields are the real form classes'
names (`ops_console.forms`: `reason`/`note`, `item`/`quantity_unavailable`, `accepting`).

Only QA customers' orders are ever acted on: every POST checks the order's user phone first."""

from __future__ import annotations

import re
from urllib.parse import urlencode

import httpx

from p3_admin import BASE_URL, staff_login
from qa_support import db_query

_CSRF_HDR = re.compile(r'"X-CSRFToken":\s*"([^"]+)"')
_CSRF_INPUT = re.compile(r'name="csrfmiddlewaretoken" value="([^"]+)"')
FORM = "application/x-www-form-urlencoded"


def assert_qa_order(order_id: int) -> None:
    rows = db_query("select u.phone from orders_order o join accounts_user u on u.id=o.user_id where o.id=%s", (order_id,))
    if rows and not str(rows[0][0]).startswith("+9190000001"):
        raise RuntimeError(f"refusing to act on non-QA order {order_id}")


class Ops:
    def __init__(self, email: str):
        self.email = email
        self.c: httpx.Client = staff_login(email)
        self.csrf: str | None = None

    def close(self) -> None:
        self.c.close()

    def get(self, path: str, **kw) -> httpx.Response:
        r = self.c.get(path, **kw)
        m = _CSRF_HDR.search(r.text) or _CSRF_INPUT.search(r.text)
        if m:
            self.csrf = m.group(1)
        return r

    def token(self) -> str:
        if not self.csrf:
            self.get("/admin/")
        if not self.csrf:
            self.csrf = self.c.cookies.get("csrftoken")
        return self.csrf

    def post(self, path: str, data: dict | list | None = None, *, htmx: bool = True, csrf: bool = True,
             order_id: int | None = None) -> httpx.Response:
        if order_id is not None:
            assert_qa_order(order_id)
        headers = {"Content-Type": FORM, "Referer": f"{BASE_URL}{path}"}
        if htmx:
            headers["HX-Request"] = "true"
        if csrf:
            headers["X-CSRFToken"] = self.token()
        body = urlencode(data or {}, doseq=True) if not isinstance(data, list) else urlencode(data)
        return self.c.post(path, content=body, headers=headers)

    # ---------------------------------------------------------------- packing console
    def step(self, store: str, order_id: int, step: str, **kw) -> httpx.Response:
        return self.post(f"/ops/store/{store}/orders/{order_id}/{step}/", order_id=order_id, **kw)

    def unavailable(self, store: str, order_id: int, item: int, qty: int, **kw) -> httpx.Response:
        return self.post(f"/ops/store/{store}/orders/{order_id}/unavailable/",
                         {"item": item, "quantity_unavailable": qty}, order_id=order_id, **kw)

    def cancel(self, store: str, order_id: int, reason: str, note: str = "", **kw) -> httpx.Response:
        return self.post(f"/ops/store/{store}/orders/{order_id}/cancel/", {"reason": reason, "note": note},
                         order_id=order_id, **kw)

    def board_cancel(self, order_id: int, reason: str, note: str = "", **kw) -> httpx.Response:
        return self.post(f"/ops/orders/{order_id}/cancel/", {"reason": reason, "note": note}, order_id=order_id, **kw)


def message(r: httpx.Response) -> str:
    from urllib.parse import unquote

    return unquote(r.headers.get("X-Ops-Message", "")) or r.text[:200]
