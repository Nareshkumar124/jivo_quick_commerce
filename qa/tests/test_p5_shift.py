"""Phase 5 slice 5.2 shifts, locations and heartbeat (06 §3 Shift/Location, 04 §2.3, §3).

Stage 1 scaffold (2026-11-05): the rider fixtures need slice 5.3 (cleanup unassigns tasks), so the
module is gated with the 5.3 cases. Not executed yet.
"""

from __future__ import annotations

import pytest

from p5_support import (  # noqa: F401 (fixtures)
    P5_53, QA02, R1_PHONE, now_iso, offset, p5_shop_a, qa_worker, r1, r2, rider_id_of,
)
from qa_support import assert_error, db_query, describe, validate_response

pytestmark = P5_53


def open_shifts(rider_id: int) -> int:
    return db_query("select count(*) from delivery_ridershift where rider_id=%s and ended_at is null", (rider_id,))[0][0]


def test_p5_tc21_shift_start_idempotent(r1):
    """P5-TC-21 🔥 shift/start at the store twice: same open shift, intervals in the answer."""
    first = r1.shift_start(offset(QA02, north_m=20))
    validate_response(first, "rider_shift_start")
    assert first.status_code == 200 and first.json()["is_online"] is True, describe(first)
    assert set(first.json()["location"]) >= {"active_interval_seconds", "idle_interval_seconds", "max_batch"}
    again = r1.shift_start(offset(QA02, north_m=20))
    assert again.status_code == 200, describe(again)
    assert again.json()["shift"]["id"] == first.json()["shift"]["id"]
    assert open_shifts(rider_id_of(R1_PHONE)) == 1


@pytest.mark.parametrize(("metres", "ok"), [(1990, True), (2010, False)])
def test_p5_tc22_shift_start_radius(r1, metres, ok):
    """P5-TC-22 RIDER_SHIFT_START_RADIUS_M 2000 from the home store."""
    r = r1.shift_start(offset(QA02, north_m=metres))
    if ok:
        assert r.status_code == 200, describe(r)
    else:
        err = assert_error(r, 422, "OUTSIDE_GEOFENCE")
        assert err["details"]["radius_m"] == 2000 and err["details"]["distance_m"] > 2000


@pytest.mark.parametrize("body", [{}, {"lat": 91, "lng": 75.78}, {"lat": "26.9", "lng": "75.7"}, {"lat": 26.9}])
def test_p5_tc22_shift_start_invalid(r1, body):
    """P5-TC-22 invalid positions → 400."""
    assert_error(r1.post("shift/start/", body), 400, "VALIDATION_ERROR")


def test_p5_tc24_shift_end_idle_then_offline_location(r1):
    """P5-TC-24 idle: offline MANUAL by the rider; a location afterwards → 409 RIDER_OFFLINE."""
    r1.online_at()
    r = r1.shift_end()
    validate_response(r, "rider_shift_end")
    assert r.status_code == 200 and r.json()["is_online"] is False, describe(r)
    assert r.json()["shift"]["end_reason"] == "MANUAL" and r.json()["shift"]["ended_by"] == "rider"
    assert_error(r1.ping(), 409, "RIDER_OFFLINE")


def test_p5_tc24_shift_end_withdraws_offer_and_refused_on_task(r1, r2, p5_shop_a):
    """P5-TC-24 with a pending offer: offline and the offer withdrawn (R2 offered next);
    with an active task: 409 ACTIVE_TASK, still online."""
    from p5_support import bring_to

    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    r2.online_at(offset(QA02, north_m=600))
    assert r1.shift_end().status_code == 200
    assert r1.offer().json()["offer"] is None
    offer = r2.wait_offer(task_id=ctx["task_id"])
    assert r2.accept(offer["id"]).status_code == 200
    assert_error(r2.shift_end(), 409, "ACTIVE_TASK")
    assert r2.heartbeat().json()["is_online"] is True


def test_p5_tc25_location_batches(r1):
    """P5-TC-25 batch sizes, duplicates and the −24 h / +2 min window."""
    r1.online_at()
    t = now_iso(-5)
    p = {"lat": QA02[0], "lng": QA02[1], "accuracy": 8}
    r = r1.post("locations/", {"points": [{**p, "recorded_at": t}, {**p, "recorded_at": t}]})
    validate_response(r, "rider_locations_create")
    assert r.status_code == 200, describe(r)
    assert (r.json()["accepted"], r.json()["duplicates"]) == (1, 1)
    r = r1.post("locations/", {"points": [{**p, "recorded_at": t}]})
    assert r.json()["duplicates"] == 1 and r.json()["accepted"] == 0
    r = r1.post("locations/", {"points": [{**p, "recorded_at": now_iso(-25 * 3600)}, {**p, "recorded_at": now_iso(180)},
                                          {**p, "recorded_at": now_iso(60)}]})
    assert (r.json()["accepted"], r.json()["rejected"]) == (1, 2), describe(r)
    assert_error(r1.post("locations/", {"points": []}), 400, "VALIDATION_ERROR")
    many = [{**p, "recorded_at": now_iso(-i - 100)} for i in range(51)]
    assert_error(r1.post("locations/", {"points": many}), 400, "VALIDATION_ERROR")
    for bad in ({**p, "lat": 91, "recorded_at": now_iso(-2)}, {**p, "accuracy": -1, "recorded_at": now_iso(-3)}):
        assert_error(r1.post("locations/", {"points": [bad]}), 400, "VALIDATION_ERROR")


def test_p5_tc27_heartbeat_states(r1, p5_shop_a):
    """P5-TC-27 heartbeat reports is_online, pending offer, active task and shift."""
    from p5_support import bring_to

    hb = r1.heartbeat()
    validate_response(hb, "rider_heartbeat")
    assert hb.json()["is_online"] is False
    r1.online_at()
    hb = r1.heartbeat().json()
    assert hb["is_online"] is True and hb["pending_offer_id"] is None and hb["active_task_id"] is None
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    assert r1.heartbeat().json()["pending_offer_id"] == ctx["offer"]["id"]
    assert r1.accept(ctx["offer"]["id"]).status_code == 200
    hb = r1.heartbeat().json()
    assert hb["active_task_id"] == ctx["task_id"] and hb["pending_offer_id"] is None


def test_p5_tc32_no_tracking_while_offline(r1):
    """P5-TC-32 points sent while offline are refused and never stored (04 §3, DPDP)."""
    rid = rider_id_of(R1_PHONE)
    before = db_query("select count(*) from delivery_riderlocation where rider_id=%s", (rid,))[0][0]
    for _ in range(3):
        assert_error(r1.ping(recorded_at=now_iso(-1)), 409, "RIDER_OFFLINE")
    after = db_query("select count(*) from delivery_riderlocation where rider_id=%s", (rid,))[0][0]
    assert after == before
