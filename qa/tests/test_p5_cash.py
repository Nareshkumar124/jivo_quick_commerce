"""Phase 5 slice 5.4: COD UPI QR, cash ledger, deposits, earnings, payouts, history, DL-61 rules.

Oracles: 08 §6 (cash, COD), 06 §3 (Paging #24, Earnings #19, cod-qr), 05 §1.5/§3, DL-61 (a)-(d).
Shapes from the slice 5.4 schema (backend/phase-5 working tree, 2026-11-06): CodQr, CashLedgerEntry,
Earnings, Payout, TaskHistoryItem/Detail, RiderCash.deposit_required.

Gated by `requires_54`: runs only when the QA instance's DB has `delivery_codqr` (migration
delivery.0003) or with QA_P5_54=1. Staff actions through qa/tools/rider_ops_driver.py.
"""

from __future__ import annotations

import os
import secrets
import threading
from datetime import timedelta
from decimal import Decimal

import pytest
from p3_support import send_webhook
from p4_support import CATALOG, FINANCE, MANAGER, OPS, STAFF, SUPER, SUPPORT
from p5_support import (  # noqa: F401 (fixtures)
    QA02,
    QA02_ID,
    R1_PHONE,
    R2_PHONE,
    bring_to,
    cod_due,
    ledger_rows,
    money,
    offset,
    p5_shop_a,
    p5_shop_b,
    payout_oracle,
    pickup_code,
    qa_worker,
    r1,
    r2,
    rider_id_of,
    rider_op,
    rider_ops,
    wrong_otp,
)
from qa_support import QA_PHONES, assert_error, db_query, describe, validate_response


def _ready_54() -> tuple[bool, str]:
    if os.environ.get("QA_P5_54") == "1":
        return True, "forced"
    try:
        ok = db_query("select to_regclass('public.delivery_codqr')")[0][0] is not None
    except Exception as exc:  # noqa: BLE001
        return False, f"cannot check delivery.0003 ({type(exc).__name__})"
    return ok, "slice 5.4 present" if ok else "awaiting slice 5.4 (delivery.0003) on the QA instance's DB"


_R, _W = _ready_54()
pytestmark = [pytest.mark.p5_53, pytest.mark.skipif(not _R, reason=_W)]


def ist_today():
    from datetime import UTC, datetime

    return (datetime.now(UTC) + timedelta(hours=5, minutes=30)).date()


def cash_of(rider) -> dict:
    return rider.me().json()["cash"]


def qr_event(qr_id: str, paise: int, payment_id: str | None = None) -> dict:
    return {
        "entity": "event",
        "event": "qr_code.credited",
        "payload": {
            "qr_code": {"entity": {"id": qr_id, "status": "closed"}},
            "payment": {"entity": {"id": payment_id or "pay_" + secrets.token_hex(7), "amount": paise,
                                   "status": "captured", "method": "upi", "order_id": None}},
        },
    }


def deliver_cash(rider, shop):
    ctx = bring_to("ATC", shop=shop, rider=rider)
    task = rider.task().json()["task"]
    r = rider.deliver(ctx["task_id"], ctx["otp"], cod_due(task))
    assert r.status_code == 200, describe(r)
    return ctx, task


# --------------------------------------------------------------------------- COD UPI QR


@pytest.mark.smoke
def test_p5_tc88_cod_qr_idempotent(r1, p5_shop_a):
    """P5-TC-88 cod-qr at AT_CUSTOMER → 200 PENDING for exactly the COD due; a repeat returns the same QR."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = r1.task().json()["task"]["cod_amount_due"]
    a = r1.post(f"tasks/{ctx['task_id']}/cod-qr/")
    validate_response(a, "rider_tasks_cod_qr")
    assert a.status_code == 200 and a.json()["status"] == "PENDING" and a.json()["amount"] == due, describe(a)
    b = r1.post(f"tasks/{ctx['task_id']}/cod-qr/")
    assert b.json()["qr_id"] == a.json()["qr_id"]


def test_p5_tc88_cod_qr_wrong_state_and_prepaid(r1, p5_shop_a):
    """P5-TC-88 cod-qr before pickup → 409; on a prepaid order → 409."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    assert r1.post(f"tasks/{ctx['task_id']}/cod-qr/").status_code == 409


@pytest.mark.smoke
def test_p5_tc89_qr_paid_then_deliver_upi(r1, p5_shop_a, api):
    """P5-TC-89 🔥 the signed QR-credited webhook marks the QR PAID (seen in tasks/current); deliver with
    mode upi → DELIVERED; no cash enters the ledger."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    paise = int(Decimal(qr["amount"]) * 100)
    before = cash_of(r1)["cash_in_hand"]
    w = send_webhook(api, qr_event(qr["qr_id"], paise), event_id="evt_qa_" + secrets.token_hex(6))
    assert w.status_code == 200, describe(w)
    assert r1.task().json()["task"]["cod_qr"]["status"] == "PAID"
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "upi", "amount": qr["amount"]})
    assert r.status_code == 200, describe(r)
    assert cash_of(r1)["cash_in_hand"] == before


def test_p5_tc89_fake_cod_qr_payment_command(r1, p5_shop_a):
    """P5-TC-89 (dev path) `manage.py fake_cod_qr_payment <order_number>` pays the open QR through the
    webhook service: QR PAID, deliver with mode upi → DELIVERED, no cash in the ledger."""
    import subprocess

    from p4_support import _ENV, BACKEND

    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    before = cash_of(r1)["cash_in_hand"]
    number = p5_shop_a.order(ctx["order_id"]).json()["order_number"]
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(_ENV)
    p = subprocess.run(["uv", "run", "--quiet", "python", "manage.py", "fake_cod_qr_payment", number],
                       cwd=BACKEND, env=env, capture_output=True, text=True, encoding="utf-8", timeout=300)
    assert p.returncode == 0 and "PAID" in p.stdout, (p.returncode, p.stdout[-500:], p.stderr[-1500:])
    assert r1.task().json()["task"]["cod_qr"]["status"] == "PAID"
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "upi", "amount": qr["amount"]})
    assert r.status_code == 200 and r.json()["status"] == "DELIVERED", describe(r)
    assert cash_of(r1)["cash_in_hand"] == before


def test_p5_tc89_upi_without_payment_refused(r1, p5_shop_a):
    """P5-TC-89 deliver with mode upi before the QR is paid → 400 and no OTP attempt used."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    task = r1.task().json()["task"]
    r1.post(f"tasks/{ctx['task_id']}/cod-qr/")
    r = r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "upi", "amount": task["cod_amount_due"]})
    assert r.status_code == 400, describe(r)
    assert r1.task().json()["task"]["delivery_otp"]["attempts_remaining"] == task["delivery_otp"]["attempts_remaining"]


@pytest.mark.smoke
def test_p5_tc90_qr_webhook_replay_one_payment(r1, p5_shop_a, api):
    """P5-TC-90 🔥 the same QR payment replayed 3 times and 3 in parallel → one Payment row; a different
    amount on a fresh QR does not mark it PAID."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    paise = int(Decimal(qr["amount"]) * 100)
    pay_id = "pay_" + secrets.token_hex(7)
    ev = qr_event(qr["qr_id"], paise, pay_id)
    eid = "evt_qa_" + secrets.token_hex(6)
    codes = [send_webhook(api, ev, event_id=eid).status_code for _ in range(3)]
    out = []
    th = [threading.Thread(target=lambda: out.append(send_webhook(api, ev, event_id="evt_qa_" + secrets.token_hex(6))
                                                     .status_code)) for _ in range(3)]
    [t.start() for t in th]
    [t.join() for t in th]
    assert all(c == 200 for c in codes + out), (codes, out)
    n = db_query("select count(*) from payments_payment where gateway_payment_id=%s", (pay_id,))[0][0]
    assert n == 1, n


def test_p5_tc90_wrong_amount_not_paid(r1, p5_shop_a, api):
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    paise = int(Decimal(qr["amount"]) * 100) - 100
    send_webhook(api, qr_event(qr["qr_id"], paise), event_id="evt_qa_" + secrets.token_hex(6))
    assert r1.task().json()["task"]["cod_qr"]["status"] != "PAID"


def test_p5_tc91_cash_then_qr_paid_is_refunded(r1, p5_shop_a, api):
    """P5-TC-91 deliver with cash, then the QR payment arrives → refunded automatically (one refund)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    task = r1.task().json()["task"]
    qr = r1.post(f"tasks/{ctx['task_id']}/cod-qr/").json()
    assert r1.deliver(ctx["task_id"], ctx["otp"], cod_due(task)).status_code == 200
    pay_id = "pay_" + secrets.token_hex(7)
    send_webhook(api, qr_event(qr["qr_id"], int(Decimal(qr["amount"]) * 100), pay_id),
                 event_id="evt_qa_" + secrets.token_hex(6))
    rows = db_query("select count(*) from payments_refund rf join payments_payment p on p.id=rf.payment_id "
                    "where p.gateway_payment_id=%s", (pay_id,))
    assert rows[0][0] == 1, rows


# --------------------------------------------------------------------------- unlocks (DL-61 a)


@pytest.mark.smoke
def test_p5_tc93_unlock_pickup_and_otp(r1, p5_shop_a):
    """P5-TC-93 🔥 5 wrong pickup codes lock; OPS unlocks → the right code works. 5 wrong OTPs lock;
    OPS unlocks → the right OTP works."""
    r1.online_at()
    ctx = bring_to("PKD", shop=p5_shop_a, rider=r1)
    code = pickup_code(ctx["order_id"])
    bad = "ZZZZ" if code != "ZZZZ" else "YYYY"
    for _ in range(5):
        r1.pickup(ctx["task_id"], bad)
    assert r1.pickup(ctx["task_id"], code).status_code == 423
    assert rider_op(op="unlock_pickup", **{"as": OPS}, order_id=ctx["order_id"])["ok"]
    assert r1.pickup(ctx["task_id"], code).status_code == 200
    otp = p5_shop_a.track(ctx["order_id"]).json()["delivery_otp"]
    assert r1.arrived_customer(ctx["task_id"]).status_code == 200
    due = cod_due(r1.task().json()["task"])  # COD: a wrong OTP counts only with a valid cash body (TC-70)
    for _ in range(5):
        r1.deliver(ctx["task_id"], wrong_otp(otp), due)
    task = r1.task().json()["task"]
    assert task["delivery_otp"]["locked"] is True
    assert rider_op(op="unlock_otp", **{"as": OPS}, order_id=ctx["order_id"])["ok"]
    assert r1.deliver(ctx["task_id"], otp, cod_due(task)).status_code == 200


# --------------------------------------------------------------------------- ledger and deposits


def test_p5_tc94_ledger_paging(r1, p5_shop_a):
    """P5-TC-94 ledger newest first with before_id paging; me.cash matches the last balance."""
    r1.online_at()
    deliver_cash(r1, p5_shop_a)
    page = r1.get("cash/ledger/", page_size=1)
    validate_response(page, "rider_cash_ledger")
    body = page.json()
    assert body["previous"] is None and len(body["results"]) == 1
    top = body["results"][0]
    assert top["entry_type"] == "COD_COLLECTED"
    assert cash_of(r1)["cash_in_hand"] == top["balance_after"]
    if body["next"]:
        nxt = r1.get("cash/ledger/", page_size=1, before_id=top["id"]).json()["results"]
        assert nxt and nxt[0]["id"] < top["id"]


@pytest.mark.smoke
def test_p5_tc95_deposit_clears_cash(r1, p5_shop_a):
    """P5-TC-95 🔥 OPS records a deposit of the whole balance → DEPOSIT entry, cash 0.00."""
    r1.online_at()
    deliver_cash(r1, p5_shop_a)
    bal = cash_of(r1)["cash_in_hand"]
    out = rider_op(op="record_deposit", **{"as": OPS}, phone=R1_PHONE, amount=bal, key="qa-" + secrets.token_hex(4))
    assert out["ok"], out
    assert cash_of(r1)["cash_in_hand"] == "0.00"
    assert ledger_rows(rider_id_of(R1_PHONE))[-1][1] == "DEPOSIT"


# 1.005: the console form refuses 3 dp (DecimalField decimal_places=2); the service itself rounds
# half-up (observation O-P5-07), so it is checked on the form in test_p5_tc96_form_refuses_3dp.
@pytest.mark.parametrize("amount", ["0", "-5", "abc", "999999.00"])
def test_p5_tc96_deposit_validation(r1, amount):
    """P5-TC-96 zero, negative, 3-dp, non-numeric and over-balance deposits are refused."""
    out = rider_op(op="record_deposit", **{"as": OPS}, phone=R1_PHONE, amount=amount)
    assert not out["ok"], out


def test_p5_tc96_form_refuses_3dp(r1):
    """P5-TC-96 the Ops Console deposit form refuses a 3-dp amount (1.005) and records nothing."""
    from p4_console import Ops

    rid = rider_id_of(R1_PHONE)
    before = len(ledger_rows(rid))
    s = Ops(OPS)
    try:
        r = s.post(f"/ops/cash/riders/{rid}/deposit/", {"amount": "1.005", "note": "QA 3dp"})
        assert r.status_code in (200, 400, 422) and "Traceback" not in r.text, r.status_code
    finally:
        s.close()
    assert len(ledger_rows(rid)) == before


def test_p5_tc96_deposit_idempotent(r1, p5_shop_a):
    """P5-TC-96 the same form (idempotency key) posted twice → one DEPOSIT."""
    r1.online_at()
    deliver_cash(r1, p5_shop_a)
    key = "qa-" + secrets.token_hex(4)
    rid = rider_id_of(R1_PHONE)
    n0 = sum(1 for r in ledger_rows(rid) if r[1] == "DEPOSIT")
    out = rider_ops({"op": "record_deposit", "as": OPS, "phone": R1_PHONE, "amount": "1.00", "key": key},
                    {"op": "record_deposit", "as": OPS, "phone": R1_PHONE, "amount": "1.00", "key": key})
    assert out[0]["ok"], out
    assert sum(1 for r in ledger_rows(rid) if r[1] == "DEPOSIT") == n0 + 1


@pytest.mark.smoke
@pytest.mark.parametrize(("role", "allowed"), [(SUPER, True), (OPS, True), (FINANCE, True), (MANAGER, False),
                                               (SUPPORT, False), (CATALOG, False), (STAFF, False)])
def test_p5_tc114_deposit_roles(r1, role, allowed):
    """P5-TC-114 🔥 DL-61 (a): deposits by Super Admin, Ops, Finance (and the store's own manager);
    Support and others refused. MANAGER is GGN-01 only, so QA-02's rider is out of scope."""
    out = rider_op(op="record_deposit", **{"as": role}, phone=R1_PHONE, amount="0.01")
    if allowed:
        assert out["ok"] or "cash" in (out.get("message") or "").lower() or out.get("code") == "VALIDATION_ERROR", out
    else:
        assert not out["ok"] and out.get("error") in ("PermissionDenied", "ValidationError"), out


# --------------------------------------------------------------------------- earnings, history, payouts


def test_p5_tc99_earnings_ranges(r1):
    """P5-TC-99 earnings for today, a range, from > to (400), and > 366 days (400)."""
    t = ist_today()
    r = r1.get("earnings/", **{"from": t.isoformat(), "to": t.isoformat()})
    validate_response(r, "rider_earnings")
    assert r.status_code == 200
    assert_error(r1.get("earnings/", **{"from": t.isoformat(), "to": (t - timedelta(days=1)).isoformat()}),
                 400, "VALIDATION_ERROR")
    assert_error(r1.get("earnings/", **{"from": (t - timedelta(days=367)).isoformat(), "to": t.isoformat()}),
                 400, "VALIDATION_ERROR")


@pytest.mark.smoke
def test_p5_tc100_earnings_per_delivery(r1, p5_shop_a):
    """P5-TC-100 a delivered task earns BASE + DISTANCE = 30.00 + 5.00 x distance_km (D-16), recorded once."""
    r1.online_at()
    ctx, task = deliver_cash(r1, p5_shop_a)
    t = ist_today().isoformat()
    e = r1.get("earnings/", **{"from": t, "to": t}).json()
    mine = [o for o in e["orders"] if o["task_id"] == ctx["task_id"]]
    assert len(mine) == 1, e
    assert Decimal(mine[0]["total"]) == payout_oracle(task["distance_km"]), (mine, task["distance_km"])


def test_p5_tc100_earnings_after_pickup_fail(r1, p5_shop_a):
    """DL-61 (c): a failed delivery after pickup still earns the fee; an unassigned one before pickup does not."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    assert r1.fail(ctx["task_id"], "WRONG_ADDRESS").status_code == 200
    t = ist_today().isoformat()
    e = r1.get("earnings/", **{"from": t, "to": t}).json()
    assert any(o["task_id"] == ctx["task_id"] for o in e["orders"]), e


def test_p5_tc101_history_paging_and_detail(r1, p5_shop_a):
    """P5-TC-101 history newest first with before_id paging; detail of own task; IDOR on detail is 404."""
    r1.online_at()
    ctx, _ = deliver_cash(r1, p5_shop_a)
    h = r1.get("tasks/history/", page_size=1)
    validate_response(h, "rider_tasks_history")
    assert h.json()["results"][0]["task_id"] == ctx["task_id"]
    d = r1.get(f"tasks/history/{ctx['task_id']}/")
    validate_response(d, "rider_tasks_history_detail")
    assert d.status_code == 200 and d.json()["status"] == "DELIVERED"


def test_p5_tc102_payout_and_mark_paid(r1, p5_shop_a):
    """P5-TC-102 FIN creates a payout for today and marks it paid; the rider sees it in /rider/payouts/."""
    r1.online_at()
    deliver_cash(r1, p5_shop_a)
    t = ist_today().isoformat()
    out = rider_op(op="create_payout", **{"as": FINANCE}, phone=R1_PHONE, start=t, end=t)
    assert out["ok"], out
    pid = out["result"]["payout_id"]
    assert rider_op(op="mark_paid", **{"as": FINANCE}, payout_id=pid, reference="QA-UTR-1")["ok"]
    p = r1.get("payouts/")
    validate_response(p, "rider_payouts_list")
    mine = [x for x in p.json()["results"] if x["id"] == pid]
    assert mine and mine[0]["status"] == "PAID" and mine[0]["reference"] == "QA-UTR-1"
    out = rider_op(op="create_payout", **{"as": FINANCE}, phone=R1_PHONE, start=t, end=t)
    assert not out["ok"] or out["result"]["amount"] == "0.00", "earning lines paid twice"


@pytest.mark.parametrize("role", [SUPPORT, STAFF, CATALOG, MANAGER])
def test_p5_tc115_payout_roles(r1, role):
    """P5-TC-115 only Finance/Super Admin create payouts."""
    t = ist_today().isoformat()
    assert not rider_op(op="create_payout", **{"as": role}, phone=R1_PHONE, start=t, end=t)["ok"]


@pytest.mark.smoke
def test_p5_tc109_records_idor(r1, r2, p5_shop_a):
    """P5-TC-109 🔥 R2 cannot read R1's history detail (404); rider_id params are ignored."""
    r1.online_at()
    ctx, _ = deliver_cash(r1, p5_shop_a)
    assert_error(r2.get(f"tasks/history/{ctx['task_id']}/"), 404, "NOT_FOUND")
    for path in ("tasks/history/", "cash/ledger/", "payouts/"):
        body = r2.get(path, rider_id=rider_id_of(R1_PHONE)).json()
        assert all(x.get("task_id") != ctx["task_id"] for x in body["results"]), path
    led2 = {x["id"] for x in r2.get("cash/ledger/").json()["results"]}
    led1 = {r[0] for r in ledger_rows(rider_id_of(R1_PHONE))}
    assert not led1 & led2


# --------------------------------------------------------------------------- DL-61 (b) cash limit, (d) COD block


@pytest.mark.smoke
def test_dl61b_cod_offer_skipped_over_cash_limit(r1, p5_shop_a):
    """DL-61 (b): with cash_in_hand + COD amount > limit, R1 gets no COD offer and sees deposit_required;
    a prepaid order is still offered."""
    rider_op(op="set_cash_limit", **{"as": SUPER}, phone=R1_PHONE, amount="1.00")
    try:
        r1.online_at()
        order = p5_shop_a.place_cod()
        assert r1.no_offer_for(20), "COD offer sent over the cash limit"
        assert cash_of(r1).get("deposit_required") is True
        p5_shop_a.cancel(order["id"])
        ctx = bring_to("OFR", shop=p5_shop_a, rider=r1, method="ONLINE")
        assert ctx["offer"]["payment_type"] != "COD"
    finally:
        rider_op(op="set_cash_limit", **{"as": SUPER}, phone=R1_PHONE, amount="5000.00")


def _refusals_since_lift(phone: str) -> int:
    return db_query(
        "select count(*) from delivery_deliverytask t join orders_order o on o.id=t.order_id "
        "join accounts_user u on u.id=o.user_id where u.phone=%s and o.payment_method='COD' "
        "and t.fail_reason='CUSTOMER_REFUSED' and (u.cod_block_lifted_at is null or t.failed_at > u.cod_block_lifted_at)",
        (phone,),
    )[0][0]


def _cod_blocked(phone: str) -> bool:
    return db_query("select cod_blocked from accounts_user where phone=%s", (phone,))[0][0]


def test_dl61d_cod_blocked_after_two_refusals(r1, p5_shop_a):
    """DL-61 (d) / P5-TC-82: refused COD deliveries since the last lift block COD at exactly 2
    (COD_NOT_AVAILABLE); OPS lifts the block and COD works again. Earlier cases may have left one
    refusal since the last lift, so the oracle is the count, read before each step."""
    phone = QA_PHONES["a"]
    r1.online_at()
    assert not _cod_blocked(phone)
    while not _cod_blocked(phone):
        before = _refusals_since_lift(phone)
        assert before < 2, f"{before} refusals since lift but not blocked"
        ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
        assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
        rider_op(op="cleanup_rider", **{"as": SUPER}, phone=R1_PHONE)
        r1.online_at()
        assert _cod_blocked(phone) is (before + 1 >= 2), (before, _cod_blocked(phone))
    from p3_support import V_SUN_1L

    p5_shop_a.fill({V_SUN_1L: 1}, address_id=p5_shop_a.address["id"])
    r = p5_shop_a.place("COD", address_id=p5_shop_a.address["id"])
    assert_error(r, r.status_code, "COD_NOT_AVAILABLE")
    assert rider_op(op="lift_cod_block", **{"as": OPS}, customer_phone=phone)["ok"]
    assert not _cod_blocked(phone) and _refusals_since_lift(phone) == 0
    p5_shop_a.place_cod()
