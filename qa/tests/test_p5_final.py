"""Phase 5 final QA (T-518, develop 8f87d7b): P0 cases that were still unexecuted after stage 2.

TC-36 cash-limit boundary (DL-61 b), TC-54/55 manual assign (DL-61 a), TC-80 WRONG_ADDRESS / OTHER
failures, TC-86 receive return with damaged units. Oracles: 08 §5-§6.4, 06 §3, DL-61, 05 §1.4.
Black-box API for riders/customers; staff actions through the backend services (rider_ops_driver).
"""

from __future__ import annotations

from decimal import Decimal

from p4_support import OPS, SUPER, refunds
from p5_support import (  # noqa: F401 (fixtures)
    P5_53, R1_PHONE, R2_PHONE, V_SUN_1L, bring_to, movements, p5_shop_a, qa_worker, r1, r2,
    rider_op, stock_at_qa02, task_row, wait_order_status,
)
from qa_support import db_query, describe

pytestmark = P5_53


def money(v) -> Decimal:
    return Decimal(str(v))


def cash(rider) -> dict:
    return rider.me().json()["cash"]


def test_p5_tc36_cash_limit_equal_is_offered(r1, p5_shop_a):
    """P5-TC-36 DL-61 (b): cash_in_hand + COD total == limit → offered (above is covered by
    test_dl61b_cod_offer_skipped_over_cash_limit). The order waits SEARCHING while R1 is offline."""
    order = p5_shop_a.place_cod()
    wait_order_status(order["id"], "ACCEPTED")
    total = money(order["bill"]["grand_total"])
    limit = money(cash(r1)["cash_in_hand"]) + total
    rider_op(op="set_cash_limit", **{"as": SUPER}, phone=R1_PHONE, amount=str(limit))
    try:
        r1.online_at()
        offer = r1.wait_offer(task_id=task_row(order["id"])["id"])
        assert offer["order_id"] == order["id"] if "order_id" in offer else offer["task_id"]
    finally:
        rider_op(op="set_cash_limit", **{"as": SUPER}, phone=R1_PHONE, amount="5000.00")


def test_p5_tc54_tc55_manual_assign(r1, r2, p5_shop_a):
    """P5-TC-54 🔥 OPS manual-assigns R2 while R1 holds the offer: ASSIGNED at once, MANUAL, R2 sees
    the task, R1's offer withdrawn. P5-TC-55: assigning an offline rider and re-assigning an order
    that already has a rider are refused and change nothing."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    oid = ctx["order_id"]
    # TC-55 (a): R2 offline → refused
    out = rider_op(op="manual_assign", **{"as": OPS}, order_id=oid, phone=R2_PHONE)
    assert not out["ok"], out
    assert task_row(oid)["rider_id"] is None
    r2.online_at()
    out = rider_op(op="manual_assign", **{"as": OPS}, order_id=oid, phone=R2_PHONE)
    assert out["ok"], out
    row = task_row(oid)
    assert row["status"] == "ASSIGNED" and row["assignment_mode"] == "MANUAL", row
    assert r2.task().json()["task"]["id"] == ctx["task_id"]
    assert r1.offer().json()["offer"] is None
    late = r1.accept(ctx["offer"]["id"])
    assert late.status_code in (404, 409), describe(late)
    # TC-55 (b): the order already has a rider → refused, rider unchanged
    out = rider_op(op="manual_assign", **{"as": OPS}, order_id=oid, phone=R1_PHONE)
    assert not out["ok"], out
    assert task_row(oid)["rider_id"] == row["rider_id"]


def test_p5_tc80_wrong_address_full_refund(r1, p5_shop_a):
    """P5-TC-80 T13 WRONG_ADDRESS on a paid ONLINE order: one refund of everything refundable
    (no fee kept: not the customer's fault, 08 §6.4)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    order = p5_shop_a.order(ctx["order_id"]).json()
    r = r1.fail(ctx["task_id"], "WRONG_ADDRESS")
    assert r.status_code == 200 and r.json()["status"] == "RETURNING", describe(r)
    rows = refunds(ctx["order_id"])
    paid = money(order["bill"]["grand_total"]) - money(order.get("amount_refunded") or "0.00")
    assert len(rows) == 1 and money(rows[0][1]) == paid, (rows, paid)


def test_p5_tc80_other_without_note(r1, p5_shop_a):
    """P5-TC-80 OTHER without a note → 400 (or accepted and recorded); never 500."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    r = r1.fail(ctx["task_id"], "OTHER")
    assert r.status_code in (200, 400), describe(r)
    if r.status_code == 400:
        assert r.json()["error"]["code"] == "VALIDATION_ERROR"
        assert r1.fail(ctx["task_id"], "OTHER", note="QA other reason").status_code == 200


def test_p5_tc86_receive_return_damaged(r1, p5_shop_a):
    """P5-TC-86 receive return: invalid damaged maps refused with nothing changed; then damaged 1 of 2
    → RETURN 2 and DAMAGE record, net on_hand += 1 (08 T14)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, lines={V_SUN_1L: 2})
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    oid = ctx["order_id"]
    line = next(i for i in p5_shop_a.order(oid).json()["items"] if i["variant_id"] == V_SUN_1L)
    before = stock_at_qa02(V_SUN_1L)
    for bad in ({line["id"]: 3}, {999999999: 1}, {line["id"]: -1}, {line["id"]: True}):
        out = rider_op(op="receive_return", **{"as": SUPER}, order_id=oid, damaged=bad)
        assert not out["ok"], (bad, out)
        assert stock_at_qa02(V_SUN_1L) == before
        assert db_query("select status from orders_order where id=%s", (oid,))[0][0] == "DELIVERY_FAILED"
    out = rider_op(op="receive_return", **{"as": SUPER}, order_id=oid, damaged={line["id"]: 1})
    assert out["ok"] and out["result"]["status"] == "RETURNED", out
    assert stock_at_qa02(V_SUN_1L)[0] == before[0] + 1
    mv = [(t, d) for v, t, d in movements(oid) if v == V_SUN_1L and t in ("RETURN", "DAMAGE")]
    assert ("RETURN", 2) in mv and any(t == "DAMAGE" for t, _ in mv), mv
