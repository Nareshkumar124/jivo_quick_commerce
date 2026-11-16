"""Phase 5, QA stage 4 (2026-11-10, develop f8db671): the P5 cases that had no execution after
stage 3. P0 first: TC-12 (admin approval UI), TC-42 / TC-45 (accept races), TC-51 (T8a during a
task), TC-110 (signed links); then the P1/P2 rest (see `02-test-case-repository.md`, Phase 5).

Staff actions go through the real admin / Ops Console pages where they exist (rider review in
`/admin/delivery/...`, manual assign in `/ops/dispatch/...`), system jobs through
`tools/rider_ops_driver.py`. QA numbers and the QA-only store QA-02 only. QA instance :8004 only.
"""

from __future__ import annotations

import concurrent.futures
import json
import os
import re
import subprocess
import time
from datetime import datetime
from decimal import Decimal
from urllib.parse import urlsplit, urlunsplit

import httpx
import pytest

from p3_admin import csrf, staff_login
from p4_support import _ENV, BACKEND, CATALOG, FINANCE, OPS, STAFF, SUPER, SUPPORT, order_row, t8a_oracle
from p4_support import ops as store_ops
from p5_support import (  # noqa: F401 (fixtures)
    DROP, QA02, QA02_ID, R1_PHONE, R2_PHONE, RIDER_DRIVER, V_SUN_1L, bring_to, cod_due, money, offers_of,
    offset, p5_shop_a, p5_shop_b, pickup_code, qa_worker, r1, r2, rider_id_of, rider_op, task_row,
    wait_order_status,
)
from qa_support import QA_PHONES, assert_error, db_query, describe

pytestmark = pytest.mark.p5_53


def _epoch(iso: str) -> float:
    return datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp()


def _admin_post(c: httpx.Client, path: str, data: dict) -> httpx.Response:
    token = csrf(c, path)
    return c.post(path, data={**data, "csrfmiddlewaretoken": token}, headers={"Referer": f"{c.base_url}{path}"})


def _rider_row(rider_id: int) -> dict:
    cols = ["status", "home_store_id", "cash_limit", "approved_by_id", "is_online"]
    return dict(zip(cols, db_query(f"select {', '.join(cols)} from delivery_rider where id=%s", (rider_id,))[0]))


# =========================================================================== P5-TC-12 (admin UI)


@pytest.mark.smoke
def test_p5_tc12_admin_approval_ui():
    """P5-TC-12 🔥 OPS in the Riders admin (real pages, POST + CSRF): the incomplete rider (QA G,
    documents PENDING, no bank) is refused with the reason; QA F with 3 of 4 documents approved is
    refused; after approving the 4th, approving with home store QA-02 → ACTIVE, home_store QA-02,
    cash_limit 5,000.00, approved_by OPS. One audit row per action (actor OPS, client IP). Roles
    without review (SS, SUP, CAT, FIN) get 403 on the approve pages."""
    f_id, g_id = rider_id_of(QA_PHONES["f"]), rider_id_of(QA_PHONES["g"])
    if _rider_row(f_id)["status"] != "PENDING_KYC":
        pytest.skip("QA F is no longer PENDING_KYC (TC-12 already ran on this DB)")
    docs = db_query("select id, doc_type, status from delivery_riderdocument where rider_id=%s order by id", (f_id,))
    assert len(docs) == 4 and all(d[2] == "PENDING" for d in docs), docs
    ops_user = db_query("select id from accounts_user where email=%s", (OPS,))[0][0]
    audit_from = db_query("select coalesce(max(id), 0) from core_auditlog")[0][0]
    for who in (STAFF, SUPPORT, CATALOG, FINANCE):
        c = staff_login(who)
        r = c.get(f"/admin/delivery/rider/{f_id}/approve/")
        assert r.status_code in (403, 404) or "/login/" in r.headers.get("location", ""), (who, r.status_code)
        c.close()
    ops = staff_login(OPS)
    try:
        # 1. incomplete rider G
        r = _admin_post(ops, f"/admin/delivery/rider/{g_id}/approve/", {"home_store": str(QA02_ID), "cash_limit": ""})
        assert r.status_code == 302, r.status_code
        page = ops.get(r.headers["location"]).text
        assert _rider_row(g_id)["status"] == "PENDING_KYC"
        assert re.search(r"document|bank", page, re.I), "refusal reason not shown"
        # 2. F with one document still PENDING
        for doc_id, _, _ in docs[:3]:
            r = _admin_post(ops, f"/admin/delivery/riderdocument/{doc_id}/approve/", {})
            assert r.status_code == 302, (doc_id, r.status_code)
        r = _admin_post(ops, f"/admin/delivery/rider/{f_id}/approve/", {"home_store": str(QA02_ID), "cash_limit": ""})
        assert r.status_code == 302
        refusal = ops.get(r.headers["location"]).text
        assert _rider_row(f_id)["status"] == "PENDING_KYC", "approved with a PENDING document"
        assert re.search(r"document", refusal, re.I), "refusal reason not shown"
        # 3. the 4th document, then the rider
        r = _admin_post(ops, f"/admin/delivery/riderdocument/{docs[3][0]}/approve/", {})
        assert r.status_code == 302
        r = _admin_post(ops, f"/admin/delivery/rider/{f_id}/approve/", {"home_store": str(QA02_ID), "cash_limit": ""})
        assert r.status_code == 302
    finally:
        ops.close()
    row = _rider_row(f_id)
    assert row["status"] == "ACTIVE" and row["home_store_id"] == QA02_ID, row
    assert row["cash_limit"] == Decimal("5000.00") and row["approved_by_id"] == ops_user, row
    assert row["is_online"] is False
    assert {d[2] for d in db_query("select id, doc_type, status from delivery_riderdocument where rider_id=%s",
                                   (f_id,))} == {"APPROVED"}
    audit = db_query("select action, object_type, object_id, actor_id, ip from core_auditlog where id>%s "
                     "and object_type in ('delivery.rider','delivery.riderdocument') order by id", (audit_from,))
    doc_ids = {str(d[0]) for d in docs}
    approvals = [a for a in audit if a[0] == "rider.document_approve" and a[2] in doc_ids]
    assert len(approvals) == 4, audit
    rider_appr = [a for a in audit if a[0] == "rider.approve" and a[2] == str(f_id)]
    assert len(rider_appr) == 1, audit
    for a in approvals + rider_appr:
        assert a[3] == ops_user and a[4], a  # actor and client IP recorded
    assert not [a for a in audit if a[0] == "rider.approve" and a[2] == str(g_id)], "refused approval audited as done"


# =========================================================================== P5-TC-42 (accept ‖ expiry)


def _spawn_driver(steps: list[dict]) -> subprocess.Popen:
    env = {k: v for k, v in os.environ.items() if not k.startswith("POSTGRES_")}
    env.update(_ENV)
    p = subprocess.Popen(["uv", "run", "--quiet", "python", str(RIDER_DRIVER)], cwd=BACKEND, env=env,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                         encoding="utf-8")
    p.stdin.write(json.dumps(steps))
    p.stdin.close()
    return p


def _driver_result(p: subprocess.Popen) -> list[dict]:
    out = p.stdout.read()
    p.wait(120)
    return [json.loads(ln) for ln in out.splitlines() if ln.startswith("{")]


JITTER = [-0.25, -0.1, -0.03, 0.0, 0.0, 0.03, 0.08, 0.15, 0.25, 0.4]


def test_p5_tc42_accept_vs_expiry_race(r1, p5_shop_a):
    """P5-TC-42 10 trials: R1's accept sent at the offer's `expires_at` + jitter (-250…+400 ms) while
    the QA driver runs `expire_offer` at exactly `expires_at` (and the worker countdown / beat
    sweep may also fire). Every trial has exactly one outcome: (200, offer ACCEPTED, task
    ASSIGNED to R1) or (409 OFFER_EXPIRED, offer EXPIRED, task not ASSIGNED). Never ASSIGNED with
    an EXPIRED offer; at most one PENDING offer per task."""
    outcomes = []
    for trial, jitter in enumerate(JITTER):
        r1.online_at()
        ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
        oid, tid, offer = ctx["order_id"], ctx["task_id"], ctx["offer"]
        exp = _epoch(offer["expires_at"])
        assert exp - time.time() > 12, f"trial {trial}: offer leaves only {exp - time.time():.1f} s"
        proc = _spawn_driver([{"op": "expire_offer", "offer_id": offer["id"], "at_epoch": exp}])
        time.sleep(max(0.0, exp + jitter - time.time()))
        r = r1.accept(offer["id"])
        drv = _driver_result(proc)
        time.sleep(1.5)
        o_status = {row[0]: row[2] for row in offers_of(tid)}[offer["id"]]
        t = task_row(oid)
        pending = [row for row in offers_of(tid) if row[2] == "PENDING"]
        assert len(pending) <= 1, (trial, pending)
        if r.status_code == 200:
            assert o_status == "ACCEPTED" and t["status"] == "ASSIGNED" and t["rider_id"] == rider_id_of(R1_PHONE), \
                (trial, o_status, t)
            outcomes.append(("accepted", jitter, drv[0]["result"]["outcome"] if drv and drv[0]["ok"] else drv))
        else:
            assert r.status_code == 409, (trial, describe(r))
            code = r.json()["error"]["code"]
            assert code in ("OFFER_EXPIRED", "OFFER_TAKEN"), (trial, describe(r))
            assert o_status == "EXPIRED" and t["status"] != "ASSIGNED", (trial, o_status, t)
            outcomes.append((f"409 {code}", jitter, drv[0]["result"]["outcome"] if drv and drv[0]["ok"] else drv))
        assert not (t["status"] == "ASSIGNED" and o_status == "EXPIRED"), (trial, t, o_status)
        assert p5_shop_a.cancel(oid).status_code == 200  # frees R1 for the next trial
    print("TC-42 outcomes:", outcomes)
    assert len(outcomes) == len(JITTER)
    wrong = [o for o in outcomes if o[0] == "409 OFFER_TAKEN"]
    if wrong:  # the race itself is safe; only the error code of a late accept is wrong
        pytest.xfail(f"BUG-0023: late accept on an expired offer answered OFFER_TAKEN in {len(wrong)} trial(s): {wrong}")


@pytest.mark.xfail(strict=True, reason="BUG-0023: late accept after a processed expiry answers OFFER_TAKEN")
def test_p5_tc42b_late_accept_after_expiry_is_offer_expired(r1, p5_shop_a):
    """P5-TC-42b (stage 4, from TC-42) only R1 online; R1 lets the offer expire and waits until the
    expiry is processed (offer EXPIRED in the DB, task back to SEARCHING/UNASSIGNED); then accepts:
    08 section 5 step 4 / 06 section 3 say 409 OFFER_EXPIRED (not OFFER_TAKEN, "taken by another rider")."""
    r1.online_at()
    ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
    tid, offer = ctx["task_id"], ctx["offer"]
    end = time.monotonic() + 80
    status = None
    while time.monotonic() < end:
        status = {row[0]: row[2] for row in offers_of(tid)}[offer["id"]]
        if status == "EXPIRED":
            break
        time.sleep(1)
    assert status == "EXPIRED", status
    print("task after expiry:", task_row(ctx["order_id"]))
    r = r1.accept(offer["id"])
    print("late accept:", describe(r))
    assert_error(r, 409, "OFFER_EXPIRED")


# =========================================================================== P5-TC-45 (manual ‖ accept)


def test_p5_tc45_manual_assign_vs_accept_race(r1, r2, p5_shop_a):
    """P5-TC-45 5 trials: OPS manual-assigns R2 through the Ops Console (POST + CSRF) in parallel
    with R1's accept of the pending offer. Exactly one rider bound; R1's accept is 200 only if R1
    is the one bound, else 409 (OFFER_TAKEN / INVALID_STATE_TRANSITION); no PENDING offer left; the
    loser's offer is WITHDRAWN when the manual assignment won."""
    ops = staff_login(OPS)
    rid1, rid2 = rider_id_of(R1_PHONE), rider_id_of(R2_PHONE)
    winners = []
    try:
        for trial in range(5):
            r1.online_at()
            r2.online_at(offset(QA02, north_m=1500))
            ctx = bring_to("OFR", shop=p5_shop_a, rider=r1)
            oid, tid, offer = ctx["order_id"], ctx["task_id"], ctx["offer"]
            path = f"/ops/dispatch/tasks/{tid}/"
            token = csrf(ops, path)

            def assign():
                return ops.post(f"{path}assign/", data={"rider": rid2, "csrfmiddlewaretoken": token},
                                headers={"Referer": f"{ops.base_url}{path}"})

            with concurrent.futures.ThreadPoolExecutor(2) as pool:
                fa = pool.submit(r1.accept, offer["id"])
                fm = pool.submit(assign)
                ra, rm = fa.result(), fm.result()
            time.sleep(1)
            t = task_row(oid)
            offers = {row[0]: row for row in offers_of(tid)}
            assert t["status"] == "ASSIGNED" and t["rider_id"] in (rid1, rid2), (trial, t, ra.status_code, rm.status_code)
            assert not [o for o in offers.values() if o[2] == "PENDING"], (trial, offers)
            if t["rider_id"] == rid1:
                assert ra.status_code == 200, (trial, describe(ra))
                assert offers[offer["id"]][2] == "ACCEPTED"
                assert t["assignment_mode"] != "MANUAL", t
            else:
                assert ra.status_code == 409 and ra.json()["error"]["code"] in ("OFFER_TAKEN", "INVALID_STATE_TRANSITION"), \
                    (trial, describe(ra))
                assert offers[offer["id"]][2] == "WITHDRAWN", offers[offer["id"]]
                assert t["assignment_mode"] == "MANUAL", t
            assert rm.status_code in (200, 302, 400, 409), rm.status_code
            busy = db_query("select rider_id, count(*) from delivery_deliverytask where rider_id in (%s,%s) and status in "
                            "('ASSIGNED','AT_STORE','PICKED_UP','AT_CUSTOMER') group by rider_id", (rid1, rid2))
            assert all(n == 1 for _, n in busy) and len(busy) == 1, busy
            winners.append("R1" if t["rider_id"] == rid1 else "R2")
            assert p5_shop_a.cancel(oid).status_code == 200
    finally:
        ops.close()
    print("TC-45 winners:", winners)


# =========================================================================== P5-TC-51 (T8a during a task)


def test_p5_tc51_t8a_during_task_changes_cod_due(r1, p5_shop_a):
    """P5-TC-51 🔥(P0) COD(A) of 2 × JV-SUN-1L, ASSIGNED to R1; OPS starts packing and marks 1 unit
    unavailable (T8a): R1's task shows `cod_amount_due` = the QA oracle's new grand_total and
    `cod_amount_previous` = the old one; R1 gets `rider.cod_amount_changed`; delivering with the old
    amount → 400; the new amount → 200; one unit leaves stock at pickup."""
    r1.online_at()
    ctx = bring_to("ASG", shop=p5_shop_a, rider=r1, lines={V_SUN_1L: 2})
    oid, tid = ctx["order_id"], ctx["task_id"]
    old = order_row(oid)
    task0 = r1.task().json()["task"]
    assert money(task0["cod_amount_due"]) == money(old["grand_total"]) and task0["cod_amount_previous"] is None, task0
    detail = p5_shop_a.order(oid).json()
    line = next(i for i in detail["items"] if i["variant_id"] == V_SUN_1L)
    expected = t8a_oracle(old, [(money(line["mrp"]), money(line["selling_price"]), 1)])
    out = store_ops({"op": "start_packing", "as": OPS, "order_id": oid},
                    {"op": "unavailable", "as": OPS, "order_id": oid, "item_id": line["id"], "unavailable": 1})
    assert all(o["ok"] for o in out), out
    new = order_row(oid)
    assert new["grand_total"] == expected["grand_total"], (new["grand_total"], expected)
    task1 = r1.task().json()["task"]
    assert money(task1["cod_amount_due"]) == expected["grand_total"], (task1["cod_amount_due"], expected)
    assert money(task1["cod_amount_previous"]) == money(old["grand_total"]), task1
    user_r1 = db_query("select id from accounts_user where phone=%s", (R1_PHONE,))[0][0]
    rows = []
    for _ in range(20):  # rider pushes carry the task id in data (order_id is NULL): stage 4 oracle fix
        rows = db_query("select body, push_body from notifications_notification where user_id=%s and "
                        "event='rider.cod_amount_changed' and data->>'task_id'=%s", (user_r1, str(tid)))
        if rows:
            break
        time.sleep(0.5)
    assert len(rows) == 1, f"{len(rows)} rider.cod_amount_changed notifications"
    text = " ".join(x or "" for x in rows[0])
    assert str(expected["grand_total"]) in text and str(money(old["grand_total"])) in text, text
    assert r1.arrived_store(tid).status_code == 200
    assert store_ops({"op": "packed", "as": OPS, "order_id": oid})[0]["ok"]
    assert r1.pickup(tid, pickup_code(oid)).status_code == 200
    otp = p5_shop_a.track(oid).json()["delivery_otp"]
    assert r1.arrived_customer(tid).status_code == 200
    r = r1.deliver(tid, otp, {"mode": "cash", "amount": str(money(old["grand_total"]))})
    assert r.status_code == 400, describe(r)
    r = r1.deliver(tid, otp, {"mode": "cash", "amount": str(expected["grand_total"])})
    assert r.status_code == 200, describe(r)
    mv = db_query("select type, delta from inventory_stockmovement where order_id=%s and variant_id=%s",
                  (oid, V_SUN_1L))
    assert sum(d for t, d in mv if d < 0) == -1, mv


# =========================================================================== P5-TC-110 (signed links)


def _tamper_path(url: str) -> str:
    parts = urlsplit(url)
    path = parts.path
    i = path.rfind("-") + 1 if "-" in path.rsplit("/", 1)[-1] else len(path) - 5
    ch = path[i]
    path = path[:i] + ("a" if ch != "a" else "b") + path[i + 1:]
    return urlunsplit((parts.scheme, parts.netloc, path, parts.query, parts.fragment))


def _tamper_expiry(url: str) -> str:
    if "X-Amz-Expires=" in url:
        return re.sub(r"X-Amz-Expires=(\d+)", lambda m: f"X-Amz-Expires={int(m.group(1)) + 3600}", url)
    return re.sub(r"Expires=(\d+)", lambda m: f"Expires={int(m.group(1)) + 3600}", url)


def test_p5_tc110_signed_links_only_as_issued_and_expire(r1, r2, p5_shop_a):
    """P5-TC-110 (P0) 09 section 3.3, with QA G's files uploaded fresh on this host (stage 4: the old
    PC's KYC files are not in this MinIO, OBS-S4-01): G's photo link and staff KYC document links
    work as issued; the same link with another object key, a stretched expiry or no signature is
    refused; R2's endpoints never carry G's or R1's KYC paths; customer A sees R1's photo link only
    through the own order's track and not after delivery; the 300 s KYC link is refused once expired."""
    from p5_support import RiderClient, png_bytes

    g = RiderClient(r1.api, QA_PHONES["g"])
    assert g.upload("PHOTO", png_bytes(), name="me.png").status_code == 201
    assert g.upload("PAN", png_bytes(), name="pan.png").status_code == 201
    g_me = g.me().json()
    g_id = rider_id_of(QA_PHONES["g"])
    links = []
    if g_me.get("photo_url"):
        links.append(g_me["photo_url"])
    for doc_type in ("PHOTO", "PAN"):
        doc = rider_op(op="document_url", **{"as": SUPER}, phone=QA_PHONES["g"], doc_type=doc_type)
        assert doc["ok"], doc
        links.append(doc["result"]["url"])
    for url in links:
        assert httpx.get(url, timeout=20).status_code == 200, url.split("?")[0]
        for bad in (_tamper_path(url), _tamper_expiry(url), url.split("?")[0]):
            assert httpx.get(bad, timeout=20).status_code in (400, 403), bad.split("?")[0]
    me2, docs2 = r2.me(), r2.get("documents/")
    for body in (me2.text, docs2.text):
        assert f"kyc/{g_id}/" not in body and f"kyc/{rider_id_of(R1_PHONE)}/" not in body
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    tr = p5_shop_a.track(ctx["order_id"]).json()
    assert tr["rider"] and tr["rider"]["photo"] and "Signature" in tr["rider"]["photo"], tr["rider"]
    due = r1.task().json()["task"]["cod_amount_due"]
    assert r1.deliver(ctx["task_id"], ctx["otp"], {"mode": "cash", "amount": due}).status_code == 200
    after = p5_shop_a.track(ctx["order_id"]).json()
    assert after["rider"] is None or after["rider"].get("photo") in (None, ""), after["rider"]
    doc = rider_op(op="document_url", **{"as": SUPER}, phone=QA_PHONES["g"], doc_type="PAN")
    url = doc["result"]["url"]
    left = _epoch(str(doc["result"]["expires_at"]).replace(" ", "T")) - time.time()
    assert 200 < left <= 310, left
    time.sleep(left + 5)
    assert httpx.get(url, timeout=20).status_code in (400, 403), "expired KYC link still served"
