"""Phase 5/6 timer-profile cases, QA stage 4 (2026-11-10, develop f8db671).

- `s4timers` (tools/instance.sh): OFFER_TIMEOUT 10 s, DISPATCH_TIMEOUT 60 s, UNASSIGNED pause 15 s,
  retry 5 s, AUTO_ACCEPT_DELAY 40 s, STORE_ACCEPTANCE_SLA 20 s: P5-TC-38 (1), P5-TC-47, P5-TC-57 (a),
  P6-TC-33 (acceptance SLA and DISPATCH_UNASSIGNED alerts).
- `triggerplaced` with QA_EXTRA_ENV="AUTO_ACCEPT_DELAY_SECONDS=40": P5-TC-38 (2).
The QA worker must run with the same timers (QA_EXTRA_ENV). QA-02 / QA numbers only; :8004 only.
"""

from __future__ import annotations

import time

import pytest

from p3_admin import csrf, staff_login
from p4_support import MANAGER, OPS
from p5_support import (  # noqa: F401 (fixtures)
    QA02_ID, R1_PHONE, offers_of, p5_shop_a, qa_worker, r1, r2, rider_id_of, task_row, wait_order_status,
)
from p6_support import staff_cookie
from qa_support import db_query
from test_p6_t612 import Listener

pytestmark = pytest.mark.p5_53


def order_status(oid: int) -> str:
    return db_query("select status from orders_order where id=%s", (oid,))[0][0]


def feeds():
    _, ops_cookie = staff_cookie(OPS)
    _, sm_cookie = staff_cookie(MANAGER)
    return Listener("/ws/ops/live/", cookie=ops_cookie), Listener("/ws/ops/live/", cookie=sm_cookie)


def wait_task(oid: int, statuses: set[str], timeout: float) -> dict | None:
    end = time.monotonic() + timeout
    row = None
    while time.monotonic() < end:
        row = task_row(oid)
        if row and row["status"] in statuses:
            return row
        time.sleep(1)
    return row


@pytest.mark.profile_s4timers
def test_p5_tc38a_no_task_while_placed_and_p6_tc33_sla_alert(r1, p5_shop_a):
    """P5-TC-38 (1) DISPATCH_TRIGGER=ACCEPTED (default): a COD order held PLACED by the 40 s auto-accept
    delay has no task; the task and R1's offer come only after ACCEPTED.
    P6-TC-33 (acceptance SLA, 20 s): ACCEPTANCE_SLA_BREACHED `alert` with the order id reaches the QA-02
    ops feed (OPS) and never the GGN-01 Store Manager's feed."""
    r1.online_at()
    ops_ws, sm_ws = feeds()
    try:
        time.sleep(1)
        t0 = time.monotonic()
        order = p5_shop_a.place_cod()
        oid = order["id"]
        alert = ops_ws.wait("alert", 35, t0, order_id=oid)
        assert alert and alert[1]["data"]["code"] == "ACCEPTANCE_SLA_BREACHED", [m for _, m in ops_ws.msgs][-5:]
        assert alert[1]["data"].get("store_id") == QA02_ID, alert[1]["data"]
        assert order_status(oid) == "PLACED"
        assert task_row(oid) is None, "a task exists while the order is PLACED (trigger ACCEPTED)"
        wait_order_status(oid, "ACCEPTED", timeout=60)
        row = wait_task(oid, {"OFFERED", "SEARCHING"}, 20)
        assert row, "no task after ACCEPTED"
        offer = r1.wait_offer(25, task_id=row["id"])
        assert offer["task_id"] == row["id"]
        time.sleep(1)
        leak = [m for _, m in sm_ws.msgs if m.get("data", {}).get("order_id") == oid]
        assert leak == [], f"GGN-01 manager feed got QA-02 order data: {leak[:2]}"
    finally:
        ops_ws.close()
        sm_ws.close()


@pytest.mark.profile_s4timers
def test_p5_tc47_give_up_pause_and_tc57a_console_retry(r1, p5_shop_a):
    """P5-TC-47 only R1 online; R1 lets the offer expire (10 s). R1 is not offered the same task again;
    at DISPATCH_TIMEOUT (60 s) or MAX_OFFER_ATTEMPTS the task is UNASSIGNED with `unassigned_at` and a
    DISPATCH_UNASSIGNED alert reaches the QA-02 feed (not GGN-01); after the 15 s pause a new round
    starts (SEARCHING / OFFERED); whether R1 is offered again is recorded (A15).
    P5-TC-57 (a) on UNASSIGNED, OPS presses Retry in the console (POST + CSRF): SEARCHING, a new round,
    audit `delivery.retry_dispatch` by OPS."""
    import threading

    from p5_support import QA02, offset
    from qa_support import clear_throttle

    r1.online_at()
    ops_ws, sm_ws = feeds()
    rid = rider_id_of(R1_PHONE)
    stop = threading.Event()

    def keep_fresh():  # R1 stays a candidate (ping < DISPATCH_PING_MAX_AGE_SECONDS) but never answers
        while not stop.wait(30):
            clear_throttle("rider_locations")
            r1.ping(offset(QA02, north_m=22))

    pinger = threading.Thread(target=keep_fresh, daemon=True)
    pinger.start()
    try:
        order = p5_shop_a.place_cod()
        oid = order["id"]
        wait_order_status(oid, "ACCEPTED", timeout=70)
        row = wait_task(oid, {"OFFERED"}, 30)
        assert row and row["status"] == "OFFERED", row
        tid = row["id"]
        first = r1.wait_offer(15, task_id=tid)
        # R1 does not answer. Watch until UNASSIGNED (dispatch timeout 60 s from the first search).
        t_un = wait_task(oid, {"UNASSIGNED"}, 100)
        assert t_un and t_un["status"] == "UNASSIGNED", t_un
        offers = offers_of(tid)
        r1_offers = [o for o in offers if o[1] == rid]
        assert r1_offers and all(o[2] in ("EXPIRED",) for o in r1_offers), offers
        assert len(r1_offers) == 1, f"R1 re-offered the same task in round 1: {offers}"
        assert db_query("select unassigned_at is not null from delivery_deliverytask where id=%s", (tid,))[0][0]
        alert = ops_ws.wait("alert", 15, 0.0, order_id=oid, code="DISPATCH_UNASSIGNED")
        assert alert and alert[1]["data"].get("store_id") == QA02_ID, [m for _, m in ops_ws.msgs][-5:]
        # after the 15 s pause: a new round
        nxt = wait_task(oid, {"SEARCHING", "OFFERED"}, 40)
        assert nxt and nxt["status"] in ("SEARCHING", "OFFERED"), nxt
        time.sleep(12)
        round2 = [o for o in offers_of(tid) if o[1] == rid and o[0] != first["id"]]
        print(f"TC-47 A15: R1 re-offered in round 2: {bool(round2)} ({round2})")
        # DL-61 (e): re-dispatch excludes only riders offered in the current round, so the fresh
        # (still silent) R1 is offered again in the new round
        assert round2, "DL-61 (e): R1 (fresh location) not offered again in the new round"
        # P5-TC-57 (a): back to UNASSIGNED, then OPS retries in the console
        t_un2 = wait_task(oid, {"UNASSIGNED"}, 100)
        assert t_un2 and t_un2["status"] == "UNASSIGNED", t_un2
        audit_from = db_query("select coalesce(max(id),0) from core_auditlog")[0][0]
        ops = staff_login(OPS)
        try:
            path = f"/ops/dispatch/tasks/{tid}/"
            token = csrf(ops, path)
            r = ops.post(f"{path}retry/", data={"csrfmiddlewaretoken": token}, headers={"Referer": f"{ops.base_url}{path}"})
            assert r.status_code == 302, r.status_code
        finally:
            ops.close()
        t_retry = wait_task(oid, {"SEARCHING", "OFFERED"}, 10)
        assert t_retry and t_retry["status"] in ("SEARCHING", "OFFERED"), t_retry
        audit = db_query("select a.action, u.email from core_auditlog a join accounts_user u on u.id=a.actor_id "
                         "where a.id>%s and a.object_type='orders.order' and a.object_id=%s", (audit_from, str(oid)))
        assert any("retry" in act and email == OPS for act, email in audit), audit
        leak = [m for _, m in sm_ws.msgs if m.get("data", {}).get("order_id") == oid]
        assert leak == [], f"GGN-01 feed got QA-02 data: {leak[:2]}"
    finally:
        stop.set()
        ops_ws.close()
        sm_ws.close()


@pytest.mark.profile_triggerplaced
def test_p5_tc38b_trigger_placed_dispatches_before_acceptance(r1, p5_shop_a):
    """P5-TC-38 (2) DISPATCH_TRIGGER=PLACED (+ a 40 s auto-accept delay): the task exists and R1 is
    offered while the order is still PLACED."""
    r1.online_at()
    order = p5_shop_a.place_cod()
    oid = order["id"]
    row = wait_task(oid, {"OFFERED", "SEARCHING"}, 20)
    assert row, "no task at PLACED with DISPATCH_TRIGGER=PLACED"
    offer = r1.wait_offer(20, task_id=row["id"])
    assert order_status(oid) == "PLACED", order_status(oid)
    assert offer["task_id"] == row["id"]
