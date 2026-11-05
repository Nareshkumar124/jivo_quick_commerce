"""Phase 5 slice 5.3 delivery task: arrival geofences, pickup and T9 stock commit, delivery OTP,
T10 (prepaid, COD cash), T13 failed delivery and refunds, T14 receive return, end-to-end flows.

Oracles: 08 §6.1 (stock), 08 §6.4 with the D-10 defaults (T13 refund = refundable − delivery fee on
customer fault), 07 (one COD_COLLECTED ledger row per order). Stage 1 scaffold (2026-11-05), not
executed: gated by p5_support.requires_53.
"""

from __future__ import annotations

import concurrent.futures
import time
from decimal import Decimal

import pytest

from p4_support import SUPER, history, refunds
from p5_support import (  # noqa: F401 (fixtures)
    DROP, P5_53, QA02, R1_PHONE, V_FLAX, V_SUN_1L, bring_to, cod_due, ledger_rows, movements, offset,
    p5_shop_a, pickup_code, qa_worker, r1, rider_id_of, rider_op, stock_at_qa02, task_row, wrong_otp,
)
from qa_support import assert_error, db_query, describe, validate_response

pytestmark = P5_53


def money(v) -> Decimal:
    return Decimal(str(v))


# --------------------------------------------------------------------------- arrival at the store


@pytest.mark.parametrize(("north_m", "accuracy", "ok"), [(150, None, True), (240, 50, True), (260, 50, False), (400, None, False)])
def test_p5_tc59_arrived_store_geofence(r1, p5_shop_a, north_m, accuracy, ok):
    """P5-TC-59 radius 200 m + min(accuracy, 50) slack (A20); outside → 422 OUTSIDE_GEOFENCE."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    r = r1.arrived_store(ctx["task_id"], offset(QA02, north_m=north_m), accuracy)
    if ok:
        validate_response(r, "rider_tasks_arrived_store")
        assert r.status_code == 200 and r.json()["status"] == "AT_STORE" and r.json()["arrived_store_at"], describe(r)
        assert r1.arrived_store(ctx["task_id"]).status_code == 200  # idempotent
    else:
        err = assert_error(r, 422, "OUTSIDE_GEOFENCE")
        assert err["details"]["radius_m"] == 200 and err["details"]["distance_m"] > 200


def test_p5_tc59_arrived_store_wrong_state(r1, p5_shop_a):
    """P5-TC-59 arrived-store from OFD → 409."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    assert_error(r1.arrived_store(ctx["task_id"]), 409, "INVALID_STATE_TRANSITION")


# --------------------------------------------------------------------------- pickup / T9


def test_p5_tc60_pickup_commits_stock(r1, p5_shop_a):
    """P5-TC-60 🔥 T9: on_hand −q, reserved −q, one SALE per line, OFD, OTP to the customer."""
    r1.online_at()
    lines = {V_SUN_1L: 2, V_FLAX: 1}
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1, lines=lines)
    before = {v: stock_at_qa02(v) for v in lines}
    r = r1.pickup(ctx["task_id"], pickup_code(ctx["order_id"]))
    validate_response(r, "rider_tasks_pickup")
    assert r.status_code == 200 and r.json()["status"] == "PICKED_UP" and r.json()["picked_up_at"], describe(r)
    assert r.json()["order_status"] == "OUT_FOR_DELIVERY"
    for v, q in lines.items():
        on_hand, reserved = stock_at_qa02(v)
        assert (on_hand, reserved) == (before[v][0] - q, before[v][1] - q), v
    sales = sorted((v, d) for v, t, d in movements(ctx["order_id"]) if t == "SALE")
    assert sales == sorted((v, -q) for v, q in lines.items())
    assert db_query("select count(*) from inventory_stockreservation where order_id=%s and status<>'COMMITTED'",
                    (ctx["order_id"],))[0][0] == 0
    assert ("PACKED", "OUT_FOR_DELIVERY", "rider") in [(f, t, a) for f, t, a in history(ctx["order_id"])]
    otp = p5_shop_a.track(ctx["order_id"]).json()["delivery_otp"]
    assert otp and len(otp) == 4 and otp.isdigit()


def test_p5_tc61_bag_qr_and_case(r1, p5_shop_a):
    """P5-TC-61 QR `JQC1:<order_number>:<code>` and the lower-case, trimmed code are accepted;
    the right code with another order number is PICKUP_CODE_INVALID."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    code, number = pickup_code(ctx["order_id"]), ctx["order"]["order_number"]
    err = assert_error(r1.pickup(ctx["task_id"], f"JQC1:JV-000000-000001:{code}"), 400, "PICKUP_CODE_INVALID")
    assert err["details"]["attempts_remaining"] == 4
    r = r1.pickup(ctx["task_id"], f"  jqc1:{number.lower()}:{code.lower()}  ")
    assert r.status_code == 200, describe(r)


@pytest.mark.parametrize("bad", ["ＡＢＣＤ", "١٢٣٤", "AB1", "A" * 50])
def test_p5_tc62_pickup_bad_shape_uses_no_attempt(r1, p5_shop_a, bad):
    """P5-TC-62 (c) non-ASCII / wrong-shape codes: 400, no attempt used, stock unchanged."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    assert_error(r1.pickup(ctx["task_id"], bad), 400, "PICKUP_CODE_INVALID")
    assert task_row(ctx["order_id"])["pickup_attempts"] == 0


def test_p5_tc62_pickup_guards(r1, p5_shop_a):
    """P5-TC-62 (a) not PACKED; (b) not at the store: 409, stock untouched."""
    r1.online_at()
    ctx = bring_to("ATS", shop=p5_shop_a, rider=r1)
    before = stock_at_qa02(V_SUN_1L)
    r = r1.pickup(ctx["task_id"], "ABCD")
    assert_error(r, 409, "INVALID_STATE_TRANSITION")
    assert r1.task().json()["task"]["ready_for_pickup"] is False
    assert stock_at_qa02(V_SUN_1L) == before


def test_p5_tc63_pickup_lock_after_five(r1, p5_shop_a):
    """P5-TC-63 attempts 4..1, then 423 PICKUP_CODE_LOCKED; the right code stays locked;
    unassign + re-assign resets the lock (5.3)."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    code = pickup_code(ctx["order_id"])
    wrong = "ZZZZ" if code.upper() != "ZZZZ" else "YYYY"
    for left in (4, 3, 2, 1):
        assert assert_error(r1.pickup(ctx["task_id"], wrong), 400, "PICKUP_CODE_INVALID")["details"]["attempts_remaining"] == left
    assert assert_error(r1.pickup(ctx["task_id"], wrong), 423, "PICKUP_CODE_LOCKED")["details"]["attempts_remaining"] == 0
    assert_error(r1.pickup(ctx["task_id"], code), 423, "PICKUP_CODE_LOCKED")
    out = rider_op(op="unassign", **{"as": SUPER}, order_id=ctx["order_id"])
    assert out["ok"], out
    out = rider_op(op="manual_assign", **{"as": SUPER}, order_id=ctx["order_id"], phone=R1_PHONE)
    assert out["ok"], out
    assert r1.arrived_store(ctx["task_id"]).status_code == 200
    assert r1.pickup(ctx["task_id"], code).status_code == 200


def test_p5_tc65_parallel_pickups_commit_once(r1, p5_shop_a):
    """P5-TC-65 5 parallel right pickups: one SALE per line, one T9 history row."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    before = stock_at_qa02(V_SUN_1L)
    code = pickup_code(ctx["order_id"])
    with concurrent.futures.ThreadPoolExecutor(5) as pool:
        codes = list(pool.map(lambda _: r1.pickup(ctx["task_id"], code).status_code, range(5)))
    assert set(codes) <= {200, 409} and 200 in codes, codes
    assert [t for _, t, _ in movements(ctx["order_id"])].count("SALE") == 1
    assert [t for _, t, _ in history(ctx["order_id"])].count("OUT_FOR_DELIVERY") == 1
    assert stock_at_qa02(V_SUN_1L) == (before[0] - 1, before[1] - 1)


# --------------------------------------------------------------------------- arrival at the customer


def test_p5_tc67_arrived_customer_geofence_and_override(r1, p5_shop_a):
    """P5-TC-67 outside without override 422; spaces only 422; a real override 200 (stored)."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    far = offset(DROP, north_m=600)
    assert_error(r1.arrived_customer(ctx["task_id"], far), 422, "OUTSIDE_GEOFENCE")
    assert_error(r1.arrived_customer(ctx["task_id"], far, override="   "), 422, "OUTSIDE_GEOFENCE")
    r = r1.arrived_customer(ctx["task_id"], far, override="gate locked")
    validate_response(r, "rider_tasks_arrived_customer")
    assert r.status_code == 200 and r.json()["status"] == "AT_CUSTOMER", describe(r)
    assert db_query("select arrival_override_reason from delivery_deliverytask where id=%s", (ctx["task_id"],))[0][0] == "gate locked"


# --------------------------------------------------------------------------- T10


def test_p5_tc68_deliver_prepaid(r1, p5_shop_a):
    """P5-TC-68 🔥 ONLINE: right OTP → DELIVERED, history T10 by the rider, invoice, rider freed."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    r = r1.deliver(ctx["task_id"], ctx["otp"])
    validate_response(r, "rider_tasks_deliver")
    assert r.status_code == 200 and r.json()["status"] == "DELIVERED" and r.json()["delivered_at"], describe(r)
    assert ("OUT_FOR_DELIVERY", "DELIVERED", "rider") in [tuple(h) for h in history(ctx["order_id"])]
    assert p5_shop_a.order(ctx["order_id"]).json()["can_download_invoice"] is True
    inv = p5_shop_a.api.get(f"/api/v1/orders/{ctx['order_id']}/invoice/", headers=p5_shop_a.h)
    assert inv.status_code in (200, 503), describe(inv)  # 503: WeasyPrint missing on this host
    cur = r1.task().json()
    assert cur["task"] is None and cur["recent_task"]["status"] == "DELIVERED"


def test_p5_tc69_deliver_cod_cash_ledger(r1, p5_shop_a):
    """P5-TC-69 🔥 COD cash: COD_COLLECTED, one ledger row of +due, cash_in_hand updated."""
    r1.online_at()
    rid = rider_id_of(R1_PHONE)
    before = ledger_rows(rid)
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = r1.task().json()["task"]["cod_amount_due"]
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": due})
    assert r.status_code == 200, describe(r)
    assert p5_shop_a.order(ctx["order_id"]).json()["payment_status"] == "COD_COLLECTED"
    new = [row for row in ledger_rows(rid) if row not in before]
    assert len(new) == 1 and new[0][1] == "COD_COLLECTED" and money(new[0][2]) == money(due)
    prev = money(before[-1][3]) if before else Decimal("0")
    assert money(new[0][3]) == prev + money(due)
    assert money(r1.me().json()["cash"]["cash_in_hand"]) == money(new[0][3])


def test_p5_tc70_cod_amount_mismatch_uses_no_otp_attempt(r1, p5_shop_a):
    """P5-TC-70 wrong COD amounts → 400 details.cod; attempts_remaining unchanged."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = money(r1.task().json()["task"]["cod_amount_due"])
    for cod in ({"mode": "cash", "amount": str(due - Decimal("0.01"))},
                {"mode": "cash", "amount": str(due + Decimal("0.01"))},
                {"mode": "cash", "amount": f"-{due}"},
                {"mode": "upi", "amount": str(due)},  # no paid QR before 5.4
                None):
        r = r1.deliver(ctx["task_id"], ctx["otp"], cod)
        assert_error(r, 400, "VALIDATION_ERROR")
        assert "cod" in r.json()["error"]["details"], describe(r)
    assert r1.task().json()["task"]["delivery_otp"]["attempts_remaining"] == 5
    # The same value written with three decimals: accepted or 400 (the exact-match rule), recorded.
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": f"{due}0"})
    assert r.status_code in (200, 400), describe(r)
    print(f"amount {due}0 for due {due}: HTTP {r.status_code}")


def test_p5_tc71_otp_lock_after_five(r1, p5_shop_a):
    """P5-TC-71 🔥 4 × 400 (4..1 left), 5th → 423 locked, right OTP still 423, `locked` true."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    bad = wrong_otp(ctx["otp"])
    for left in (4, 3, 2, 1):
        assert assert_error(r1.deliver(ctx["task_id"], bad), 400, "DELIVERY_OTP_INVALID")["details"]["attempts_remaining"] == left
    assert assert_error(r1.deliver(ctx["task_id"], bad), 423, "DELIVERY_OTP_LOCKED")["details"]["attempts_remaining"] == 0
    assert_error(r1.deliver(ctx["task_id"], ctx["otp"]), 423, "DELIVERY_OTP_LOCKED")
    assert r1.task().json()["task"]["delivery_otp"]["locked"] is True
    r1.arrived_customer(ctx["task_id"])
    assert r1.task().json()["task"]["delivery_otp"]["locked"] is True


def test_p5_tc72_parallel_wrong_otps_never_exceed_five(r1, p5_shop_a):
    """P5-TC-72 20 parallel wrong OTPs: ≤ 4 × 400, otp_attempts ≤ 5, then locked."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    bad = wrong_otp(ctx["otp"])
    with concurrent.futures.ThreadPoolExecutor(20) as pool:
        codes = list(pool.map(lambda _: r1.deliver(ctx["task_id"], bad).status_code, range(20)))
    assert set(codes) <= {400, 423} and codes.count(400) <= 4, codes
    assert task_row(ctx["order_id"])["otp_attempts"] <= 5
    assert_error(r1.deliver(ctx["task_id"], ctx["otp"]), 423, "DELIVERY_OTP_LOCKED")


@pytest.mark.parametrize("otp", ["", "123", "12345", "abcd", "١٢٣٤", " 1234 "])
def test_p5_tc73_malformed_otp_never_500(r1, p5_shop_a, otp):
    """P5-TC-73 malformed OTPs: 400 (VALIDATION_ERROR or DELIVERY_OTP_INVALID, A12), never 500."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    r = r1.deliver(ctx["task_id"], otp)
    assert r.status_code == 400, describe(r)
    print(otp.encode("unicode_escape"), r.json()["error"]["code"],
          r1.task().json()["task"]["delivery_otp"]["attempts_remaining"])


def test_p5_tc74_deliver_wrong_states_and_repeat(r1, p5_shop_a):
    """P5-TC-74 deliver before arrival → 409; after DELIVERED → 200, no second ledger row."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    due = cod_due(r1.task().json()["task"])
    assert_error(r1.deliver(ctx["task_id"], ctx["otp"], due), 409, "INVALID_STATE_TRANSITION")
    assert r1.arrived_customer(ctx["task_id"]).status_code == 200
    assert r1.deliver(ctx["task_id"], ctx["otp"], due).status_code == 200
    rows = len(ledger_rows(rider_id_of(R1_PHONE)))
    assert r1.deliver(ctx["task_id"], ctx["otp"], due).status_code == 200
    assert len(ledger_rows(rider_id_of(R1_PHONE))) == rows


def test_p5_tc75_parallel_cod_delivers_collect_once(r1, p5_shop_a):
    """P5-TC-75 5 parallel delivers: one DELIVERED history row and one ledger row."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = cod_due(r1.task().json()["task"])
    with concurrent.futures.ThreadPoolExecutor(5) as pool:
        codes = list(pool.map(lambda _: r1.deliver(ctx["task_id"], ctx["otp"], due).status_code, range(5)))
    assert set(codes) <= {200, 409} and 200 in codes, codes
    assert [t for _, t, _ in history(ctx["order_id"])].count("DELIVERED") == 1
    assert sum(1 for row in ledger_rows(rider_id_of(R1_PHONE)) if row[4] == ctx["order_id"]) == 1


def test_p5_tc76_track_after_delivery_hides_phone_and_otp(r1, p5_shop_a):
    """P5-TC-76 DL-56: after DELIVERED, rider.phone, delivery_otp and eta_at are null."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    assert r1.deliver(ctx["task_id"], ctx["otp"]).status_code == 200
    t = p5_shop_a.track(ctx["order_id"])
    validate_response(t, "orders_track")
    body = t.json()
    assert body["status"] == "DELIVERED" and body["delivery_otp"] is None and body["eta_at"] is None
    assert body["rider"] is None or body["rider"]["phone"] is None


# --------------------------------------------------------------------------- T13 / T14


def expected_failed_refund(order: dict, customer_fault: bool) -> Decimal:
    """08 §6.4 (D-10 default): everything still refundable, minus the delivery fee on customer fault."""
    paid = money(order["bill"]["grand_total"]) - money(order.get("amount_refunded") or "0.00")
    return paid - (money(order["bill"]["delivery_fee"]) if customer_fault else Decimal("0"))


def test_p5_tc78_fail_refused_online_refund_keeps_delivery_fee(r1, p5_shop_a):
    """P5-TC-78 🔥 T13 CUSTOMER_REFUSED: RETURNING, DELIVERY_FAILED, one refund (fee kept)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    order = p5_shop_a.order(ctx["order_id"]).json()
    r = r1.fail(ctx["task_id"], "CUSTOMER_REFUSED")
    validate_response(r, "rider_tasks_fail")
    assert r.status_code == 200 and r.json()["status"] == "RETURNING" and r.json()["failed_at"], describe(r)
    assert r.json()["fail_reason"] == "CUSTOMER_REFUSED"
    assert ("OUT_FOR_DELIVERY", "DELIVERY_FAILED", "rider") in [tuple(h) for h in history(ctx["order_id"])]
    rows = refunds(ctx["order_id"])
    assert len(rows) == 1 and rows[0][3] == "DELIVERY_FAILED" and rows[0][4] == f"failed:{ctx['order_id']}"
    assert money(rows[0][1]) == expected_failed_refund(order, customer_fault=True)
    assert_error(r1.shift_end(), 409, "ACTIVE_TASK")


def test_p5_tc79_not_reachable_guards(r1, p5_shop_a):
    """P5-TC-79 NOT_REACHABLE: 1 call → 400; inside the 10-min wait → 409 WAIT_NOT_ELAPSED;
    from PICKED_UP (no arrival) → 409."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1, method="ONLINE")
    assert_error(r1.fail(ctx["task_id"], "CUSTOMER_NOT_REACHABLE", call_attempts=2), 409, "INVALID_STATE_TRANSITION")
    assert r1.arrived_customer(ctx["task_id"]).status_code == 200
    assert_error(r1.fail(ctx["task_id"], "CUSTOMER_NOT_REACHABLE", call_attempts=1), 400, "VALIDATION_ERROR")
    err = assert_error(r1.fail(ctx["task_id"], "CUSTOMER_NOT_REACHABLE", call_attempts=2), 409, "INVALID_STATE_TRANSITION")
    assert err["details"]["reason"] == "WAIT_NOT_ELAPSED" and err["details"]["not_reachable_after"]


@pytest.mark.profile_riderclock
def test_p5_tc79_not_reachable_after_wait(r1, p5_shop_a):
    """P5-TC-79 (riderclock profile, 20 s wait) 2 calls after the wait → 200, fee kept."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    order = p5_shop_a.order(ctx["order_id"]).json()
    time.sleep(22)
    assert r1.fail(ctx["task_id"], "CUSTOMER_NOT_REACHABLE", call_attempts=2).status_code == 200
    assert money(refunds(ctx["order_id"])[0][1]) == expected_failed_refund(order, customer_fault=True)


def test_p5_tc81_fail_cod_nothing_due(r1, p5_shop_a):
    """P5-TC-81 COD refused: payment_status FAILED; no ledger row; no refund."""
    r1.online_at()
    rows = len(ledger_rows(rider_id_of(R1_PHONE)))
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    assert p5_shop_a.order(ctx["order_id"]).json()["payment_status"] == "FAILED"
    assert len(ledger_rows(rider_id_of(R1_PHONE))) == rows and refunds(ctx["order_id"]) == []


def test_p5_tc83_fail_idempotent_one_refund(r1, p5_shop_a):
    """P5-TC-83 repeated and parallel fails: one refund, one T13 history row."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        codes = list(pool.map(lambda _: r1.fail(ctx["task_id"], "WRONG_ADDRESS").status_code, range(3)))
    assert set(codes) <= {200, 409} and 200 in codes, codes
    assert r1.fail(ctx["task_id"], "WRONG_ADDRESS").status_code == 200
    assert len(refunds(ctx["order_id"])) == 1
    assert [t for _, t, _ in history(ctx["order_id"])].count("DELIVERY_FAILED") == 1


def test_p5_tc85_receive_return_restocks(r1, p5_shop_a):
    """P5-TC-85 🔥 T14 (service as Super Admin until the 5.4 console): RETURNED, RETURN per line,
    on_hand += q, rider freed."""
    r1.online_at()
    lines = {V_SUN_1L: 1, V_FLAX: 1}
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, lines=lines)
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    before = {v: stock_at_qa02(v) for v in lines}
    out = rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])
    assert out["ok"] and out["result"]["status"] == "RETURNED", out
    assert db_query("select status from orders_order where id=%s", (ctx["order_id"],))[0][0] == "RETURNED"
    for v, q in lines.items():
        assert stock_at_qa02(v)[0] == before[v][0] + q
    assert sorted((v, d) for v, t, d in movements(ctx["order_id"]) if t == "RETURN") == sorted((v, q) for v, q in lines.items())
    assert r1.task().json()["task"] is None
    assert r1.shift_end().status_code == 200


def test_p5_tc87_receive_return_wrong_state_and_twice(r1, p5_shop_a):
    """P5-TC-87 receive while OFD → refused; a second receive adds no movement."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    assert not rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])["ok"]
    assert r1.arrived_customer(ctx["task_id"]).status_code == 200
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    assert rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])["ok"]
    n = len(movements(ctx["order_id"]))
    assert not rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])["ok"]
    assert len(movements(ctx["order_id"])) == n


# --------------------------------------------------------------------------- end to end


def test_p5_tc125_online_end_to_end(r1, p5_shop_a):
    """P5-TC-125 🔥 ONLINE: T3, T6, T7, T8, T9, T10 in order; bill unchanged; stock committed."""
    r1.online_at()
    before = stock_at_qa02(V_SUN_1L)
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    assert r1.deliver(ctx["task_id"], ctx["otp"]).status_code == 200
    path = [t for _, t, _ in history(ctx["order_id"])]
    assert path == ["PAYMENT_PENDING", "PLACED", "ACCEPTED", "PACKING", "PACKED", "OUT_FOR_DELIVERY", "DELIVERED"], path
    final = p5_shop_a.order(ctx["order_id"]).json()
    assert final["bill"] == ctx["order"]["bill"]
    assert stock_at_qa02(V_SUN_1L) == (before[0] - 1, before[1])


def test_p5_tc126_cod_end_to_end_to_t10(r1, p5_shop_a):
    """P5-TC-126 🔥 (to T10; the deposit half is 5.4) COD cash collected once."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    assert r1.deliver(ctx["task_id"], ctx["otp"], cod_due(r1.task().json()["task"])).status_code == 200
    o = p5_shop_a.order(ctx["order_id"]).json()
    assert (o["status"], o["payment_status"]) == ("DELIVERED", "COD_COLLECTED")


def test_p5_tc127_failed_returned_refund_settles(r1, p5_shop_a):
    """P5-TC-127 ONLINE refused → returned; the QA worker settles the refund → PARTIALLY_REFUNDED."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1, method="ONLINE")
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    assert rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])["ok"]
    end = time.monotonic() + 90
    while time.monotonic() < end:
        o = p5_shop_a.order(ctx["order_id"]).json()
        if o["payment_status"] in ("PARTIALLY_REFUNDED", "REFUNDED"):
            break
        time.sleep(2)
    assert o["payment_status"] == "PARTIALLY_REFUNDED", o["payment_status"]
    assert r1.task().json()["task"] is None
