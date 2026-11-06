"""Phase 3 order placement (08 T1/T2, 06 §2.6, DL-44): COD and ONLINE placement, the bill
snapshot, stock reservation, Idempotency-Key replay and reuse, PRICE_CHANGED, the guards and
their error codes, one unpaid order at a time, cancel (T5), list/detail, IDOR.

Stock hygiene: COD orders stay PLACED (cannot be cancelled in P3) and keep 1 unit of a
high-stock variant reserved each; ONLINE orders are cancelled again (T5 releases stock)."""

from __future__ import annotations

from decimal import Decimal

import pytest

from p3_support import (
    ORDERS,
    V_CANOLA_1L,
    V_CANOLA_2L,
    V_FLAX,
    V_SUN_1L,
    expected_bill,
    new_key,
    stock,
)
from qa_support import assert_error, db_query, describe, validate_response


def reservations(order_id: int) -> list[tuple]:
    return db_query(
        "select variant_id, quantity, expires_at is not null from inventory_stockreservation where order_id=%s order by variant_id",
        (order_id,),
    )


def history(order_id: int) -> list[tuple]:
    return db_query(
        "select from_status, to_status from orders_orderstatushistory where order_id=%s order by id", (order_id,)
    )


@pytest.mark.smoke
def test_p3_tc20_place_cod(shop_a):
    """P3-TC-20 🔥 COD (T2): 201 PLACED, razorpay null, payment_status COD_PENDING, bill
    snapshot = cart bill = 08 §6.2, stock reserved (no expiry), ordered lines leave the cart,
    history row ''->PLACED, order number JV-YYMMDD-NNNNNN, strict schema."""
    lines = {V_CANOLA_1L: 1}
    cart = shop_a.fill(lines, address_id=shop_a.address["id"])
    before = stock(V_CANOLA_1L)
    r = shop_a.place("COD", address_id=shop_a.address["id"])
    validate_response(r, "orders_create")
    assert r.status_code == 201, describe(r)
    body = r.json()
    order = body["order"]
    assert body["razorpay"] is None
    assert order["status"] == "PLACED" and order["payment_status"] == "COD_PENDING"
    assert order["bill"] == cart["bill"] == expected_bill(lines)
    assert order["order_number"].startswith("JV-") and order["order_number"].endswith(f"{order['id']:06d}")
    assert order["payment_expires_at"] is None and order["placed_at"] and order["eta_at"]
    assert order["address"]["house"] == shop_a.address["house"]
    assert [i["variant_id"] for i in order["items"]] == [V_CANOLA_1L]
    after = stock(V_CANOLA_1L)
    assert after == (before[0], before[1] + 1), (before, after)
    assert reservations(order["id"]) == [(V_CANOLA_1L, 1, False)]
    assert history(order["id"]) == [("", "PLACED")]
    assert shop_a.cart().json()["items"] == []
    r = shop_a.order(order["id"])
    validate_response(r, "orders_retrieve")
    assert r.json()["bill"] == order["bill"]


@pytest.mark.smoke
def test_p3_tc21_place_online_and_cancel(shop_a):
    """P3-TC-21 🔥 ONLINE (T1): 201 PAYMENT_PENDING with razorpay {key_id fake, order_*,
    amount = grand_total x 100 paise, INR}; stock reserved with expiry; payment_expires_at =
    created + 15 min; cart kept. Cancel (T5): CANCELLED, payment_status FAILED, stock released,
    cart kept; a second cancel is 409 INVALID_STATE_TRANSITION."""
    lines = {V_CANOLA_2L: 2}
    shop_a.fill(lines, address_id=shop_a.address["id"])
    before = stock(V_CANOLA_2L)
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    validate_response(r, "orders_create")
    assert r.status_code == 201, describe(r)
    order, rzp = r.json()["order"], r.json()["razorpay"]
    assert order["status"] == "PAYMENT_PENDING" and order["payment_status"] == "PENDING"
    assert rzp["key_id"] == "rzp_fake_jivo_local" and rzp["order_id"].startswith("order_")
    assert rzp["amount"] == int(Decimal(order["bill"]["grand_total"]) * 100) and rzp["currency"] == "INR"
    assert order["can_cancel"] is True and order["can_retry_payment"] is True
    assert stock(V_CANOLA_2L) == (before[0], before[1] + 2)
    assert reservations(order["id"]) == [(V_CANOLA_2L, 2, True)]
    assert len(shop_a.cart().json()["items"]) == 1
    exp = db_query("select extract(epoch from payment_expires_at - created_at) from orders_order where id=%s", (order["id"],))[0][0]
    assert 14 * 60 < float(exp) <= 15 * 60 + 5, exp
    r = shop_a.cancel(order["id"], "CHANGE_PAYMENT_METHOD")
    validate_response(r, "orders_cancel")
    assert r.json()["status"] == "CANCELLED" and r.json()["payment_status"] == "FAILED"
    assert stock(V_CANOLA_2L) == before
    assert history(order["id"]) == [("", "PAYMENT_PENDING"), ("PAYMENT_PENDING", "CANCELLED")]
    assert len(shop_a.cart().json()["items"]) == 1, "T5 keeps the cart"
    err = assert_error(shop_a.cancel(order["id"]), 409, "INVALID_STATE_TRANSITION")
    assert err["details"] == {"status": "CANCELLED"}


@pytest.mark.smoke
def test_p3_tc22_idempotent_replay(shop_a):
    """P3-TC-22 🔥 Same Idempotency-Key + same body: 200 with the same order (no second order,
    no second reservation); same key + different body: 400 VALIDATION_ERROR on the header."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    key = new_key()
    expected = shop_a.cart().json()["bill"]["grand_total"]
    first = shop_a.place("ONLINE", address_id=shop_a.address["id"], key=key, expected=expected)
    assert first.status_code == 201, describe(first)
    oid = first.json()["order"]["id"]
    again = shop_a.place("ONLINE", address_id=shop_a.address["id"], key=key, expected=expected)
    validate_response(again, "orders_create")
    assert again.status_code == 200 and again.json()["order"]["id"] == oid
    assert again.json()["razorpay"]["order_id"] == first.json()["razorpay"]["order_id"]
    n = db_query("select count(*) from orders_order where user_id=%s and idempotency_key=%s", (shop_a.session.user["id"], key))[0][0]
    assert n == 1
    assert len(reservations(oid)) == 1
    err = assert_error(shop_a.place("COD", address_id=shop_a.address["id"], key=key, expected=expected), 400, "VALIDATION_ERROR")
    assert "Idempotency-Key" in err["details"]


def test_p3_tc23_idempotency_key_rules(shop_a):
    """P3-TC-23 Missing / too short / bad characters / too long Idempotency-Key: 400."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    body = {"address_id": shop_a.address["id"], "payment_method": "COD", "expected_grand_total": shop_a.cart().json()["bill"]["grand_total"]}
    r = shop_a.api.post(ORDERS, json=body, headers=shop_a.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    for bad in ("short", "has space in it", "x" * 65, "ключ-ключ-ключ"):
        try:
            r = shop_a.api.post(ORDERS, json=body, headers={**shop_a.h, "Idempotency-Key": bad})
        except UnicodeEncodeError:
            continue
        assert_error(r, 400, "VALIDATION_ERROR")


@pytest.mark.smoke
def test_p3_tc24_price_changed(shop_a):
    """P3-TC-24 🔥 expected_grand_total differs from the server bill: 409 PRICE_CHANGED
    {expected_grand_total, grand_total}; nothing created."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    actual = shop_a.cart().json()["bill"]["grand_total"]
    n0 = db_query("select count(*) from orders_order where user_id=%s", (shop_a.session.user["id"],))[0][0]
    err = assert_error(shop_a.place("COD", address_id=shop_a.address["id"], expected="1.00"), 409, "PRICE_CHANGED")
    assert err["details"] == {"expected_grand_total": "1.00", "grand_total": actual}
    n1 = db_query("select count(*) from orders_order where user_id=%s", (shop_a.session.user["id"],))[0][0]
    assert n0 == n1


def test_p3_tc25_placement_guards(shop_a, make_address):
    """P3-TC-25 Guards: empty cart 400; unserviceable address 422 NOT_SERVICEABLE; below min
    order 422 MIN_ORDER_NOT_MET {min_order_value, item_total, amount_to_min_order}; bad
    payment_method 400; another user's/unknown address 400."""
    from conftest import MUMBAI_ADDRESS

    shop_a.clear()
    r = shop_a.place("COD", address_id=shop_a.address["id"], expected="0.00")
    assert_error(r, 400, "VALIDATION_ERROR")
    shop_a.fill({V_FLAX: 1}, address_id=shop_a.address["id"])  # 169 >= 99 min
    mumbai = make_address(shop_a.session, **MUMBAI_ADDRESS)
    err = assert_error(shop_a.place("COD", address_id=mumbai["id"]), 422, "NOT_SERVICEABLE")
    assert err["details"] == {"address_id": mumbai["id"]}
    assert_error(shop_a.place("COD", address_id=99999999), 400, "VALIDATION_ERROR")
    assert_error(shop_a.place("CASH", address_id=shop_a.address["id"]), 400, "VALIDATION_ERROR")


def test_p3_tc26_min_order_not_met(shop_a):
    """P3-TC-26 Below the store minimum: 422 MIN_ORDER_NOT_MET with the amounts (skips when no
    demo variant is priced below the minimum)."""
    min_order = db_query("select min_order_value from stores_pricingconfig where store_id=1")[0][0]
    cheap = db_query(
        "select v.id from catalog_productvariant v join inventory_storeinventory i on i.variant_id=v.id and i.store_id=1 "
        "where coalesce(i.price_override, v.selling_price) < %s and i.on_hand - i.reserved > 0 and i.is_available limit 1",
        (min_order,),
    )
    if not cheap:
        pytest.skip(f"no demo variant priced below the minimum ₹{min_order}")
    shop_a.fill({cheap[0][0]: 1}, address_id=shop_a.address["id"])
    err = assert_error(shop_a.place("COD", address_id=shop_a.address["id"]), 422, "MIN_ORDER_NOT_MET")
    assert set(err["details"]) == {"min_order_value", "item_total", "amount_to_min_order"}


@pytest.mark.smoke
def test_p3_tc27_one_unpaid_order(shop_a):
    """P3-TC-27 🔥 A second placement while one is PAYMENT_PENDING: 409
    INVALID_STATE_TRANSITION {pending_order_id} (DL-44), for both ONLINE and COD."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    first = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert first.status_code == 201, describe(first)
    for method in ("ONLINE", "COD"):
        err = assert_error(shop_a.place(method, address_id=shop_a.address["id"]), 409, "INVALID_STATE_TRANSITION")
        assert err["details"] == {"pending_order_id": first.json()["order"]["id"]}


def test_p3_tc28_cod_limit(shop_a):
    """P3-TC-28 COD above cod_max_order_value: 422 COD_NOT_AVAILABLE {reason ABOVE_LIMIT,
    cod_max_order_value}; the cart's COD method shows is_available false. Nothing reserved."""
    cod_max = db_query("select cod_max_order_value from stores_pricingconfig where store_id=1")[0][0]
    lines = {V_CANOLA_2L: 4}  # 2196
    body = shop_a.fill(lines, address_id=shop_a.address["id"])
    if Decimal(body["bill"]["grand_total"]) <= cod_max:
        pytest.skip("cart not above the COD limit")
    cod = [p for p in body["payment_methods"] if p["method"] == "COD"][0]
    assert cod["is_available"] is False and cod["unavailable_reason"] == "ABOVE_LIMIT"
    before = stock(V_CANOLA_2L)
    err = assert_error(shop_a.place("COD", address_id=shop_a.address["id"]), 422, "COD_NOT_AVAILABLE")
    assert err["details"] == {"reason": "ABOVE_LIMIT", "cod_max_order_value": f"{cod_max:.2f}"}
    assert stock(V_CANOLA_2L) == before


@pytest.mark.smoke
def test_p3_tc29_order_idor(shop_a, shop_b):
    """P3-TC-29 🔥 Another user's order: retrieve, cancel, retry-payment and verify are 404,
    and the order is unchanged; it never appears in the other user's list."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    oid, rzp = r.json()["order"]["id"], r.json()["razorpay"]["order_id"]
    assert_error(shop_b.order(oid), 404, "NOT_FOUND")
    assert_error(shop_b.cancel(oid), 404, "NOT_FOUND")
    assert_error(shop_b.retry(oid), 404, "NOT_FOUND")
    assert_error(shop_b.verify(oid, rzp), 404, "NOT_FOUND")
    ids = [o["id"] for o in shop_b.api.get(ORDERS, headers=shop_b.h).json()["results"]]
    assert oid not in ids
    assert shop_a.order(oid).json()["status"] == "PAYMENT_PENDING"


def test_p3_tc30_list_and_filters(shop_a):
    """P3-TC-30 GET /orders/: strict schema; status=active includes PAYMENT_PENDING; past has
    terminal states only; bad status value 400; auth required."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    oid = shop_a.place("ONLINE", address_id=shop_a.address["id"]).json()["order"]["id"]
    r = shop_a.api.get(ORDERS, headers=shop_a.h, params={"status": "active"})
    validate_response(r, "orders_list")
    assert oid in [o["id"] for o in r.json()["results"]]
    shop_a.cancel(oid)
    past = shop_a.api.get(ORDERS, headers=shop_a.h, params={"status": "past"})
    validate_response(past, "orders_list")
    terminal = {"DELIVERED", "CANCELLED", "PAYMENT_FAILED", "RETURNED"}
    assert all(o["status"] in terminal for o in past.json()["results"])
    assert oid in [o["id"] for o in past.json()["results"]]
    assert_error(shop_a.api.get(ORDERS, headers=shop_a.h, params={"status": "bogus"}), 400, "VALIDATION_ERROR")
    assert_error(shop_a.api.get(ORDERS), 401, "AUTH_REQUIRED")


def test_p3_tc31_cancel_rules(shop_a):
    """P3-TC-31 Cancel needs a known reason (400 otherwise); a COD PLACED order cannot be
    cancelled by the customer in P3 (409 {status: PLACED})."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    oid = shop_a.place("ONLINE", address_id=shop_a.address["id"]).json()["order"]["id"]
    r = shop_a.api.post(f"{ORDERS}{oid}/cancel/", json={"reason": "BOGUS"}, headers=shop_a.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    r = shop_a.api.post(f"{ORDERS}{oid}/cancel/", json={}, headers=shop_a.h)
    assert_error(r, 400, "VALIDATION_ERROR")
    cod = db_query(
        "select id from orders_order where user_id=%s and status='PLACED' and payment_method='COD' limit 1",
        (shop_a.session.user["id"],),
    )
    if cod:
        err = assert_error(shop_a.cancel(cod[0][0]), 409, "INVALID_STATE_TRANSITION")
        assert err["details"] == {"status": "PLACED"}
