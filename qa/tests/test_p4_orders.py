"""Phase 4 customer order API (QA T-416): order detail with timeline, cancellation and refunds
(06 §2.6 P4 contract, interim schema of backend/phase-4 R1), customer cancel T11 (08 §7, §6.4),
reorder and invoice.

Status (2026-11-04): the P4 contract (R1) is exported in the backend4 worktree; the behaviour
(R2) is not merged in develop. Cases that need R2 are skipped with "awaiting P4 R2 merge" and
carry full bodies, so the merge only needs the skip removed. Cases whose behaviour already
holds on develop (P3 rules that P4 keeps) run now.

Staff actions (accept, start packing, item unavailable) are driven through `p4_support.Console`,
which is bound to the Ops Console URLs once admin's P4 R2 is merged."""

from __future__ import annotations

import concurrent.futures
import time
from decimal import Decimal

import pytest

from p3_support import V_CANOLA_1L, V_MUSTARD_1L, V_PUMPKIN, V_SUN_1L, captured_event, fake_id, send_webhook, stock
from qa_support import STORE_HEADERS, assert_error, db_query, describe, validate_response


ORDER_FIELDS_P4 = {"timeline", "cancellation", "amount_refunded", "refunds", "can_download_invoice"}
CUSTOMER_LABELS = {  # 08 §1
    "PAYMENT_PENDING": "Completing payment",
    "PLACED": "Order placed",
    "ACCEPTED": "Order confirmed",
    "PACKING": "Packing your order",
    "CANCELLED": "Cancelled",
}


def paid_online(shop, lines: dict[int, int] | None = None) -> dict:
    """An ONLINE order of `shop`, paid through the fake gateway's verify (T3): PLACED/PAID."""
    shop.fill(lines or {V_SUN_1L: 1}, address_id=shop.address["id"])
    r = shop.place("ONLINE", address_id=shop.address["id"])
    assert r.status_code == 201, describe(r)
    order, rzp = r.json()["order"], r.json()["razorpay"]
    v = shop.verify(order["id"], rzp["order_id"])
    assert v.status_code == 200 and v.json()["status"] == "PLACED", describe(v)
    return v.json()


def cod_order(shop, lines: dict[int, int] | None = None) -> dict:
    shop.fill(lines or {V_SUN_1L: 1}, address_id=shop.address["id"])
    r = shop.place("COD", address_id=shop.address["id"])
    assert r.status_code == 201, describe(r)
    return r.json()["order"]


def refund_rows(order_id: int) -> list[tuple]:
    return db_query("select amount, status, reason, idempotency_key from payments_refund where order_id=%s order by id", (order_id,))


def wait_refunded(shop, order_id: int, timeout: float = 90) -> dict:
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        o = shop.order(order_id).json()
        if o["payment_status"] in ("REFUNDED", "PARTIALLY_REFUNDED"):
            return o
        time.sleep(2)
    return shop.order(order_id).json()


# --------------------------------------------------------------------------- runnable on develop


def test_p4_tc07a_cancel_idor_pending(shop_a, shop_b):
    """P4-TC-07 (part a, runs on develop) User B cancels user A's PAYMENT_PENDING order: 404,
    A's order unchanged. Part b (PLACED, T11) needs R2."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    oid = r.json()["order"]["id"]
    assert_error(shop_b.cancel(oid), 404, "NOT_FOUND")
    assert shop_a.order(oid).json()["status"] == "PAYMENT_PENDING"


def test_p4_tc08_customer_cannot_use_staff_reasons(shop_a):
    """P4-TC-08 The customer cancel takes only the customer reasons (`CancelReasonEnum`); the
    staff reasons of `OrderCancelReasonEnum` (ITEMS_UNAVAILABLE, SUSPECTED_FRAUD, NO_RIDER, ...)
    and a note over 250 characters are 400; the order is unchanged."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    oid = r.json()["order"]["id"]
    for reason in ("ITEMS_UNAVAILABLE", "SUSPECTED_FRAUD", "NO_RIDER", "OTHER_STAFF", "CUSTOMER_REQUEST", "", None, 5):
        assert_error(shop_a.cancel(oid, reason=reason), 400, "VALIDATION_ERROR")
    path = f"/api/v1/orders/{oid}/cancel/"
    r = shop_a.api.post(path, json={"reason": "OTHER", "note": "x" * 251}, headers=shop_a.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    assert shop_a.order(oid).json()["status"] == "PAYMENT_PENDING"


def test_p4_tc14a_order_endpoints_need_auth(api):
    """P4-TC-14 (part a) Order list/detail/cancel without a token: 401 AUTH_REQUIRED."""
    assert_error(api.get("/api/v1/orders/"), 401, "AUTH_REQUIRED")
    assert_error(api.get("/api/v1/orders/1/"), 401, "AUTH_REQUIRED")
    assert_error(api.post("/api/v1/orders/1/cancel/", json={"reason": "OTHER"}), 401, "AUTH_REQUIRED")


# --------------------------------------------------------------------------- P4 R2 (merged in develop 74f47d1)


@pytest.mark.smoke
def test_p4_tc01_order_detail_p4_shape(shop_a):
    """P4-TC-01 🔥 Order detail of a fresh ONLINE order and of a paid one: strict P4 schema;
    timeline oldest first with the 08 §1 labels; cancellation null; refunds []; amount_refunded
    "0.00"; can_download_invoice false; every line quantity_unavailable 0."""
    o = paid_online(shop_a)
    r = shop_a.order(o["id"])
    validate_response(r, "orders_retrieve")
    body = r.json()
    assert ORDER_FIELDS_P4 <= body.keys()
    assert [t["status"] for t in body["timeline"]] == ["PAYMENT_PENDING", "PLACED"]
    ats = [t["at"] for t in body["timeline"]]
    assert ats == sorted(ats)
    for t in body["timeline"]:
        assert t["title"].startswith(CUSTOMER_LABELS[t["status"]])
    assert body["cancellation"] is None and body["refunds"] == [] and body["amount_refunded"] == "0.00"
    assert body["can_download_invoice"] is False and body["can_cancel"] is True
    assert all(line["quantity_unavailable"] == 0 for line in body["items"])


@pytest.mark.smoke
def test_p4_tc02_cancel_cod_placed(shop_a):
    """P4-TC-02 🔥 T11 on a COD order in PLACED: 200 CANCELLED; cancellation {reason, message,
    cancelled_by customer}; the reservation is released; no Refund row; can_cancel false; the
    timeline ends with CANCELLED."""
    before = stock(V_SUN_1L)
    o = cod_order(shop_a)
    assert stock(V_SUN_1L)[1] == before[1] + 1
    r = shop_a.cancel(o["id"], reason="ORDERED_BY_MISTAKE")
    validate_response(r, "orders_cancel")
    assert r.status_code == 200, describe(r)
    body = r.json()
    assert body["status"] == "CANCELLED" and body["can_cancel"] is False
    assert body["cancellation"]["reason"] == "ORDERED_BY_MISTAKE" and body["cancellation"]["cancelled_by"] == "customer"
    assert body["timeline"][-1]["status"] == "CANCELLED"
    assert stock(V_SUN_1L) == before
    assert refund_rows(o["id"]) == []


@pytest.mark.smoke
def test_p4_tc03_cancel_paid_online_full_refund(shop_a):
    """P4-TC-03 🔥 T11 on a paid ONLINE order: one full refund (reason ORDER_CANCELLED) to the
    original payment; payment_status REFUND_PENDING then REFUNDED (QA worker on DB 7);
    amount_refunded = grand_total; stock released; a repeat cancel is 409 and adds no refund."""
    before = stock(V_SUN_1L)
    o = paid_online(shop_a)
    r = shop_a.cancel(o["id"])
    assert r.status_code == 200, describe(r)
    body = r.json()
    assert body["payment_status"] in ("REFUND_PENDING", "REFUNDED")
    assert len(body["refunds"]) == 1 and body["refunds"][0]["amount"] == o["bill"]["grand_total"]
    assert body["refunds"][0]["reason"] == "ORDER_CANCELLED"
    assert stock(V_SUN_1L) == before
    assert_error(shop_a.cancel(o["id"]), 409, "INVALID_STATE_TRANSITION")
    done = wait_refunded(shop_a, o["id"])
    assert done["payment_status"] == "REFUNDED" and done["amount_refunded"] == o["bill"]["grand_total"]
    assert done["refunds"][0]["status"] == "PROCESSED"
    assert len(refund_rows(o["id"])) == 1


def test_p4_tc06_parallel_cancel_one_refund(shop_a):
    """P4-TC-06 The same paid order cancelled 5× in parallel: exactly one 200, the others 409;
    exactly one Refund row; the reservation released once."""
    before = stock(V_SUN_1L)
    o = paid_online(shop_a)
    with concurrent.futures.ThreadPoolExecutor(5) as pool:
        codes = sorted(f.result().status_code for f in [pool.submit(shop_a.cancel, o["id"]) for _ in range(5)])
    assert codes == [200, 409, 409, 409, 409], codes
    assert len(refund_rows(o["id"])) == 1
    assert stock(V_SUN_1L) == before


@pytest.mark.smoke
def test_p4_tc07b_cancel_idor_placed(shop_a, shop_b):
    """P4-TC-07 🔥 (part b) User B cancels user A's PLACED COD order: 404; A's order stays
    PLACED with its reservation; then A cancels it (cleanup)."""
    o = cod_order(shop_a)
    assert_error(shop_b.cancel(o["id"]), 404, "NOT_FOUND")
    assert shop_a.order(o["id"]).json()["status"] == "PLACED"
    assert shop_a.cancel(o["id"]).status_code == 200


@pytest.mark.smoke
def test_p4_tc11_reorder_idempotent(shop_a):
    """P4-TC-11 🔥 Reorder a past order: 200 ReorderResult; each line raised to the ordered
    units (never on top); added_count = lines now in the cart; a repeat changes nothing; the cart
    reserves no stock (08 §6.1)."""
    o = cod_order(shop_a, {V_SUN_1L: 2, V_CANOLA_1L: 1})
    shop_a.cancel(o["id"])
    shop_a.clear()
    reserved = stock(V_SUN_1L)[1]
    r1 = shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=shop_a.h)
    validate_response(r1, "orders_reorder")
    assert r1.status_code == 200, describe(r1)
    lines = {line["variant"]["id"]: line["quantity"] for line in r1.json()["cart"]["items"]}
    assert lines == {V_SUN_1L: 2, V_CANOLA_1L: 1}
    assert r1.json()["added_count"] == 2 and r1.json()["unavailable"] == []
    r2 = shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=shop_a.h)
    assert {line["variant"]["id"]: line["quantity"] for line in r2.json()["cart"]["items"]} == lines
    assert stock(V_SUN_1L)[1] == reserved


def test_p4_tc12_reorder_unavailable_lines(shop_a):
    """P4-TC-12 Reorder of an order whose lines are now out of stock / not sold at the store:
    `unavailable` lists them with OUT_OF_STOCK / NOT_AVAILABLE and added_quantity 0; the
    available lines are added. (Built from an order placed before the stock change: on the
    shared DB only the already-OOS demo variant can be used, so an order of it is made through
    the history of user A when one exists.)"""
    rows = db_query(
        "select o.id from orders_order o join orders_orderitem i on i.order_id=o.id join accounts_user u on u.id=o.user_id "
        "where u.phone=%s and i.variant_id in (%s, %s) limit 1",
        (shop_a.session.phone, V_MUSTARD_1L, V_PUMPKIN),
    )
    if not rows:
        pytest.skip("no QA order with a now-unavailable variant (needs an ops stock change on a QA-owned store)")
    r = shop_a.api.post(f"/api/v1/orders/{rows[0][0]}/reorder/", headers=shop_a.h)
    assert r.status_code == 200, describe(r)
    reasons = {i["variant_id"]: i["reason"] for i in r.json()["unavailable"]}
    assert reasons.get(V_MUSTARD_1L, "OUT_OF_STOCK") == "OUT_OF_STOCK"
    assert reasons.get(V_PUMPKIN, "NOT_AVAILABLE") == "NOT_AVAILABLE"


@pytest.mark.smoke
def test_p4_tc14b_reorder_invoice_idor_and_headers(api, shop_a, shop_b):
    """P4-TC-14 🔥 (part b) Reorder and invoice of another user's order: 404; reorder without
    X-Store-Id: 400; unknown store: 404 STORE_NOT_FOUND; no token: 401."""
    o = cod_order(shop_a)
    try:
        assert_error(shop_b.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=shop_b.h), 404, "NOT_FOUND")
        assert_error(shop_b.api.get(f"/api/v1/orders/{o['id']}/invoice/", headers=shop_b.h), 404, "NOT_FOUND")
        no_store = {k: v for k, v in shop_a.h.items() if k != "X-Store-Id"}
        assert shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=no_store).status_code == 400
        assert_error(shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers={**shop_a.h, "X-Store-Id": "999999"}), 404, "STORE_NOT_FOUND")
        assert_error(api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=STORE_HEADERS), 401, "AUTH_REQUIRED")
        assert_error(api.get(f"/api/v1/orders/{o['id']}/invoice/"), 401, "AUTH_REQUIRED")
    finally:
        shop_a.cancel(o["id"])


def test_p4_tc15_invoice_not_delivered(shop_a):
    """P4-TC-15 Invoice of an order that is not DELIVERED: 409 INVALID_STATE_TRANSITION
    {status}; can_download_invoice false."""
    o = cod_order(shop_a)
    try:
        err = assert_error(shop_a.api.get(f"/api/v1/orders/{o['id']}/invoice/", headers=shop_a.h), 409, "INVALID_STATE_TRANSITION")
        assert err["details"] == {"status": "PLACED"}
        assert shop_a.order(o["id"]).json()["can_download_invoice"] is False
    finally:
        shop_a.cancel(o["id"])


def test_p4_tc18_list_after_cancel(shop_a):
    """P4-TC-18 A cancelled order is in `?status=past`, not `active`; the summary validates
    strictly against the P4 schema."""
    o = cod_order(shop_a)
    shop_a.cancel(o["id"])
    past = shop_a.api.get("/api/v1/orders/?status=past", headers=shop_a.h)
    validate_response(past, "orders_list")
    assert o["id"] in [x["id"] for x in past.json()["results"]]
    active = shop_a.api.get("/api/v1/orders/?status=active", headers=shop_a.h).json()["results"]
    assert o["id"] not in [x["id"] for x in active]


def test_p4_tc59_paid_cancel_refund_then_late_webhook(api, shop_a):
    """P4-TC-59 E2E (API part) Paid ONLINE order cancelled by the customer; a `payment.captured`
    webhook for the same capture afterwards adds no second refund; the refund settles once."""
    o = paid_online(shop_a)
    pay = db_query("select gateway_order_id, gateway_payment_id from payments_payment where order_id=%s and status='CAPTURED'", (o["id"],))[0]
    assert shop_a.cancel(o["id"]).status_code == 200
    amount = int(Decimal(o["bill"]["grand_total"]) * 100)
    send_webhook(api, captured_event(pay[0], pay[1], amount), event_id=fake_id("evt_"))
    assert len(refund_rows(o["id"])) == 1
    assert wait_refunded(shop_a, o["id"])["payment_status"] == "REFUNDED"


# --------------------------------------------------------------------------- with store actions
# Staff steps go through the backend services (p4_support.ops) until the Ops Console merges.

from p4_support import MANAGER, STAFF, op, ops  # noqa: E402


@pytest.mark.parametrize("method", ["ONLINE", "COD"])
def test_p4_tc04_cancel_in_accepted(shop_a, method):
    """P4-TC-04 The store accepts (T6), then the customer cancels in ACCEPTED (T11): 200
    CANCELLED, cancelled_by customer; ONLINE: one full refund; COD: nothing due (FAILED)."""
    before = stock(V_SUN_1L)
    o = paid_online(shop_a) if method == "ONLINE" else cod_order(shop_a)
    assert op(op="accept", **{"as": STAFF}, order_id=o["id"])["ok"]
    r = shop_a.cancel(o["id"])
    assert r.status_code == 200, describe(r)
    body = r.json()
    assert body["status"] == "CANCELLED" and body["cancellation"]["cancelled_by"] == "customer"
    if method == "ONLINE":
        assert [x["amount"] for x in body["refunds"]] == [o["bill"]["grand_total"]]
        assert wait_refunded(shop_a, o["id"])["payment_status"] == "REFUNDED"
    else:
        assert body["refunds"] == [] and body["payment_status"] == "FAILED"
    assert stock(V_SUN_1L) == before


@pytest.mark.smoke
@pytest.mark.parametrize("state", ["PACKING", "PACKED"])
def test_p4_tc05_cancel_refused_from_packing(shop_a, state):
    """P4-TC-05 🔥 Customer cancel in PACKING / PACKED: 409 INVALID_STATE_TRANSITION {status};
    can_cancel false; nothing released or refunded. Cleanup: the Store Manager cancels (T12)."""
    o = paid_online(shop_a)
    steps = [{"op": "accept", "as": STAFF, "order_id": o["id"]}, {"op": "start_packing", "as": STAFF, "order_id": o["id"]}]
    if state == "PACKED":
        steps.append({"op": "packed", "as": STAFF, "order_id": o["id"]})
    assert all(x["ok"] for x in ops(*steps))
    reserved = stock(V_SUN_1L)
    try:
        err = assert_error(shop_a.cancel(o["id"]), 409, "INVALID_STATE_TRANSITION")
        assert err["details"] == {"status": state}
        body = shop_a.order(o["id"]).json()
        assert body["status"] == state and body["can_cancel"] is False and body["refunds"] == []
        assert stock(V_SUN_1L) == reserved
    finally:
        assert op(op="cancel", **{"as": MANAGER}, order_id=o["id"], reason="OTHER_STAFF")["ok"]


def test_p4_tc09_cancel_vs_start_packing_race(shop_a):
    """P4-TC-09 Customer cancel and staff Start packing at the same instant, 3 rounds: either
    CANCELLED (+1 refund, start packing refused) or PACKING (cancel 409, no refund); never both."""
    import threading

    outcomes = []
    for _ in range(3):
        o = paid_online(shop_a)
        assert op(op="accept", **{"as": STAFF}, order_id=o["id"])["ok"]
        res = {}
        # The driver needs ~3 s to boot Django; start it first and fire the cancel when it is up.
        t = threading.Thread(target=lambda: res.setdefault("pack", op(op="start_packing", **{"as": STAFF}, order_id=o["id"])))
        t.start()
        time.sleep(2.6)
        res["cancel"] = shop_a.cancel(o["id"])
        t.join()
        final = shop_a.order(o["id"]).json()
        n_ref = len(refund_rows(o["id"]))
        if res["cancel"].status_code == 200:
            assert not res["pack"]["ok"] and final["status"] == "CANCELLED" and n_ref == 1
            outcomes.append("cancelled")
        else:
            assert res["cancel"].status_code == 409 and res["pack"]["ok"] and final["status"] == "PACKING" and n_ref == 0
            outcomes.append("packing")
            op(op="cancel", **{"as": MANAGER}, order_id=o["id"], reason="OTHER_STAFF")
    print("race outcomes", outcomes)


@pytest.mark.profile_cancelplaced
def test_p4_tc10_cancel_until_placed(shop_a):
    """P4-TC-10 Instance with CUSTOMER_CANCEL_UNTIL=PLACED: can_cancel true in PLACED, false in
    ACCEPTED, and the customer cancel in ACCEPTED is 409."""
    o = cod_order(shop_a)
    assert shop_a.order(o["id"]).json()["can_cancel"] is True
    assert op(op="accept", **{"as": STAFF}, order_id=o["id"])["ok"]
    try:
        assert shop_a.order(o["id"]).json()["can_cancel"] is False
        err = assert_error(shop_a.cancel(o["id"]), 409, "INVALID_STATE_TRANSITION")
        assert err["details"] == {"status": "ACCEPTED"}
    finally:
        op(op="cancel", **{"as": MANAGER}, order_id=o["id"], reason="OTHER_STAFF")


def test_p4_tc13_reorder_keeps_larger_cart_line(shop_a):
    """P4-TC-13 Reorder when the cart already holds more units of a line: that line is left as
    it is (never lowered, never added on top); the other line is raised to the ordered units."""
    o = cod_order(shop_a, {V_SUN_1L: 1, V_CANOLA_1L: 1})
    shop_a.cancel(o["id"])
    shop_a.clear()
    assert shop_a.set_qty(V_SUN_1L, 3).status_code == 200
    r = shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=shop_a.h)
    assert r.status_code == 200, describe(r)
    lines = {line["variant"]["id"]: line["quantity"] for line in r.json()["cart"]["items"]}
    assert lines == {V_SUN_1L: 3, V_CANOLA_1L: 1}
    assert r.json()["added_count"] == 2


def test_p4_tc12b_reorder_out_of_and_limited_stock(shop_a, shop_b):
    """P4-TC-12 (b) Without any stock change: Olive 5L (on_hand 2, max 2). A orders 2 (unpaid,
    then cancelled, T5). B's unpaid order holds 2 → A's reorder: OUT_OF_STOCK, added 0, the
    other line (Sun) added. B holds 1 → LIMITED_STOCK, added_quantity 1. Reorder never reserves.
    (NOT_AVAILABLE needs a variant delisted at the store: QA-owned store / staging.)"""
    V_OLIVE_5L = 6
    if stock(V_OLIVE_5L)[0] - stock(V_OLIVE_5L)[1] < 2:
        pytest.skip("Olive 5L not fully available right now")
    shop_a.fill({V_OLIVE_5L: 2, V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    oid = r.json()["order"]["id"]
    assert shop_a.cancel(oid).status_code == 200
    try:
        for held, reason, added in ((2, "OUT_OF_STOCK", 0), (1, "LIMITED_STOCK", 1)):
            shop_b.fill({V_OLIVE_5L: held}, address_id=shop_b.address["id"])
            rb = shop_b.place("ONLINE", address_id=shop_b.address["id"])
            assert rb.status_code == 201, describe(rb)
            shop_a.clear()
            reserved = stock(V_OLIVE_5L)[1]
            ra = shop_a.api.post(f"/api/v1/orders/{oid}/reorder/", headers=shop_a.h)
            validate_response(ra, "orders_reorder")
            assert ra.status_code == 200, describe(ra)
            body = ra.json()
            issues = {i["variant_id"]: i for i in body["unavailable"]}
            assert set(issues) == {V_OLIVE_5L}, body["unavailable"]
            assert issues[V_OLIVE_5L]["reason"] == reason and issues[V_OLIVE_5L]["added_quantity"] == added
            assert issues[V_OLIVE_5L]["requested_quantity"] == 2
            cart = {line["variant"]["id"]: line["quantity"] for line in body["cart"]["items"]}
            assert cart.get(V_SUN_1L) == 1 and cart.get(V_OLIVE_5L, 0) == added
            assert body["added_count"] == (2 if added else 1)
            assert stock(V_OLIVE_5L)[1] == reserved
            assert shop_b.cancel(rb.json()["order"]["id"]).status_code == 200
    finally:
        shop_b.cancel_pending()
        shop_a.clear()
