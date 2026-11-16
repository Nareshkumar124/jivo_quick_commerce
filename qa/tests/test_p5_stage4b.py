"""Phase 5, QA stage 4 part 2 (2026-11-10, develop f8db671): the P1/P2 P5 cases without an
execution after stage 3 that run on the `local` instance profile. Part 1 (P0 cases) is
`test_p5_stage4.py`; the timer-profile cases (TC-38, 47, 57a) are in `test_p5_stage4_profiles.py`.
QA numbers and the QA-only store QA-02 only. QA instance :8004 only."""

from __future__ import annotations

import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx
import pytest

from p3_admin import csrf, staff_login
from p4_support import CATALOG, FINANCE, OPS, STAFF, SUPER, SUPPORT
from p4_support import ops as store_ops
from p5_support import (  # noqa: F401 (fixtures)
    QA02, QA02_ID, R1_PHONE, RiderClient, bring_to, ensure_active_rider, money, now_iso, offers_of, offset,
    p5_shop_a, p5_shop_b, qa_worker, r1, r2, rider_id_of, rider_op, task_row, wait_order_status,
)
from qa_support import QA_PHONES, TEST_OTP, assert_error, bearer, clear_throttle, db_query, describe
from test_p5_stage4 import _admin_post, _epoch, _tamper_expiry

pytestmark = pytest.mark.p5_53
IST = timezone(timedelta(hours=5, minutes=30))
SMQ, SM = "qa02.manager@jivo.test", "store.manager@jivo.test"
ROLE_SET = (SUPER, OPS, SMQ, SM, FINANCE, SUPPORT, STAFF, CATALOG)
DL61_ALLOWED = {SUPER, OPS, SMQ}  # DL-61 (a): Super Admin, Ops, Store Manager of the rider's store


def ist_day_bounds() -> tuple[datetime, datetime]:
    start = datetime.now(IST).replace(hour=0, minute=0, second=0, microsecond=0)
    return start, start + timedelta(days=1)


def inr(value) -> str:
    from test_p7_console import inr as _inr

    return _inr(str(value))


def notif_count(phone: str, order_id: int, event: str, wait_s: float = 10) -> int:
    user = db_query("select id from accounts_user where phone=%s", (phone,))[0][0]
    n, end = 0, time.monotonic() + wait_s
    while time.monotonic() < end:
        n = db_query("select count(*) from notifications_notification where user_id=%s and order_id=%s and event=%s",
                     (user, order_id, event))[0][0]
        if n:
            break
        time.sleep(0.5)
    return n


def console_post(c: httpx.Client, path: str, page: str, data: dict | None = None) -> httpx.Response:
    """POST from a console page (CSRF from `page`; a 403 page has no token, so send none)."""
    got = c.get(page)
    m = re.search(r'name="csrfmiddlewaretoken" value="([^"]+)"', got.text)
    token = m.group(1) if m else c.cookies.get("csrftoken", "")
    return c.post(path, data={**(data or {}), "csrfmiddlewaretoken": token}, headers={"Referer": f"{c.base_url}{page}"})


# =========================================================================== 5.2 / 5.3


def test_p5_tc26_mocked_location_stored_and_alerted(r1, p5_shop_a):
    """P5-TC-26 a point with `is_mocked` true while on a task: 200; stored with is_mocked; ops alert
    MOCKED_LOCATION on the QA-02 feed; the rider is not blocked (the next normal ping is 200)."""
    from p6_support import staff_cookie
    from test_p6_t612 import Listener

    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    _, cookie = staff_cookie(OPS)
    feed = Listener("/ws/ops/live/", cookie=cookie)
    try:
        time.sleep(1)
        t0 = time.monotonic()
        clear_throttle("rider_locations")
        r = r1.ping(offset(QA02, north_m=35), is_mocked=True)
        assert r.status_code == 200, describe(r)
        rid = rider_id_of(R1_PHONE)
        rows = db_query("select is_mocked from delivery_riderlocation where rider_id=%s order by id desc limit 1", (rid,))
        assert rows and rows[0][0] is True, rows
        alert = feed.wait("alert", 10, t0)
        assert alert, f"no alert on the ops feed: {[m.get('type') for _, m in feed.msgs]}"
        assert "MOCKED_LOCATION" in str(alert[1]["data"]), alert[1]
        clear_throttle("rider_locations")
        assert r1.ping(offset(QA02, north_m=36)).status_code == 200
        assert r1.task().json()["task"]["id"] == ctx["task_id"]
    finally:
        feed.close()


def test_p5_tc64_pickup_rate_limit(r1, p5_shop_a):
    """P5-TC-64 11 pickup calls in one minute with wrong-shape codes (the lock is never reached):
    10 × 400, the 11th 429 RATE_LIMITED with Retry-After; pickup_attempts stays 0."""
    r1.online_at()
    ctx = bring_to("ATS", shop=p5_shop_a, rider=r1)
    clear_throttle("rider_pickup")
    codes = [r1.pickup(ctx["task_id"], "x").status_code for _ in range(10)]
    assert codes == [400] * 10, codes
    r = r1.pickup(ctx["task_id"], "x")
    assert_error(r, 429, "RATE_LIMITED")
    assert r.headers.get("Retry-After"), dict(r.headers)
    assert task_row(ctx["order_id"])["pickup_attempts"] == 0
    clear_throttle("rider_pickup")


def test_p5_tc50a_packed_sets_ready_and_notifies(r1, p5_shop_a):
    """P5-TC-50 (a) ASSIGNED task; OPS starts packing and marks packed (T8): the rider's task shows
    `ready_for_pickup` true and R1 gets one `rider.order_ready` notification."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    oid = ctx["order_id"]
    assert r1.task().json()["task"].get("ready_for_pickup") is False
    out = store_ops({"op": "start_packing", "as": OPS, "order_id": oid}, {"op": "packed", "as": OPS, "order_id": oid})
    assert all(o["ok"] for o in out), out
    assert r1.task().json()["task"]["ready_for_pickup"] is True
    user = db_query("select id from accounts_user where phone=%s", (R1_PHONE,))[0][0]
    n = 0
    for _ in range(20):  # rider pushes carry the task id in data (order_id NULL)
        n = db_query("select count(*) from notifications_notification where user_id=%s and event='rider.order_ready' "
                     "and data->>'task_id'=%s", (user, str(ctx["task_id"])))[0][0]
        if n:
            break
        time.sleep(0.5)
    assert n == 1, n


def test_p5_tc57b_retry_on_assigned_refused(r1, p5_shop_a):
    """P5-TC-57 (b) OPS presses "retry dispatch" in the console on an ASSIGNED task → refused: the
    task keeps R1, no new offer."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1)
    tid = ctx["task_id"]
    ops = staff_login(OPS)
    try:
        before = len(offers_of(tid))
        r = console_post(ops, f"/ops/dispatch/tasks/{tid}/retry/", f"/ops/dispatch/tasks/{tid}/")
        assert r.status_code in (302, 400, 409), r.status_code
        t = task_row(ctx["order_id"])
        assert t["status"] == "ASSIGNED" and t["rider_id"] == rider_id_of(R1_PHONE), t
        assert len(offers_of(tid)) == before
    finally:
        ops.close()


def test_p5_tc29_presence_from_server_receipt_time(r1, p5_shop_a):
    """P5-TC-29 R1 starts a shift, sends one point with `recorded_at` = now + 110 s, then nothing:
    130 s later R1 is not a candidate for a new order (presence counts from the server's receipt
    time, `DISPATCH_PING_MAX_AGE_SECONDS` 120): no offer within 20 s, the task SEARCHING."""
    clear_throttle("rider_locations")
    clear_throttle("rider_heartbeat")
    assert r1.shift_start(offset(QA02, north_m=20)).status_code == 200
    clear_throttle("rider_locations")
    r = r1.ping(offset(QA02, north_m=21), recorded_at=now_iso(110))
    assert r.status_code in (200, 400), describe(r)
    time.sleep(130)
    order = p5_shop_a.place_cod()
    wait_order_status(order["id"], "ACCEPTED")
    assert r1.no_offer_for(20), "R1 was offered on a 130 s old point (the future recorded_at counted)"
    t = task_row(order["id"])
    assert t and t["status"] in ("SEARCHING", "UNASSIGNED"), t


def test_p5_tc58_dispatch_latency_from_history():
    """P5-TC-58 (P2) server side, today's QA-02 orders: ACCEPTED (history) → first offer
    `offered_at`, for tasks offered within 60 s (a rider was free): p95 < 3 s (09 §1)."""
    # Stage 4 oracle fix: only orders since the running instance started (this build and host). The
    # morning's stage-3 orders ran on another PC with the 2 s localhost-Redis delay (OBS-S3-01).
    from qa_support import PRIVATE

    start = datetime.fromtimestamp((PRIVATE / ".instance-profile").stat().st_mtime, IST)
    end = datetime.now(IST) + timedelta(minutes=1)
    rows = db_query(
        "select extract(epoch from (min(f.offered_at) - h.created_at)) from orders_orderstatushistory h "
        "join orders_order o on o.id=h.order_id join delivery_deliverytask t on t.order_id=o.id "
        "join delivery_deliveryoffer f on f.task_id=t.id where o.store_id=%s and h.to_status='ACCEPTED' "
        "and h.created_at >= %s and h.created_at < %s group by h.id, h.created_at", (QA02_ID, start, end))
    deltas = sorted(float(d) for (d,) in rows if d is not None and 0 <= float(d) < 60)
    assert len(deltas) >= 10, f"only {len(deltas)} samples today"
    p50 = deltas[len(deltas) // 2]
    p95 = deltas[min(len(deltas) - 1, int(len(deltas) * 0.95))]
    print(f"TC-58: n={len(deltas)} p50={p50:.2f}s p95={p95:.2f}s max={deltas[-1]:.2f}s")
    assert p95 < 3.0, f"p95 {p95:.2f}s (n={len(deltas)})"


# =========================================================================== T13 photo, invoice


def _padded_jpeg(base: bytes, target: int) -> bytes:
    """A valid JPEG of about `target` bytes: COM segments inserted after SOI (EXIF kept)."""
    assert base[:2] == b"\xff\xd8"
    out, size = bytearray(base[:2]), len(base)
    chunk = b"Q" * 65000
    while size + len(chunk) + 4 < target:
        out += b"\xff\xfe" + (len(chunk) + 2).to_bytes(2, "big") + chunk
        size += len(chunk) + 4
    return bytes(out + base[2:])


def test_p5_tc84_fail_photo_validation_and_exif(r1, p5_shop_a):
    """P5-TC-84 fail at AT_CUSTOMER with a photo: a PDF → 400; a 6 MB JPEG → 400/413; a 1.2 MB JPEG →
    400 (1 MB cap, 04 §2.6); nothing is failed by those. Then an 800 KB JPEG with EXIF GPS → 200; the
    stored file (private bucket) is a re-encoded JPEG without EXIF, its URL signed, unsigned refused."""
    exif = (Path(__file__).parent / "fixtures" / "exif_gps.jpg").read_bytes()
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    tid, oid = ctx["task_id"], ctx["order_id"]

    def fail_with(content: bytes, name: str, mime: str) -> httpx.Response:
        return r1.api.post(f"/api/v1/rider/tasks/{tid}/fail/", headers=r1.h, data={"reason": "CUSTOMER_REFUSED"},
                           files={"photo": (name, content, mime)}, timeout=120)

    pdf = fail_with(b"%PDF-1.4\n%QA\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF", "x.pdf", "application/pdf")
    assert pdf.status_code == 400, describe(pdf)
    big = fail_with(_padded_jpeg(exif, 6 * 1024 * 1024), "big.jpg", "image/jpeg")
    assert big.status_code in (400, 413), big.status_code
    over = fail_with(_padded_jpeg(exif, 1_250_000), "over.jpg", "image/jpeg")
    assert over.status_code == 400, describe(over)
    assert task_row(oid)["status"] == "AT_CUSTOMER"
    ok = fail_with(_padded_jpeg(exif, 800 * 1024), "door.jpg", "image/jpeg")
    assert ok.status_code == 200, describe(ok)
    info = rider_op(op="fail_photo_info", order_id=oid)
    assert info["ok"], info
    res = info["result"]
    assert res["name"].startswith("delivery-failures/") and res["head"].startswith("ffd8"), res
    assert not res["has_exif"], "EXIF kept in the stored failure photo"
    assert res["size"] < 800 * 1024, res["size"]
    assert res["signed"] and httpx.get(res["url"].split("?")[0], timeout=20).status_code in (400, 403)


def test_p5_tc77_invoice_signed_link(r1, p5_shop_a, p5_shop_b):
    """P5-TC-77 A's DELIVERED order: invoice 200 with `invoice_number` <prefix>/<FY>/<6 digits> and a
    signed URL expiring within 600 s that serves a PDF; tampered or unsigned URL refused; B → 404;
    a not-delivered order → 409. (503 = WeasyPrint missing on this host: recorded as ⏭, not ✅.)"""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = r1.task().json()["task"]["cod_amount_due"]
    assert r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": due}).status_code == 200
    oid = ctx["order_id"]
    r = p5_shop_a.api.get(f"/api/v1/orders/{oid}/invoice/", headers=p5_shop_a.h, timeout=120)
    if r.status_code == 503:
        pytest.skip(f"invoice PDF unavailable on this host (503): {r.text[:200]}")
    assert r.status_code == 200, describe(r)
    body = r.json()
    assert re.fullmatch(r"[A-Z0-9-]+/\d{2,4}-\d{2}/\d{6}", body["invoice_number"]), body["invoice_number"]
    url = body["url"]
    left = _epoch(body["expires_at"]) - time.time()
    assert 0 < left <= 610, left
    pdf = httpx.get(url, timeout=30)
    assert pdf.status_code == 200 and pdf.content[:4] == b"%PDF", pdf.status_code
    assert httpx.get(_tamper_expiry(url), timeout=30).status_code in (400, 403)
    assert httpx.get(url.split("?")[0], timeout=30).status_code in (400, 403)
    assert_error(p5_shop_b.api.get(f"/api/v1/orders/{oid}/invoice/", headers=p5_shop_b.h), 404, "NOT_FOUND")
    other = p5_shop_a.place_cod()
    assert p5_shop_a.api.get(f"/api/v1/orders/{other['id']}/invoice/", headers=p5_shop_a.h).status_code == 409


# =========================================================================== 5.4 (cash, access, ops roles)


def test_p5_tc103_reads_in_any_status(r1):
    """P5-TC-103 R1 SUSPENDED and QA G (PENDING_KYC): history, earnings, ledger and payouts → 200."""
    paths = ["tasks/history/", "earnings/", "cash/ledger/", "payouts/"]
    out = rider_op(op="suspend", **{"as": SUPER}, phone=R1_PHONE, reason="QA TC-103 read check")
    assert out["ok"] and out["result"]["status"] == "SUSPENDED", out
    try:
        codes = [r1.get(p).status_code for p in paths]
    finally:
        back = rider_op(op="reinstate", **{"as": SUPER}, phone=R1_PHONE)
        assert back["ok"] and back["result"]["status"] == "ACTIVE", back
    assert codes == [200] * 4, codes
    g = RiderClient(r1.api, QA_PHONES["g"])
    assert g.me().json()["status"] == "PENDING_KYC"
    assert [g.get(p).status_code for p in paths] == [200] * 4


def test_p5_tc97_day_end_report_matches_sql(r1, p5_shop_a):
    """P5-TC-97 one more COD delivery and a deposit today, then the QA-02 day-end report (service and
    console `/ops/cash/?store=QA-02` as OPS): per rider collected, deposited and difference equal a
    SQL oracle over the cash ledger (IST day, store QA-02)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    due = r1.task().json()["task"]["cod_amount_due"]
    assert r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": due}).status_code == 200
    dep = rider_op(op="record_deposit", **{"as": OPS}, phone=R1_PHONE, amount=due, key=f"qa-tc97-{uuid.uuid4().hex[:8]}")
    assert dep["ok"], dep
    start, end = ist_day_bounds()
    oracle = {rid: (money(c or 0), money(-(d or 0))) for rid, c, d in db_query(
        "select rider_id, sum(amount) filter (where entry_type='COD_COLLECTED'), "
        "sum(amount) filter (where entry_type='DEPOSIT') from delivery_ridercashledger where store_id=%s and "
        "recorded_at >= %s and recorded_at < %s and entry_type in ('COD_COLLECTED','DEPOSIT') group by rider_id",
        (QA02_ID, start, end))}
    rep = rider_op(op="day_report", **{"as": OPS}, store_id=QA02_ID, day=start.date().isoformat())
    assert rep["ok"], rep
    svc = {row["rider_id"]: (money(row["collected"]), money(row["deposited"])) for row in rep["result"]["riders"]}
    assert svc == oracle, (svc, oracle)
    for row in rep["result"]["riders"]:
        assert money(row["difference"]) == money(row["collected"]) - money(row["deposited"])
    ops = staff_login(OPS)
    try:
        page = ops.get("/ops/cash/", params={"store": QA02_ID}).text
    finally:
        ops.close()
    for rid, (col, depo) in oracle.items():
        m = re.search(rf'data-testid="report-rider-{rid}">(.*?)</tr>', page, re.S)
        assert m, f"rider {rid} missing from the console day report"
        cells = re.findall(r"<td>(.*?)</td>", m.group(1))
        assert cells[1] == inr(col) and cells[2] == inr(depo), (rid, cells, col, depo)


def test_p5_tc117_ops_actions_role_matrix(r1, p5_shop_a):
    """P5-TC-117 per role through the real pages: force offline (`/ops/dispatch/riders/<id>/offline/`),
    cash limit (admin action) and unlock delivery OTP (an OTP-locked task). DL-61 (a), which replaced
    the A4 assumption: SA, OPS and the Store Manager of the rider's store may; the GGN-01 manager
    gets 404 (not his store); FIN/SUP/SS/CAT 403. A refusal changes nothing and writes no audit."""
    rid = rider_id_of(R1_PHONE)
    results = {}
    audit_from = db_query("select coalesce(max(id),0) from core_auditlog")[0][0]
    for who in ROLE_SET:
        c = staff_login(who)
        try:
            r1.online_at()
            f = console_post(c, f"/ops/dispatch/riders/{rid}/offline/", "/ops/dispatch/")
            online = db_query("select is_online from delivery_rider where id=%s", (rid,))[0][0]
            page = c.get(f"/admin/delivery/rider/{rid}/cash-limit/")
            lim = _admin_post(c, f"/admin/delivery/rider/{rid}/cash-limit/", {"amount": "5000.00"}).status_code \
                if page.status_code == 200 else page.status_code
            results[who] = (f.status_code, online, lim)
        finally:
            c.close()
    print("TC-117 force offline / cash limit per role:", results)
    known_bug = []
    for who, (fcode, online, lim) in results.items():
        if who in DL61_ALLOWED:
            assert fcode == 302 and online is False, (who, fcode, online)
            if who == SMQ and lim == 403:
                known_bug.append(who)  # BUG-0024: the admin action needs review_rider
            else:
                assert lim == 302, (who, lim)
        elif who == SM:
            assert fcode == 404 and online is True and lim in (403, 404), (who, fcode, online, lim)
        else:
            assert fcode == 403 and online is True and lim == 403, (who, fcode, online, lim)
    for email, action in db_query(
            "select u.email, a.action from core_auditlog a join accounts_user u on u.id=a.actor_id where a.id>%s "
            "and a.object_type='delivery.rider' and a.object_id=%s", (audit_from, str(rid))):
        assert email in DL61_ALLOWED, (email, action)
    # unlock delivery OTP: lock the task with 5 wrong OTPs; refused roles leave it locked; SMQ unlocks
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    tid, oid = ctx["task_id"], ctx["order_id"]
    due = r1.task().json()["task"]["cod_amount_due"]
    bad = f"{(int(ctx['otp']) + 1) % 10_000:04d}"
    for _ in range(5):
        r1.deliver(tid, bad, {"mode": "cash", "amount": due})
    assert task_row(oid)["otp_attempts"] >= 5
    for who in (FINANCE, SUPPORT, STAFF, CATALOG, SM):
        c = staff_login(who)
        try:
            r = console_post(c, f"/ops/dispatch/tasks/{tid}/unlock-otp/", "/ops/")
            assert r.status_code in (403, 404), (who, r.status_code)
        finally:
            c.close()
    assert task_row(oid)["otp_attempts"] >= 5
    smq = staff_login(SMQ)
    try:
        r = console_post(smq, f"/ops/dispatch/tasks/{tid}/unlock-otp/", f"/ops/dispatch/tasks/{tid}/")
        assert r.status_code == 302, r.status_code
    finally:
        smq.close()
    assert task_row(oid)["otp_attempts"] == 0
    assert r1.deliver(tid, ctx["otp"], {"mode": "cash", "amount": due}).status_code == 200
    if known_bug:
        pytest.xfail("BUG-0024: the QA-02 Store Manager gets 403 on the admin cash-limit action (DL-61 a allows it)")


# =========================================================================== 5.1 erasure (QA H)


def test_p5_tc18_rider_erasure_and_kyc_purge(api):
    """P5-TC-18 QA H (+919000000108, PM-approved spare): rider with 4 documents, bank, QA-02 and a short
    shift with a ping; deletes the account (API, rider app); anonymise (driver, as the beat job after
    the grace period): name, dob, emergency contact, vehicle number, bank blanked; location history
    deleted; kyc_purge_after = today + 365. The purge with today = that date (guarded to this rider)
    deletes the 4 document rows and files; the old signed link then fails."""
    from conftest import request_otp

    phone = QA_PHONES["h"]
    rider = ensure_active_rider(api, phone)
    rid = rider_id_of(phone)
    clear_throttle("rider_locations")
    # a shift starts at the store (geofence; 5 km away is 422, stage 4 test fix)
    assert rider.shift_start(offset(QA02, north_m=20)).status_code == 200
    clear_throttle("rider_locations")
    assert rider.ping(offset(QA02, north_m=21)).status_code == 200
    assert rider.shift_end().status_code == 200
    assert db_query("select count(*) from delivery_riderlocation where rider_id=%s", (rid,))[0][0] >= 1
    doc = rider_op(op="document_url", **{"as": SUPER}, phone=phone, doc_type="PAN")
    assert doc["ok"], doc
    old_url = doc["result"]["url"]
    assert httpx.get(old_url, timeout=20).status_code == 200
    assert request_otp(api, phone, purpose="delete_account", app="rider").status_code == 200
    r = api.post("/api/v1/me/delete/", json={"otp": TEST_OTP, "reason": "QA P5-TC-18 erasure"},
                 headers={**rider.h})
    assert r.status_code == 200, describe(r)
    an = rider_op(op="anonymise_rider_user", phone=phone)
    assert an["ok"] and an["result"]["anonymised"] is True, an
    cols = ["full_name", "dob", "emergency_contact_name", "emergency_contact_phone", "vehicle_number",
            "bank_account_name", "bank_account_number_encrypted", "bank_account_last4", "ifsc", "kyc_purge_after",
            "anonymised_at", "is_online"]
    row = dict(zip(cols, db_query(f"select {', '.join(cols)} from delivery_rider where id=%s", (rid,))[0]))
    for k in cols[:9]:
        assert row[k] in ("", None), (k, row[k])
    assert row["kyc_purge_after"] == datetime.now(IST).date() + timedelta(days=365), row["kyc_purge_after"]
    assert db_query("select count(*) from delivery_riderlocation where rider_id=%s", (rid,))[0][0] == 0
    assert db_query("select count(*) from delivery_riderdocument where rider_id=%s", (rid,))[0][0] == 4
    pg = rider_op(op="purge_kyc_for", rider_id=rid, today=row["kyc_purge_after"].isoformat())
    assert pg["ok"] and pg["result"]["deleted"] == 4, pg
    assert db_query("select count(*) from delivery_riderdocument where rider_id=%s", (rid,))[0][0] == 0
    assert httpx.get(old_url, timeout=20).status_code in (403, 404), "purged KYC file still served"


# =========================================================================== fuzz (rider operations)

RIDER_FUZZED = [
    "rider_me_retrieve", "rider_stores_list", "rider_offers_current", "rider_offers_accept", "rider_offers_reject",
    "rider_tasks_current", "rider_tasks_history", "rider_tasks_history_detail", "rider_earnings",
    "rider_cash_ledger", "rider_payouts_list", "rider_ratings_list", "rider_heartbeat",
    "rider_tasks_arrived_store", "rider_tasks_arrived_customer", "rider_tasks_pickup", "rider_tasks_deliver",
    "rider_tasks_fail", "rider_tasks_cod_qr",
]


def test_p5_tc129_fuzz_rider_operations(api):
    """P5-TC-129 schemathesis on the rider operations with QA G's rider token (PENDING_KYC, no tasks,
    so generated ids are foreign/missing and nothing real changes): no 5xx, documented status codes,
    schema-valid JSON. Excluded: register/documents/bank/shift/locations (would change KYC or
    presence; covered by hand-written cases)."""
    import schemathesis
    from hypothesis import HealthCheck, given, settings
    from schemathesis.checks import not_a_server_error
    from schemathesis.specs.openapi.checks import (
        content_type_conformance, response_schema_conformance, status_code_conformance,
    )

    from qa_support import BASE_URL, RIDER_HEADERS, schema_path

    g = RiderClient(api, QA_PHONES["g"])
    headers = {**RIDER_HEADERS, **bearer(g.session.access)}
    schema = schemathesis.openapi.from_path(str(schema_path())).include(operation_id=RIDER_FUZZED)
    failures = []
    for op in schema.get_all_operations():
        operation = op.ok()

        @given(case=operation.as_strategy())
        @settings(max_examples=8, deadline=None, suppress_health_check=list(HealthCheck), derandomize=True)
        def run(case):
            checks = [not_a_server_error, status_code_conformance, content_type_conformance,
                      response_schema_conformance]
            raw_id = (case.path_parameters or {}).get("id")
            if raw_id is not None and (not isinstance(raw_id, int) or raw_id < 0):
                checks = [not_a_server_error]  # does not route: Django's DEBUG HTML 404
            case.call_and_validate(base_url=BASE_URL, headers=headers, checks=checks)

        try:
            run()
        except Exception as exc:  # collect all operations, then fail once
            failures.append(f"{operation.label}: {str(exc)[:600]}")
    assert not failures, "\n".join(failures)
