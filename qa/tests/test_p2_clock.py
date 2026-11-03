"""Phase 2 store hours (06 §2.3, 03 §2.3, 07 §2.2): closed store, opens_at, ETA null, message,
home store block, browsing while closed, and the open/close boundaries.

Runs only on the `clock` instance profile: the QA harness (qa/tools/clock/sitecustomize.py) shifts
the backend's clock to QA_FAKE_NOW, and writes the offset to private/.instance-clock-offset, so
the expected state is computed here from the same shifted "now" and the store's StoreTiming rows
(read-only SQL). Read-only requests only.

    QA_FAKE_NOW=2026-11-03T23:30:00+05:30 qa/tools/instance.sh start clock 0b801d1
"""

from __future__ import annotations

import time
from datetime import UTC, datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from qa_support import PRIVATE, STORE_HEADERS, STORE_POINT, db_query, describe, validate_response

pytestmark = pytest.mark.profile_clock
IST = ZoneInfo("Asia/Kolkata")


def _fake_now() -> datetime:
    offset = float((PRIVATE / ".instance-clock-offset").read_text())
    return datetime.fromtimestamp(time.time() + offset, tz=IST)


def _windows():
    return db_query("select weekday, opens_at, closes_at from stores_storetiming where store_id = 1 order by weekday, opens_at")


def _expected(now: datetime):
    """(is_open, opens_at UTC | None) from StoreTiming (IST wall clock; closes_at exclusive)."""
    windows = _windows()
    is_open = any(w == now.weekday() and o <= now.time() < c for w, o, c in windows)
    if is_open:
        return True, None
    for offset in range(8):
        day = (now + timedelta(days=offset)).date()
        for w, o, _ in windows:
            start = datetime.combine(day, o, tzinfo=IST)
            if w == day.weekday() and start > now:
                return False, start.astimezone(UTC)
    return False, None


def _state(api):
    r = api.get("/api/v1/serviceability/", params={"lat": STORE_POINT[0], "lng": STORE_POINT[1]})
    assert r.status_code == 200, describe(r)
    validate_response(r, "serviceability_check")
    return r.json()


def _near_boundary(now: datetime, seconds: int = 20) -> bool:
    return any(
        abs((datetime.combine(now.date(), t, tzinfo=IST) - now).total_seconds()) < seconds
        for _, o, c in _windows()
        for t in (o, c)
    )


def test_p2_tc09_store_status_at_fake_time(api):
    """P2-TC-09/10 🔥 At the shifted time: is_open per StoreTiming; when closed: still serviceable,
    opens_at = the next opening (UTC), eta_minutes null, message names the opening time in IST
    ("It opens at 7:00 AM." / "It opens tomorrow at 7:00 AM."); home `store` block identical;
    the catalog stays browsable (no STORE_CLOSED on reads)."""
    now = _fake_now()
    if _near_boundary(now):
        pytest.skip("too close to an open/close boundary: see test_p2_tc11")
    is_open, opens_at = _expected(now)
    body = _state(api)
    print(f"fake now {now.isoformat()} -> {body}")
    assert body["serviceable"] is True
    assert body["store"]["is_open"] is is_open
    if is_open:
        assert body["store"]["opens_at"] is None and body["message"] is None and body["eta_minutes"]
    else:
        assert body["eta_minutes"] is None
        got = datetime.fromisoformat(body["store"]["opens_at"].replace("Z", "+00:00"))
        assert got == opens_at, (got, opens_at)
        local = opens_at.astimezone(IST)
        clock = f"{local.hour % 12 or 12}:{local.minute:02d} {'AM' if local.hour < 12 else 'PM'}"
        day = "tomorrow at" if local.date() == now.date() + timedelta(days=1) else "at"
        assert body["message"] == f"The store is closed now. It opens {day} {clock}.", body["message"]
    home = api.get("/api/v1/home/", headers=STORE_HEADERS)
    assert home.status_code == 200, describe(home)
    assert home.json()["store"] == body["store"]
    for path in ("/api/v1/products/", "/api/v1/products/1/", "/api/v1/categories/"):
        r = api.get(path, headers=STORE_HEADERS)
        assert r.status_code == 200, describe(r)


def test_p2_tc11_boundary_transition(api):
    """P2-TC-11 Within 60 s before an opening (07:00) or closing (23:00) boundary: the state
    before is as expected, and flips right after the boundary (status is never cached; closes_at
    is exclusive)."""
    now = _fake_now()
    boundary = None
    for _, o, c in _windows():
        for t in (o, c):
            candidate = datetime.combine(now.date(), t, tzinfo=IST)
            if 0 < (candidate - now).total_seconds() <= 60:
                boundary = candidate
    if boundary is None:
        pytest.skip("not started just before a boundary (use QA_FAKE_NOW=...T06:59:30 or T22:59:30)")
    before_open, _ = _expected(now)
    assert _state(api)["store"]["is_open"] is before_open
    time.sleep((boundary - _fake_now()).total_seconds() + 3)
    after = _state(api)
    print(f"boundary {boundary.time()}: before is_open={before_open}, after {after}")
    assert after["store"]["is_open"] is (not before_open)
    assert (after["eta_minutes"] is None) is before_open
