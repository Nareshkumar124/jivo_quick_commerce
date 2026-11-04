"""Phase 4 store operations (QA T-416): 08 T6, T7, T8, T8a, T12; §6.1, §6.3, §6.4; 05 §3 rows
for order processing, cancel and refund; refunds (retry, sync, the customer's PENDING view).

Stage 1 (2026-11-04, develop 74f47d1): the backend P4 R2 is merged, the admin P4 (Ops Console
pages) is not. Staff actions are therefore driven through the backend services the console will
call (`apps.orders.store_ops`, `apps.payments.order_refunds`) by `qa/tools/store_ops_driver.py`,
as the seeded staff users, against the same DB and QA Redis/broker as the :8004 instance. The
customer-side effects are checked black-box through the :8004 API, money and stock by read-only
SQL. Console-only aspects (pages, HTMX partials, CSRF, hidden buttons) stay skipped until the
admin P4 merges (`CONSOLE`).
"""

from __future__ import annotations

import time
from decimal import Decimal

import pytest

from p3_support import V_CANOLA_1L, V_FLAX, V_SUN_1L, money, stock
from p4_support import (
    CATALOG,
    FINANCE,
    MANAGER,
    OPS,
    STAFF,
    SUPER,
    SUPPORT,
    audit_rows,
    history,
    op,
    ops,
    order_row,
    refunds,
    t8a_oracle,
)
from qa_support import db_query, describe, validate_response
from test_p4_orders import cod_order, paid_online, wait_refunded

CONSOLE = pytest.mark.skip(reason="Ops Console P4 (admin) not merged yet: console UI case")
SACHET = 25  # JV-WG-PW-10S, ₹45 (seed_demo, P4)


def as_(who: str, action: str, order_id: int, **kw) -> dict:
    return op(op=action, **{"as": who}, order_id=order_id, **kw)


def items_of(shop, order_id: int) -> dict[int, dict]:
    return {line["variant_id"]: line for line in shop.order(order_id).json()["items"]}


def accept_and_pack(order_id: int) -> None:
    res = ops({"op": "accept", "as": STAFF, "order_id": order_id}, {"op": "start_packing", "as": STAFF, "order_id": order_id})
    assert all(r["ok"] for r in res), res


# --------------------------------------------------------------------------- T6 / T7 / T8


@pytest.mark.smoke
def test_p4_tc19_accept_t6(shop_a):
    """P4-TC-19 🔥 Store Staff accepts a PLACED COD order (T6): ACCEPTED; history row with
    actor_type store; one audit row; customer timeline adds "Order confirmed"; a second accept is
    refused (INVALID_STATE_TRANSITION) and writes no second history row."""
    o = cod_order(shop_a)
    try:
        r = as_(STAFF, "accept", o["id"])
        assert r["ok"] and r["result"]["status"] == "ACCEPTED", r
        assert len(r["result"]["pickup_code"]) == 4
        assert history(o["id"])[-1] == ("PLACED", "ACCEPTED", "store")
        assert [a[0] for a in audit_rows(o["id"])] == ["order.accept"]
        body = shop_a.order(o["id"])
        validate_response(body, "orders_retrieve")
        tl = body.json()["timeline"]
        assert tl[-1]["status"] == "ACCEPTED" and tl[-1]["title"].startswith("Order confirmed")
        again = as_(STAFF, "accept", o["id"])
        assert again["code"] == "INVALID_STATE_TRANSITION" and again["details"] == {"status": "ACCEPTED"}
        assert len([h for h in history(o["id"]) if h[1] == "ACCEPTED"]) == 1
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


@pytest.mark.smoke
def test_p4_tc20_start_packing_and_pack_t7_t8(shop_a):
    """P4-TC-20 🔥 T7 then T8: PACKING then PACKED; the pickup code stays; can_cancel false
    from PACKING; history actor_type store; the customer timeline shows both steps."""
    o = cod_order(shop_a)
    try:
        code = as_(STAFF, "accept", o["id"])["result"]["pickup_code"]
        r = as_(STAFF, "start_packing", o["id"])
        assert r["ok"] and r["result"]["status"] == "PACKING"
        assert shop_a.order(o["id"]).json()["can_cancel"] is False
        r = as_(STAFF, "packed", o["id"])
        assert r["ok"] and r["result"]["status"] == "PACKED" and r["result"]["pickup_code"] == code
        assert [h[1] for h in history(o["id"])][-3:] == ["ACCEPTED", "PACKING", "PACKED"]
        assert {h[2] for h in history(o["id"])[-3:]} == {"store"}
        statuses = [t["status"] for t in shop_a.order(o["id"]).json()["timeline"]]
        assert statuses[-3:] == ["ACCEPTED", "PACKING", "PACKED"]
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


def test_p4_tc21_transition_guards(shop_a):
    """P4-TC-21 Out-of-order actions are refused with INVALID_STATE_TRANSITION and change
    nothing: pack / start packing from PLACED, pack from ACCEPTED, accept a PACKING order, every
    action on CANCELLED and on PAYMENT_PENDING."""
    o = cod_order(shop_a)
    h0 = len(history(o["id"]))
    res = ops(
        {"op": "packed", "as": STAFF, "order_id": o["id"]},
        {"op": "start_packing", "as": STAFF, "order_id": o["id"]},
        {"op": "accept", "as": STAFF, "order_id": o["id"]},
        {"op": "packed", "as": STAFF, "order_id": o["id"]},
        {"op": "start_packing", "as": STAFF, "order_id": o["id"]},
        {"op": "accept", "as": STAFF, "order_id": o["id"]},
    )
    assert [r.get("code") for r in res] == ["INVALID_STATE_TRANSITION", "INVALID_STATE_TRANSITION", None,
                                             "INVALID_STATE_TRANSITION", None, "INVALID_STATE_TRANSITION"], res
    assert len(history(o["id"])) == h0 + 2
    assert as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")["ok"]
    for action in ("accept", "start_packing", "packed", "cancel"):
        r = as_(MANAGER, action, o["id"], **({"reason": "OTHER_STAFF"} if action == "cancel" else {}))
        assert r["code"] == "INVALID_STATE_TRANSITION", (action, r)
    # PAYMENT_PENDING (an unpaid ONLINE order)
    shop_a.fill({V_SUN_1L: 1}, address_id=shop_a.address["id"])
    p = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert p.status_code == 201, describe(p)
    pid = p.json()["order"]["id"]
    for action in ("accept", "start_packing", "packed", "cancel"):
        r = as_(MANAGER, action, pid, **({"reason": "OTHER_STAFF"} if action == "cancel" else {}))
        assert r["code"] == "INVALID_STATE_TRANSITION", (action, r)
    r = as_(STAFF, "unavailable", pid, item_id=items_of(shop_a, pid)[V_SUN_1L]["id"], unavailable=1)
    assert r["code"] == "INVALID_STATE_TRANSITION"
    assert shop_a.order(pid).json()["status"] == "PAYMENT_PENDING"


# --------------------------------------------------------------------------- T8a


@pytest.mark.smoke
def test_p4_tc22_item_unavailable_online(shop_a):
    """P4-TC-22 🔥 T8a on a paid ONLINE order in PACKING (2× Sun 1L + 1× Canola 1L): 1 of the 2
    Sun units unavailable. Bill = independent oracle (08 §6.3); one ITEMS_UNAVAILABLE refund of
    old − new grand_total; reserved −1; quantity_unavailable 1; line_total and item_count count
    the units coming; amount_paid unchanged; the same adjustment again changes nothing."""
    o = paid_online(shop_a, {V_SUN_1L: 2, V_CANOLA_1L: 1})
    try:
        accept_and_pack(o["id"])
        old = order_row(o["id"])
        lines = items_of(shop_a, o["id"])
        sun, can = lines[V_SUN_1L], lines[V_CANOLA_1L]
        expected = t8a_oracle(old, [(money(sun["mrp"]), money(sun["selling_price"]), 1), (money(can["mrp"]), money(can["selling_price"]), 1)])
        reserved = stock(V_SUN_1L)[1]
        r = as_(STAFF, "unavailable", o["id"], item_id=sun["id"], unavailable=1)
        assert r["ok"], r
        new = order_row(o["id"])
        for k in ("mrp_total", "item_total", "coupon_discount", "delivery_fee", "small_cart_fee", "handling_fee", "tip", "grand_total"):
            assert money(new[k]) == expected[k], (k, new[k], expected[k])
        assert new["amount_paid"] == old["amount_paid"] == money(o["bill"]["grand_total"])
        rows = refunds(o["id"])
        assert len(rows) == 1 and rows[0][1] == expected["refund"] and rows[0][3] == "item_unavailable"
        assert stock(V_SUN_1L)[1] == reserved - 1
        body = shop_a.order(o["id"])
        validate_response(body, "orders_retrieve")
        b = body.json()
        sl = {x["variant_id"]: x for x in b["items"]}[V_SUN_1L]
        assert sl["quantity"] == 2 and sl["quantity_unavailable"] == 1 and money(sl["line_total"]) == money(sun["selling_price"])
        assert b["item_count"] == 2 and b["bill"]["grand_total"] == f"{expected['grand_total']:.2f}"
        assert [x["reason"] for x in b["refunds"]] == ["ITEMS_UNAVAILABLE"]
        again = as_(STAFF, "unavailable", o["id"], item_id=sun["id"], unavailable=1)
        assert again["ok"] and len(refunds(o["id"])) == 1
        assert [a[0] for a in audit_rows(o["id"])].count("order.items_unavailable") == 1
        done = wait_refunded(shop_a, o["id"])
        assert done["payment_status"] == "PARTIALLY_REFUNDED" and money(done["amount_refunded"]) == expected["refund"]
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")
    # After the cancel: the rest is refunded, never more than paid.
    final = wait_refunded(shop_a, o["id"], timeout=60)
    total = sum((money(x["amount"]) for x in final["refunds"]), Decimal("0"))
    assert total == money(o["bill"]["grand_total"]), final["refunds"]


def test_p4_tc23_item_unavailable_cod(shop_a):
    """P4-TC-23 T8a on a COD order: amount due reduced per the oracle; no Refund row;
    payment_status still COD_PENDING; reserved −1."""
    o = cod_order(shop_a, {V_SUN_1L: 2, V_CANOLA_1L: 1})
    try:
        accept_and_pack(o["id"])
        old = order_row(o["id"])
        lines = items_of(shop_a, o["id"])
        sun, can = lines[V_SUN_1L], lines[V_CANOLA_1L]
        expected = t8a_oracle(old, [(money(sun["mrp"]), money(sun["selling_price"]), 1), (money(can["mrp"]), money(can["selling_price"]), 1)])
        reserved = stock(V_SUN_1L)[1]
        assert as_(STAFF, "unavailable", o["id"], item_id=sun["id"], unavailable=1)["ok"]
        new = order_row(o["id"])
        assert money(new["grand_total"]) == expected["grand_total"]
        assert new["payment_status"] == "COD_PENDING" and refunds(o["id"]) == []
        assert stock(V_SUN_1L)[1] == reserved - 1
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


def test_p4_tc24_all_units_unavailable_cancels(shop_a):
    """P4-TC-24 T8a removing every unit (two steps: Sun 1 of 1, then Canola 1 of 1): the order is
    CANCELLED (ITEMS_UNAVAILABLE, cancelled_by store); ONLINE refunds total = amount paid, never
    more; the whole reservation is released; the last line keeps its quantities."""
    before_sun, before_can = stock(V_SUN_1L), stock(V_CANOLA_1L)
    o = paid_online(shop_a, {V_SUN_1L: 1, V_CANOLA_1L: 1})
    accept_and_pack(o["id"])
    lines = items_of(shop_a, o["id"])
    assert as_(STAFF, "unavailable", o["id"], item_id=lines[V_SUN_1L]["id"], unavailable=1)["ok"]
    r = as_(STAFF, "unavailable", o["id"], item_id=lines[V_CANOLA_1L]["id"], unavailable=1)
    assert r["ok"] and r["result"]["status"] == "CANCELLED", r
    row = order_row(o["id"])
    assert row["cancel_reason"] == "ITEMS_UNAVAILABLE" and row["cancelled_by_type"] == "store"
    assert stock(V_SUN_1L) == before_sun and stock(V_CANOLA_1L) == before_can
    done = wait_refunded(shop_a, o["id"])
    total = sum((money(x["amount"]) for x in done["refunds"]), Decimal("0"))
    assert total == money(o["bill"]["grand_total"]) == money(row["amount_paid"])
    assert done["payment_status"] == "REFUNDED" and done["cancellation"]["cancelled_by"] == "store"


def test_p4_tc25_fees_never_increase(shop_a):
    """P4-TC-25 T8a dropping item_total below free delivery (299) and below the small-cart
    threshold (149): Sun 1L (165) + 3 sachets (135) = 300 → Sun unavailable → 135. The delivery
    and small-cart fees are not charged (capped at the old 0.00); new grand_total ≤ old; the
    refund = old − new."""
    o = paid_online(shop_a, {V_SUN_1L: 1, SACHET: 3})
    try:
        accept_and_pack(o["id"])
        old = order_row(o["id"])
        assert old["delivery_fee"] == 0 and old["small_cart_fee"] == 0
        lines = items_of(shop_a, o["id"])
        sa = lines[SACHET]
        expected = t8a_oracle(old, [(money(sa["mrp"]), money(sa["selling_price"]), 3)])
        assert as_(STAFF, "unavailable", o["id"], item_id=lines[V_SUN_1L]["id"], unavailable=1)["ok"]
        new = order_row(o["id"])
        assert new["delivery_fee"] == 0 and new["small_cart_fee"] == 0
        assert money(new["grand_total"]) == expected["grand_total"] <= money(old["grand_total"])
        assert [r[1] for r in refunds(o["id"])] == [expected["refund"]]
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


def test_p4_tc26_coupon_kept_after_unavailability(shop_a):
    """P4-TC-26 FLAT coupon JIVO50 (min 299) on 2× Sun (330): T8a of 1 unit (165, below the
    minimum): discount 50 kept (≤ new item_total); redemption stays APPLIED (REVERSED after the cancel); grand_total per
    the oracle."""
    shop_a.fill({V_SUN_1L: 2}, address_id=shop_a.address["id"])
    ap = shop_a.apply("JIVO50")
    if ap.status_code != 200:
        pytest.skip(f"JIVO50 not applicable to QA user A now: {describe(ap)}")
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"])
    assert r.status_code == 201, describe(r)
    order, rzp = r.json()["order"], r.json()["razorpay"]
    v = shop_a.verify(order["id"], rzp["order_id"])
    assert v.status_code == 200, describe(v)
    oid = order["id"]
    try:
        accept_and_pack(oid)
        old = order_row(oid)
        assert old["coupon_discount"] == Decimal("50.00")
        sun = items_of(shop_a, oid)[V_SUN_1L]
        expected = t8a_oracle(old, [(money(sun["mrp"]), money(sun["selling_price"]), 1)])
        assert as_(STAFF, "unavailable", oid, item_id=sun["id"], unavailable=1)["ok"]
        new = order_row(oid)
        assert new["coupon_discount"] == Decimal("50.00") and money(new["grand_total"]) == expected["grand_total"]
        red = db_query("select status from promotions_couponredemption where order_id=%s", (oid,))
        assert red and red[0][0] == "APPLIED", red  # 07: HELD/APPLIED/RELEASED/REVERSED
    finally:
        as_(MANAGER, "cancel", oid, reason="OTHER_STAFF")
    assert db_query("select status from promotions_couponredemption where order_id=%s", (oid,))[0][0] == "REVERSED"


def test_p4_tc27_unavailability_guards(shop_a, shop_b):
    """P4-TC-27 T8a refused, nothing changed: on PACKED; unavailable > quantity; negative; a
    bool; lowering an earlier mark; an item of another order. The same value twice refunds once
    (TC-22)."""
    o = paid_online(shop_a, {V_SUN_1L: 2})
    other = cod_order(shop_b, {V_FLAX: 1})
    try:
        accept_and_pack(o["id"])
        sun = items_of(shop_a, o["id"])[V_SUN_1L]
        other_item = items_of(shop_b, other["id"])[V_FLAX]["id"]
        res = ops(
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": 3},
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": -1},
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": True},
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": other_item, "unavailable": 1},
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": 1},
            {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": 0},
            {"op": "packed", "as": STAFF, "order_id": o["id"]},
        )
        assert [r["ok"] for r in res] == [False, False, False, False, True, False, True], res
        assert all(r["error"] == "ValidationError" for r in res[:4] + [res[5]])
        r = as_(STAFF, "unavailable", o["id"], item_id=sun["id"], unavailable=2)
        assert r["code"] == "INVALID_STATE_TRANSITION"
        assert len(refunds(o["id"])) == 1 and items_of(shop_b, other["id"])[V_FLAX]["quantity_unavailable"] == 0
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")
        shop_b.cancel(other["id"])


# --------------------------------------------------------------------------- T12


@pytest.mark.parametrize("state", ["PLACED", "ACCEPTED", "PACKING", "PACKED"])
def test_p4_tc28_staff_cancel_t12(shop_a, state):
    """P4-TC-28 Store Manager cancels a paid ONLINE order in each state (T12): CANCELLED,
    cancelled_by store; full refund; reservation released with no StockMovement and no on_hand
    change; audit row order.cancel. Ops cancels a COD one (cancelled_by ops)."""
    before = stock(V_SUN_1L)
    moves = db_query("select count(*) from inventory_stockmovement")[0][0]
    o = paid_online(shop_a)
    steps = {"PLACED": [], "ACCEPTED": ["accept"], "PACKING": ["accept", "start_packing"], "PACKED": ["accept", "start_packing", "packed"]}[state]
    if steps:
        assert all(r["ok"] for r in ops(*[{"op": s, "as": STAFF, "order_id": o["id"]} for s in steps]))
    r = as_(MANAGER, "cancel", o["id"], reason="STORE_CLOSING", note="QA")
    assert r["ok"] and r["result"]["status"] == "CANCELLED", r
    assert order_row(o["id"])["cancelled_by_type"] == "store"
    assert stock(V_SUN_1L) == before
    assert db_query("select count(*) from inventory_stockmovement")[0][0] == moves
    assert audit_rows(o["id"])[-1][0] == "order.cancel"
    done = wait_refunded(shop_a, o["id"])
    assert done["payment_status"] == "REFUNDED" and done["amount_refunded"] == o["bill"]["grand_total"]
    assert done["cancellation"]["cancelled_by"] == "store"
    if state == "PLACED":
        c = cod_order(shop_a)
        r = as_(OPS, "cancel", c["id"], reason="SUSPECTED_FRAUD")
        assert r["ok"] and order_row(c["id"])["cancelled_by_type"] == "ops"
        assert shop_a.order(c["id"]).json()["payment_status"] == "FAILED"


def test_p4_tc29_staff_cancel_requires_reason(shop_a):
    """P4-TC-29 Staff cancel without a reason, or with a customer-only reason: refused."""
    o = cod_order(shop_a)
    try:
        for reason in ("", "CHANGED_MIND", "ORDERED_BY_MISTAKE", "BOGUS"):
            r = as_(MANAGER, "cancel", o["id"], reason=reason)
            assert not r["ok"] and r["error"] == "ValidationError", (reason, r)
        assert order_row(o["id"])["status"] == "PLACED"
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


# --------------------------------------------------------------------------- roles (service level)


@pytest.mark.smoke
def test_p4_tc31_role_matrix_service_level(shop_a):
    """P4-TC-31 🔥 (service level; the console pages are checked when admin P4 merges) 05 §3:
    process (accept/pack/unavailable): Super, Ops, Store Manager, Store Staff; not Catalog,
    Support, Finance. Cancel: Super, Ops, Store Manager, Support; not Store Staff, Catalog,
    Finance. Manual refund: Super, Support (≤ limit), Finance; not Ops, Store Manager, Store
    Staff, Catalog."""
    o = cod_order(shop_a)
    try:
        denied = ops(*[{"op": "accept", "as": who, "order_id": o["id"]} for who in (CATALOG, SUPPORT, FINANCE)])
        assert [r.get("error") for r in denied] == ["PermissionDenied"] * 3, denied
        denied = ops(*[{"op": "cancel", "as": who, "order_id": o["id"], "reason": "OTHER_STAFF"} for who in (STAFF, CATALOG, FINANCE)])
        assert [r.get("error") for r in denied] == ["PermissionDenied"] * 3, denied
        assert order_row(o["id"])["status"] == "PLACED"
        for who in (SUPER, OPS, MANAGER):
            c = cod_order(shop_a)
            assert as_(who, "accept", c["id"])["ok"], who
            assert as_(SUPPORT if who == SUPER else who, "cancel", c["id"], reason="OTHER_STAFF")["ok"], who
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")
    p = paid_online(shop_a)
    try:
        denied = ops(*[{"op": "manual_refund", "as": who, "order_id": p["id"], "amount": "1.00"} for who in (OPS, MANAGER, STAFF, CATALOG)])
        assert [r.get("error") for r in denied] == ["PermissionDenied"] * 4, denied
        assert refunds(p["id"]) == []
    finally:
        as_(MANAGER, "cancel", p["id"], reason="OTHER_STAFF")


# --------------------------------------------------------------------------- refunds


def test_p4_tc32_support_refund_limit_and_cap(shop_a):
    """P4-TC-32 Support: 500.01 refused (limit), 500.00 allowed; Finance: no limit; a refund
    above what is refundable is refused (cap); refunds never exceed amount_paid. Order of
    2× Olive... uses 4× Canola 2L-free variants: 3× Canola 1L (837) paid online."""
    o = paid_online(shop_a, {V_CANOLA_1L: 3})
    paid = money(o["bill"]["grand_total"])
    try:
        r = ops(
            {"op": "manual_refund", "as": SUPPORT, "order_id": o["id"], "amount": "500.01"},
            {"op": "manual_refund", "as": SUPPORT, "order_id": o["id"], "amount": "500.00"},
            {"op": "manual_refund", "as": FINANCE, "order_id": o["id"], "amount": str(paid - Decimal("500.00") + Decimal("0.01"))},
            {"op": "manual_refund", "as": FINANCE, "order_id": o["id"], "amount": str(paid - Decimal("500.00"))},
            {"op": "manual_refund", "as": SUPER, "order_id": o["id"], "amount": "0.01"},
        )
        assert [x["ok"] for x in r] == [False, True, False, True, False], r
        assert "at most" in r[0]["message"] and "At most" in r[2]["message"]
        rows = refunds(o["id"])
        assert sum((x[1] for x in rows), Decimal("0")) == paid and len(rows) == 2
        done = wait_refunded(shop_a, o["id"])
        assert done["payment_status"] == "REFUNDED" and money(done["amount_refunded"]) == paid
        assert {x["reason"] for x in done["refunds"]} == {"GOODWILL"}
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")
    assert len(refunds(o["id"])) == 2  # the cancel adds no refund: nothing left to refund


def test_p4_tc33_manual_partial_then_full(shop_a):
    """P4-TC-33 Manual partial (GOODWILL) → PARTIALLY_REFUNDED; then the rest → REFUNDED;
    amount_refunded = sum of processed refunds."""
    o = paid_online(shop_a)
    paid = money(o["bill"]["grand_total"])
    try:
        assert as_(FINANCE, "manual_refund", o["id"], amount="40.00")["ok"]
        mid = wait_refunded(shop_a, o["id"])
        assert mid["payment_status"] == "PARTIALLY_REFUNDED" and mid["amount_refunded"] == "40.00"
        assert as_(FINANCE, "manual_refund", o["id"], amount=str(paid - Decimal("40.00")))["ok"]
        end = time.monotonic() + 60
        while time.monotonic() < end and shop_a.order(o["id"]).json()["payment_status"] != "REFUNDED":
            time.sleep(2)
        done = shop_a.order(o["id"]).json()
        assert done["payment_status"] == "REFUNDED" and money(done["amount_refunded"]) == paid
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


def test_p4_tc34_retry_only_failed(shop_a):
    """P4-TC-34 (part) Retry is refused for a PROCESSED refund and for a fresh PENDING one (not
    stuck). The FAILED path needs a gateway refusal (refund.failed webhook): see the report."""
    o = paid_online(shop_a)
    as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")
    rid = refunds(o["id"])[0][0]
    r = op(op="retry_refund", **{"as": FINANCE}, refund_id=rid)
    assert not r["ok"] and r["error"] == "ValidationError", r
    wait_refunded(shop_a, o["id"])
    r = op(op="retry_refund", **{"as": FINANCE}, refund_id=rid)
    assert not r["ok"], r
    r = op(op="retry_refund", **{"as": OPS}, refund_id=rid)
    assert r["error"] == "PermissionDenied", r


# --------------------------------------------------------------------------- not yet runnable


@pytest.mark.skip(reason="runs on QA-02 in test_p4_console.py::test_p4_tc30_store_scoping (stage 2)")
def test_p4_tc30_store_scoping():
    """P4-TC-30 🔥 Store Staff / Manager of GGN-01 act on another store's order: not found."""


@pytest.mark.skip(reason="runs on QA-02 in test_p4_console.py::test_p4_tc36_auto_accept_qa02 (stage 2)")
def test_p4_tc36_auto_accept():
    """P4-TC-36 auto-accept after AUTO_ACCEPT_DELAY_SECONDS, history actor_type system."""


def test_p4_tc37_acceptance_sla_alert(shop_a):
    """P4-TC-37 A PLACED order older than STORE_ACCEPTANCE_SLA_SECONDS (60 s) is alerted once
    (`alerted`, then `already`); a fresh order is `not_due`; an accepted one `skipped`."""
    o = cod_order(shop_a)
    try:
        assert op(op="sla_alert", order_id=o["id"])["result"] in ("not_due", "alerted", "already")
        time.sleep(62)
        first = op(op="sla_alert", order_id=o["id"])["result"]
        # The :8001 beat sweep (shared DB) may have alerted first through its own Redis.
        assert first in ("alerted", "already"), first
        assert op(op="sla_alert", order_id=o["id"])["result"] == "already"
        as_(STAFF, "accept", o["id"])
        assert op(op="sla_alert", order_id=o["id"])["result"] == "skipped"
    finally:
        as_(MANAGER, "cancel", o["id"], reason="OTHER_STAFF")


@CONSOLE
def test_p4_tc38_live_board():
    """P4-TC-38 /ops/orders/live/ columns, filters, HTMX poll, masked phone."""


@CONSOLE
def test_p4_tc39_packing_console_page():
    """P4-TC-39 /ops/store/<store>/ queue, pick list, slip, accepting switch."""


@CONSOLE
def test_p4_tc40_orders_admin():
    """P4-TC-40 Orders admin filters, detail, actions, CSV export escaping."""


@pytest.mark.smoke
def test_p4_tc41_audit_rows_service_level(shop_a):
    """P4-TC-41 🔥 (service level) accept, start packing, unavailable, packed, cancel and refund
    each write exactly one audit row with the acting staff user and no customer PII (no phone,
    name or address in `changes`). The audit-log page (read-only, Super/Finance) is a console
    case."""
    o = paid_online(shop_a, {V_SUN_1L: 2})
    sun = items_of(shop_a, o["id"])[V_SUN_1L]
    res = ops(
        {"op": "accept", "as": STAFF, "order_id": o["id"]},
        {"op": "start_packing", "as": STAFF, "order_id": o["id"]},
        {"op": "unavailable", "as": STAFF, "order_id": o["id"], "item_id": sun["id"], "unavailable": 1},
        {"op": "packed", "as": STAFF, "order_id": o["id"]},
        {"op": "manual_refund", "as": SUPPORT, "order_id": o["id"], "amount": "1.00"},
        {"op": "cancel", "as": MANAGER, "order_id": o["id"], "reason": "OTHER_STAFF", "note": "QA note text"},
    )
    assert all(r["ok"] for r in res), res
    staff_ids = dict(db_query("select email, id from accounts_user where email = any(%s)", ([STAFF, MANAGER, SUPPORT],)))
    rows = db_query("select action, actor_id, changes::text from core_auditlog where object_type='orders.order' and object_id=%s order by id", (str(o["id"]),))
    assert [(a, actor) for a, actor, _ in rows] == [
        ("order.accept", staff_ids[STAFF]),
        ("order.start_packing", staff_ids[STAFF]),
        ("order.items_unavailable", staff_ids[STAFF]),
        ("order.packed", staff_ids[STAFF]),
        ("refund.issue", staff_ids[SUPPORT]),
        ("order.cancel", staff_ids[MANAGER]),
    ], rows
    blob = " ".join(c for _, _, c in rows)
    assert "+91" not in blob and "QA note text" not in blob and shop_a.address["house"] not in blob


@CONSOLE
def test_p4_tc42_console_csrf_and_safe_methods():
    """P4-TC-42 console POST without CSRF: 403; GET never changes state."""


def test_p4_tc48_domain_events_after_commit(shop_a):
    """P4-TC-48 (log level) T6 and T11 each produce one notification task on the QA broker,
    executed by the QA worker after commit: checked in the worker log by order number."""
    from qa_support import QA_DIR

    o = cod_order(shop_a)
    assert as_(STAFF, "accept", o["id"])["ok"]
    assert shop_a.cancel(o["id"]).status_code == 200
    time.sleep(8)
    logs = sorted((QA_DIR / "private" / "logs").glob("worker-p4*.log"), key=lambda p: p.stat().st_mtime)
    text = logs[-1].read_text(encoding="utf-8", errors="replace")
    hits = [ln for ln in text.splitlines() if f"{o['id']}" in ln and "succeeded" in ln]
    print("\n".join(hits[-10:]))
    assert hits, "no task for the order in the QA worker log"
