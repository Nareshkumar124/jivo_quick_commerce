"""Phase 3 payments (08 §4, T3/T3a/T5, 06 §2.6, DL-45): verify (signature, wrong gateway order,
idempotency), webhook (signature over raw bytes, event-id idempotency, order-insensitivity with
verify, amount check, payment.failed), retry-payment, late capture on a cancelled order
(auto-refund), and the no-duplicate-financial-transaction invariant.

All against the FakeRazorpayGateway (local settings) with the published dev-only secrets."""

from __future__ import annotations

import json
from decimal import Decimal

import pytest

from p3_support import (
    V_SUN_1L,
    captured_event,
    checkout_signature,
    failed_event,
    fake_id,
    new_key,
    send_webhook,
    stock,
)
from qa_support import assert_error, db_query, describe, validate_response


def payments(order_id: int) -> list[tuple]:
    return db_query(
        "select gateway_order_id, gateway_payment_id, status, amount from payments_payment where order_id=%s order by id",
        (order_id,),
    )


def refunds(order_id: int) -> list[tuple]:
    return db_query(
        "select r.amount, r.status, r.idempotency_key from payments_refund r join payments_payment p on p.id=r.payment_id "
        "where p.order_id=%s order by r.id",
        (order_id,),
    )


def webhook_rows(event_id: str) -> list[tuple]:
    return db_query("select event_type, processed_at is not null, error from payments_paymentwebhookevent where event_id=%s", (event_id,))


@pytest.fixture
def pending(shop_a):
    """An ONLINE order of user A awaiting payment: (shop, order, razorpay)."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    return shop_a, r.json()["order"], r.json()["razorpay"]


def paise(order) -> int:
    return int(Decimal(order["bill"]["grand_total"]) * 100)


def test_p3_tc32_signature_example():
    """P3-TC-32 The published worked example of the fake checkout signature (06 §2.6) matches
    Razorpay's algorithm."""
    assert checkout_signature("order_Nq3uVxY7kL9pQe", "pay_Nq3vA1bC2dE3fG") == (
        "bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977"
    )


@pytest.mark.smoke
def test_p3_tc33_verify_places_order(pending):
    """P3-TC-33 🔥 Verify with a valid signature: 200 PLACED, payment_status PAID, one CAPTURED
    payment, reservation stops expiring, ordered lines leave the cart, history T3. Repeat
    verify (same ids): 200 PLACED, still one capture, no refund."""
    shop, order, rzp = pending
    pay_id = fake_id("pay_")
    r = shop.verify(order["id"], rzp["order_id"], pay_id)
    validate_response(r, "payments_razorpay_verify")
    assert r.status_code == 200 and r.json()["status"] == "PLACED" and r.json()["payment_status"] == "PAID", describe(r)
    assert r.json()["payment_expires_at"] is None and r.json()["eta_at"]
    for _ in range(2):
        again = shop.verify(order["id"], rzp["order_id"], pay_id)
        assert again.status_code == 200 and again.json()["status"] == "PLACED", describe(again)
    captured = [p for p in payments(order["id"]) if p[2] == "CAPTURED"]
    assert len(captured) == 1 and captured[0][1] == pay_id
    assert refunds(order["id"]) == []
    exp = db_query("select bool_or(expires_at is not null) from inventory_stockreservation where order_id=%s", (order["id"],))[0][0]
    assert exp is False
    assert shop.cart().json()["items"] == []
    hist = db_query("select from_status, to_status from orders_orderstatushistory where order_id=%s order by id", (order["id"],))
    assert hist == [("", "PAYMENT_PENDING"), ("PAYMENT_PENDING", "PLACED")]


@pytest.mark.smoke
def test_p3_tc34_verify_rejections(pending, shop_b):
    """P3-TC-34 🔥 Verify: wrong signature / signature with another secret / a gateway order
    that is not this order's: 400 PAYMENT_VERIFICATION_FAILED and the order stays
    PAYMENT_PENDING; malformed fields 400 VALIDATION_ERROR; non-ASCII signature 400 (never 500);
    another user's order 404; no token 401."""
    shop, order, rzp = pending
    pay_id = fake_id("pay_")
    assert_error(shop.verify(order["id"], rzp["order_id"], pay_id, "0" * 64), 400, "PAYMENT_VERIFICATION_FAILED")
    assert_error(shop.verify(order["id"], rzp["order_id"], pay_id, checkout_signature(rzp["order_id"], pay_id, "wrong-secret")), 400, "PAYMENT_VERIFICATION_FAILED")
    other = fake_id("order_")
    assert_error(shop.verify(order["id"], other, pay_id, checkout_signature(other, pay_id)), 400, "PAYMENT_VERIFICATION_FAILED")
    r = shop.verify(order["id"], rzp["order_id"], pay_id, "é" * 64)
    assert r.status_code == 400, describe(r)
    r = shop.api.post("/api/v1/payments/razorpay/verify/", json={"order_id": order["id"]}, headers=shop.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    assert_error(shop_b.verify(order["id"], rzp["order_id"]), 404, "NOT_FOUND")
    r = shop.api.post("/api/v1/payments/razorpay/verify/", json={})
    assert_error(r, 401, "AUTH_REQUIRED")
    assert shop.order(order["id"]).json()["status"] == "PAYMENT_PENDING"
    assert [p for p in payments(order["id"]) if p[2] == "CAPTURED"] == []


@pytest.mark.smoke
def test_p3_tc35_webhook_signature(api, pending):
    """P3-TC-35 🔥 Webhook: bad signature, signature of a different body, missing signature or
    missing event id: 400 and nothing stored; the order stays PAYMENT_PENDING."""
    shop, order, rzp = pending
    event = captured_event(rzp["order_id"], fake_id("pay_"), paise(order))
    body = json.dumps(event).encode()
    eid = fake_id("evt_")
    assert_error(send_webhook(api, event, event_id=eid, signature="0" * 64), 400, "PAYMENT_VERIFICATION_FAILED")
    from p3_support import webhook_signature

    tampered = body.replace(b'"upi"', b'"card"')
    assert_error(send_webhook(api, event, event_id=eid, raw=tampered, signature=webhook_signature(body)), 400, "PAYMENT_VERIFICATION_FAILED")
    import httpx

    r = httpx.post(f"{api.base_url}/api/v1/payments/razorpay/webhook/", content=body, headers={"Content-Type": "application/json", "X-Razorpay-Event-Id": eid})
    assert r.status_code == 400, describe(r)
    r = httpx.post(f"{api.base_url}/api/v1/payments/razorpay/webhook/", content=body, headers={"Content-Type": "application/json", "X-Razorpay-Signature": webhook_signature(body)})
    assert r.status_code == 400, describe(r)
    assert webhook_rows(eid) == []
    assert shop.order(order["id"]).json()["status"] == "PAYMENT_PENDING"


@pytest.mark.smoke
def test_p3_tc36_webhook_capture_then_verify(api, pending):
    """P3-TC-36 🔥 payment.captured webhook first: 200 processed, order PLACED; same event id
    again: duplicate; a new event id for the same payment: no second capture; verify
    afterwards: 200 PLACED. Exactly one CAPTURED payment, no refund."""
    shop, order, rzp = pending
    pay_id = fake_id("pay_")
    event = captured_event(rzp["order_id"], pay_id, paise(order))
    eid = fake_id("evt_")
    r = send_webhook(api, event, event_id=eid)
    validate_response(r, "payments_razorpay_webhook")
    assert r.json() == {"status": "processed"}, describe(r)
    assert shop.order(order["id"]).json()["status"] == "PLACED"
    assert send_webhook(api, event, event_id=eid).json() == {"status": "duplicate"}
    send_webhook(api, event)  # Razorpay retry under a new event id
    v = shop.verify(order["id"], rzp["order_id"], pay_id)
    assert v.status_code == 200 and v.json()["status"] == "PLACED", describe(v)
    captured = [p for p in payments(order["id"]) if p[2] == "CAPTURED"]
    assert len(captured) == 1, captured
    assert refunds(order["id"]) == []
    assert webhook_rows(eid) == [("payment.captured", True, "")]


def test_p3_tc37_webhook_wrong_amount(api, pending):
    """P3-TC-37 A capture whose amount is not grand_total never places the order (08 T3
    guard): it stays PAYMENT_PENDING and the capture is refunded in full; the customer can
    still cancel."""
    shop, order, rzp = pending
    pay_id = fake_id("pay_")
    r = send_webhook(api, captured_event(rzp["order_id"], pay_id, paise(order) - 100))
    assert r.status_code == 200, describe(r)
    assert shop.order(order["id"]).json()["status"] == "PAYMENT_PENDING"
    refs = refunds(order["id"])
    assert len(refs) == 1 and refs[0][0] == Decimal(paise(order) - 100) / 100, refs
    r = shop.cancel(order["id"])
    assert r.status_code == 200 and r.json()["status"] == "CANCELLED", describe(r)


@pytest.mark.smoke
def test_p3_tc38_late_capture_after_cancel(api, pending):
    """P3-TC-38 🔥 T3a: verify on a CANCELLED order is 409 INVALID_STATE_TRANSITION (not
    revived), the capture is refunded in full once (payment_status REFUND_PENDING); a webhook
    for the same capture adds no second refund; stock stays released."""
    shop, order, rzp = pending
    before = stock(V_SUN_1L)
    assert shop.cancel(order["id"]).status_code == 200
    released = stock(V_SUN_1L)
    assert released[1] == before[1] - 1
    pay_id = fake_id("pay_")
    err = assert_error(shop.verify(order["id"], rzp["order_id"], pay_id), 409, "INVALID_STATE_TRANSITION")
    assert err["details"] == {"status": "CANCELLED"}
    send_webhook(api, captured_event(rzp["order_id"], pay_id, paise(order)))
    o = shop.order(order["id"]).json()
    assert o["status"] == "CANCELLED" and o["payment_status"] in ("REFUND_PENDING", "REFUNDED"), o["payment_status"]
    refs = refunds(order["id"])
    assert len(refs) == 1 and refs[0][0] == Decimal(order["bill"]["grand_total"]), refs
    assert stock(V_SUN_1L) == released


def test_p3_tc39_retry_payment(pending):
    """P3-TC-39 Retry: 200 OrderPlacement with a new gateway order; same key returns the same
    gateway order; payment_expires_at not extended; paying either gateway order places the
    order; a capture on the other one afterwards is refunded as a duplicate (DL-45); retry on
    the PLACED order is 409."""
    shop, order, rzp = pending
    key = new_key()
    r1 = shop.retry(order["id"], key)
    validate_response(r1, "orders_retry_payment")
    assert r1.status_code == 200, describe(r1)
    new_rzp = r1.json()["razorpay"]["order_id"]
    assert new_rzp != rzp["order_id"]
    assert r1.json()["order"]["payment_expires_at"] == order["payment_expires_at"]
    r2 = shop.retry(order["id"], key)
    assert r2.json()["razorpay"]["order_id"] == new_rzp
    assert shop.verify(order["id"], new_rzp).json()["status"] == "PLACED"
    shop.verify(order["id"], rzp["order_id"])  # the first attempt is paid too
    refs = refunds(order["id"])
    assert len(refs) == 1 and refs[0][0] == Decimal(order["bill"]["grand_total"]), refs
    o = shop.order(order["id"]).json()
    assert o["status"] == "PLACED" and o["payment_status"] == "PAID"
    err = assert_error(shop.retry(order["id"]), 409, "INVALID_STATE_TRANSITION")
    assert err["details"] == {"status": "PLACED"}


def test_p3_tc40_retry_requires_key(pending):
    """P3-TC-40 Retry without Idempotency-Key: 400; on a cancelled order: 409."""
    shop, order, _ = pending
    r = shop.api.post(f"/api/v1/orders/{order['id']}/retry-payment/", json={}, headers=shop.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    shop.cancel(order["id"])
    err = assert_error(shop.retry(order["id"]), 409, "INVALID_STATE_TRANSITION")
    assert err["details"] == {"status": "CANCELLED"}


def test_p3_tc41_payment_failed_webhook(api, pending):
    """P3-TC-41 payment.failed marks only that attempt FAILED; the order keeps waiting (retry
    allowed); a later capture still places the order; payment.failed after a capture never
    overwrites it."""
    shop, order, rzp = pending
    r = send_webhook(api, failed_event(rzp["order_id"], fake_id("pay_"), paise(order)))
    assert r.json() == {"status": "processed"}, describe(r)
    assert shop.order(order["id"]).json()["status"] == "PAYMENT_PENDING"
    assert payments(order["id"])[0][2] == "FAILED"
    pay_id = fake_id("pay_")
    send_webhook(api, captured_event(rzp["order_id"], pay_id, paise(order)))
    assert shop.order(order["id"]).json()["status"] == "PLACED"
    r = send_webhook(api, failed_event(rzp["order_id"], fake_id("pay_"), paise(order)))
    assert r.json()["status"] in ("ignored", "processed")
    assert any(p[2] == "CAPTURED" and p[1] == pay_id for p in payments(order["id"]))
    assert shop.order(order["id"]).json()["status"] == "PLACED"


def test_p3_tc42_webhook_unknown_and_malformed(api):
    """P3-TC-42 Signed events for an unknown gateway order, an unhandled type, or a malformed
    payload: 200 ignored (never 5xx); an unsigned-but-JSON garbage body: 400."""
    assert send_webhook(api, captured_event(fake_id("order_"), fake_id("pay_"), 100)).json() == {"status": "ignored"}
    assert send_webhook(api, {"event": "order.paid", "payload": {}}).json() == {"status": "ignored"}
    r = send_webhook(api, {"event": "payment.captured", "payload": {"payment": {}}})
    assert r.status_code == 200 and r.json() == {"status": "ignored"}, describe(r)
    r = send_webhook(api, {}, raw=b"not json")
    assert r.status_code == 400, describe(r)


def test_p3_tc57_webhook_overlong_ids(api, pending):
    """P3-TC-57 A signed payment.captured whose payment id is longer than the stored column
    (or long enough that the refund key overflows) is a malformed payload: 200 `ignored`
    (06 §2.6), never a 500; the order is untouched."""
    shop, order, rzp = pending
    r1 = send_webhook(api, captured_event(rzp["order_id"], "pay_" + "A" * 70, paise(order)))
    r2 = send_webhook(api, captured_event(rzp["order_id"], "pay_" + "B" * 54, paise(order) - 100))
    assert shop.order(order["id"]).json()["status"] == "PAYMENT_PENDING"
    assert (r1.status_code, r2.status_code) == (200, 200), (describe(r1), describe(r2))
    assert r1.json() == r2.json() == {"status": "ignored"}  # BUG-0009 fixed (41f02f6)
    assert [p for p in payments(order["id"]) if p[2] == "CAPTURED"] == [] and refunds(order["id"]) == []


def test_p3_tc58_refund_webhook_idempotent(api):
    """P3-TC-58 refund.processed for an already processed refund (replayed twice, new event
    ids) leaves the order's amount_refunded and payment_status unchanged (no double count);
    refund.failed for an unknown refund id: ignored. Needs a refund processed by a worker on
    the QA broker (see 03 report)."""
    row = db_query(
        "select r.gateway_refund_id, r.order_id, r.amount from payments_refund r join orders_order o on o.id=r.order_id "
        "where r.status='PROCESSED' and r.gateway_refund_id <> '' and o.payment_status='REFUNDED' limit 1"
    )
    if not row:
        pytest.skip("no processed refund yet (run a Celery worker on the QA broker DB 7)")
    rid, oid, amount = row[0]
    before = db_query("select payment_status, amount_refunded from orders_order where id=%s", (oid,))[0]
    event = {"event": "refund.processed", "payload": {"refund": {"entity": {"id": rid, "amount": int(amount * 100), "status": "processed"}}}}
    for _ in range(2):
        r = send_webhook(api, event)
        assert r.status_code == 200 and r.json()["status"] in ("processed", "ignored"), describe(r)
    assert db_query("select payment_status, amount_refunded from orders_order where id=%s", (oid,))[0] == before
    unknown = {"event": "refund.failed", "payload": {"refund": {"entity": {"id": fake_id("rfnd_"), "amount": 100}}}}
    assert send_webhook(api, unknown).json() == {"status": "ignored"}
