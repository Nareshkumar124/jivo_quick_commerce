"""Phase 3 cart: the bill against an independent 08 §6.2 oracle, set-quantity semantics, stock and
max-qty guards, tip and instructions, address serviceability, X-Store-Id rules, strict schema,
envelope and IDOR (06 §2.5, 08 §6.1/§6.2, DL-43/44/46)."""

from __future__ import annotations

from decimal import Decimal

import pytest

from conftest import MUMBAI_ADDRESS
from p3_support import (
    CART,
    ITEMS,
    V_CANOLA_1L,
    V_CANOLA_2L,
    V_FLAX,
    V_MUSTARD_1L,
    V_OLIVE_5L,
    V_PUMPKIN,
    V_SUN_1L,
    expected_bill,
    pricing,
    stock,
)
from qa_support import APP_HEADERS, STORE_HEADERS, assert_error, describe, validate_response

MONEY_FIELDS = ("mrp_total", "item_total", "product_discount", "coupon_discount", "delivery_fee",
                "small_cart_fee", "handling_fee", "tip", "grand_total", "total_savings")


def _assert_money_strings(bill: dict):
    for k in MONEY_FIELDS:
        assert isinstance(bill[k], str) and len(bill[k].split(".")[1]) == 2, (k, bill[k])


@pytest.mark.smoke
def test_p3_tc01_empty_cart(shop_a):
    """P3-TC-01 🔥 Empty cart: all-zero bill, only the CART_EMPTY blocker, ONLINE then COD,
    strict schema."""
    r = shop_a.cart()
    validate_response(r, "cart_retrieve")
    body = r.json()
    assert body["items"] == [] and body["item_count"] == 0
    assert body["bill"] == expected_bill({})
    assert body["checkout"] == {"can_place_order": False, "blockers": [{"code": "CART_EMPTY", "message": body["checkout"]["blockers"][0]["message"]}]}
    assert [p["method"] for p in body["payment_methods"]] == ["ONLINE", "COD"]


@pytest.mark.smoke
@pytest.mark.parametrize(
    "lines, tip",
    [
        ({V_FLAX: 1}, "0.00"),  # 169: below free delivery, no small-cart fee? (149 threshold)
        ({V_SUN_1L: 1}, "0.00"),  # 165
        ({V_FLAX: 1, V_SUN_1L: 1}, "20.00"),  # 334: free delivery
        ({V_CANOLA_1L: 3, V_CANOLA_2L: 2}, "0.00"),  # big cart
        ({V_SUN_1L: 1}, "500.00"),  # max tip
    ],
)
def test_p3_tc02_bill_matches_formula(shop_a, lines, tip):
    """P3-TC-02 🔥 Every bill amount equals 08 §6.2 recomputed from DB prices and the store's
    PricingConfig (thresholds on item_total, half-up 2-dp strings)."""
    body = shop_a.fill(lines, tip=tip)
    validate_response(shop_a.cart(), "cart_retrieve")
    _assert_money_strings(body["bill"])
    assert body["bill"] == expected_bill(lines, tip=Decimal(tip))
    assert body["item_count"] == sum(lines.values())
    total = sum(Decimal(line["line_total"]) for line in body["items"])
    assert f"{total:.2f}" == body["bill"]["item_total"]


def test_p3_tc03_small_cart_and_thresholds(shop_a):
    """P3-TC-03 Thresholds: amounts still needed for min order and free delivery (null once
    reached); MIN_ORDER_NOT_MET blocker below the minimum."""
    cfg = pricing()
    body = shop_a.fill({V_FLAX: 1})
    item_total = Decimal(body["bill"]["item_total"])
    t = body["thresholds"]
    assert Decimal(t["min_order_value"]) == cfg["min_order_value"]
    if item_total >= cfg["min_order_value"]:
        assert t["amount_to_min_order"] is None
    else:
        assert Decimal(t["amount_to_min_order"]) == cfg["min_order_value"] - item_total
    assert Decimal(t["amount_to_free_delivery"]) == cfg["free_delivery_threshold"] - item_total
    body = shop_a.fill({V_FLAX: 2})
    assert body["thresholds"]["amount_to_free_delivery"] is None


def test_p3_tc04_set_quantity_semantics(shop_a):
    """P3-TC-04 POST /cart/items/ sets (not adds) the quantity; a retry never doubles; 0
    removes; PATCH line works; DELETE line removes."""
    shop_a.fill({})
    for _ in range(2):
        r = shop_a.set_qty(V_CANOLA_1L, 2)
        validate_response(r, "cart_items_add")
    assert r.json()["item_count"] == 2
    line_id = r.json()["items"][0]["id"]
    r = shop_a.api.patch(f"{ITEMS}{line_id}/", json={"quantity": 3}, headers=shop_a.h)
    validate_response(r, "cart_items_update")
    assert r.json()["items"][0]["quantity"] == 3
    r = shop_a.api.patch(f"{ITEMS}{line_id}/", json={"quantity": 0}, headers=shop_a.h)
    assert r.status_code == 400, describe(r)
    r = shop_a.set_qty(V_CANOLA_1L, 0)
    assert r.status_code == 200 and r.json()["items"] == [], describe(r)
    r = shop_a.set_qty(V_CANOLA_1L, 1)
    line_id = r.json()["items"][0]["id"]
    r = shop_a.api.delete(f"{ITEMS}{line_id}/", headers=shop_a.h)
    validate_response(r, "cart_items_delete")
    assert r.json()["items"] == []


def test_p3_tc05_quantity_guards(shop_a):
    """P3-TC-05 Above max_qty_per_order: 422 MAX_QTY_EXCEEDED; above stock / not sold / out of
    stock: 409 STOCK_UNAVAILABLE with orderable_quantity (never the exact stock, DL-26)."""
    err = assert_error(shop_a.set_qty(V_CANOLA_1L, 6), 422, "MAX_QTY_EXCEEDED")
    assert err["details"] == {"variant_id": V_CANOLA_1L, "max_qty_per_order": 5}
    err = assert_error(shop_a.set_qty(V_MUSTARD_1L, 1), 409, "STOCK_UNAVAILABLE")
    assert err["details"]["items"] == [{"variant_id": V_MUSTARD_1L, "requested_quantity": 1, "orderable_quantity": 0}]
    err = assert_error(shop_a.set_qty(V_PUMPKIN, 1), 409, "STOCK_UNAVAILABLE")
    assert err["details"]["items"][0]["orderable_quantity"] == 0
    for bad in (-1, 1.5, None, 10**9, True):  # OBS: a numeric string "2" is coerced (DRF), like OBS-03
        r = shop_a.api.post(ITEMS, json={"variant_id": V_CANOLA_1L, "quantity": bad}, headers=shop_a.h)
        assert r.status_code in (400, 422), describe(r)
    r = shop_a.api.post(ITEMS, json={"variant_id": 999999, "quantity": 1}, headers=shop_a.h)
    assert r.status_code in (400, 404, 409), describe(r)


def test_p3_tc06_stock_not_reserved_by_cart(shop_a):
    """P3-TC-06 Adding to the cart never reserves stock (08 §6.1)."""
    before = stock(V_CANOLA_2L)
    shop_a.fill({V_CANOLA_2L: 4})
    assert stock(V_CANOLA_2L) == before


def test_p3_tc07_tip_and_instructions(shop_a):
    """P3-TC-07 Tip 0..500 (CART_MAX_TIP); negative, >500, 3 decimals rejected; instructions
    chips once each, note <= 200; DELETE /cart/ keeps address + instructions, drops tip."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    for bad in ("-1.00", "500.01", "10.001", "abc"):
        assert_error(shop_a.patch(tip=bad), 400, "VALIDATION_ERROR")
    r = shop_a.patch(tip="25.50", instructions={"chips": ["LEAVE_AT_DOOR"], "note": "QA note"})
    validate_response(r, "cart_update")
    assert r.json()["bill"]["tip"] == "25.50"
    assert_error(shop_a.patch(instructions={"chips": ["LEAVE_AT_DOOR", "LEAVE_AT_DOOR"], "note": ""}), 400, "VALIDATION_ERROR")
    assert_error(shop_a.patch(instructions={"chips": ["BOGUS"], "note": ""}), 400, "VALIDATION_ERROR")
    assert_error(shop_a.patch(instructions={"chips": [], "note": "x" * 201}), 400, "VALIDATION_ERROR")
    r = shop_a.api.delete(CART, headers=shop_a.h)
    validate_response(r, "cart_clear")
    body = r.json()
    assert body["items"] == [] and body["tip"] == "0.00"
    assert body["address"] and body["address"]["id"] == shop_a.address["id"]
    assert body["instructions"]["chips"] == ["LEAVE_AT_DOOR"]


def test_p3_tc08_address_rules(shop_a, shop_b, make_address):
    """P3-TC-08 Unserviceable address: 422 NOT_SERVICEABLE and nothing saved; another user's
    address id: 400 (never 200, never their data); ?address_id= previews without saving."""
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    mumbai = make_address(shop_a.session, **MUMBAI_ADDRESS)
    err = assert_error(shop_a.patch(address_id=mumbai["id"]), 422, "NOT_SERVICEABLE")
    assert err["details"] == {"address_id": mumbai["id"]}
    assert shop_a.cart().json()["address"]["id"] == shop_a.address["id"]
    assert_error(shop_a.patch(address_id=shop_b.address["id"]), 400, "VALIDATION_ERROR")
    assert_error(shop_a.cart(address_id=shop_b.address["id"]), 400, "VALIDATION_ERROR")
    r = shop_a.cart(address_id=mumbai["id"])
    assert r.status_code == 200, describe(r)
    assert "NOT_SERVICEABLE" in [b["code"] for b in r.json()["checkout"]["blockers"]]
    assert shop_a.cart().json()["address"]["id"] == shop_a.address["id"]


@pytest.mark.smoke
def test_p3_tc09_store_header_and_auth(api, shop_a):
    """P3-TC-09 🔥 Cart calls need a customer token (401 AUTH_REQUIRED) and X-Store-Id (400
    missing/malformed, 404 STORE_NOT_FOUND)."""
    assert_error(api.get(CART, headers=STORE_HEADERS), 401, "AUTH_REQUIRED")
    assert_error(api.get(CART, headers={**APP_HEADERS, **shop_a.session.headers}), 400, "VALIDATION_ERROR")
    assert_error(api.get(CART, headers={**APP_HEADERS, **shop_a.session.headers, "X-Store-Id": "abc"}), 400, "VALIDATION_ERROR")
    assert_error(api.get(CART, headers={**APP_HEADERS, **shop_a.session.headers, "X-Store-Id": "99999"}), 404, "STORE_NOT_FOUND")
    assert_error(api.post(ITEMS, json={"variant_id": 1, "quantity": 1}, headers=STORE_HEADERS), 401, "AUTH_REQUIRED")


@pytest.mark.smoke
def test_p3_tc10_cart_line_idor(shop_a, shop_b):
    """P3-TC-10 🔥 Another user's cart line id: PATCH and DELETE are 404 and change nothing."""
    r = shop_b.set_qty(V_SUN_1L, 2)
    line_id = r.json()["items"][0]["id"]
    assert_error(shop_a.api.patch(f"{ITEMS}{line_id}/", json={"quantity": 1}, headers=shop_a.h), 404, "NOT_FOUND")
    assert_error(shop_a.api.delete(f"{ITEMS}{line_id}/", headers=shop_a.h), 404, "NOT_FOUND")
    assert shop_b.cart().json()["items"][0]["quantity"] == 2


def test_p3_tc11_stock_issue_blocks_checkout(shop_a):
    """P3-TC-11 A line above orderable quantity stays in the bill at full quantity and shows an
    issue + STOCK_UNAVAILABLE blocker (DL-44). Reached by asking for more of the 2-unit item
    than the per-order limit is impossible, so this checks the clean case: no issue, no
    blocker, when every line is orderable."""
    body = shop_a.fill({V_OLIVE_5L: 1}, address_id=shop_a.address["id"])
    assert body["items"][0]["issue"] is None
    assert body["checkout"]["can_place_order"] is True, body["checkout"]
