"""Phase 5 cases still owed after stage 4, run on main (2026-11-16): P5-TC-50 (b) and P5-TC-92.

Run on the `local` profile with two timers shortened through QA_EXTRA_ENV (instance, worker and
drivers alike), so the cases fit in minutes and the dispatch retry cannot fire by itself:

    QA_EXTRA_ENV="DISPATCH_RETRY_SECONDS=300 DISPATCH_TIMEOUT_SECONDS=900 COD_QR_EXPIRY_SECONDS=20" \
        bash qa/tools/instance.sh start local
    QA_EXTRA_ENV="..." uv run pytest tests/test_p5_main.py

Each test skips itself when the running instance does not have those values. QA numbers and the
QA-only store QA-02 only. QA instance :8004 only.
"""

from __future__ import annotations

import os
import secrets
import time
from datetime import UTC, datetime
from decimal import Decimal

import pytest
from p3_support import send_webhook
from p4_support import OPS, order_row, t8a_oracle
from p4_support import ops as store_ops
from p5_support import (  # noqa: F401 (fixtures)
    QA02_ID,
    R1_PHONE,
    V_SUN_1L,
    bring_to,
    ledger_rows,
    money,
    p5_shop_a,
    pickup_code,
    qa_worker,
    r1,
    rider_id_of,
    wait_task_status,
)
from qa_support import db_query, describe
from test_p5_cash import qr_event

pytestmark = pytest.mark.p5_53

EXTRA = dict(kv.split("=", 1) for kv in os.environ.get("QA_EXTRA_ENV", "").split() if "=" in kv)
QR_EXPIRY = int(EXTRA.get("COD_QR_EXPIRY_SECONDS", "900"))
RETRY = int(EXTRA.get("DISPATCH_RETRY_SECONDS", "15"))


def online_riders_at_qa02() -> list[tuple]:
    return db_query(
        "select r.id, u.phone from delivery_rider r join accounts_user u on u.id = r.user_id "
        "where r.is_online and r.home_store_id = %s", (QA02_ID,))


def qr_rows(order_id: int) -> list[tuple]:
    return db_query("select gateway_qr_id, status, amount from delivery_codqr where order_id=%s order by id",
                    (order_id,))


def refunds_for_payment(pay_id: str) -> list[tuple]:
    return db_query(
        "select rf.reason, rf.amount from payments_refund rf join payments_payment p on p.id = rf.payment_id "
        "where p.gateway_payment_id = %s", (pay_id,))


def pay_qr(api, qr_id: str, amount: str) -> str:
    pay_id = "pay_" + secrets.token_hex(7)
    w = send_webhook(api, qr_event(qr_id, int(Decimal(amount) * 100), pay_id), event_id="evt_qa_" + secrets.token_hex(6))
    assert w.status_code == 200, describe(w)
    return pay_id


# =========================================================================== P5-TC-50 (b)


def test_p5_tc50b_packed_dispatches_before_the_retry(r1, p5_shop_a):
    """P5-TC-50 (b) 08 T8 "if no rider yet, raise dispatch priority": a task SEARCHING with its next
    retry far in the future (no rider was online) is offered as soon as the order is packed, not
    at the retry. R1 comes online after the search failed, so only the T8 trigger can offer it."""
    if RETRY < 120:
        pytest.skip("needs QA_EXTRA_ENV DISPATCH_RETRY_SECONDS >= 120 on the instance and worker")
    others = [p for _, p in online_riders_at_qa02() if p != R1_PHONE]
    if others:
        pytest.skip(f"other riders online at QA-02: {others}")
    order = p5_shop_a.place_cod({V_SUN_1L: 1})
    oid = order["id"]
    row = wait_task_status(oid, "SEARCHING", timeout=45)
    nxt, end = None, time.monotonic() + 20
    while nxt is None and time.monotonic() < end:  # the ACCEPTED dispatch has run and found nobody
        nxt = db_query("select next_dispatch_at from delivery_deliverytask where order_id=%s", (oid,))[0][0]
        if nxt is None:
            time.sleep(0.5)
    assert nxt is not None, row
    assert (nxt - datetime.now(UTC)).total_seconds() > 60, f"retry not far enough ahead: {nxt}"
    r1.online_at()
    assert r1.no_offer_for(4), "offered before packing: the retry rule did not hold"
    t0 = time.monotonic()
    out = store_ops({"op": "start_packing", "as": OPS, "order_id": oid}, {"op": "packed", "as": OPS, "order_id": oid})
    assert all(o["ok"] for o in out), out
    offer = r1.wait_offer(timeout=20, task_id=row["id"])
    waited = time.monotonic() - t0
    print(f"TC-50b: offer {offer['id']} {waited:.1f}s after packing; retry was due at {nxt.isoformat()}")
    assert datetime.now(UTC) < nxt, "offer came only at the retry"


# =========================================================================== P5-TC-92


def test_p5_tc92a_qr_after_t8a_is_for_the_new_due(r1, p5_shop_a, api):
    """P5-TC-92 (1) COD of 2 units reduced by T8a before pickup: the QR is for the new due (the
    order's new grand_total = QA oracle), not the offer's cod_amount; paying it lets R1 deliver
    with UPI; nothing enters R1's cash ledger."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1, lines={V_SUN_1L: 2})
    oid, tid = ctx["order_id"], ctx["task_id"]
    old = order_row(oid)
    offered = money(ctx["offer"]["cod_amount"])
    assert offered == money(old["grand_total"]), (offered, old["grand_total"])
    line = next(i for i in p5_shop_a.order(oid).json()["items"] if i["variant_id"] == V_SUN_1L)
    expected = t8a_oracle(old, [(money(line["mrp"]), money(line["selling_price"]), 1)])["grand_total"]
    out = store_ops({"op": "start_packing", "as": OPS, "order_id": oid},
                    {"op": "unavailable", "as": OPS, "order_id": oid, "item_id": line["id"], "unavailable": 1})
    assert all(o["ok"] for o in out), out
    assert r1.arrived_store(tid).status_code == 200
    assert store_ops({"op": "packed", "as": OPS, "order_id": oid})[0]["ok"]
    assert r1.pickup(tid, pickup_code(oid)).status_code == 200
    otp = p5_shop_a.track(oid).json()["delivery_otp"]
    assert r1.arrived_customer(tid).status_code == 200
    q = r1.post(f"tasks/{tid}/cod-qr/")
    assert q.status_code == 200, describe(q)
    qr = q.json()
    print(f"TC-92a: offer cod_amount {offered}, new due {expected}, QR amount {qr['amount']}")
    assert money(qr["amount"]) == expected and money(qr["amount"]) != offered, (qr, expected, offered)
    ledger_before = len(ledger_rows(rider_id_of(R1_PHONE)))
    pay_qr(api, qr["qr_id"], qr["amount"])
    assert r1.task().json()["task"]["cod_qr"]["status"] == "PAID"
    r = r1.deliver(tid, otp, {"mode": "upi", "amount": qr["amount"]})
    assert r.status_code == 200, describe(r)
    assert len(ledger_rows(rider_id_of(R1_PHONE))) == ledger_before


def _expired_qr(r1, shop):
    if QR_EXPIRY > 60:
        pytest.skip("needs QA_EXTRA_ENV COD_QR_EXPIRY_SECONDS <= 60 on the instance and worker")
    r1.online_at()
    ctx = bring_to("ATC", shop=shop, rider=r1)
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    assert qr["status"] == "PENDING", qr
    time.sleep(QR_EXPIRY + 2)
    shown = r1.task().json()["task"]["cod_qr"]
    assert shown["qr_id"] == qr["qr_id"] and shown["status"] == "EXPIRED", shown
    return ctx, qr


def test_p5_tc92b_replaced_expired_qr_late_payment_refunded(r1, p5_shop_a, api):
    """P5-TC-92 (2) A QR left unpaid past expires_at shows EXPIRED; asking again gives a new QR and
    closes the old one EXPIRED; a late payment to the old QR is refunded in full (cod_qr_unused),
    never counted: the new QR stays PENDING and cash delivery still works."""
    ctx, qr = _expired_qr(r1, p5_shop_a)
    again = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    assert again["qr_id"] != qr["qr_id"] and again["status"] == "PENDING", again
    rows = {q: s for q, s, _ in qr_rows(ctx["order_id"])}
    assert rows[qr["qr_id"]] == "EXPIRED", rows
    pay_id = pay_qr(api, qr["qr_id"], qr["amount"])
    refunds = refunds_for_payment(pay_id)
    assert len(refunds) == 1 and refunds[0][0] == "cod_qr_unused" and money(refunds[0][1]) == money(qr["amount"]), refunds
    assert r1.task().json()["task"]["cod_qr"]["status"] == "PENDING"
    task = r1.task().json()["task"]
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": task["cod_amount_due"]})
    assert r.status_code == 200, describe(r)


@pytest.mark.xfail(strict=True, reason="BUG-0025: a credit on an expired, unreplaced QR is accepted as PAID")
def test_p5_tc92c_expired_qr_paid_late_is_refunded(r1, p5_shop_a, api):
    """P5-TC-92 (2') A payment on an expired QR that was not replaced (still PENDING in the DB, shown
    EXPIRED to the rider): 06 slice 5.4 and 08 T10 say a credit on an expired QR is refunded in full
    and never pays the order."""
    ctx, qr = _expired_qr(r1, p5_shop_a)
    pay_id = pay_qr(api, qr["qr_id"], qr["amount"])
    refunds = refunds_for_payment(pay_id)
    status = {q: s for q, s, _ in qr_rows(ctx["order_id"])}[qr["qr_id"]]
    print(f"TC-92c: late credit on expired QR -> QR {status}, refunds {refunds}")
    # leave the task clean whatever happened: deliver by the way the server now allows
    task = r1.task().json()["task"]
    cod = {"mode": "upi", "amount": qr["amount"]} if status == "PAID" else {"mode": "cash", "amount": task["cod_amount_due"]}
    assert r1.deliver(ctx["task_id"], ctx["otp"], cod).status_code == 200
    assert status != "PAID", "a credit on an expired QR paid the order (06 slice 5.4: it must be refunded)"
    assert len(refunds) == 1 and refunds[0][0] == "cod_qr_unused", refunds


def test_p5_tc92d_failed_task_qr_payment_refunded(r1, p5_shop_a, api):
    """P5-TC-92 (3) The task is failed (T13) with a PENDING QR: the QR is closed CANCELLED; a payment
    to it afterwards is refunded in full, the order is not COD_COLLECTED and R1's ledger is unchanged."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    oid = ctx["order_id"]
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    ledger_before = len(ledger_rows(rider_id_of(R1_PHONE)))
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    rows = {q: s for q, s, _ in qr_rows(oid)}
    assert rows[qr["qr_id"]] == "CANCELLED", rows
    pay_id = pay_qr(api, qr["qr_id"], qr["amount"])
    refunds = refunds_for_payment(pay_id)
    assert len(refunds) == 1 and refunds[0][0] == "cod_qr_unused" and money(refunds[0][1]) == money(qr["amount"]), refunds
    assert {q: s for q, s, _ in qr_rows(oid)}[qr["qr_id"]] == "CANCELLED"
    assert p5_shop_a.order(oid).json()["payment_status"] != "COD_COLLECTED"
    assert len(ledger_rows(rider_id_of(R1_PHONE))) == ledger_before
