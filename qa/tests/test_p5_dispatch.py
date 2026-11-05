"""Phase 5 slice 5.3 dispatch and offers (08 §5, §2.1, T8, T11; 04 §2.4; 06 §3 5.3 notes).

Stage 1 scaffold (2026-11-05), not executed: skipped until slice 5.3 (fd1490c) is on develop and
`delivery.0002` is applied (p5_support.requires_53). All orders at QA-02, riders C (R1) and D (R2).
"""

from __future__ import annotations

import concurrent.futures
import time
from datetime import datetime

from p5_support import (  # noqa: F401 (fixtures)
    P5_53, QA02, R1_PHONE, bring_to, offers_of, offset, p5_shop_a, p5_shop_b,
    payout_oracle, qa_worker, r1, r2, rider_id_of, task_row, wait_order_status, wait_task_status,
)
from qa_support import assert_error, db_query, describe, validate_response

pytestmark = P5_53

OFFER_KEYS = {"id", "task_id", "store_name", "drop_locality", "distance_km", "payment_type", "cod_amount",
              "estimated_payout", "item_count", "offered_at", "expires_at"}


def parse(ts: str) -> datetime:
    return datetime.fromisoformat(ts.replace("Z", "+00:00"))


def test_p5_tc34_offer_reaches_rider_without_customer_pii(r1, p5_shop_a):
    """P5-TC-34 🔥 COD order → OFFERED to the online rider; locality only, 30 s window, money strings."""
    r1.online_at()
    order = p5_shop_a.place_cod()
    wait_order_status(order["id"], "ACCEPTED")
    accepted = time.monotonic()
    offer = r1.wait_offer(timeout=20)
    seen_after = time.monotonic() - accepted
    r = r1.offer()
    validate_response(r, "rider_offers_current")
    assert set(offer) == OFFER_KEYS
    assert offer["payment_type"] == "COD" and offer["cod_amount"] == order["bill"]["grand_total"]
    assert (parse(offer["expires_at"]) - parse(offer["offered_at"])).total_seconds() == 30
    text = str(offer)
    for secret in (p5_shop_a.address["house"], p5_shop_a.address["building_street"], p5_shop_a.session.phone,
                   str(p5_shop_a.address["lat"])):
        assert secret not in text, "offer leaks the customer's address or phone before accept"
    assert task_row(order["id"])["status"] == "OFFERED"
    print(f"offer seen {seen_after:.2f}s after ACCEPTED (local, remote DB)")


def test_p5_tc35_offline_or_stale_rider_not_offered(r1, r2, p5_shop_a):
    """P5-TC-35 (offline and stale-ping variants) R2 never offered; R1 is."""
    r1.online_at(offset(QA02, north_m=800))  # R1 away: R2 would rank first if eligible
    r2.online_at(offset(QA02, north_m=10))
    assert r2.shift_end().status_code == 200  # variant: offline
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert r2.offer().json()["offer"] is None
    assert {row[1] for row in offers_of(ctx["task_id"])} == {rider_id_of(R1_PHONE)}


def test_p5_tc37_at_store_first_then_nearest(r1, r2, p5_shop_a, p5_shop_b):
    """P5-TC-37 (a) at-store rider beats a farther one; (c) both away: nearest first."""
    r1.online_at(offset(QA02, north_m=150))
    r2.online_at(offset(QA02, north_m=1200))
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert r2.offer().json()["offer"] is None
    assert r1.reject(ctx["offer"]["id"]).status_code == 204  # frees R1's slot for part (c)
    r2.wait_offer(task_id=ctx["task_id"])  # next candidate
    # (c) a new order: R1 900 m, R2 600 m -> R2 first (R2 is busy with an offer: end it first)
    r1.online_at(offset(QA02, north_m=900))
    assert r2.reject(r2.offer().json()["offer"]["id"]).status_code == 204
    r2.online_at(offset(QA02, north_m=600))
    p5_shop_b.place_cod()
    first = None
    for _ in range(40):
        if r2.offer().json()["offer"]:
            first = "R2"
            break
        if r1.offer().json()["offer"]:
            first = "R1"
            break
        time.sleep(0.5)
    assert first == "R2"


def test_p5_tc39_accept_reveals_address_idempotent(r1, p5_shop_a):
    """P5-TC-39 🔥 accept → ASSIGNED with the full address; a repeat accept is 200 (same task)."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    r = r1.accept(ctx["offer"]["id"])
    validate_response(r, "rider_offers_accept")
    assert r.status_code == 200 and r.json()["status"] == "ASSIGNED" and r.json()["assigned_at"], describe(r)
    assert r.json()["customer_address"]["house"] == p5_shop_a.address["house"]
    again = r1.accept(ctx["offer"]["id"])
    assert again.status_code == 200 and again.json()["id"] == r.json()["id"]
    assert r1.offer().json()["offer"] is None
    cur = r1.task()
    validate_response(cur, "rider_tasks_current")
    assert cur.json()["task"]["id"] == ctx["task_id"]
    assert db_query("select status from orders_order where id=%s", (ctx["order_id"],))[0][0] == "ACCEPTED"


def test_p5_tc40_reject_offers_next_rider(r1, r2, p5_shop_a):
    """P5-TC-40 reject (reason stored) → R2 offered; R1 never re-offered; bad reason 400."""
    r1.online_at()
    r2.online_at(offset(QA02, north_m=500))
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert_error(r1.reject(ctx["offer"]["id"], reason="BORED"), 400, "VALIDATION_ERROR")
    r = r1.reject(ctx["offer"]["id"])
    assert r.status_code == 204, describe(r)
    first = offers_of(ctx["task_id"])[0]
    assert (first[2], first[5]) == ("REJECTED", "TOO_FAR")
    r2.wait_offer(task_id=ctx["task_id"])
    assert r2.reject(r2.offer().json()["offer"]["id"], reason=None).status_code == 204  # reason optional
    time.sleep(20)
    assert r1.offer().json()["offer"] is None, "R1 re-offered a task it already rejected"


def test_p5_tc41_expiry_then_late_accept(r1, r2, p5_shop_a):
    """P5-TC-41 no answer for 30 s (+ sweep) → EXPIRED, R2 offered; late accept 409 OFFER_EXPIRED."""
    r1.online_at()
    r2.online_at(offset(QA02, north_m=500))
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    r2.wait_offer(timeout=60, task_id=ctx["task_id"])
    assert offers_of(ctx["task_id"])[0][2] == "EXPIRED"
    assert_error(r1.accept(ctx["offer"]["id"]), 409, "OFFER_EXPIRED")
    r = r1.reject(ctx["offer"]["id"])
    assert r.status_code == 409, describe(r)


def test_p5_tc43_parallel_accepts_one_assignment(r1, p5_shop_a):
    """P5-TC-43 10 parallel accepts by the owner: 200/409 only, one assignment, one active task."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    with concurrent.futures.ThreadPoolExecutor(10) as pool:
        codes = list(pool.map(lambda _: r1.accept(ctx["offer"]["id"]).status_code, range(10)))
    assert set(codes) <= {200, 409} and 200 in codes, codes
    active = db_query(
        "select count(*) from delivery_deliverytask where rider_id=%s and status in "
        "('ASSIGNED','AT_STORE','PICKED_UP','AT_CUSTOMER','RETURNING')",
        (rider_id_of(R1_PHONE),),
    )[0][0]
    assert active == 1


def test_p5_tc44_cancel_vs_accept_race(r1, p5_shop_a):
    """P5-TC-44 customer cancel ‖ accept: never an ASSIGNED task on a CANCELLED order."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    with concurrent.futures.ThreadPoolExecutor(2) as pool:
        f_cancel = pool.submit(p5_shop_a.cancel, ctx["order_id"])
        f_accept = pool.submit(r1.accept, ctx["offer"]["id"])
    cancel, accept = f_cancel.result(), f_accept.result()
    assert cancel.status_code == 200, describe(cancel)
    assert accept.status_code in (200, 409), describe(accept)
    if accept.status_code == 409:
        assert accept.json()["error"]["code"] == "OFFER_TAKEN"
    assert wait_task_status(ctx["order_id"], "CANCELLED", timeout=10)
    assert r1.task().json()["task"] is None


def test_p5_tc46_going_offline_withdraws_offer(r1, r2, p5_shop_a):
    """P5-TC-46 offline with a pending offer: accept → 409 OFFER_TAKEN (or RIDER_OFFLINE); R2 next."""
    r1.online_at()
    r2.online_at(offset(QA02, north_m=500))
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert r1.shift_end().status_code == 200
    r = r1.accept(ctx["offer"]["id"])
    assert r.status_code == 409 and r.json()["error"]["code"] in ("OFFER_TAKEN", "RIDER_OFFLINE"), describe(r)
    r2.wait_offer(task_id=ctx["task_id"])


def test_p5_tc48_rider_coming_online_gets_waiting_order(r1, p5_shop_a):
    """P5-TC-48 no candidate → SEARCHING; a rider coming online is offered within the retry."""
    order = p5_shop_a.place_cod()
    wait_order_status(order["id"], "ACCEPTED")
    wait_task_status(order["id"], "SEARCHING")
    time.sleep(5)
    r1.online_at()
    offer = r1.wait_offer(timeout=40)
    assert offer["task_id"] == task_row(order["id"])["id"]


def test_p5_tc49_cancellation_withdraws_offer_or_cancels_task(r1, p5_shop_a):
    """P5-TC-49 (a) cancel while OFFERED; (b) cancel while ASSIGNED (order ACCEPTED)."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert p5_shop_a.cancel(ctx["order_id"]).status_code == 200
    assert offers_of(ctx["task_id"])[-1][2] == "WITHDRAWN"
    assert r1.offer().json()["offer"] is None
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    assert p5_shop_a.cancel(ctx["order_id"]).status_code == 200
    cur = r1.task().json()
    assert cur["task"] is None and cur["recent_task"]["status"] == "CANCELLED"
    assert task_row(ctx["order_id"])["status"] == "CANCELLED"
    bring_to("OFR", shop=p5_shop_a, rider=r1)  # freed: the next order is offered


def test_p5_tc52_payout_estimate(r1, p5_shop_a):
    """P5-TC-52 estimated_payout = 30.00 + 5.00 x distance_km (D-16), money as strings."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    for body in (ctx["offer"], ctx["task"]):
        assert isinstance(body["estimated_payout"], str) and isinstance(body["distance_km"], str)
        assert body["estimated_payout"] == str(payout_oracle(body["distance_km"]))


def test_p5_tc53_one_order_at_a_time(r1, p5_shop_a, p5_shop_b):
    """P5-TC-53 two orders, one rider: never two PENDING offers or two active tasks."""
    r1.online_at()
    p5_shop_a.place_cod()
    p5_shop_b.place_cod()
    time.sleep(20)
    rid = rider_id_of(R1_PHONE)
    pending = db_query("select count(*) from delivery_deliveryoffer where rider_id=%s and status='PENDING'", (rid,))[0][0]
    assert pending <= 1
    offer = r1.wait_offer()
    assert r1.accept(offer["id"]).status_code == 200
    time.sleep(20)
    assert r1.offer().json()["offer"] is None, "a busy rider was offered a second order"

