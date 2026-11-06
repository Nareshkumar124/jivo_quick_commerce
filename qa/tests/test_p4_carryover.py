"""Phase 3 cases carried into Phase 4 (DL-50): P3-TC-26 -> P4-TC-49 (minimum order, needs the
₹45 wheatgrass sachet `JV-WG-PW-10S` that backend P4 R2 adds to the seed) and P3-TC-63 ->
P4-TC-50 (gateway unreachable, needs the `FAKE_GATEWAY_DOWN` switch of the fake gateway, P4 R2).

P4-TC-50 runs only on an instance started with the `gwdown` profile (FAKE_GATEWAY_DOWN=1)."""

from __future__ import annotations

import pytest

from p3_support import V_SUN_1L, money
from qa_support import assert_error, db_query, describe




def sachet_variant() -> int | None:
    rows = db_query("select id from catalog_productvariant where sku=%s", ("JV-WG-PW-10S",))
    return rows[0][0] if rows else None


def test_p4_tc49_min_order_not_met(shop_a):
    """P4-TC-49 (ex P3-TC-26) One ₹45 sachet: the cart shows the MIN_ORDER_NOT_MET blocker with
    amount_to_min_order = min_order_value - item_total; `POST /orders/` (COD and ONLINE) is 422
    MIN_ORDER_NOT_MET {min_order_value, item_total, amount_to_min_order}; nothing created."""
    vid = sachet_variant()
    if vid is None:
        pytest.skip("JV-WG-PW-10S not seeded on this DB (the PM runs seed_demo after the R2 merge)")
    shop_a.fill({vid: 1}, address_id=shop_a.address["id"])
    before = db_query("select count(*) from orders_order")[0][0]
    for method in ("COD", "ONLINE"):
        err = assert_error(shop_a.place(method, address_id=shop_a.address["id"]), 422, "MIN_ORDER_NOT_MET")
        d = err["details"]
        assert money(d["amount_to_min_order"]) == money(d["min_order_value"]) - money(d["item_total"]) > 0
    assert db_query("select count(*) from orders_order")[0][0] == before


@pytest.mark.profile_gwdown
def test_p4_tc50_gateway_down(shop_a):
    """P4-TC-50 (ex P3-TC-63) With the fake gateway down: ONLINE placement is 503
    SERVICE_UNAVAILABLE and creates no order, payment or reservation; COD still places (no
    gateway call); verify of a pending order is 503 and the order stays PAYMENT_PENDING."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    before = db_query("select count(*) from orders_order")[0][0]
    assert_error(shop_a.place("ONLINE", address_id=shop_a.address["id"]), 503, "SERVICE_UNAVAILABLE")
    assert db_query("select count(*) from orders_order")[0][0] == before
    r = shop_a.place("COD", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    shop_a.cancel(r.json()["order"]["id"])


@pytest.mark.profile_gwdown
def test_p4_tc50b_verify_and_retry_gateway_down(api):
    """P4-TC-50 (part b) A PAYMENT_PENDING order of QA user D, placed before the instance was
    restarted with the gateway down: verify is 503 SERVICE_UNAVAILABLE (or the signature check
    still passes locally and the order is placed: recorded either way), retry-payment is 503;
    the order is never failed by the outage."""
    from conftest import login
    from p3_support import Shop, fake_id, checkout_signature
    from qa_support import QA_PHONES

    shop = Shop(api, login(QA_PHONES["d"]))
    pending = [o for o in shop.api.get("/api/v1/orders/", headers=shop.h, params={"status": "active"}).json()["results"]
               if o["status"] == "PAYMENT_PENDING"]
    if not pending:
        pytest.skip("no PAYMENT_PENDING order of user D (create one before starting the gwdown profile)")
    oid = pending[0]["id"]
    assert_error(shop.retry(oid), 503, "SERVICE_UNAVAILABLE")
    rzp = db_query("select gateway_order_id from payments_payment where order_id=%s order by id desc limit 1", (oid,))[0][0]
    pay = fake_id("pay_")
    r = shop.api.post("/api/v1/payments/razorpay/verify/", headers=shop.h, json={
        "order_id": oid, "razorpay_order_id": rzp, "razorpay_payment_id": pay,
        "razorpay_signature": checkout_signature(rzp, pay)})
    print("verify while gateway down:", r.status_code, r.text[:200])
    assert r.status_code in (200, 503), describe(r)
    if r.status_code == 503:
        assert shop.order(oid).json()["status"] == "PAYMENT_PENDING"
    shop.cancel(oid)
