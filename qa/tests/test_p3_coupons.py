"""Phase 3 coupons on the cart (06 §2.5 coupon rules, DL-45/46): apply/remove, case
insensitivity, FLAT/PERCENT maths with max_discount and the category eligible-subtotal cap,
min order (item_total before coupon), a coupon that stops applying, the coupon sheet, and the
coupon discount inside the 08 §6.2 bill. Uses the seeded demo coupons read-only (applying a
coupon to a cart consumes nothing)."""

from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal

import pytest

from p3_support import (
    COUPONS,
    V_CANOLA_1L,
    V_CANOLA_2L,
    V_CHIA,
    V_FLAX,
    V_SUN_1L,
    expected_bill,
    variant_prices,
)
from qa_support import assert_error, db_query, validate_response


def coupon(code: str) -> dict:
    row = db_query(
        "select discount_type, value, max_discount, min_order_value, first_order_only, is_active, is_visible "
        "from promotions_coupon where code=%s",
        (code,),
    )
    if not row:
        pytest.skip(f"demo coupon {code} not seeded")
    keys = ["discount_type", "value", "max_discount", "min_order_value", "first_order_only", "is_active", "is_visible"]
    return dict(zip(keys, row[0]))


def item_total(lines):
    prices = variant_prices(lines)
    return sum((prices[v][1] * q for v, q in lines.items()), Decimal("0"))


def expected_discount(code: str, eligible: Decimal) -> Decimal:
    c = coupon(code)
    if c["discount_type"] == "FLAT":
        d = c["value"]
    else:
        d = (eligible * c["value"] / 100).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    if c["max_discount"] is not None:
        d = min(d, c["max_discount"])
    return min(d, eligible)


@pytest.mark.smoke
def test_p3_tc12_flat_coupon_applied(shop_a):
    """P3-TC-12 🔥 FLAT coupon (JIVO50) case-insensitive: discount = value, bill per 08 §6.2
    with the coupon; DELETE is idempotent and restores the bill."""
    lines = {V_CANOLA_1L: 2}
    shop_a.fill(lines)
    r = shop_a.apply("jivo50")
    validate_response(r, "cart_coupon_apply")
    body = r.json()
    disc = expected_discount("JIVO50", item_total(lines))
    assert body["coupon"]["code"] == "JIVO50" and body["coupon"]["is_applicable"] is True
    assert body["bill"] == expected_bill(lines, coupon_discount=disc)
    for _ in range(2):
        r = shop_a.remove_coupon()
        validate_response(r, "cart_coupon_remove")
    assert r.json()["coupon"] is None and r.json()["bill"] == expected_bill(lines)


def test_p3_tc13_percent_coupon_capped(shop_a):
    """P3-TC-13 PERCENT coupon (JIVO10, 10% up to max_discount) on a big cart is capped at
    max_discount; on a smaller cart it is 10% half-up."""
    big = {V_CANOLA_2L: 4, V_CANOLA_1L: 5}  # 3591
    shop_a.fill(big)
    body = shop_a.apply("JIVO10").json()
    assert body["bill"]["coupon_discount"] == f"{expected_discount('JIVO10', item_total(big)):.2f}"
    assert Decimal(body["bill"]["coupon_discount"]) == coupon("JIVO10")["max_discount"]
    small = {V_CANOLA_2L: 1}  # 549 (>= 499)
    shop_a.fill(small)
    body = shop_a.apply("JIVO10").json()
    assert body["bill"] == expected_bill(small, coupon_discount=expected_discount("JIVO10", item_total(small)))


def test_p3_tc14_category_coupon_eligible_subtotal(shop_a):
    """P3-TC-14 Category coupon (OILS15, Edible Oils incl. sub-categories) computes on the
    eligible subtotal only (seeds excluded); a cart with no eligible item: 422
    COUPON_NOT_ELIGIBLE reason NO_ELIGIBLE_ITEMS."""
    lines = {V_SUN_1L: 1, V_FLAX: 2}  # 165 oil + 338 seeds
    shop_a.fill(lines)
    body = shop_a.apply("OILS15").json()
    eligible = item_total({V_SUN_1L: 1})
    disc = expected_discount("OILS15", eligible)
    assert body["bill"]["coupon_discount"] == f"{disc:.2f}", body["bill"]
    assert body["bill"] == expected_bill(lines, coupon_discount=disc)
    shop_a.remove_coupon()
    shop_a.fill({V_FLAX: 1, V_CHIA: 1})
    err = assert_error(shop_a.apply("OILS15"), 422, "COUPON_NOT_ELIGIBLE")
    assert err["details"].get("reason") == "NO_ELIGIBLE_ITEMS", err


def test_p3_tc15_min_order_value(shop_a):
    """P3-TC-15 Below min_order_value (compared to item_total before the coupon): 422
    COUPON_NOT_ELIGIBLE {reason MIN_ORDER_VALUE, min_order_value, amount_to_unlock}."""
    lines = {V_SUN_1L: 1}  # 165 < 299
    shop_a.fill(lines)
    err = assert_error(shop_a.apply("JIVO50"), 422, "COUPON_NOT_ELIGIBLE")
    c = coupon("JIVO50")
    assert err["details"]["reason"] == "MIN_ORDER_VALUE"
    assert Decimal(err["details"]["min_order_value"]) == c["min_order_value"]
    assert Decimal(err["details"]["amount_to_unlock"]) == c["min_order_value"] - item_total(lines)


def test_p3_tc16_coupon_stops_applying(shop_a):
    """P3-TC-16 A coupon that stops applying after items are removed stays on the cart with
    is_applicable false, discount 0, amount_to_unlock, and a coupon checkout blocker."""
    shop_a.fill({V_CANOLA_1L: 2}, address_id=shop_a.address["id"])
    assert shop_a.apply("JIVO50").status_code == 200
    body = shop_a.set_qty(V_CANOLA_1L, 1).json()  # 279 < 299
    assert body["coupon"]["code"] == "JIVO50"
    assert body["coupon"]["is_applicable"] is False
    assert body["coupon"]["discount"] == "0.00" and body["bill"]["coupon_discount"] == "0.00"
    assert body["coupon"]["amount_to_unlock"] == "20.00"
    codes = [b["code"] for b in body["checkout"]["blockers"]]
    assert "COUPON_NOT_ELIGIBLE" in codes and body["checkout"]["can_place_order"] is False


def test_p3_tc17_unknown_and_malformed_codes(shop_a):
    """P3-TC-17 Unknown code: 422 COUPON_INVALID; empty/oversized/non-string code: 400."""
    shop_a.fill({V_CANOLA_1L: 2})
    assert_error(shop_a.apply("QA-NO-SUCH-CODE"), 422, "COUPON_INVALID")
    for bad in ("", "x" * 500, 123, None):
        r = shop_a.api.post("/api/v1/cart/coupon/", json={"code": bad}, headers=shop_a.h)
        assert r.status_code in (400, 422), r.text
        assert r.json()["error"]["code"] in ("VALIDATION_ERROR", "COUPON_INVALID")


def test_p3_tc18_coupon_sheet(shop_a):
    """P3-TC-18 GET /cart/coupons/: strict schema; visible coupons only (hidden JIVOSTAFF not
    listed); eligible first; savings equal the discount the coupon would give; is_applied."""
    lines = {V_CANOLA_1L: 2}
    shop_a.fill(lines)
    shop_a.apply("JIVO50")
    r = shop_a.api.get(COUPONS, headers=shop_a.h)
    validate_response(r, "cart_coupons_list")
    results = r.json()["results"]
    codes = [c["code"] for c in results]
    assert "JIVOSTAFF" not in codes
    flags = [c["is_eligible"] for c in results]
    assert flags == sorted(flags, reverse=True), "eligible coupons first"
    by_code = {c["code"]: c for c in results}
    assert by_code["JIVO50"]["is_applied"] is True
    for code, c in by_code.items():
        if c["is_eligible"] and code != "WELCOME100":
            assert Decimal(c["savings"]) == expected_discount(code, item_total(lines) if code != "OILS15" else item_total(lines)), code
    eligible = [Decimal(c["savings"]) for c in results if c["is_eligible"]]
    assert eligible == sorted(eligible, reverse=True), "eligible sorted by savings"


def test_p3_tc19_coupon_auth_and_store(api, shop_a):
    """P3-TC-19 Coupon endpoints need a token and X-Store-Id."""
    from qa_support import APP_HEADERS, STORE_HEADERS

    assert_error(api.get(COUPONS, headers=STORE_HEADERS), 401, "AUTH_REQUIRED")
    assert_error(api.post("/api/v1/cart/coupon/", json={"code": "JIVO50"}, headers=STORE_HEADERS), 401, "AUTH_REQUIRED")
    assert_error(api.get(COUPONS, headers={**APP_HEADERS, **shop_a.session.headers}), 400, "VALIDATION_ERROR")


def test_p3_tc55_first_order_only(shop_a, shop_factory):
    """P3-TC-55 WELCOME100 (first_order_only): a customer with an earlier order that reached
    PLACED gets 422 COUPON_NOT_ELIGIBLE reason FIRST_ORDER_ONLY; a customer whose orders never
    reached PLACED (only cancelled unpaid ones) is still eligible (DL-45)."""
    lines = {V_CANOLA_2L: 1}  # 549 >= 399
    placed = db_query(
        "select count(*) from orders_order where user_id=%s and placed_at is not null", (shop_a.session.user["id"],)
    )[0][0]
    if not placed:
        pytest.skip("user A has no PLACED order yet (run test_p3_orders first)")
    shop_a.fill(lines)
    err = assert_error(shop_a.apply("WELCOME100"), 422, "COUPON_NOT_ELIGIBLE")
    assert err["details"]["reason"] == "FIRST_ORDER_ONLY", err
    shop_c = shop_factory("c")
    never = db_query(
        "select count(*) from orders_order where user_id=%s and placed_at is not null", (shop_c.session.user["id"],)
    )[0][0]
    if never:
        pytest.skip("user C already has a PLACED order")
    shop_c.fill(lines)
    r = shop_c.apply("WELCOME100")
    assert r.status_code == 200 and r.json()["coupon"]["is_applicable"] is True, r.text
