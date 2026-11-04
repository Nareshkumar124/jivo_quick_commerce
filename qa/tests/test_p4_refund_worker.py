"""Phase 4 refunds that need the QA worker stopped (P4-TC-34 FAILED → retry, P4-TC-35
`sync_refund_status`). The worker is the QA one (broker Redis DB 7); it is restarted at the end
of every test. Staff steps through `p4_support.ops` (Ops Console not merged)."""

from __future__ import annotations

import time

import pytest

from p3_support import send_webhook
from p4_support import FINANCE, ops, refunds, start_worker, stop_worker
from qa_support import db_query, describe
from test_p4_orders import paid_online


@pytest.fixture
def worker_stopped():
    stop_worker()
    yield
    start_worker("worker-p4s1c.log")


def _refund_failed_event(gateway_refund_id: str, payment_id: str, receipt: str, amount_paise: int) -> dict:
    return {
        "entity": "event",
        "event": "refund.failed",
        "payload": {"refund": {"entity": {"id": gateway_refund_id, "payment_id": payment_id, "receipt": receipt,
                                          "amount": amount_paise, "status": "failed", "currency": "INR"}}},
    }


def _wait(pred, timeout=90):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if pred():
            return True
        time.sleep(2)
    return pred()


def test_p4_tc34_failed_refund_retry(api, shop_a, worker_stopped):
    """P4-TC-34 A cancel refund the gateway refuses (refund.failed webhook, matched by receipt)
    is FAILED; the customer still sees it as PENDING (payment_status REFUND_PENDING); Finance
    retries it → `<key>:retry-1`; a second retry is refused; when the worker runs, the original
    task does not resend the FAILED refund and the retry settles: REFUNDED, one PROCESSED refund
    visible, amount_refunded = grand_total."""
    o = paid_online(shop_a)
    assert shop_a.cancel(o["id"]).status_code == 200
    (rid, amount, status, reason, key), = refunds(o["id"])
    assert status == "PENDING" and key == f"cancel:{o['id']}"
    pay_id = db_query("select p.gateway_payment_id from payments_payment p join payments_refund r on r.payment_id=p.id where r.id=%s", (rid,))[0][0]
    r = send_webhook(api, _refund_failed_event("rfnd_QAfailed" + str(rid), pay_id, key, int(amount * 100)))
    assert r.status_code == 200, describe(r)
    assert db_query("select status from payments_refund where id=%s", (rid,))[0][0] == "FAILED"
    body = shop_a.order(o["id"]).json()
    assert body["payment_status"] == "REFUND_PENDING"
    assert [x["status"] for x in body["refunds"]] == ["PENDING"]  # FAILED shown as PENDING
    res = ops({"op": "retry_refund", "as": FINANCE, "refund_id": rid}, {"op": "retry_refund", "as": FINANCE, "refund_id": rid})
    assert res[0]["ok"] and res[0]["result"]["key"] == f"{key}:retry-1", res
    assert not res[1]["ok"] and "already been retried" in res[1]["message"], res
    start_worker("worker-p4s1c.log")
    assert _wait(lambda: shop_a.order(o["id"]).json()["payment_status"] == "REFUNDED")
    rows = refunds(o["id"])
    assert [(x[2], x[4]) for x in rows] == [("FAILED", key), ("PROCESSED", f"{key}:retry-1")], rows
    body = shop_a.order(o["id"]).json()
    assert [(x["status"], x["amount"]) for x in body["refunds"]] == [("PROCESSED", o["bill"]["grand_total"])]
    assert body["amount_refunded"] == o["bill"]["grand_total"]


def test_p4_tc35_sync_refund_status_resends_once(shop_a, worker_stopped):
    """P4-TC-35 A refund PENDING with no gateway answer past REFUND_STUCK_MINUTES (0 for the
    driver process only) is re-queued by `sync_refund_status`, twice in a row; with the original
    task that makes three deliveries: exactly one gateway refund is recorded (lookup by receipt),
    the order settles REFUNDED once."""
    o = paid_online(shop_a)
    assert shop_a.cancel(o["id"]).status_code == 200
    (rid, _, status, _, _), = refunds(o["id"])
    assert status == "PENDING"
    res = ops({"op": "sync_refund_status"}, {"op": "sync_refund_status"}, extra_env={"REFUND_STUCK_MINUTES": "0"})
    assert all(r["ok"] and r["result"].get("resent", 0) >= 1 for r in res), res
    start_worker("worker-p4s1c.log")
    assert _wait(lambda: shop_a.order(o["id"]).json()["payment_status"] == "REFUNDED")
    time.sleep(5)
    rows = db_query("select status, gateway_refund_id from payments_refund where order_id=%s", (o["id"],))
    assert len(rows) == 1 and rows[0][0] == "PROCESSED" and rows[0][1], rows
    after = ops({"op": "sync_refund_status"})[0]
    assert after["ok"]
