"""Phase 6 (T-611) black-box: order socket, rider socket access, ops live feed, inbox,
notification matrix, purge schedule, socket abuse limits (06 §4, §2.7, §5; 08 §9; 09).

Cases: `qa/docs/02-test-case-repository.md` (Phase 6). T-612/613/614 cases are skipped with the
reason until those tasks land. Runs against the QA instance on 127.0.0.1:8004 only.
"""

from __future__ import annotations

import asyncio
import json
import re
import time
from pathlib import Path

import httpx
import pytest
from websockets.exceptions import InvalidStatus

from conftest import login
from p4_support import CATALOG, FINANCE, MANAGER, OPS, STAFF, SUPER, SUPPORT
from p5_support import QA02_ID, p5_shop_a, qa_worker  # noqa: F401 (fixtures)
from p6_support import (
    CREATED_KEYS,
    ORIGIN,
    STATUS_KEYS,
    assert_shape,
    auth,
    clear_socket_slots,
    collect,
    ops_close_code,
    orders_of,
    recv,
    run,
    staff_cookie,
    until_closed,
    ws_open,
)
from qa_support import (
    APP_HEADERS,
    QA_DIR,
    QA_PHONES,
    RIDER_HEADERS,
    assert_error,
    bearer,
    db_query,
    describe,
    openapi,
    redact,
    validate_response,
)

T612 = pytest.mark.skip(reason="T-612 merged (d29ed94): implemented in tests/test_p6_t612.py")
OTP_RE = re.compile(r"\bOTP\s*:?\s*\d{4,6}\b")


@pytest.fixture(scope="module", autouse=True)
def _slots():
    clear_socket_slots()
    yield
    clear_socket_slots()


@pytest.fixture(scope="module")
def a():
    return login(QA_PHONES["a"])


@pytest.fixture(scope="module")
def b():
    return login(QA_PHONES["b"])


@pytest.fixture(scope="module")
def a_order(a):
    orders = orders_of(a.access)
    if not orders:
        pytest.skip("QA customer A has no order")
    return orders[0]


@pytest.fixture(scope="module")
def b_order(b):
    orders = orders_of(b.access)
    if not orders:
        pytest.skip("QA customer B has no order")
    return orders[0]


def opath(order_id: int) -> str:
    return f"/ws/v1/orders/{order_id}/"


# =========================================================================== order socket


def test_p6_tc01_first_message_auth_then_snapshot(a, a_order):
    """P6-TC-01 auth via the first message: auth.ok {user_id, expires_at}, then one order.status
    snapshot; shape {type, data, sent_at}; no customer data or OTP."""

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            ok = await auth(ws, a.access)
            snap = await recv(ws, 5)
            extra = await collect(ws, 2)
            return ok, snap, extra

    ok, snap, extra = run(go())
    assert ok and ok["type"] == "auth.ok", ok
    assert_shape(ok)
    assert ok["data"]["user_id"] == a.user["id"]
    assert ok["data"]["expires_at"].endswith("Z")
    assert snap and snap["type"] == "order.status", snap
    assert_shape(snap)
    assert set(snap["data"]) == STATUS_KEYS, snap["data"]
    assert snap["data"]["order_id"] == a_order["id"] and snap["data"]["status"] == a_order["status"]
    assert extra == [], extra  # exactly one snapshot


def test_p6_tc02_tc05_token_in_url_ignored_then_auth_timeout(a, a_order):
    """P6-TC-02 a token in the URL query is ignored (no auth.ok, nothing sent);
    P6-TC-05 the socket is closed 4408 after WS_AUTH_TIMEOUT_SECONDS (10 s)."""

    async def go():
        t0 = time.monotonic()
        async with ws_open(f"{opath(a_order['id'])}?token={a.access}") as ws:
            code, msgs = await until_closed(ws, 15)
        return code, msgs, time.monotonic() - t0

    code, msgs, took = run(go())
    assert msgs == [], redact(json.dumps(msgs))
    assert code == 4408, code
    assert 8 <= took <= 14, took


def test_p6_tc03_subprotocol_auth(a, a_order):
    """P6-TC-03 subprotocols jivo.v1 + jivo.auth.<jwt>: jivo.v1 selected, the token never echoed,
    auth.ok then the snapshot without an auth message."""

    async def go():
        async with ws_open(opath(a_order["id"]), subprotocols=["jivo.v1", f"jivo.auth.{a.access}"]) as ws:
            headers = dict(ws.response.headers.raw_items())
            first, second = await recv(ws, 5), await recv(ws, 5)
            return ws.subprotocol, headers, first, second

    proto, headers, first, second = run(go())
    assert proto == "jivo.v1"
    assert all(a.access not in v for v in headers.values()), "token echoed in a response header"
    assert first["type"] == "auth.ok" and second["type"] == "order.status"


@pytest.mark.parametrize("kind", ["tampered", "refresh", "empty", "huge", "number"])
def test_p6_tc04_bad_tokens_4401(a, a_order, kind):
    """P6-TC-04 tampered / refresh token / empty / 4,000 chars / a number → 4401, nothing sent."""
    head, payload, sig = a.access.split(".")
    token = {
        "tampered": f"{head}.{payload}.{sig[:-4]}{'AAAA' if not sig.endswith('AAAA') else 'BBBB'}",
        "refresh": a.refresh,
        "empty": "",
        "huge": "x" * 4000,  # message stays under WS_MAX_MESSAGE_BYTES; a bigger one is TC-50
        "number": 12345,
    }[kind]

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            await ws.send(json.dumps({"type": "auth", "token": token}))
            return await until_closed(ws, 6)

    code, msgs = run(go())
    assert msgs == [] and code == 4401, (code, redact(json.dumps(msgs)))


@pytest.mark.parametrize("first", ['{"type": "ping"}', "not json", "[1, 2]"])
def test_p6_tc06_first_message_not_auth_4400(a_order, first):
    """P6-TC-06 a first message that is not auth (ping, non-JSON, array) → 4400, nothing sent."""

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            await ws.send(first)
            return await until_closed(ws, 6)

    code, msgs = run(go())
    assert msgs == [] and code == 4400, (code, msgs)


@pytest.mark.smoke
@pytest.mark.parametrize("which", ["other_users", "missing"])
def test_p6_tc07_idor_other_or_missing_order_4404(a, b_order, which):
    """P6-TC-07 A's token on B's order and on a missing id → the same 4404, no data."""
    order_id = b_order["id"] if which == "other_users" else 999_999_999

    async def go():
        async with ws_open(opath(order_id)) as ws:
            await ws.send(json.dumps({"type": "auth", "token": a.access}))
            return await until_closed(ws, 6)

    code, msgs = run(go())
    assert msgs == [] and code == 4404, (code, redact(json.dumps(msgs)))


def test_p6_tc08_renewal_same_user_ok_other_user_4401(a, b, a_order):
    """P6-TC-08 re-auth with a fresh token of the same user → second auth.ok; with another user's
    valid token → 4401."""
    fresh = httpx.post(f"{ORIGIN}/api/v1/auth/token/refresh/", json={"refresh": a.refresh}, headers=APP_HEADERS)
    assert fresh.status_code == 200, describe(fresh)
    a.access, a.refresh = fresh.json()["access"], fresh.json().get("refresh", a.refresh)

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            await auth(ws, a.access)
            await recv(ws, 5)  # snapshot
            renewed = await auth(ws, a.access)
            await ws.send(json.dumps({"type": "auth", "token": b.access}))
            code, msgs = await until_closed(ws, 6)
            return renewed, code, msgs

    renewed, code, msgs = run(go())
    assert renewed and renewed["type"] == "auth.ok", renewed
    assert code == 4401 and msgs == [], (code, msgs)


@pytest.mark.skip(reason="P6-TC-09 needs the `shorttoken` instance profile (stage 2)")
def test_p6_tc09_expiry_closes_4401():
    """P6-TC-09 placeholder."""


def test_p6_tc10_ping_and_unknown_type(a, a_order):
    """P6-TC-10 ping → pong with sent_at; an unknown type → error VALIDATION_ERROR, socket open."""

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            await auth(ws, a.access)
            await recv(ws, 5)
            await ws.send(json.dumps({"type": "ping"}))
            pong = await recv(ws, 5)
            await ws.send(json.dumps({"type": "bogus"}))
            err = await recv(ws, 5)
            await ws.send(json.dumps({"type": "ping"}))
            pong2 = await recv(ws, 5)
            return pong, err, pong2

    pong, err, pong2 = run(go())
    assert pong["type"] == "pong" and pong["sent_at"].endswith("Z"), pong
    assert err["type"] == "error" and err["data"]["code"] == "VALIDATION_ERROR", err
    assert pong2["type"] == "pong"


@pytest.mark.smoke
def test_p6_tc11_tc30_tc31_live_status_and_ops_scope(qa_worker, p5_shop_a):  # noqa: F811
    """P6-TC-11 a cancel reaches the order socket as order.status CANCELLED within 3 s;
    P6-TC-30 OPS gets order.created/order.status for the QA-02 order, SM and SS (GGN-01) nothing;
    P6-TC-31 the ops messages carry exactly the 06 §4.2 keys (no customer data)."""
    _, ops_cookie = staff_cookie(OPS)
    _, sm_cookie = staff_cookie(MANAGER)
    _, ss_cookie = staff_cookie(STAFF)
    shop = p5_shop_a

    async def go():
        kw = {"origin": ORIGIN}
        from p6_support import ws_open as wo

        async with wo("/ws/ops/live/", additional_headers={"Cookie": ops_cookie}, **kw) as ops, \
                wo("/ws/ops/live/", additional_headers={"Cookie": sm_cookie}, **kw) as sm, \
                wo("/ws/ops/live/", additional_headers={"Cookie": ss_cookie}, **kw) as ss:
            await asyncio.sleep(1)
            # A paid ONLINE order: COD can be blocked for A by the P5 DL-61 (d) case.
            await asyncio.to_thread(shop.place_online_paid)
            oid = shop.placed[-1]
            async with wo(opath(oid)) as cust:
                await auth(cust, shop.session.access)
                await recv(cust, 5)  # snapshot
                await asyncio.sleep(3)  # let auto-accept (if any) land first
                await collect(cust, 0.5)
                t0 = time.monotonic()
                r = await asyncio.to_thread(shop.cancel, oid)
                assert r.status_code == 200, describe(r)
                got = None
                while time.monotonic() - t0 < 10:
                    m = await recv(cust, 10 - (time.monotonic() - t0))
                    if m is None:
                        break
                    if m["type"] == "order.status" and m["data"]["status"] == "CANCELLED":
                        got = time.monotonic() - t0
                        break
            await asyncio.sleep(2)
            o, s1, s2 = await asyncio.gather(collect(ops, 1), collect(sm, 1), collect(ss, 1))
            return oid, got, o, s1, s2

    oid, latency, ops_msgs, sm_msgs, ss_msgs = run(go())
    assert latency is not None, "no order.status CANCELLED on the customer socket within 10 s"
    assert latency <= 3.0, f"order.status CANCELLED took {latency:.2f} s (> 3 s)"
    mine = [m for m in ops_msgs if m.get("data", {}).get("order_id") == oid]
    types = {m["type"] for m in mine}
    assert {"order.created", "order.status"} <= types, [m["type"] for m in ops_msgs]
    for m in mine:
        assert_shape(m)
        assert m["data"]["store_id"] == QA02_ID
        keys = CREATED_KEYS if m["type"] == "order.created" else STATUS_KEYS
        assert set(m["data"]) == keys, m["data"]
    leak = [m for m in sm_msgs + ss_msgs if m.get("data", {}).get("store_id") == QA02_ID
            or m.get("data", {}).get("order_id") == oid]
    assert leak == [], f"cross-store leak to GGN-01 staff: {leak}"


def test_p6_tc12_no_otp_on_any_snapshot(a):
    """P6-TC-12 no otp key or OTP value in any order.status snapshot of A's orders (all states)."""
    orders = orders_of(a.access)
    by_status = {}
    for o in orders:
        by_status.setdefault(o["status"], o)

    async def go():
        out = []
        for o in by_status.values():
            async with ws_open(opath(o["id"])) as ws:
                await auth(ws, a.access)
                out.append(await recv(ws, 5))
        return out

    snaps = run(go())
    assert snaps, "no orders"
    for s in snaps:
        blob = json.dumps(s).lower()
        assert "otp" not in blob, s
        assert set(s["data"]) == STATUS_KEYS


def test_p6_tc13_deleted_user_4401():
    """P6-TC-13 a token of a user who deleted the account (spare QA user J, +919000000110, PM-approved
    2026-11-09) is refused with 4401 on the rider socket, where the same user's live account gets
    4403 (no rider profile): the auth step itself rejects the deleted user, nothing is sent."""
    from conftest import request_otp
    from qa_support import TEST_OTP

    j = login(QA_PHONES["j"], app="rider")
    live = login(QA_PHONES["j"], app="rider")
    cust = login(QA_PHONES["j"])

    async def one(token):
        async with ws_open("/ws/v1/rider/") as ws:
            await ws.send(json.dumps({"type": "auth", "token": token}))
            return await until_closed(ws, 4)

    assert run(one(live.access)) == (4403, []), "live non-rider user should be 4403"
    with httpx.Client(base_url=ORIGIN, timeout=60) as c:
        assert request_otp(c, QA_PHONES["j"], purpose="delete_account").status_code == 200
        r = c.post("/api/v1/me/delete/", json={"otp": TEST_OTP, "reason": "QA P6-TC-13"},
                   headers={**APP_HEADERS, **bearer(cust.access)})
    assert r.status_code == 200, describe(r)
    code, msgs = run(one(j.access))
    assert (code, msgs) == (4401, []), (code, msgs)


@T612
def test_p6_tc14_rider_location_to_owner_only():
    """P6-TC-14 (T-612)."""


@T612
def test_p6_tc15_eta_formula_and_throttle():
    """P6-TC-15 (T-612)."""


@T612
def test_p6_tc16_no_location_outside_delivery():
    """P6-TC-16 (T-612)."""


def test_p6_tc18_reconnect_fresh_snapshot(a, a_order):
    """P6-TC-18 close and reconnect: a fresh snapshot each time (state, not diffs)."""

    async def go():
        snaps = []
        for _ in range(3):
            async with ws_open(opath(a_order["id"])) as ws:
                await auth(ws, a.access)
                snaps.append(await recv(ws, 5))
        return snaps

    snaps = run(go())
    assert all(s and s["type"] == "order.status" and s["data"]["order_id"] == a_order["id"] for s in snaps)


# =========================================================================== rider socket


@pytest.mark.smoke
def test_p6_tc19_rider_socket_access():
    """P6-TC-19 R1 rider-app token → auth.ok (if R1 is ACTIVE); R1 customer-app token → 4403;
    E (no rider profile) rider-app token → 4403."""
    r1_rider = login(QA_PHONES["c"], app="rider")
    me = httpx.get(f"{ORIGIN}/api/v1/rider/me/", headers={**RIDER_HEADERS, **bearer(r1_rider.access)})
    r1_customer = login(QA_PHONES["c"])
    e_rider = login(QA_PHONES["e"], app="rider")

    async def one(token):
        async with ws_open("/ws/v1/rider/") as ws:
            await ws.send(json.dumps({"type": "auth", "token": token}))
            return await until_closed(ws, 4)

    async def go():
        return await one(r1_rider.access), await one(r1_customer.access), await one(e_rider.access)

    (c1, m1), (c2, m2), (c3, m3) = run(go())
    if me.status_code == 200 and me.json().get("status") == "ACTIVE":
        assert c1 is None and m1 and m1[0]["type"] == "auth.ok", (c1, m1)
    else:
        assert c1 == 4403, (c1, me.status_code)
    assert (c2, m2) == (4403, []), (c2, m2)
    assert (c3, m3) == (4403, []), (c3, m3)


@pytest.mark.skip(reason="P6-TC-20 needs a spare QA rider and the `wsrecheck` profile (stage 2)")
def test_p6_tc20_suspended_rider_closed_4403():
    """P6-TC-20 placeholder."""


@T612
def test_p6_tc21_offer_new_under_3s():
    """P6-TC-21 (T-612)."""


@T612
def test_p6_tc22_offer_withdrawn_reasons():
    """P6-TC-22 (T-612)."""


@T612
def test_p6_tc23_offer_expired_vs_withdrawn():
    """P6-TC-23 (T-612)."""


@T612
def test_p6_tc24_task_updated_changes():
    """P6-TC-24 (T-612)."""


@T612
def test_p6_tc25_cash_update_event():
    """P6-TC-25 (T-612)."""


@T612
def test_p6_tc26_rider_sockets_scoped():
    """P6-TC-26 (T-612)."""


# =========================================================================== ops live feed


@pytest.mark.smoke
def test_p6_tc27_ops_feed_open_and_ping():
    """P6-TC-27 OPS session + allowed Origin: open without an auth message; ping → pong."""
    _, cookie = staff_cookie(OPS)
    code, msgs = run(ops_close_code(cookie))
    assert code is None, code
    assert msgs and msgs[0]["type"] == "pong", msgs


def test_p6_tc28_ops_feed_refusals():
    """P6-TC-28 no cookie → 4401; forged session → 4401; bad Origin → handshake 403; no Origin →
    handshake refused."""
    _, cookie = staff_cookie(OPS)
    assert run(ops_close_code(None))[0] == 4401
    assert run(ops_close_code("sessionid=qa0forged0session0id0000000000000"))[0] == 4401
    assert run(ops_close_code(cookie, origin="https://evil.example")) == ("refused", 403)
    assert run(ops_close_code(cookie, origin=None))[0] == "refused"


@pytest.mark.smoke
@pytest.mark.parametrize(
    "email,expected",
    [(SUPER, None), (OPS, None), (MANAGER, None), (STAFF, None), (SUPPORT, None), (FINANCE, None),
     (CATALOG, 4403)],
)
def test_p6_tc29_ops_feed_role_matrix(email, expected):
    """P6-TC-29 roles with orders.view_order and a store open the feed; Catalog Manager → 4403."""
    _, cookie = staff_cookie(email)
    code, _ = run(ops_close_code(cookie, wait=3))
    assert code == expected, (email, code)


@pytest.mark.skip(reason="P6-TC-32 needs the `wsrecheck` profile (short WS_OPS_RECHECK_SECONDS), stage 2")
def test_p6_tc32_session_end_closes_feed():
    """P6-TC-32 placeholder."""


@pytest.mark.skip(reason="P6-TC-33 needs a timer profile (SLA/unassigned alerts), stage 2")
def test_p6_tc33_alerts_to_store_feeds():
    """P6-TC-33 placeholder."""


@T612
def test_p6_tc34_rider_status_and_location_to_ops():
    """P6-TC-34 (T-612)."""


# =========================================================================== inbox


INBOX = "/api/v1/me/notifications/"


def inbox(session, app="customer", **params) -> httpx.Response:
    h = {**(RIDER_HEADERS if app == "rider" else APP_HEADERS), **bearer(session.access)}
    return httpx.get(f"{ORIGIN}{INBOX}", headers=h, params=params, timeout=30)


def mark(session, nid, app="customer") -> httpx.Response:
    h = {**(RIDER_HEADERS if app == "rider" else APP_HEADERS), **bearer(session.access)}
    return httpx.post(f"{ORIGIN}{INBOX}{nid}/read/", headers=h, timeout=30)


@pytest.mark.smoke
def test_p6_tc35_inbox_list(a):
    """P6-TC-35 200 page, newest first, schema-valid, customer entries only."""
    r = inbox(a, page_size=100)
    validate_response(r, "me_notifications_list")
    rows = r.json()["results"]
    if not rows:
        pytest.skip("A has no inbox entries yet")
    created = [x["created_at"] for x in rows]
    assert created == sorted(created, reverse=True)
    ids = [x["id"] for x in rows]
    apps = db_query("select distinct app from notifications_notification where id = any(%s)", (ids,))
    assert apps == [("customer",)], apps


@pytest.mark.smoke
def test_p6_tc36_inbox_read_and_idor(a, b):
    """P6-TC-36 own entry read twice → 200 read; B's id, a missing id, and an entry of the same
    user's other app → 404."""
    rows = inbox(a).json()["results"]
    if not rows:
        pytest.skip("A has no inbox entries")
    nid = rows[-1]["id"]
    r1, r2 = mark(a, nid), mark(a, nid)
    validate_response(r1, "me_notifications_read")
    assert r1.json()["read"] is True and r2.json()["read"] is True
    b_rows = inbox(b).json()["results"]
    if b_rows:
        assert_error(mark(a, b_rows[0]["id"]), 404, "NOT_FOUND")
    assert_error(mark(a, 999_999_999), 404, "NOT_FOUND")
    rider_ids = db_query(
        "select n.id from notifications_notification n join accounts_user u on u.id=n.user_id "
        "where u.phone=%s and n.app='rider' and n.in_inbox order by n.id desc limit 1",
        (QA_PHONES["c"],),
    )
    if rider_ids:
        c_customer = login(QA_PHONES["c"])
        assert_error(mark(c_customer, rider_ids[0][0]), 404, "NOT_FOUND")


def test_p6_tc37_read_all(a):
    """P6-TC-37 read-all → {updated: n}; again → {updated: 0}; every entry read."""
    h = {**APP_HEADERS, **bearer(a.access)}
    first = httpx.post(f"{ORIGIN}{INBOX}read-all/", headers=h)
    validate_response(first, "me_notifications_read_all")
    second = httpx.post(f"{ORIGIN}{INBOX}read-all/", headers=h)
    assert second.json() == {"updated": 0}, second.json()
    assert all(x["read"] for x in inbox(a, page_size=100).json()["results"])


@pytest.mark.smoke
def test_p6_tc38_no_otp_in_inbox():
    """P6-TC-38 no OTP in any inbox body (all users, read-only SQL); rider_arrived never in the inbox."""
    leaks = db_query(
        "select count(*) from notifications_notification where in_inbox and body ~ %s", (r"OTP\s*:?\s*[0-9]{4}",)
    )[0][0]
    assert leaks == 0, f"{leaks} inbox bodies contain an OTP"
    arrived = db_query(
        "select count(*) from notifications_notification where event='order.rider_arrived' and in_inbox"
    )[0][0]
    assert arrived == 0


@pytest.mark.parametrize("auth_header", [None, "Bearer not.a.jwt"])
def test_p6_tc39_inbox_needs_auth(auth_header):
    """P6-TC-39 inbox list/read/read-all without or with a bad token → 401 envelope."""
    h = {**APP_HEADERS, **({"Authorization": auth_header} if auth_header else {})}
    for r in (
        httpx.get(f"{ORIGIN}{INBOX}", headers=h),
        httpx.post(f"{ORIGIN}{INBOX}1/read/", headers=h),
        httpx.post(f"{ORIGIN}{INBOX}read-all/", headers=h),
    ):
        assert r.status_code == 401, describe(r)
        assert set(r.json()["error"]) == {"code", "message", "details"}


def test_p6_tc40_page_cap_and_links(a):
    """P6-TC-40 page_size capped at 100; link is jivo://orders/<id>[/detail] or null."""
    r = inbox(a, page_size=1000)
    assert r.status_code == 200
    rows = r.json()["results"]
    assert len(rows) <= 100
    for x in rows:
        assert x["link"] is None or re.fullmatch(r"jivo://orders/\d+(/detail)?", x["link"]), x["link"]


# =========================================================================== notifications


SMS_EVENTS = {"order.placed", "order.items_adjusted", "order.out_for_delivery", "order.cancelled", "refund.processed"}
PUSH_ONLY = {"order.accepted", "order.payment_failed", "order.delivered", "order.delivery_failed", "order.rider_arrived"}


@pytest.mark.smoke
def test_p6_tc41_event_channel_matrix():
    """P6-TC-41 08 §9: SMS only for placed/items_adjusted/out_for_delivery/cancelled/refund;
    push-only events have sms_status NONE; at most one row per (event, user, order)."""
    rows = db_query(
        "select event, sms_status, count(*) from notifications_notification where app='customer' group by 1, 2"
    )
    wrong = [(e, s, n) for e, s, n in rows
             if (e in PUSH_ONLY and s != "NONE") or (e in SMS_EVENTS and s == "NONE")]
    assert wrong == [], wrong
    dupes = db_query(
        "select event, user_id, order_id, count(*) from notifications_notification "
        "where order_id is not null and event <> 'order.items_adjusted' "
        "group by 1, 2, 3 having count(*) > 1 limit 5"
    )
    assert dupes == [], dupes


def test_p6_tc42_no_sms_sent_without_dlt():
    """P6-TC-42 no SMS SENT without a DLT template id."""
    n = db_query(
        "select count(*) from notifications_notification where sms_status='SENT' and coalesce(sms_dlt_template_id,'')=''"
    )[0][0]
    assert n == 0


@pytest.mark.smoke
def test_p6_tc43_no_otp_at_rest():
    """P6-TC-43 no OTP left in push_body / sms_body / body of out-for-delivery rows after sending."""
    n = db_query(
        "select count(*) from notifications_notification where event='order.out_for_delivery' "
        "and push_status <> 'PENDING' and sms_status <> 'PENDING' "
        "and (push_body ~ %s or sms_body ~ %s or body ~ %s)",
        (r"OTP\s*:?\s*[0-9]{4}",) * 3,
    )[0][0]
    assert n == 0, f"{n} rows keep a delivery OTP at rest"


@pytest.mark.skip(reason="P6-TC-44 needs a gateway-fault instance profile; covered by backend unit tests")
def test_p6_tc44_retries():
    """P6-TC-44 placeholder."""


@pytest.mark.skip(reason="P6-TC-45 config review (DevOps/PM), not black-box")
def test_p6_tc45_push_backend_refused_on_staging():
    """P6-TC-45 placeholder."""


def test_p6_tc46_cancel_text_quotes_stored_refund(qa_worker, p5_shop_a):  # noqa: F811
    """P6-TC-46 a paid ONLINE order cancelled by A → the order.cancelled inbox body quotes
    ₹<Refund.amount> of the stored cancel refund."""
    p5_shop_a.place_online_paid()
    oid = p5_shop_a.placed[-1]
    r = p5_shop_a.cancel(oid)
    assert r.status_code == 200, describe(r)
    end, entry = time.monotonic() + 30, None
    while time.monotonic() < end and entry is None:
        rows = inbox(p5_shop_a.session, page_size=20).json()["results"]
        entry = next((x for x in rows if x["link"] == f"jivo://orders/{oid}/detail"
                      and x["title"] == "Order cancelled"), None)
        time.sleep(1)
    assert entry, "no order.cancelled inbox entry within 30 s"
    refund = db_query(
        "select amount from payments_refund where order_id=%s and idempotency_key like %s order by id desc limit 1",
        (oid, f"cancel:{oid}%"),
    )
    assert refund, "no cancel refund row"
    amount = f"{refund[0][0]:,.2f}"
    assert f"₹{amount}" in entry["body"], entry["body"]


# =========================================================================== purge


def test_p6_tc47_purge_jobs_scheduled():
    """P6-TC-47 purge and sweep jobs in the beat schedule (read-only)."""
    rows = dict(db_query(
        "select task, coalesce(i.every::text || ' ' || i.period, c.minute || ' ' || c.hour) "
        "from django_celery_beat_periodictask p "
        "left join django_celery_beat_intervalschedule i on i.id=p.interval_id "
        "left join django_celery_beat_crontabschedule c on c.id=p.crontab_id "
        "where p.enabled and task in ('realtime.purge_old_locations', "
        "'notifications.purge_old_notifications', 'notifications.sweep_stuck_sends')"
    ))
    missing = {"realtime.purge_old_locations", "notifications.purge_old_notifications",
               "notifications.sweep_stuck_sends"} - set(rows)
    assert not missing, f"not in the beat schedule DB (beat may not have run since T-611): {missing}; have {rows}"


def test_p6_tc48_retention_informational():
    """P6-TC-48 no notification older than 90 days and no rider location older than 30 days."""
    old_n = db_query("select count(*) from notifications_notification where created_at < now() - interval '90 days'")[0][0]
    old_l = db_query("select count(*) from delivery_riderlocation where recorded_at < now() - interval '31 days'")[0][0]
    assert (old_n, old_l) == (0, 0), (old_n, old_l)


# =========================================================================== abuse limits


@pytest.mark.smoke
def test_p6_tc49_max_sockets_per_user(a, a_order):
    """P6-TC-49 the 6th authorised socket of one user → 4429; after a close, a new one is accepted."""
    clear_socket_slots()

    async def go():
        from websockets.asyncio.client import connect

        from p6_support import WS_BASE

        url = WS_BASE + opath(a_order["id"])
        socks = []
        try:
            for _ in range(5):
                ws = await connect(url, open_timeout=10)
                socks.append(ws)
                ok = await auth(ws, a.access)
                assert ok["type"] == "auth.ok", ok
                await recv(ws, 5)
            sixth = await connect(url, open_timeout=10)
            socks.append(sixth)
            await sixth.send(json.dumps({"type": "auth", "token": a.access}))
            code6, _ = await until_closed(sixth, 6)
            await socks[0].close()
            await asyncio.sleep(1)
            again = await connect(url, open_timeout=10)
            socks.append(again)
            ok_again = await auth(again, a.access)
            return code6, ok_again
        finally:
            for ws in socks:
                await ws.close()

    code6, ok_again = run(go())
    assert code6 == 4429, code6
    assert ok_again and ok_again["type"] == "auth.ok", ok_again


@pytest.mark.xfail(strict=True, reason="BUG-0020: 1011 instead of 1009 on daphne")
@pytest.mark.parametrize("when", ["before_auth", "after_auth"])
def test_p6_tc50_message_over_4096_bytes_1009(a, a_order, when):
    """P6-TC-50 a 5,000-byte message → closed 1009, before and after auth."""

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            if when == "after_auth":
                await auth(ws, a.access)
                await recv(ws, 5)
            await ws.send(json.dumps({"type": "ping", "pad": "x" * 5000}))
            return await until_closed(ws, 6)

    code, _ = run(go())
    assert code == 1009, code


def test_p6_tc51_too_many_bad_messages_4400(a, a_order):
    """P6-TC-51 10 malformed/unknown messages get an error each; the 11th closes 4400."""

    async def go():
        async with ws_open(opath(a_order["id"])) as ws:
            await auth(ws, a.access)
            await recv(ws, 5)
            errors = 0
            for i in range(10):
                await ws.send("nope" if i % 2 else json.dumps({"type": "zzz"}))
                m = await recv(ws, 5)
                errors += bool(m and m["type"] == "error")
            await ws.send(json.dumps({"type": "zzz"}))
            code, _ = await until_closed(ws, 6)
            return errors, code

    errors, code = run(go())
    assert errors == 10 and code == 4400, (errors, code)


def test_p6_tc52_malformed_frames_never_crash(a, a_order):
    """P6-TC-52 binary, invalid JSON, deep nesting, huge numbers, unicode: no crash; a second open
    socket keeps working; /health/live 200."""
    payloads = [b"\x00\xff\xfe", "{", "[" * 1000 + "]" * 1000, '{"type": 1e999999}',
                '{"type": "ping", "x": 123456789012345678901234567890}', '{"type": "‮😀"}',
                '{"type": null}', '{"type": ["auth"]}', '{"type": {"a": 1}}']

    async def go():
        async with ws_open(opath(a_order["id"])) as keep:
            await auth(keep, a.access)
            await recv(keep, 5)
            for p in payloads:
                async with ws_open(opath(a_order["id"])) as ws:
                    await auth(ws, a.access)
                    await recv(ws, 5)
                    await ws.send(p)
                    await collect(ws, 1)
            await keep.send(json.dumps({"type": "ping"}))
            return await recv(keep, 5)

    pong = run(go())
    assert pong and pong["type"] == "pong", pong
    assert httpx.get(f"{ORIGIN}/health/live").status_code == 200


def test_p6_tc53_no_leaked_slots(a, a_order):
    """P6-TC-53 20 connect/auth/close cycles (≤ 5 open at once), then 5 fresh sockets authorise."""
    clear_socket_slots()

    async def cycle():
        async with ws_open(opath(a_order["id"])) as ws:
            await auth(ws, a.access)

    async def go():
        for _ in range(4):
            await asyncio.gather(*(cycle() for _ in range(5)))
        await asyncio.sleep(1)
        from websockets.asyncio.client import connect

        from p6_support import WS_BASE

        socks, oks = [], []
        try:
            for _ in range(5):
                ws = await connect(WS_BASE + opath(a_order["id"]), open_timeout=10)
                socks.append(ws)
                oks.append((await auth(ws, a.access) or {}).get("type"))
        finally:
            for ws in socks:
                await ws.close()
        return oks

    assert run(go()) == ["auth.ok"] * 5


@pytest.mark.skip(reason="P6-TC-54 ASGI frame cap is a DevOps config review")
def test_p6_tc54_asgi_frame_cap():
    """P6-TC-54 placeholder."""


# =========================================================================== cross-cutting


@pytest.mark.smoke
def test_p6_tc55_no_jwt_in_instance_log():
    """P6-TC-55 the QA instance log contains no JWT (tokens were sent in messages, subprotocols
    and, deliberately, one URL query in TC-02)."""
    logs = sorted((QA_DIR / "private" / "logs").glob("instance-*-p5.log"))
    if not logs:
        pytest.skip("no QA instance log")
    # TC-02 deliberately puts a token in a URL query (a client mistake); those lines are excluded.
    text = "\n".join(ln for ln in Path(logs[-1]).read_text(encoding="utf-8", errors="replace").splitlines()
                     if "?token=" not in ln)
    hits = re.findall(r"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}", text)
    assert not hits, f"{len(hits)} JWT(s) in {logs[-1].name} (first: {hits[0][:4]}...{hits[0][-4:]})"


def test_p6_tc56_ws_message_components():
    """P6-TC-56 a Ws…Message component per 06 §4.2 message type."""
    comps = set(openapi()["components"]["schemas"])
    ws = {c for c in comps if c.startswith("Ws") and c.endswith("Message")}
    expected_types = {"order.status", "order.eta", "order.created", "rider.location", "rider.status", "offer.new",
                      "offer.withdrawn", "task.updated", "alert", "auth.ok", "pong", "error"}
    assert len(ws) >= len(expected_types), sorted(ws)


_ = (InvalidStatus,)  # imported for readers: handshake refusals surface as InvalidStatus
