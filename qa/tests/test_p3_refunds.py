"""Phase 3 refund webhook ordering (T-303 fix run, merged in develop dff62d5; QA T-310).

The refund `refund.*` webhook can reach the server before `payments.process_refund` has recorded
the gateway refund id. The merged fix (payments/services.py `_refund_by_receipt`):
- a webhook whose `receipt` is the refund's receipt is matched by it (receipt fallback);
- with no match while a refund of that payment is PENDING without a gateway id and younger than
  `REFUND_WEBHOOK_RETRY_WINDOW_SECONDS` (default 2 h), it answers 503 `SERVICE_UNAVAILABLE` and
  stores nothing, so the gateway's retry (same event id) is processed once the id is recorded;
- past that window, or for a payment with no such refund, the event is `ignored`.

These tests need **no Celery worker consuming the QA broker (Redis DB 7)** when they start: each
one creates the refund, checks that nothing recorded its gateway id, sends the early webhook,
and only then starts a short-lived QA worker itself (`qa_worker()`, QA Redis URLs only) to run
the queued task. If an outside worker records the id first, the test skips with that reason.

Receipts and fake refund ids are derived the way the server documents them (06 §2.6 fake
gateway; `refund_receipt()` keeps keys of at most 40 characters; the refund key of a capture is
`capture:<payment id>`). These are the dev fake's published rules, not secrets."""

from __future__ import annotations

import contextlib
import hashlib
import os
import subprocess
import sys
import time
from decimal import Decimal

import pytest

from p3_support import V_SUN_1L, captured_event, fake_id, send_webhook
from qa_support import REPO, PRIVATE, assert_error, db_query, describe

QA_WORKER_ENV = {
    "REDIS_URL": "redis://localhost:6380/5",
    "CHANNELS_REDIS_URL": "redis://localhost:6380/6",
    "CELERY_BROKER_URL": "redis://localhost:6380/7",
    "DJANGO_SETTINGS_MODULE": "config.settings.local",
    "SMS_BACKEND": "apps.notifications.sms.ConsoleSmsBackend",
    "PYTHONUNBUFFERED": "1",
}


@contextlib.contextmanager
def qa_worker(log_name: str):
    """A Celery worker on the QA broker (DB 7) only, from this checkout's backend, for the
    duration of the block. Never port 6379; killed (whole tree) on exit."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(QA_WORKER_ENV)
    log = open(PRIVATE / "logs" / log_name, "a", encoding="utf-8")  # noqa: SIM115
    cmd = ["uv", "run", "celery", "-A", "config", "worker", "--pool=solo", "--without-heartbeat", "--without-mingle", "--without-gossip"]
    flags = subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform == "win32" else 0
    proc = subprocess.Popen(cmd, cwd=REPO / "backend", env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
    try:
        yield proc
    finally:
        if sys.platform == "win32":
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
        else:
            proc.terminate()
        proc.wait(timeout=30)
        log.close()


def refund_row(payment_id: str):
    rows = db_query(
        "select r.id, r.status, r.gateway_refund_id, r.amount, r.order_id, r.idempotency_key from payments_refund r "
        "join payments_payment p on p.id=r.payment_id where p.gateway_payment_id=%s order by r.id",
        (payment_id,),
    )
    return rows


def wait_for(predicate, timeout: float = 90, step: float = 1.0):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    return predicate()


def receipt_for(key: str) -> str:
    return key if len(key) <= 40 else "rk_" + hashlib.sha256(key.encode()).hexdigest()[:37]


def fake_refund_id(payment_id: str, receipt: str) -> str:
    """The fake gateway's refund id: deterministic per (payment, receipt), like Razorpay's
    receipt idempotency."""
    return "rfnd_" + hashlib.sha256(f"{payment_id}|{receipt}".encode()).hexdigest()[:14]


def refund_event(kind: str, refund_id: str, payment_id: str, amount_paise: int, receipt: str | None = None) -> dict:
    entity = {"id": refund_id, "entity": "refund", "amount": amount_paise, "currency": "INR", "payment_id": payment_id, "status": kind}
    if receipt is not None:
        entity["receipt"] = receipt
    return {"entity": "event", "event": f"refund.{kind}", "payload": {"refund": {"entity": entity}}}


def webhook_rows(event_id: str) -> list[tuple]:
    return db_query("select processed_at is not null from payments_paymentwebhookevent where event_id=%s", (event_id,))


def order_money(order_id: int):
    return db_query("select status, payment_status, amount_refunded, grand_total from orders_order where id=%s", (order_id,))[0]


@pytest.fixture
def late_refund(shop_a):
    """An ONLINE order of user A, cancelled, then captured late (T3a): one PENDING refund with
    no gateway id yet, queued for `process_refund`. Returns (order, payment id, amount paise)."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    order, rzp = r.json()["order"], r.json()["razorpay"]
    assert shop_a.cancel(order["id"]).status_code == 200
    amount = int(Decimal(order["bill"]["grand_total"]) * 100)
    pay_id = fake_id("pay_")
    r = send_webhook(shop_a.api, captured_event(rzp["order_id"], pay_id, amount))
    assert r.status_code == 200 and r.json()["status"] == "processed", describe(r)
    time.sleep(4)  # give an outside worker (if any) the time to show itself
    rows = refund_row(pay_id)
    assert len(rows) == 1, rows
    if rows[0][2]:
        pytest.skip("a Celery worker is consuming the QA broker (DB 7): stop it to run the refund-ordering tests")
    assert rows[0][1] == "PENDING"
    return order, pay_id, amount


def test_p3_tc65_refund_webhook_before_task_503_then_retry(api, late_refund):
    """P3-TC-65 refund.processed arrives before the task recorded the refund id (no receipt):
    503 SERVICE_UNAVAILABLE, nothing stored; once the task records the id, the gateway's retry
    (same event id) is processed; the refund counts once; a replay is `duplicate`."""
    order, pay_id, amount = late_refund
    rid = fake_refund_id(pay_id, receipt_for(f"capture:{pay_id}"))
    event = refund_event("processed", rid, pay_id, amount)
    evt = fake_id("evt_")
    r = send_webhook(api, event, event_id=evt)
    assert_error(r, 503, "SERVICE_UNAVAILABLE")
    assert webhook_rows(evt) == [], "a 503 must store nothing"
    assert refund_row(pay_id)[0][1:3] == ("PENDING", "")
    r = send_webhook(api, event, event_id=evt)  # a gateway retry while still unrecorded: 503 again
    assert_error(r, 503, "SERVICE_UNAVAILABLE")
    with qa_worker("worker-p3r-tc65.log"):
        row = wait_for(lambda: (x := refund_row(pay_id)[0])[2] and x)
    assert row[1:3] == ("PROCESSED", rid), row
    r = send_webhook(api, event, event_id=evt)
    assert r.status_code == 200 and r.json()["status"] == "processed", describe(r)
    assert webhook_rows(evt) == [(True,)]
    r = send_webhook(api, event, event_id=evt)
    assert r.json() == {"status": "duplicate"}
    status, pstatus, refunded, total = order_money(order["id"])
    assert (status, pstatus) == ("CANCELLED", "REFUNDED")
    assert refunded == total == Decimal(amount) / 100
    assert len(refund_row(pay_id)) == 1


def test_p3_tc66_refund_webhook_receipt_fallback(api, late_refund):
    """P3-TC-66 refund.processed before the task, carrying the refund's receipt: matched by the
    receipt and processed at once (200); the queued task then finds the refund settled and makes
    no second refund; the order is REFUNDED once."""
    order, pay_id, amount = late_refund
    receipt = receipt_for(f"capture:{pay_id}")
    rid = fake_refund_id(pay_id, receipt)
    r = send_webhook(api, refund_event("processed", rid, pay_id, amount, receipt=receipt))
    assert r.status_code == 200 and r.json()["status"] == "processed", describe(r)
    assert refund_row(pay_id)[0][1:3] == ("PROCESSED", rid)
    before = order_money(order["id"])
    assert before[1] == "REFUNDED" and before[2] == before[3]
    with qa_worker("worker-p3r-tc66.log"):
        time.sleep(15)  # the queued process_refund runs and must skip
    rows = refund_row(pay_id)
    assert len(rows) == 1 and rows[0][1:3] == ("PROCESSED", rid), rows
    assert order_money(order["id"]) == before


def test_p3_tc67_unmatched_refund_event_ignored(api, late_refund):
    """P3-TC-67 While payment A has an unrecorded PENDING refund: a refund event for another
    payment (B, no refunds) is `ignored` (not 503); an event carrying A's receipt but B's payment
    id is `ignored` too (receipts match only within their payment). A's refund is untouched."""
    order, pay_id, amount = late_refund
    other = fake_id("pay_")
    r = send_webhook(api, refund_event("processed", fake_id("rfnd_"), other, amount))
    assert r.status_code == 200 and r.json() == {"status": "ignored"}, describe(r)
    r = send_webhook(api, refund_event("processed", fake_id("rfnd_"), other, amount, receipt=receipt_for(f"capture:{pay_id}")))
    assert r.status_code == 200 and r.json() == {"status": "ignored"}, describe(r)
    r = send_webhook(api, refund_event("failed", fake_id("rfnd_"), "not-a-payment-id", amount))
    assert r.status_code == 200 and r.json() == {"status": "ignored"}, describe(r)
    assert refund_row(pay_id)[0][1:3] == ("PENDING", "")
    with qa_worker("worker-p3r-tc67.log"):
        row = wait_for(lambda: (x := refund_row(pay_id)[0])[1] == "PROCESSED" and x)
    assert row and row[2] == fake_refund_id(pay_id, receipt_for(f"capture:{pay_id}"))
    assert order_money(order["id"])[1] == "REFUNDED"


def test_p3_tc68_failed_refund_not_reopened(api, late_refund):
    """P3-TC-68 refund.failed (matched by receipt) before the task: the refund is FAILED; the
    queued task then skips it (FAILED never goes back to PENDING, no gateway refund is made, no
    second Refund row); the order is not marked REFUNDED."""
    order, pay_id, amount = late_refund
    receipt = receipt_for(f"capture:{pay_id}")
    rid = fake_refund_id(pay_id, receipt)
    r = send_webhook(api, refund_event("failed", rid, pay_id, amount, receipt=receipt))
    assert r.status_code == 200 and r.json()["status"] == "processed", describe(r)
    assert refund_row(pay_id)[0][1] == "FAILED"
    with qa_worker("worker-p3r-tc68.log"):
        time.sleep(15)
    rows = refund_row(pay_id)
    assert len(rows) == 1 and rows[0][1] == "FAILED", rows
    status, pstatus, refunded, _ = order_money(order["id"])
    assert pstatus != "REFUNDED" and refunded == Decimal("0.00"), (pstatus, refunded)


@pytest.mark.profile_refundwindow
def test_p3_tc69_refund_webhook_past_window_ignored(api, late_refund):
    """P3-TC-69 The 503 is bounded: past REFUND_WEBHOOK_RETRY_WINDOW_SECONDS (the refundwindow
    profile sets 20 s) an unmatched refund event for a payment whose refund is still PENDING
    without an id is `ignored` (200), not 503; the refund is then settled by the task as usual."""
    order, pay_id, amount = late_refund
    event = refund_event("processed", fake_id("rfnd_"), pay_id, amount)
    r = send_webhook(api, event)
    assert_error(r, 503, "SERVICE_UNAVAILABLE")  # inside the window
    time.sleep(22)
    r = send_webhook(api, event)
    assert r.status_code == 200 and r.json() == {"status": "ignored"}, describe(r)
    assert refund_row(pay_id)[0][1:3] == ("PENDING", "")
    with qa_worker("worker-p3r-tc69.log"):
        row = wait_for(lambda: (x := refund_row(pay_id)[0])[1] == "PROCESSED" and x)
    assert row
