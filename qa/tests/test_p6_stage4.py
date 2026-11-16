"""Phase 6 profile cases, QA stage 4 (2026-11-10, develop f8db671): P6-TC-09 (token expiry on an open
socket, real 15 min lifetime), P6-TC-20 / P6-TC-32 (`wsrecheck` profile: re-checks every 5 s) and the
DELIVERY_FAILED part of P6-TC-33 (local). The ACCEPTANCE_SLA_BREACHED / DISPATCH_UNASSIGNED parts of
P6-TC-33 run in `test_p5_stage4_profiles.py` (s4timers). QA instance :8004 only.
"""

from __future__ import annotations

import json
import time

import pytest
from websockets.sync.client import connect

from conftest import login
from p3_admin import csrf
from p4_support import MANAGER, OPS, SUPER
from p5_support import (  # noqa: F401 (fixtures)
    QA02_ID, R2_PHONE, bring_to, p5_shop_a, qa_worker, r1, r2, rider_op,
)
from p6_support import WS_BASE, orders_of, staff_cookie
from qa_support import QA_PHONES, jwt_claims
from test_p6_t612 import Listener


@pytest.mark.any_profile
def test_p6_tc09_access_expiry_closes_socket_4401():
    """P6-TC-09 (slow, about 15 min) customer A authenticates the order socket with a fresh access
    token (15 min lifetime, 06 §2.1) and never renews it: the server closes the socket with 4401 at
    the token's `exp` (06 §4.1), not before and not much later."""
    a = login(QA_PHONES["a"])
    orders = orders_of(a.access)
    if not orders:
        pytest.skip("QA customer A has no order")
    exp = jwt_claims(a.access)["exp"]
    ws = connect(f"{WS_BASE}/ws/v1/orders/{orders[0]['id']}/", open_timeout=10)
    ws.send(json.dumps({"type": "auth", "token": a.access}))
    first = json.loads(ws.recv(timeout=10))
    assert first["type"] == "auth.ok", first
    code = None
    closed_at = None
    while time.time() < exp + 120:
        try:
            ws.recv(timeout=20)
        except TimeoutError:
            if time.time() < exp - 30:
                ws.send(json.dumps({"type": "ping"}))  # keep the connection active, not the token
            continue
        except Exception as exc:  # ConnectionClosed
            code = getattr(getattr(exc, "rcvd", None), "code", None)
            closed_at = time.time()
            break
    assert code == 4401, f"close code {code}"
    assert exp - 5 <= closed_at <= exp + 70, f"closed {closed_at - exp:+.0f} s from exp"


@pytest.mark.profile_wsrecheck
def test_p6_tc20_suspended_rider_socket_closed_4403(r2):
    """P6-TC-20 R2's rider socket is open and authorised; Ops suspends R2: the socket is closed with
    4403 at the next re-check (WS_RIDER_RECHECK_SECONDS = 5 on this profile)."""
    s = Listener("/ws/v1/rider/", r2.session.access)
    try:
        assert s.wait("auth.ok", 5)
        out = rider_op(op="suspend", **{"as": SUPER}, phone=R2_PHONE, reason="QA P6-TC-20 socket re-check")
        assert out["ok"], out
        t0 = time.monotonic()
        while s.closed is None and time.monotonic() - t0 < 20:
            time.sleep(0.2)
        assert s.closed == 4403, s.closed
        assert time.monotonic() - t0 <= 12, f"closed {time.monotonic() - t0:.1f} s after the suspension"
    finally:
        s.close()
        back = rider_op(op="reinstate", **{"as": SUPER}, phone=R2_PHONE)
        assert back["ok"] and back["result"]["status"] == "ACTIVE", back


@pytest.mark.profile_wsrecheck
def test_p6_tc32_ops_feed_closed_after_logout():
    """P6-TC-32 OPS opens the live feed, then logs out of the panel in the same browser session
    (POST /admin/logout/ + CSRF): the feed closes with 4401 at the next re-check (5 s here)."""
    c, cookie = staff_cookie(OPS)
    feed = Listener("/ws/ops/live/", cookie=cookie)
    try:
        time.sleep(2)
        assert feed.closed is None, feed.closed
        token = csrf(c, "/admin/")
        r = c.post("/admin/logout/", data={"csrfmiddlewaretoken": token}, headers={"Referer": f"{c.base_url}/admin/"})
        assert r.status_code in (200, 302), r.status_code
        t0 = time.monotonic()
        while feed.closed is None and time.monotonic() - t0 < 20:
            time.sleep(0.2)
        assert feed.closed == 4401, feed.closed
        assert time.monotonic() - t0 <= 12, f"closed {time.monotonic() - t0:.1f} s after the logout"
    finally:
        feed.close()
        c.close()


def test_p6_tc33c_delivery_failed_alert_to_store_feed_only(r1, p5_shop_a):
    """P6-TC-33 (DELIVERY_FAILED) R1 fails A's QA-02 delivery at the door: an `alert` DELIVERY_FAILED
    with the order id reaches the QA-02 ops feed (OPS); the GGN-01 Store Manager's feed gets nothing
    about the order."""
    _, ops_cookie = staff_cookie(OPS)
    _, sm_cookie = staff_cookie(MANAGER)
    ops_ws = Listener("/ws/ops/live/", cookie=ops_cookie)
    sm_ws = Listener("/ws/ops/live/", cookie=sm_cookie)
    try:
        r1.online_at()
        ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
        oid = ctx["order_id"]
        t0 = time.monotonic()
        assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
        alert = ops_ws.wait("alert", 10, t0, order_id=oid, code="DELIVERY_FAILED")
        assert alert and alert[1]["data"].get("store_id") == QA02_ID, [m for _, m in ops_ws.msgs][-5:]
        time.sleep(1)
        leak = [m for _, m in sm_ws.msgs if m.get("data", {}).get("order_id") == oid]
        assert leak == [], f"GGN-01 feed got the QA-02 alert: {leak[:2]}"
    finally:
        ops_ws.close()
        sm_ws.close()
