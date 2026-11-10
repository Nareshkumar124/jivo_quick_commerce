"""Phase 6 T-612 black-box (merged in develop d29ed94): rider location fan-out and the tracking
gate, order.eta (08 §8) and its throttle, rider socket offer/task/cash events, socket scoping,
ops rider.status / rider.location / task.status, notification.new + unread count.

Cases P6-TC-14/15/16, 21-26, 34 and P6-TC-58/59 (`02-test-case-repository.md`, Phase 6). The
stubs of the same IDs in `test_p6_ws.py` stay skipped and point here. Sockets are read by a
background thread (`Listener`) so the REST steps can run in between. QA instance :8004 only.
"""

from __future__ import annotations

import json
import math
import threading
import time
from datetime import datetime

import httpx
import pytest
from websockets.exceptions import ConnectionClosed
from websockets.sync.client import connect

from conftest import login
from p4_support import MANAGER, OPS, SUPER
from p5_support import (  # noqa: F401 (fixtures)
    DROP, QA02, QA02_ID, R1_PHONE, bring_to, distance_m, offset, p5_shop_a, p5_shop_b, pack, pickup_code,
    qa_worker, r1, r2, rider_id_of, rider_op,
)
from p6_support import ORIGIN, WS_BASE, clear_socket_slots, staff_cookie
from qa_support import APP_HEADERS, QA_PHONES, bearer, clear_throttle, describe

pytestmark = pytest.mark.usefixtures("_slots612")


@pytest.fixture(scope="module")
def _slots612():
    clear_socket_slots()
    yield
    clear_socket_slots()


class Listener:
    """A socket read on a thread; `msgs` = [(monotonic, message)]."""

    def __init__(self, path: str, token: str | None = None, cookie: str | None = None):
        kw = {"open_timeout": 10, "close_timeout": 3}
        if cookie:
            kw["additional_headers"] = {"Cookie": cookie}
            kw["origin"] = ORIGIN
        self.ws = connect(WS_BASE + path, **kw)
        self.msgs: list[tuple[float, dict]] = []
        self.closed: int | None = None
        if token:
            self.ws.send(json.dumps({"type": "auth", "token": token}))
        self._stop = False
        self.t = threading.Thread(target=self._run, daemon=True)
        self.t.start()

    def _run(self):
        while not self._stop:
            try:
                raw = self.ws.recv(timeout=0.5)
            except TimeoutError:
                continue
            except ConnectionClosed as exc:
                self.closed = exc.rcvd.code if exc.rcvd else None
                return
            self.msgs.append((time.monotonic(), json.loads(raw)))

    def of(self, typ: str, since: float = 0.0, **match) -> list[dict]:
        return [m for t, m in self.msgs if t >= since and m.get("type") == typ
                and all(m.get("data", {}).get(k) == v for k, v in match.items())]

    def wait(self, typ: str, timeout: float = 10, since: float = 0.0, **match) -> tuple[float, dict] | None:
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            for t, m in list(self.msgs):
                if t >= since and m.get("type") == typ and all(m.get("data", {}).get(k) == v for k, v in match.items()):
                    return t, m
            time.sleep(0.1)
        return None

    def close(self):
        self._stop = True
        try:
            self.ws.close()
        except Exception:
            pass
        self.t.join(3)


def ping_at(rider, point, heading: float = 45.0):
    clear_throttle("rider_locations")
    r = rider.ping(point, heading=heading)
    assert r.status_code == 200, describe(r)


def eta_oracle(point) -> int:
    km = distance_m(point, DROP) / 1000
    return max(1, math.ceil(km * 1.3 / 20 * 60 + 2))


# =========================================================================== customer: location / ETA


@pytest.mark.smoke
def test_p6_tc14_tc15_tc16_location_gate_eta_and_scope(r1, p5_shop_a, p5_shop_b):
    """P6-TC-14 🔥 rider.location (exact keys) reaches the owner's order socket only (B's socket on B's
    order gets nothing); P6-TC-16 none while the task is only OFFERED and none after DELIVERED
    (06 §4.2 tracking gate = ASSIGNED..AT_CUSTOMER); P6-TC-15 order.eta while OUT_FOR_DELIVERY
    = ceil(km × 1.3 / 20 × 60 + 2) from the ping, at most one per 30 s from pings."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    oid = ctx["order_id"]
    a_ws = Listener(f"/ws/v1/orders/{oid}/", p5_shop_a.session.access)
    b_ws = None
    try:
        assert a_ws.wait("auth.ok", 5)
        t0 = time.monotonic()
        ping_at(r1, offset(QA02, north_m=25))  # OFFERED: gate closed
        time.sleep(2)
        assert a_ws.of("rider.location", t0) == [], "rider.location before the task is ASSIGNED"
        assert r1.accept(ctx["offer"]["id"]).status_code == 200
        # B's order only now (stage 3): placed earlier, its task could take R1's only offer slot first.
        b_order = p5_shop_b.place_cod()
        b_ws = Listener(f"/ws/v1/orders/{b_order['id']}/", p5_shop_b.session.access)
        assert b_ws.wait("auth.ok", 5)
        t1 = time.monotonic()
        pt = offset(QA02, north_m=40)
        ping_at(r1, pt, heading=72.5)
        got = a_ws.wait("rider.location", 8, t1)
        assert got, "no rider.location for an ASSIGNED task"
        data = got[1]["data"]
        assert set(data) == {"order_id", "lat", "lng", "heading", "recorded_at"}, data
        assert data["order_id"] == oid and abs(data["lat"] - pt[0]) < 1e-6
        heading_dropped = data["heading"] != 72.5  # BUG-0022: checked last so the rest still runs
        # pickup → OUT_FOR_DELIVERY
        assert r1.arrived_store(ctx["task_id"]).status_code == 200
        pack(oid)
        assert r1.pickup(ctx["task_id"], pickup_code(oid)).status_code == 200
        time.sleep(31)  # let the 30 s ETA throttle lapse after the status-change ETAs
        t2 = time.monotonic()
        mid = offset(DROP, north_m=900)
        ping_at(r1, mid)
        eta = a_ws.wait("order.eta", 8, t2)
        assert eta, "no order.eta from a ping while OUT_FOR_DELIVERY"
        assert set(eta[1]["data"]) == {"order_id", "eta_at", "eta_minutes"}
        assert eta[1]["data"]["eta_minutes"] == eta_oracle(mid), (eta[1]["data"], eta_oracle(mid))
        t3 = time.monotonic()
        ping_at(r1, offset(DROP, north_m=600))
        ping_at(r1, offset(DROP, north_m=300))
        time.sleep(3)
        assert len(a_ws.of("rider.location", t3)) >= 1
        assert a_ws.of("order.eta", t3) == [], "order.eta from pings more often than every 30 s"
        track = httpx.get(f"{ORIGIN}/api/v1/orders/{oid}/track/", headers=p5_shop_a.h, timeout=30).json()
        assert track.get("live_eta_minutes") is not None, track.keys()
        # deliver → gate closes
        assert r1.arrived_customer(ctx["task_id"]).status_code == 200
        otp = track["delivery_otp"]
        due = r1.task().json()["task"]["cod_amount_due"]
        assert r1.deliver(ctx["task_id"], otp, {"mode": "cash", "amount": due}).status_code == 200
        time.sleep(1)
        t4 = time.monotonic()
        ping_at(r1, offset(DROP, north_m=10))
        time.sleep(3)
        assert a_ws.of("rider.location", t4) == [], "rider.location after DELIVERED"
        # B's own order has no rider: any rider.location is a leak; order.eta only when it is A's
        # (B's own order legitimately gets ETAs; stage 3 oracle fix).
        leak = [m for _, m in b_ws.msgs if m.get("data", {}).get("order_id") == oid
                or m.get("type") == "rider.location"]
        assert leak == [], f"B's socket got A's live data: {leak[:2]}"
        for _, m in a_ws.msgs:
            assert "delivery_otp" not in json.dumps(m) and otp not in json.dumps(m.get("data", {}).get("body", "")), m
        if heading_dropped:
            pytest.xfail(f"BUG-0022: rider.location heading {data['heading']!r}, the ping sent 72.5")
    finally:
        a_ws.close()
        if b_ws is not None:
            b_ws.close()


@pytest.mark.smoke
def test_p6_tc58_notification_new_and_unread_count(r1, p5_shop_a):
    """P6-TC-58 🔥 a new inbox entry reaches the open order socket as notification.new with
    unread_count = GET /me/notifications/unread-count/ at that moment; link jivo://orders/<id>."""
    r1.online_at()
    order = p5_shop_a.place_cod()
    oid = order["id"]
    ws = Listener(f"/ws/v1/orders/{oid}/", p5_shop_a.session.access)
    try:
        assert ws.wait("auth.ok", 5)
        got = ws.wait("notification.new", 30)
        assert got, "no notification.new on the order socket (accepted / offer flow)"
        d = got[1]["data"]
        assert set(d) >= {"id", "title", "body", "category", "link", "read", "created_at", "unread_count"}, d
        assert d["link"] in (f"jivo://orders/{oid}", None) and d["read"] is False
        r = httpx.get(f"{ORIGIN}/api/v1/me/notifications/unread-count/", headers={**APP_HEADERS,
                      **bearer(p5_shop_a.session.access)}, timeout=30)
        assert r.status_code == 200 and r.json()["unread"] >= d["unread_count"] >= 1, (r.text, d)
        rr = httpx.get(f"{ORIGIN}/api/v1/me/notifications/unread-count/",
                       headers={**APP_HEADERS, "X-App-Name": "rider", **bearer(r1.session.access)}, timeout=30)
        assert rr.status_code == 200 and isinstance(rr.json()["unread"], int)
    finally:
        ws.close()


# =========================================================================== rider socket


@pytest.mark.smoke
def test_p6_tc21_tc26_tc22_offer_new_scoped_then_cancel_withdrawn(r1, r2, p5_shop_a):
    """P6-TC-21 🔥 offer.new on R1's socket ≤ 3 s after offered_at, data == GET /rider/offers/current/;
    P6-TC-26 🔥 R2 (online elsewhere / not offered) receives nothing about it;
    P6-TC-22 the customer cancels → offer.withdrawn reason ORDER_CANCELLED."""
    s1 = Listener("/ws/v1/rider/", r1.session.access)
    s2 = Listener("/ws/v1/rider/", r2.session.access)
    try:
        assert s1.wait("auth.ok", 5) and s2.wait("auth.ok", 5)
        r1.online_at()
        ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
        got = s1.wait("offer.new", 10, task_id=ctx["task_id"])
        assert got, "no offer.new on the rider socket"
        rest = r1.offer().json()["offer"]
        assert got[1]["data"] == rest, (got[1]["data"], rest)
        offered = datetime.fromisoformat(rest["offered_at"].replace("Z", "+00:00")).timestamp()
        recv_wall = time.time() - (time.monotonic() - got[0])
        assert recv_wall - offered <= 3.0, f"offer.new {recv_wall - offered:.2f} s after offered_at"
        assert p5_shop_a.cancel(ctx["order_id"]).status_code == 200
        w = s1.wait("offer.withdrawn", 10, task_id=ctx["task_id"])
        assert w and w[1]["data"]["reason"] == "ORDER_CANCELLED" and w[1]["data"]["offer_id"] == rest["id"], w
        time.sleep(1)
        leak = [m for _, m in s2.msgs if m.get("data", {}).get("task_id") == ctx["task_id"]]
        assert leak == [], f"R2 got R1's offer events: {leak}"
    finally:
        s1.close()
        s2.close()


def test_p6_tc23_offer_timeout_is_offer_expired(r1, p5_shop_a):
    """P6-TC-23 an offer that times out → offer.expired {offer_id, task_id, reason EXPIRED} (06 §4.2)."""
    s1 = Listener("/ws/v1/rider/", r1.session.access)
    try:
        assert s1.wait("auth.ok", 5)
        r1.online_at()
        ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
        # Stage 3: expire_offer() before expires_at is a no-op ("not_due"), so wait the 30 s offer
        # timeout out; the countdown task may expire it first ("skipped"), which is equally valid.
        due = datetime.fromisoformat(ctx["offer"]["expires_at"].replace("Z", "+00:00"))
        time.sleep(max(0.0, (due - datetime.now(due.tzinfo)).total_seconds()) + 1)
        out = rider_op(op="expire_offer", **{"as": SUPER}, offer_id=ctx["offer"]["id"])
        assert out["ok"] and out["result"]["outcome"] in ("expired", "skipped"), out
        got = s1.wait("offer.expired", 10, offer_id=ctx["offer"]["id"])
        assert got and got[1]["data"] == {"offer_id": ctx["offer"]["id"], "task_id": ctx["task_id"],
                                          "reason": "EXPIRED"}, got
        assert s1.of("offer.withdrawn", offer_id=ctx["offer"]["id"]) == []
    finally:
        s1.close()


def test_p6_tc24_task_updated_order_packed(r1, p5_shop_a):
    """P6-TC-24 an assigned task's order is packed → task.updated change ORDER_PACKED, keys
    {task_id, order_id, status, order_status, change}; REST task agrees."""
    s1 = Listener("/ws/v1/rider/", r1.session.access)
    try:
        assert s1.wait("auth.ok", 5)
        r1.online_at()
        ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
        t0 = time.monotonic()
        pack(ctx["order_id"])
        got = s1.wait("task.updated", 10, t0, change="ORDER_PACKED")
        assert got, f"no task.updated ORDER_PACKED: {[m['type'] for _, m in s1.msgs]}"
        d = got[1]["data"]
        assert set(d) == {"task_id", "order_id", "status", "order_status", "change"}, d
        assert d["order_status"] == "PACKED" and d["task_id"] == ctx["task_id"]
        assert r1.task().json()["task"]["status"] == d["status"]
    finally:
        s1.close()


def test_p6_tc25_cash_updated_on_collection_and_deposit(r1, p5_shop_a):
    """P6-TC-25 COD collected → cash.updated reason COD_COLLECTED; ops deposit → cash.updated reason
    DEPOSIT; cash_in_hand equals GET /rider/me cash."""
    s1 = Listener("/ws/v1/rider/", r1.session.access)
    try:
        assert s1.wait("auth.ok", 5)
        r1.online_at()
        ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
        due = r1.task().json()["task"]["cod_amount_due"]
        t0 = time.monotonic()
        assert r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": due}).status_code == 200
        c1 = s1.wait("cash.updated", 10, t0, reason="COD_COLLECTED")
        assert c1, f"no cash.updated COD_COLLECTED: {[m['type'] for _, m in s1.msgs]}"
        cash = r1.me().json()["cash"]
        assert c1[1]["data"]["cash_in_hand"] == cash["cash_in_hand"], (c1[1]["data"], cash)
        t1 = time.monotonic()
        out = rider_op(op="record_deposit", **{"as": OPS}, phone=R1_PHONE, amount=due,
                       key=f"qa-p6-tc25-{ctx['order_id']}")
        assert out["ok"], out
        c2 = s1.wait("cash.updated", 10, t1, reason="DEPOSIT")
        assert c2, "no cash.updated DEPOSIT"
        assert c2[1]["data"]["cash_in_hand"] == r1.me().json()["cash"]["cash_in_hand"]
        assert set(c2[1]["data"]) >= {"rider_id", "cash_in_hand", "cash_limit", "limit_reached", "deposit_required",
                                      "reason", "updated_at"}
    finally:
        s1.close()


# =========================================================================== ops feed


def test_p6_tc34_rider_status_location_task_status_to_store_feeds(r1, p5_shop_a):
    """P6-TC-34 rider.status (online), task.status and rider.location of a QA-02 rider reach OPS's
    feed with store_id QA-02; the GGN-01 Store Manager's feed gets none of them."""
    _, ops_cookie = staff_cookie(OPS)
    _, sm_cookie = staff_cookie(MANAGER)
    ops = Listener("/ws/ops/live/", cookie=ops_cookie)
    sm = Listener("/ws/ops/live/", cookie=sm_cookie)
    rid = rider_id_of(R1_PHONE)
    try:
        time.sleep(1)
        t0 = time.monotonic()
        r1.online_at()
        st = ops.wait("rider.status", 10, t0, rider_id=rid)
        assert st and st[1]["data"]["store_id"] == QA02_ID and st[1]["data"]["is_online"] is True, st
        ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
        ts = ops.wait("task.status", 10, t0, task_id=ctx["task_id"], status="ASSIGNED")
        assert ts and ts[1]["data"]["rider_id"] == rid and ts[1]["data"]["store_id"] == QA02_ID, ts
        t1 = time.monotonic()
        ping_at(r1, offset(QA02, north_m=50))
        loc = ops.wait("rider.location", 10, t1, rider_id=rid)
        assert loc and loc[1]["data"]["store_id"] == QA02_ID, loc
        time.sleep(1)
        leak = [m for _, m in sm.msgs if m.get("data", {}).get("store_id") == QA02_ID
                or m.get("data", {}).get("rider_id") == rid]
        assert leak == [], f"GGN-01 manager got QA-02 rider data: {leak[:2]}"
        for _, m in ops.msgs:
            blob = json.dumps(m)
            assert QA_PHONES["a"] not in blob and "QA Flat 5" not in blob
    finally:
        ops.close()
        sm.close()


# =========================================================================== polling fallback parity


@pytest.mark.smoke
def test_p6_tc59_polling_fallback_matches_socket(r1, p5_shop_a):
    """P6-TC-59 🔥 06 §4.1 fallback: the REST endpoints the apps poll when the socket drops carry the
    same state the sockets pushed. While OUT_FOR_DELIVERY: `track` status / task_status = the last
    `order.status`; `track.rider` lat/lng = the last `rider.location`; `live_eta_minutes` = the
    last `order.eta`. The rider's `GET /rider/tasks/current/` status = the last `task.updated`.
    With both sockets closed, the delivery still shows up on REST only (DELIVERED, rider gone)."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    oid, tid = ctx["order_id"], ctx["task_id"]
    a_ws = Listener(f"/ws/v1/orders/{oid}/", p5_shop_a.session.access)
    r_ws = Listener("/ws/v1/rider/", r1.session.access)
    track_url = f"{ORIGIN}/api/v1/orders/{oid}/track/"
    try:
        assert a_ws.wait("auth.ok", 5) and r_ws.wait("auth.ok", 5)
        assert r1.arrived_store(tid).status_code == 200
        pack(oid)
        assert r1.pickup(tid, pickup_code(oid)).status_code == 200
        ofd_pushed = bool(a_ws.wait("order.status", 10, status="OUT_FOR_DELIVERY"))  # BUG-0021, checked last
        time.sleep(31)  # ETA throttle (30 s) after the status-change ETA
        t1 = time.monotonic()
        pt = offset(DROP, north_m=800)
        ping_at(r1, pt, heading=10.0)
        assert a_ws.wait("rider.location", 8, t1) and a_ws.wait("order.eta", 8, t1), "no live data from the ping"
        time.sleep(1)
        last = {typ: a_ws.of(typ)[-1]["data"] for typ in ("order.status", "rider.location", "order.eta")}
        track = httpx.get(track_url, headers=p5_shop_a.h, timeout=30)
        assert track.status_code == 200, describe(track)
        tr = track.json()
        assert tr["status"] == "OUT_FOR_DELIVERY", tr["status"]
        assert not ofd_pushed or last["order.status"]["status"] == "OUT_FOR_DELIVERY", last["order.status"]
        assert tr["task_status"] == "PICKED_UP", tr["task_status"]
        assert abs(tr["rider"]["lat"] - last["rider.location"]["lat"]) < 1e-6
        assert abs(tr["rider"]["lng"] - last["rider.location"]["lng"]) < 1e-6
        assert tr["live_eta_minutes"] == last["order.eta"]["eta_minutes"], (tr["live_eta_minutes"], last["order.eta"])
        upd = r_ws.of("task.updated")
        rest_task = r1.task().json()["task"]
        assert upd, "no task.updated on the rider socket"
        assert rest_task["id"] == tid and rest_task["status"] == "PICKED_UP", rest_task.get("status")
        assert upd[-1]["data"].get("task_id", tid) == tid
        # 06 §4.2: task.updated covers changes the rider did not make (ORDER_PACKED, ...); the rider's
        # own pickup is not pushed, so the last one may predate PICKED_UP (stage 3 oracle fix).
        allowed = {"ORDER_PACKED", "ORDER_CANCELLED", "AMOUNT_CHANGED", "REASSIGNED", "ASSIGNED", "STATUS_CHANGED"}
        assert all(m["data"].get("change") in allowed for m in upd), [m["data"] for m in upd]
        otp = tr["delivery_otp"]
    finally:
        a_ws.close()
        r_ws.close()
    # sockets closed (app offline / socket dropped): the apps poll REST
    assert r1.arrived_customer(tid).status_code == 200
    due = r1.task().json()["task"]["cod_amount_due"]
    assert r1.deliver(tid, otp, {"mode": "cash", "amount": due}).status_code == 200
    tr = httpx.get(track_url, headers=p5_shop_a.h, timeout=30).json()
    assert tr["status"] == "DELIVERED" and tr["delivery_otp"] is None and tr["live_eta_minutes"] is None, tr
    assert tr["rider"] is None or tr["rider"].get("phone") is None, tr["rider"]
    assert r1.task().json()["task"] is None
    if not ofd_pushed:
        pytest.xfail("BUG-0021: T9 pickup sends no order.status OUT_FOR_DELIVERY on the order socket")
