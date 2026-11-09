"""Phase 5 slice 5.3 security: IDOR on every rider object, customer tracking and OTP visibility
(DL-56, 09 §3.2), error envelope on the rider endpoints (06 §6).

Stage 1 scaffold (2026-11-05), not executed: gated by p5_support.requires_53.
"""

from __future__ import annotations

import time

import httpx
import pytest

from conftest import login
from p5_support import (  # noqa: F401 (fixtures)
    P5_53, QA02, RiderClient, bring_to, offset, p5_shop_a, p5_shop_b, pickup_code, qa_worker,
    r1, r2, task_row, wait_order_status,
)
from qa_support import QA_PHONES, RIDER_HEADERS, assert_error, describe, validate_response

pytestmark = P5_53

TASK_ACTIONS = ["arrived-store", "pickup", "arrived-customer", "cod-qr", "deliver", "fail"]


def call_task_action(rider: RiderClient, task_id: int, action: str, ctx: dict) -> httpx.Response:
    if action == "arrived-store":
        return rider.arrived_store(task_id)
    if action == "pickup":
        return rider.pickup(task_id, pickup_code(ctx["order_id"]))
    if action == "arrived-customer":
        return rider.arrived_customer(task_id)
    if action == "cod-qr":
        return rider.post(f"tasks/{task_id}/cod-qr/")
    if action == "deliver":
        return rider.deliver(task_id, ctx.get("otp") or "0000")
    return rider.fail(task_id, "WRONG_ADDRESS")


def test_p5_tc104_other_riders_offer_is_404(r1, r2, p5_shop_a):
    """P5-TC-104 🔥 R2 accept/reject on R1's offer → 404; the offer stays PENDING."""
    r1.online_at()
    r2.online_at(offset(QA02, north_m=1500))
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert_error(r2.accept(ctx["offer"]["id"]), 404, "NOT_FOUND")
    assert_error(r2.reject(ctx["offer"]["id"]), 404, "NOT_FOUND")
    assert r1.offer().json()["offer"]["id"] == ctx["offer"]["id"]


@pytest.mark.parametrize("stage", ["ASG", "PKD", "ATC"])
def test_p5_tc105_other_riders_task_is_404(r1, r2, p5_shop_a, stage):
    """P5-TC-105 🔥 every task action on R1's task by R2 → 404; R1's task unchanged and its
    pickup/OTP counters untouched."""
    r1.online_at()
    r2.online_at(offset(QA02, north_m=1500))
    ctx = bring_to(stage, shop=p5_shop_a, rider=r1)
    before = task_row(ctx["order_id"])
    for action in TASK_ACTIONS:
        r = call_task_action(r2, ctx["task_id"], action, ctx)
        assert_error(r, 404, "NOT_FOUND")
    after = task_row(ctx["order_id"])
    assert (after["status"], after["rider_id"], after["pickup_attempts"], after["otp_attempts"]) == (
        before["status"], before["rider_id"], before["pickup_attempts"], before["otp_attempts"])
    assert r2.task().json()["task"] is None


def test_p5_tc106_id_enumeration_reveals_nothing(r1, r2, p5_shop_a):
    """P5-TC-106 R2 sweeping ids around R1's offer/task: only 404, bodies identical for missing
    and foreign ids."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    foreign = r2.post(f"tasks/{ctx['task_id']}/arrived-store/", {"lat": QA02[0], "lng": QA02[1]})
    missing = r2.post("tasks/999999999/arrived-store/", {"lat": QA02[0], "lng": QA02[1]})
    assert foreign.status_code == missing.status_code == 404
    assert foreign.json() == missing.json()
    for task_id in range(ctx["task_id"] - 25, ctx["task_id"] + 25):
        r = r2.post(f"tasks/{task_id}/arrived-store/", {"lat": QA02[0], "lng": QA02[1]})
        assert r.status_code == 404, describe(r)
    for offer_id in range(ctx["offer"]["id"] - 25, ctx["offer"]["id"] + 25):
        assert r2.accept(offer_id).status_code == 404


def test_p5_tc107_customer_on_rider_endpoints(r1, p5_shop_a, api):
    """P5-TC-107 a user without a rider profile: 403 PERMISSION_DENIED, rider_status NONE."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    h = {**RIDER_HEADERS, **p5_shop_a.session.headers}
    for method, path in (("get", "me/"), ("get", "offers/current/"), ("get", "tasks/current/"),
                         ("post", f"offers/{ctx['offer']['id']}/accept/"), ("post", "shift/start/")):
        r = getattr(api, method)(f"/api/v1/rider/{path}", headers=h, **({"json": {}} if method == "post" else {}))
        err = assert_error(r, 403, "PERMISSION_DENIED")
        assert err["details"].get("rider_status") == "NONE"
    assert r1.offer().json()["offer"]["id"] == ctx["offer"]["id"]


def test_p5_tc108_track_is_owner_only(r1, p5_shop_a, p5_shop_b, api):
    """P5-TC-108 🔥 B and the delivering rider reading A's track → 404."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1, method="ONLINE")
    assert_error(p5_shop_b.track(ctx["order_id"]), 404, "NOT_FOUND")
    rider_as_customer = api.get(f"/api/v1/orders/{ctx['order_id']}/track/",
                                headers={**RIDER_HEADERS, **r1.session.headers})
    assert_error(rider_as_customer, 404, "NOT_FOUND")


def test_p5_tc119_track_visibility_by_state(r1, p5_shop_a):
    """P5-TC-119 🔥 DL-56: rider null until ASSIGNED; name only before pickup; phone + OTP only
    while OUT_FOR_DELIVERY; the OTP shown is the one deliver accepts."""
    r1.online_at()
    order = p5_shop_a.place_online_paid()
    oid = order["id"]
    wait_order_status(oid, "ACCEPTED")
    t = p5_shop_a.track(oid)
    validate_response(t, "orders_track")
    assert t.json()["rider"] is None and t.json()["delivery_otp"] is None
    offer = r1.wait_offer()
    assert p5_shop_a.track(oid).json()["rider"] is None  # OFFERED: no rider yet
    task = r1.accept(offer["id"]).json()
    seen = p5_shop_a.track(oid).json()
    assert seen["rider"]["phone"] is None and seen["delivery_otp"] is None
    name = seen["rider"]["name"]
    assert name.endswith(".") and len(name.split()[-1]) == 2, name  # "First L."
    assert r1.arrived_store(task["id"]).status_code == 200
    assert p5_shop_a.track(oid).json()["rider"]["phone"] is None
    from p5_support import pack

    pack(oid)
    assert r1.pickup(task["id"], pickup_code(oid)).status_code == 200
    seen = p5_shop_a.track(oid).json()
    assert seen["rider"]["phone"] == r1.phone and seen["delivery_otp"]
    assert r1.arrived_customer(task["id"]).status_code == 200
    seen = p5_shop_a.track(oid).json()
    assert seen["rider"]["phone"] == r1.phone
    assert r1.deliver(task["id"], seen["delivery_otp"]).status_code == 200


@pytest.mark.parametrize("ending", ["DELIVERY_FAILED", "RETURNED", "CANCELLED"])
def test_p5_tc120_track_hidden_after_failure_or_cancel(r1, p5_shop_a, ending):
    """P5-TC-120 phone and OTP null after DELIVERY_FAILED, RETURNED and CANCELLED (after ASG)."""
    from p4_support import SUPER
    from p5_support import rider_op

    r1.online_at()
    if ending == "CANCELLED":
        ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
        assert p5_shop_a.cancel(ctx["order_id"]).status_code == 200
    else:
        ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
        assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
        if ending == "RETURNED":
            assert rider_op(op="receive_return", **{"as": SUPER}, order_id=ctx["order_id"])["ok"]
    body = p5_shop_a.track(ctx["order_id"]).json()
    assert body["status"] == ending and body["delivery_otp"] is None
    # 06 §3 "eta_at (null once finished)"; DELIVERY_FAILED is not terminal in 08 §1 and the server
    # still sends eta_at there (observation O-P5-08, PM to decide). RETURNED/CANCELLED must be null.
    if ending != "DELIVERY_FAILED":
        assert body["eta_at"] is None, body["eta_at"]
    assert body["rider"] is None or body["rider"]["phone"] is None


def test_p5_tc121_otp_only_in_owner_track(r1, p5_shop_a):
    """P5-TC-121 (API part) the OTP value is absent from the order detail/list and from every
    rider response; the rider sees only {length, attempts_remaining, locked}."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    otp = ctx["otp"]
    for r in (p5_shop_a.order(ctx["order_id"]), p5_shop_a.api.get("/api/v1/orders/", headers=p5_shop_a.h),
              r1.task(), r1.heartbeat(), r1.offer(), r1.me()):
        assert r.status_code == 200, describe(r)
        assert f'"{otp}"' not in r.text, f"OTP leaked in {r.request.url.path}"
    assert set(r1.task().json()["task"]["delivery_otp"]) == {"length", "attempts_remaining", "locked"}


def test_p5_tc122_rider_location_on_track(r1, p5_shop_a):
    """P5-TC-122 a new point shows on the owner's track within 5 s (local indication)."""
    r1.online_at()
    ctx = bring_to("OFD", shop=p5_shop_a, rider=r1)
    point = offset(QA02, north_m=700)
    sent = time.monotonic()
    assert r1.ping(point).status_code == 200
    while time.monotonic() - sent < 10:
        rider = p5_shop_a.track(ctx["order_id"]).json()["rider"]
        if abs(rider["lat"] - point[0]) < 1e-5 and abs(rider["lng"] - point[1]) < 1e-5:
            break
        time.sleep(0.25)
    lag = time.monotonic() - sent
    assert lag < 5, f"location reached track after {lag:.2f}s"


def test_p5_tc123_what_each_side_sees(r1, p5_shop_a):
    """P5-TC-123 offer: locality only; customer: abbreviated rider name, never the full surname."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    assert p5_shop_a.address["house"] not in str(ctx["offer"])
    full = r1.me().json()["full_name"]
    shown = p5_shop_a.track(ctx["order_id"]).json()["rider"]["name"]
    assert shown != full and full.split()[-1] not in shown.split()


@pytest.mark.parametrize(("method", "path"), [
    ("get", "offers/current/"), ("post", "offers/1/accept/"), ("post", "offers/1/reject/"),
    ("get", "tasks/current/"), ("post", "tasks/1/arrived-store/"), ("post", "tasks/1/pickup/"),
    ("post", "tasks/1/arrived-customer/"), ("post", "tasks/1/cod-qr/"), ("post", "tasks/1/deliver/"),
    ("post", "tasks/1/fail/"),
])
def test_p5_tc130_rider_endpoints_auth_envelope(api, method, path):
    """P5-TC-130 no token → 401 AUTH_REQUIRED; a bad token → 401 TOKEN_INVALID; wrong method → 405."""
    url = f"/api/v1/rider/{path}"
    assert_error(getattr(api, method)(url, headers=RIDER_HEADERS), 401, "AUTH_REQUIRED")
    bad = {**RIDER_HEADERS, "Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9.e30.x"}
    assert_error(getattr(api, method)(url, headers=bad), 401, "TOKEN_INVALID")
    session = login(QA_PHONES["c"], app="rider")
    wrong = "put" if method == "post" else "post"
    r = getattr(api, wrong)(url, headers={**RIDER_HEADERS, **session.headers}, **({"json": {}} if wrong != "get" else {}))
    assert_error(r, 405, "METHOD_NOT_ALLOWED")

