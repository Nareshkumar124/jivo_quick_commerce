"""Phase 3 races and limits (08 §6.1 lock rules, 06 §2.6): the last units under concurrent
placement (no oversell), one Idempotency-Key fired in parallel (one order), the coupon hold
(HELD -> RELEASED on T5), the 30/hour placement limit, and the T4 expiry run by the :8001 beat
(slow; `-m slow`). Light concurrency only (<= 8 in flight, shared DB)."""

from __future__ import annotations

import os
import time
from concurrent.futures import ThreadPoolExecutor

import pytest

from p3_support import ORDERS, V_CANOLA_1L, V_OLIVE_5L, V_SUN_1L, captured_event, fake_id, new_key, send_webhook, stock
from conftest import login
from qa_support import QA_PHONES, assert_error, clear_throttle, client, db_query, describe


@pytest.mark.smoke
def test_p3_tc43_no_oversell_last_units(shop_factory):
    """P3-TC-43 🔥 Five customers place ONLINE orders for the last 2 units at once: exactly one
    201, the others 409 STOCK_UNAVAILABLE; reserved never exceeds on_hand. The winner is
    cancelled afterwards (stock released)."""
    on_hand, reserved = stock(V_OLIVE_5L)
    if on_hand - reserved != 2:
        pytest.skip(f"needs exactly 2 available units of variant {V_OLIVE_5L} (has {on_hand - reserved})")
    shops = [shop_factory(k) for k in "abcde"]
    expected = {}
    for s in shops:
        expected[id(s)] = s.fill({V_OLIVE_5L: 2}, address_id=s.address["id"])["bill"]["grand_total"]

    def go(s):
        with client() as c:
            from p3_support import Shop

            return Shop(c, s.session).place("ONLINE", address_id=s.address["id"], expected=expected[id(s)])

    with ThreadPoolExecutor(5) as pool:
        results = list(pool.map(go, shops))
    codes = sorted(r.status_code for r in results)
    winners = [r for r in results if r.status_code == 201]
    try:
        assert codes == [201, 409, 409, 409, 409], [describe(r) for r in results]
        for r in results:
            if r.status_code == 409:
                assert r.json()["error"]["code"] == "STOCK_UNAVAILABLE"
        on_hand2, reserved2 = stock(V_OLIVE_5L)
        assert reserved2 == reserved + 2 and reserved2 <= on_hand2
    finally:
        for s, r in zip(shops, results):
            if r.status_code == 201:
                s.cancel(r.json()["order"]["id"])
    assert stock(V_OLIVE_5L) == (on_hand, reserved)


@pytest.mark.smoke
def test_p3_tc44_same_key_in_parallel(shop_a):
    """P3-TC-44 🔥 The same Idempotency-Key sent 6 times in parallel: one order, one
    reservation; every response is 201/200 with that order."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    expected = shop_a.cart().json()["bill"]["grand_total"]
    key = new_key()

    def go(_):
        with client() as c:
            from p3_support import Shop

            return Shop(c, shop_a.session).place("ONLINE", address_id=shop_a.address["id"], expected=expected, key=key)

    with ThreadPoolExecutor(6) as pool:
        results = list(pool.map(go, range(6)))
    ids = {r.json()["order"]["id"] for r in results if r.status_code in (200, 201)}
    assert all(r.status_code in (200, 201) for r in results), [describe(r) for r in results]
    assert len(ids) == 1 and sorted(r.status_code for r in results).count(201) == 1
    oid = ids.pop()
    n = db_query("select count(*) from orders_order where user_id=%s and idempotency_key=%s", (shop_a.session.user["id"], key))[0][0]
    assert n == 1
    assert db_query("select count(*) from inventory_stockreservation where order_id=%s", (oid,))[0][0] == 1


def test_p3_tc45_coupon_hold_and_release(shop_a):
    """P3-TC-45 An ONLINE order with a coupon holds it (HELD redemption, counted against the
    limits, order.coupon_discount = cart discount); T5 releases it (RELEASED) and no APPLIED
    row exists."""
    shop_a.fill({V_CANOLA_1L: 2}, address_id=shop_a.address["id"])
    assert shop_a.apply("JIVO50").status_code == 200
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    order = r.json()["order"]
    assert order["coupon_code"] == "JIVO50" and order["bill"]["coupon_discount"] == "50.00"
    rows = db_query("select status, discount_amount from promotions_couponredemption where order_id=%s", (order["id"],))
    assert [(s, f"{d:.2f}") for s, d in rows] == [("HELD", "50.00")]
    shop_a.cancel(order["id"])
    rows = db_query("select status from promotions_couponredemption where order_id=%s", (order["id"],))
    assert rows == [("RELEASED",)], rows


@pytest.mark.limits
def test_p3_tc46_placement_rate_limit(api, shop_factory):
    """P3-TC-46 orders_create is limited per user (30/hour): the 31st call is 429
    RATE_LIMITED with details.retry_after_seconds and Retry-After. Uses empty-cart calls (400,
    nothing created); the QA throttle history is cleared before and after."""
    shop = shop_factory("e")
    clear_throttle("orders_create")
    try:
        body = {"address_id": shop.address["id"], "payment_method": "COD", "expected_grand_total": "0.00"}
        codes = []
        for _ in range(30):
            r = api.post(ORDERS, json=body, headers={**shop.h, "Idempotency-Key": new_key()})
            codes.append(r.status_code)
        assert set(codes) == {400}, codes
        r = api.post(ORDERS, json=body, headers={**shop.h, "Idempotency-Key": new_key()})
        err = assert_error(r, 429, "RATE_LIMITED")
        assert int(err["details"]["retry_after_seconds"]) > 0 and r.headers.get("Retry-After")
    finally:
        clear_throttle("orders_create")


@pytest.mark.slow
def test_p3_tc47_expiry_t4_then_late_capture(api, shop_factory):
    """P3-TC-47 T4 via the :8001 beat's expire_unpaid_orders (same DB): after the 15-minute
    window the unpaid order becomes PAYMENT_FAILED (payment_status FAILED), stock released,
    coupon hold released, cart kept, retry 409; a late payment.captured webhook then refunds
    in full and never revives it (T3a)."""
    if os.environ.get("QA_SLOW") != "1":
        pytest.skip("slow (~16 min): set QA_SLOW=1")
    shop = shop_factory("d")
    shop.fill({V_CANOLA_1L: 2}, address_id=shop.address["id"])
    assert shop.apply("JIVO50").status_code == 200
    before = stock(V_CANOLA_1L)
    r = shop.place("ONLINE", address_id=shop.address["id"])
    assert r.status_code == 201, describe(r)
    order, rzp = r.json()["order"], r.json()["razorpay"]
    assert stock(V_CANOLA_1L)[1] == before[1] + 2
    deadline = time.time() + 19 * 60
    status = "PAYMENT_PENDING"
    while time.time() < deadline:
        shop.session = login(QA_PHONES["d"])  # access tokens last 15 min, as long as the window
        status = shop.order(order["id"]).json()["status"]
        if status != "PAYMENT_PENDING":
            break
        time.sleep(30)
    assert status == "PAYMENT_FAILED", status
    o = shop.order(order["id"]).json()
    assert o["payment_status"] == "FAILED" and o["can_retry_payment"] is False
    assert stock(V_CANOLA_1L) == before
    assert db_query("select status from promotions_couponredemption where order_id=%s", (order["id"],)) == [("RELEASED",)]
    assert len(shop.cart().json()["items"]) == 1
    assert_error(shop.retry(order["id"]), 409, "INVALID_STATE_TRANSITION")
    paise = int(float(order["bill"]["grand_total"]) * 100)
    r = send_webhook(api, captured_event(rzp["order_id"], fake_id("pay_"), paise))
    assert r.json() == {"status": "processed"}
    o = shop.order(order["id"]).json()
    assert o["status"] == "PAYMENT_FAILED" and o["payment_status"] in ("REFUND_PENDING", "REFUNDED")
    refs = db_query("select count(*) from payments_refund where order_id=%s", (order["id"],))[0][0]
    assert refs == 1


def _pending_online(shop):
    shop.fill({V_SUN_1L: 1}, address_id=shop.address["id"])
    r = shop.place("ONLINE", address_id=shop.address["id"])
    assert r.status_code == 201, describe(r)
    return r.json()["order"], r.json()["razorpay"]


def test_p3_tc52_same_webhook_in_parallel(api, shop_a):
    """P3-TC-52 One payment.captured event (same X-Razorpay-Event-Id) delivered 6 times at
    once: never a 5xx, exactly one `processed`, one capture, no refund, one stored event."""
    order, rzp = _pending_online(shop_a)
    paise = int(float(order["bill"]["grand_total"]) * 100)
    event, eid = captured_event(rzp["order_id"], fake_id("pay_"), paise), fake_id("evt_")
    with ThreadPoolExecutor(6) as pool:
        results = list(pool.map(lambda _: send_webhook(api, event, event_id=eid), range(6)))
    assert all(r.status_code == 200 for r in results), [describe(r) for r in results]
    statuses = sorted(r.json()["status"] for r in results)
    assert statuses.count("processed") == 1, statuses
    assert db_query("select count(*) from payments_payment where order_id=%s and status='CAPTURED'", (order["id"],))[0][0] == 1
    assert db_query("select count(*) from payments_refund where order_id=%s", (order["id"],))[0][0] == 0
    assert db_query("select count(*) from payments_paymentwebhookevent where event_id=%s", (eid,))[0][0] == 1


def test_p3_tc53_verify_races_cancel(shop_a):
    """P3-TC-53 Verify and cancel at the same moment (x3 rounds): the order ends either PLACED
    (paid, cancel 409) or CANCELLED (verify 409 + one full refund); never both, never a 5xx,
    stock reserved iff PLACED."""
    from p3_support import Shop

    for _ in range(3):
        order, rzp = _pending_online(shop_a)

        def do(kind):
            with client() as c:
                s = Shop(c, shop_a.session)
                return s.verify(order["id"], rzp["order_id"]) if kind == "verify" else s.cancel(order["id"])

        with ThreadPoolExecutor(2) as pool:
            v, c = pool.map(do, ["verify", "cancel"])
        assert v.status_code in (200, 409) and c.status_code in (200, 409), (describe(v), describe(c))
        final = shop_a.order(order["id"]).json()
        refunds = db_query("select count(*) from payments_refund where order_id=%s", (order["id"],))[0][0]
        active = db_query("select count(*) from inventory_stockreservation where order_id=%s and status='ACTIVE'", (order["id"],))[0][0]
        if final["status"] == "PLACED":
            assert (v.status_code, c.status_code, refunds, active) == (200, 409, 0, 1), final
        else:
            assert final["status"] == "CANCELLED"
            assert (v.status_code, c.status_code, refunds, active) == (409, 200, 1, 0), final


def test_p3_tc54_required_headers(api, shop_a):
    """P3-TC-54 POST /orders/ needs X-Store-Id (400); the app headers are informational (06
    §2.1: requests without them are processed and never get 426, P0-TC-13), so a request
    without them reaches the normal guards; the webhook needs none (covered by every webhook
    test, which sends no app headers)."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    body = {"address_id": shop_a.address["id"], "payment_method": "ONLINE", "expected_grand_total": "1.00"}
    hdrs = {k: v for k, v in shop_a.h.items() if k != "X-Store-Id"}
    r = api.post(ORDERS, json=body, headers={**hdrs, "Idempotency-Key": new_key()})
    assert_error(r, 400, "VALIDATION_ERROR")
    import httpx

    bare = {"Authorization": shop_a.session.headers["Authorization"], "X-Store-Id": "1", "Idempotency-Key": new_key()}
    r = httpx.post(f"{api.base_url}{ORDERS}", json=body, headers=bare)
    assert_error(r, 409, "PRICE_CHANGED")
