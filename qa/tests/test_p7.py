"""Phase 7 black-box: order ratings, rider ratings, support tickets (customer and rider, per-app
scoping, attachments, staff side), reports (role matrix, store scoping, CSV escaping, sales
summary oracle incl. DL-65), DPDP erasure of rating comments and ticket bodies.

Cases: `qa/docs/02-test-case-repository.md` (Phase 7, P7-TC-01..40). QA instance :8004 only.
Staff-side actions go through `tools/p7_driver.py` (admin P7 screens not merged).
"""

from __future__ import annotations

import concurrent.futures
import csv
import io
import re
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

import httpx
import pytest

from conftest import login, request_otp
from p4_support import CATALOG, FINANCE, MANAGER, OPS, QA02_MANAGER, STAFF, SUPER, SUPPORT
from p5_support import (  # noqa: F401 (fixtures)
    QA02_ID, R1_PHONE, R2_PHONE, bring_to, make_qa02_shop, p5_shop_a, p5_shop_b, qa_worker, r1, r2,
    rider_id_of, png_bytes,
)
from p7_support import TICKETS, Tickets, deliver, p7_op, p7_ops, png_with_exif
from qa_support import (
    APP_HEADERS, BASE_URL, QA_PHONES, RIDER_HEADERS, TEST_OTP, assert_error, bearer, clear_throttle,
    db_query, describe, validate_response,
)

IST = ZoneInfo("Asia/Kolkata")
ERASED = "[removed: account deleted]"


def money(v) -> Decimal:
    return Decimal(str(v))


def rate(session, oid: int, body: dict, app_headers=APP_HEADERS) -> httpx.Response:
    return httpx.post(f"{BASE_URL}/api/v1/orders/{oid}/rating/", json=body,
                      headers={**app_headers, **bearer(session.access)}, timeout=60)


def get_rating(session, oid: int) -> httpx.Response:
    return httpx.get(f"{BASE_URL}/api/v1/orders/{oid}/rating/", headers={**APP_HEADERS, **bearer(session.access)},
                     timeout=60)


def rider_ratings(session, **params) -> httpx.Response:
    return httpx.get(f"{BASE_URL}/api/v1/rider/ratings/", params=params,
                     headers={**RIDER_HEADERS, **bearer(session.access)}, timeout=60)


@pytest.fixture(autouse=True)
def _throttles():
    for scope in ("support_tickets_create", "support_messages", "support_attachments"):
        clear_throttle(scope)
    yield


# =========================================================================== ratings


@pytest.fixture
def delivered_a(r1, p5_shop_a):
    r1.online_at()
    ctx = deliver(p5_shop_a, r1)
    return {**ctx, "shop": p5_shop_a, "rider": r1}


@pytest.mark.smoke
def test_p7_tc01_rate_delivered_order_and_rider(delivered_a):
    """P7-TC-01 🔥 DELIVERED order rated once: 201 OrderRating; GET equal; order can_rate false +
    rating; rider average recomputed = mean of the rider's RIDER stars (1 dp, half up)."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    before = shop.order(oid).json()
    assert before["can_rate"] is True and before["rating"] is None, before.get("can_rate")
    body = {"order_stars": 4, "rider_stars": 5, "tags": ["ON_TIME", "POLITE_RIDER", "WELL_PACKED", "ON_TIME"],
            "comment": "  QA P7 rating comment  "}
    r = rate(shop.session, oid, body)
    assert r.status_code == 201, describe(r)
    validate_response(r, "orders_rating_create")
    got = r.json()
    assert got["order_stars"] == 4 and got["rider_stars"] == 5 and got["comment"] == "QA P7 rating comment"
    assert sorted(got["tags"]) == sorted(["ON_TIME", "POLITE_RIDER", "WELL_PACKED"]), got["tags"]
    g = get_rating(shop.session, oid)
    assert g.status_code == 200 and g.json() == got, describe(g)
    after = shop.order(oid).json()
    assert after["can_rate"] is False and after["rating"]["order_stars"] == 4
    rows = db_query("select target, stars, tags, rider_id from orders_rating where order_id=%s order by target", (oid,))
    by = {t: (s, tg, rid) for t, s, tg, rid in rows}
    assert set(by) == {"ORDER", "RIDER"}
    assert by["RIDER"][2] == rider_id_of(R1_PHONE)
    assert "POLITE_RIDER" in by["RIDER"][1] and "POLITE_RIDER" not in by["ORDER"][1]
    avg_sql = db_query("select round(avg(stars)::numeric, 1), (select rating_avg from delivery_rider where id=%s) "
                       "from orders_rating where target='RIDER' and rider_id=%s",
                       (rider_id_of(R1_PHONE), rider_id_of(R1_PHONE)))[0]
    assert money(avg_sql[0]) == money(avg_sql[1]), avg_sql


@pytest.mark.smoke
def test_p7_tc02_rated_once_and_parallel(r1, p5_shop_a):
    """P7-TC-02 🔥 a second rating → 400 ALREADY_RATED; 5 parallel first ratings → exactly one 201."""
    r1.online_at()
    ctx = deliver(p5_shop_a, r1)
    oid = ctx["order_id"]
    with concurrent.futures.ThreadPoolExecutor(5) as ex:
        res = list(ex.map(lambda i: rate(p5_shop_a.session, oid, {"order_stars": 1 + i}), range(5)))
    codes = sorted(r.status_code for r in res)
    assert codes == [201, 400, 400, 400, 400], codes
    for r in res:
        if r.status_code == 400:
            err = assert_error(r, 400, "VALIDATION_ERROR")
            assert err["details"]["reason"] == "ALREADY_RATED", err
    assert db_query("select count(*) from orders_rating where order_id=%s and target='ORDER'", (oid,))[0][0] == 1
    err = assert_error(rate(p5_shop_a.session, oid, {"order_stars": 5}), 400, "VALIDATION_ERROR")
    assert err["details"]["reason"] == "ALREADY_RATED"


@pytest.mark.smoke
def test_p7_tc03_not_delivered_refused(p5_shop_a):
    """P7-TC-03 🔥 PLACED/ACCEPTED and CANCELLED orders → 400 NOT_DELIVERED; GET → 404; can_rate false."""
    order = p5_shop_a.place_cod()
    oid = order["id"]
    err = assert_error(rate(p5_shop_a.session, oid, {"order_stars": 5}), 400, "VALIDATION_ERROR")
    assert err["details"]["reason"] == "NOT_DELIVERED" and "order" in err["details"], err
    assert p5_shop_a.order(oid).json()["can_rate"] is False
    assert p5_shop_a.cancel(oid).status_code == 200
    err = assert_error(rate(p5_shop_a.session, oid, {"order_stars": 5}), 400, "VALIDATION_ERROR")
    assert err["details"]["reason"] == "NOT_DELIVERED"
    assert_error(get_rating(p5_shop_a.session, oid), 404, "NOT_FOUND")
    assert db_query("select count(*) from orders_rating where order_id=%s", (oid,))[0][0] == 0


@pytest.mark.smoke
def test_p7_tc04_idor(delivered_a):
    """P7-TC-04 🔥 B rates / reads A's delivered order → 404 (both before and after A rates);
    a missing id → 404; no token → 401."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    b = login(QA_PHONES["b"])
    assert_error(rate(b, oid, {"order_stars": 1, "comment": "IDOR"}), 404, "NOT_FOUND")
    assert_error(rate(b, 999_999_999, {"order_stars": 1}), 404, "NOT_FOUND")
    assert rate(shop.session, oid, {"order_stars": 5}).status_code == 201
    assert_error(get_rating(b, oid), 404, "NOT_FOUND")
    assert_error(rate(b, oid, {"order_stars": 1}), 404, "NOT_FOUND")
    r = httpx.post(f"{BASE_URL}/api/v1/orders/{oid}/rating/", json={"order_stars": 1}, headers=APP_HEADERS)
    assert r.status_code == 401, describe(r)
    assert db_query("select count(*) from orders_rating where order_id=%s and user_id<>%s",
                    (oid, shop.session.user["id"]))[0][0] == 0


@pytest.mark.parametrize("body,field", [
    ({"order_stars": 5, "tags": ["POLITE_RIDER"]}, "tags"),
    ({"order_stars": 5, "tags": ["RUDE_RIDER"], "rider_stars": None}, "tags"),
    ({"order_stars": 0}, "order_stars"),
    ({"order_stars": 6}, "order_stars"),
    ({"order_stars": 5, "rider_stars": 9}, "rider_stars"),
    ({"order_stars": 5, "tags": ["GREAT"]}, "tags"),
    ({"order_stars": 5, "comment": "x" * 501}, "comment"),
    ({"order_stars": "five"}, "order_stars"),
    ({}, "order_stars"),
])
def test_p7_tc05_validation(delivered_a, body, field):
    """P7-TC-05 rider tags need rider_stars; stars 1-5; unknown tag; comment ≤ 500 → 400 details.<field>;
    nothing stored."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    err = assert_error(rate(shop.session, oid, body), 400, "VALIDATION_ERROR")
    assert field in err["details"], err
    assert db_query("select count(*) from orders_rating where order_id=%s", (oid,))[0][0] == 0


def test_p7_tc06_order_only_rating_no_rider_row(delivered_a):
    """P7-TC-06 order stars only (shared tag ON_TIME) → one ORDER row, no RIDER row; rider_stars null."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    r = rate(shop.session, oid, {"order_stars": 3, "tags": ["ON_TIME"]})
    assert r.status_code == 201 and r.json()["rider_stars"] is None, describe(r)
    assert [t for (t,) in db_query("select target from orders_rating where order_id=%s", (oid,))] == ["ORDER"]


@pytest.mark.smoke
def test_p7_tc07_rider_ratings_list_own_only_no_pii(delivered_a, r2):
    """P7-TC-07 🔥 GET /rider/ratings/: own ratings only, items exactly {id, stars, tags, rated_at,
    order_number} (no comment, no customer); summary = SQL; R2 never sees R1's rating; a
    customer-app token is refused; before_id paging."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    assert rate(shop.session, oid, {"order_stars": 2, "rider_stars": 2, "tags": ["RUDE_RIDER", "LATE_DELIVERY"],
                                    "comment": "QA-SECRET-COMMENT"}).status_code == 201
    r1s = delivered_a["rider"].session
    r = rider_ratings(r1s)
    assert r.status_code == 200, describe(r)
    validate_response(r, "rider_ratings_list")
    body = r.json()
    assert "QA-SECRET-COMMENT" not in r.text and QA_PHONES["a"] not in r.text
    number = shop.order(oid).json()["order_number"]
    mine = [i for i in body["results"] if i["order_number"] == number]
    assert len(mine) == 1 and set(mine[0]) == {"id", "stars", "tags", "rated_at", "order_number"}, mine
    assert mine[0]["stars"] == 2 and set(mine[0]["tags"]) == {"RUDE_RIDER", "LATE_DELIVERY"}
    rid = rider_id_of(R1_PHONE)
    cnt, avg = db_query("select count(*), round(avg(stars)::numeric,1) from orders_rating "
                        "where target='RIDER' and rider_id=%s", (rid,))[0]
    assert body["ratings_count"] == cnt and money(body["rating_avg"]) == money(avg), (body["ratings_count"], cnt)
    other = rider_ratings(r2.session)
    assert other.status_code == 200 and number not in other.text, describe(other)
    cust = httpx.get(f"{BASE_URL}/api/v1/rider/ratings/", headers={**APP_HEADERS, **bearer(login(R1_PHONE).access)})
    assert cust.status_code in (403,), describe(cust)
    first = body["results"][0]["id"]
    page = rider_ratings(r1s, before_id=first, page_size=1)
    assert page.status_code == 200 and all(i["id"] < first for i in page.json()["results"]), describe(page)
    assert len(page.json()["results"]) <= 1


def test_p7_tc08_staff_rating_scope(delivered_a):
    """P7-TC-08 staff ratings: OPS/SUPPORT/SA see the QA-02 rating; Store Manager (GGN-01 only)
    does not; Catalog/Finance/Store Staff are refused (05 §2 Ratings)."""
    shop, oid = delivered_a["shop"], delivered_a["order_id"]
    assert rate(shop.session, oid, {"order_stars": 5}).status_code == 201
    out = p7_ops(*[{"op": "staff_ratings", "as": who, "order_ids": [oid]}
                   for who in (SUPER, OPS, SUPPORT, MANAGER, CATALOG, FINANCE, STAFF)])
    seen = dict(zip(("SA", "OPS", "SUP", "SM", "CAT", "FIN", "SS"), out))
    for who in ("SA", "OPS", "SUP"):
        assert seen[who]["ok"] and seen[who]["result"] == [oid], (who, seen[who])
    assert seen["SM"]["ok"] and seen["SM"]["result"] == [], seen["SM"]
    for who in ("CAT", "FIN", "SS"):
        assert not seen[who]["ok"] and seen[who]["error"] == "PermissionDenied", (who, seen[who])


# =========================================================================== support tickets


@pytest.fixture(scope="module")
def ta():
    return Tickets(login(QA_PHONES["a"]))


@pytest.fixture(scope="module")
def tb():
    return Tickets(login(QA_PHONES["b"]))


@pytest.mark.smoke
def test_p7_tc10_create_list_detail(ta):
    """P7-TC-10 🔥 customer creates a ticket (OTHER) → 201 detail (TK-number, OPEN, can_reply,
    one message); list shows it first; detail equal; SLA due times set (NORMAL 60 min / 24 h)."""
    r = ta.create("OTHER", "QA P7-TC-10 where is my refund please")
    assert r.status_code == 201, describe(r)
    validate_response(r, "support_tickets_create")
    t = r.json()
    assert re.fullmatch(r"TK-\d{6,}", t["number"]) and t["status"] == "OPEN" and t["can_reply"] is True, t
    assert [m["from_support"] for m in t["messages"]] == [False]
    lst = ta.list()
    validate_response(lst, "support_tickets_list")
    assert lst.json()["results"][0]["id"] == t["id"]
    d = ta.get(t["id"])
    validate_response(d, "support_tickets_retrieve")
    assert d.json()["id"] == t["id"] and len(d.json()["messages"]) == 1
    sla = p7_op(op="ticket_sla", ticket_id=t["id"])["result"]
    assert sla["app"] == "customer" and sla["priority"] == "NORMAL", sla
    f = datetime.fromisoformat(sla["first_response_due_at"])
    res = datetime.fromisoformat(sla["resolution_due_at"])
    assert timedelta(minutes=59) <= f - datetime.fromisoformat(d.json()["created_at"].replace("Z", "+00:00")) <= timedelta(minutes=61), sla
    assert res - f == timedelta(hours=24) - timedelta(minutes=60), sla


@pytest.mark.parametrize("body,field", [
    ({"category": "MISSING_ITEMS", "message": "QA missing items in my bag"}, "order_id"),
    ({"category": "LATE_DELIVERY", "message": "QA late delivery happened"}, "order_id"),
    ({"category": "OTHER", "message": "too short"}, "message"),
    ({"category": "OTHER", "message": "x" * 1001}, "message"),
    ({"category": "OTHER", "message": "          a         "}, "message"),
    ({"category": "BOGUS", "message": "QA bogus category text"}, "category"),
    ({"category": "TASK", "message": "QA rider-only category from customer"}, "category"),
    ({"category": "OTHER", "message": "QA order 999999999 not mine", "order_id": 999_999_999}, "order_id"),
])
def test_p7_tc11_create_validation(ta, body, field):
    """P7-TC-11 create validation → 400 details.<field> (order-bound categories need order_id;
    message 10-1000 after trimming; rider categories only from the rider app; unknown order)."""
    with httpx.Client(base_url=BASE_URL, timeout=60) as c:
        r = c.post(TICKETS, headers=ta.h, json=body)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert field in err["details"], err


def test_p7_tc11b_other_users_order_same_as_missing(ta, tb, p5_shop_b):
    """P7-TC-11 B's order id in A's ticket → the same 400 as a missing order (no existence leak)."""
    order = p5_shop_b.place_cod()
    with httpx.Client(base_url=BASE_URL, timeout=60) as c:
        mine = c.post(TICKETS, headers=ta.h, json={"category": "MISSING_ITEMS", "message": "QA other's order id",
                                                   "order_id": order["id"]})
        missing = c.post(TICKETS, headers=ta.h, json={"category": "MISSING_ITEMS", "message": "QA other's order id",
                                                      "order_id": 999_999_998})
    e1 = assert_error(mine, 400, "VALIDATION_ERROR")
    e2 = assert_error(missing, 400, "VALIDATION_ERROR")
    assert e1["details"] == e2["details"] and e1["message"] == e2["message"], (e1, e2)


@pytest.mark.smoke
def test_p7_tc12_ticket_idor(ta, tb):
    """P7-TC-12 🔥 B on A's ticket: GET / reply / upload → 404; A's list never contains B's ticket."""
    t = ta.create("OTHER", "QA P7-TC-12 IDOR target ticket").json()
    assert_error(tb.get(t["id"]), 404, "NOT_FOUND")
    assert_error(tb.reply(t["id"], "QA IDOR reply"), 404, "NOT_FOUND")
    assert_error(tb.upload(t["id"], png_bytes()), 404, "NOT_FOUND")
    assert_error(tb.get(999_999_999), 404, "NOT_FOUND")
    assert all(x["id"] != t["id"] for x in tb.list(page_size=100).json()["results"])
    assert db_query("select count(*) from support_ticketmessage where ticket_id=%s", (t["id"],))[0][0] == 1
    r = httpx.get(f"{BASE_URL}{TICKETS}", headers=APP_HEADERS)
    assert r.status_code == 401


@pytest.mark.smoke
def test_p7_tc13_per_app_scoping_customer_and_rider(r1):
    """P7-TC-13 🔥 a user who is both customer and rider (QA C): a customer-app ticket and a
    rider-app ticket; each app lists only its own; the other app's id → 404 on GET/reply/upload."""
    cust = Tickets(login(R1_PHONE), "customer")
    rider = Tickets(r1.session, "rider")
    tc = cust.create("OTHER", "QA P7-TC-13 customer side ticket")
    tr = rider.create("OTHER", "QA P7-TC-13 rider side ticket")
    assert tc.status_code == 201 and tr.status_code == 201, (describe(tc), describe(tr))
    tc, tr = tc.json(), tr.json()
    assert {x["id"] for x in cust.list(page_size=100).json()["results"]}.isdisjoint({tr["id"]})
    assert {x["id"] for x in rider.list(page_size=100).json()["results"]}.isdisjoint({tc["id"]})
    for a, other in ((cust, tr["id"]), (rider, tc["id"])):
        assert_error(a.get(other), 404, "NOT_FOUND")
        assert_error(a.reply(other, "QA cross-app reply"), 404, "NOT_FOUND")
        assert_error(a.upload(other, png_bytes()), 404, "NOT_FOUND")
    apps = dict(db_query("select id, app from support_supportticket where id in (%s, %s)", (tc["id"], tr["id"])))
    assert apps == {tc["id"]: "customer", tr["id"]: "rider"}, apps


def test_p7_tc14_rider_categories_and_records(r1, r2, p5_shop_a):
    """P7-TC-14 rider ticket TASK with own task → 201 (order_number shown); R2 naming R1's task →
    400 details.task_id; PAYOUT with an unknown payout → 400."""
    r1.online_at()
    ctx = deliver(p5_shop_a, r1)
    rt = Tickets(r1.session, "rider")
    r = rt.create("TASK", "QA P7-TC-14 task ticket for my delivery", task_id=ctx["task_id"])
    assert r.status_code == 201, describe(r)
    assert r.json()["task_id"] == ctx["task_id"] and r.json()["order_number"], r.json()
    err = assert_error(Tickets(r2.session, "rider").create("TASK", "QA P7-TC-14 not my task here",
                                                            task_id=ctx["task_id"]), 400, "VALIDATION_ERROR")
    assert "task_id" in err["details"], err
    err = assert_error(rt.create("PAYOUT", "QA P7-TC-14 unknown payout id", payout_id=999_999_999), 400,
                       "VALIDATION_ERROR")
    assert "payout_id" in err["details"], err


@pytest.mark.smoke
def test_p7_tc15_attachments(ta, tb):
    """P7-TC-15 🔥 PNG upload → {key, url} signed for 600 s; the stored file is WebP without the EXIF
    marker; reply with the key → message attachments; reusing the key, another ticket's key, a
    key of another user, > 3 keys → 400 details.attachment_keys; bad types → 400."""
    t1 = ta.create("OTHER", "QA P7-TC-15 attachments ticket one").json()
    t2 = ta.create("OTHER", "QA P7-TC-15 attachments ticket two").json()
    up = ta.upload(t1["id"], png_with_exif())
    assert up.status_code == 201, describe(up)
    validate_response(up, "support_tickets_attachments_create")
    key, url = up.json()["key"], up.json()["url"]
    # SigV4 (X-Amz-Expires=600) or SigV2 query auth (Expires=<epoch>, Signature=), as local MinIO signs
    from urllib.parse import parse_qs, urlparse
    import time as _time

    qs = parse_qs(urlparse(url).query)
    if "X-Amz-Expires" in qs:
        assert qs["X-Amz-Expires"] == ["600"] and "X-Amz-Signature" in qs, "url not a 600 s signed URL"
    else:
        assert "Signature" in qs and "Expires" in qs, "url not signed"
        assert abs(int(qs["Expires"][0]) - (_time.time() + 600)) < 90, ("expiry not ~600 s", qs["Expires"])
    raw = httpx.get(url, timeout=30)
    assert raw.status_code == 200 and raw.content[:4] == b"RIFF" and raw.content[8:12] == b"WEBP"
    assert b"QAEXIFMARKER" not in raw.content and b"EXIF" not in raw.content[:64]
    unsigned = url.split("?")[0]
    assert httpx.get(unsigned, timeout=30).status_code in (401, 403), "private bucket served an unsigned URL"
    # another ticket's key / another user's key
    up2 = ta.upload(t2["id"], png_bytes())
    k2 = up2.json()["key"]
    err = assert_error(ta.reply(t1["id"], "QA wrong ticket key", [k2]), 400, "VALIDATION_ERROR")
    assert "attachment_keys" in err["details"]
    tbt = tb.create("OTHER", "QA P7-TC-15 B's own ticket").json()
    kb = tb.upload(tbt["id"], png_bytes()).json()["key"]
    err = assert_error(ta.reply(t1["id"], "QA B's key", [kb]), 400, "VALIDATION_ERROR")
    assert "attachment_keys" in err["details"]
    keys4 = [ta.upload(t1["id"], png_bytes()).json()["key"] for _ in range(3)] + [key]
    err = assert_error(ta.reply(t1["id"], "QA four keys", keys4), 400, "VALIDATION_ERROR")
    assert "attachment_keys" in err["details"]
    ok = ta.reply(t1["id"], "QA with photo", [key])
    assert ok.status_code == 201, describe(ok)
    validate_response(ok, "support_tickets_messages_create")
    last = ok.json()["messages"][-1]
    assert [a["key"] for a in last["attachments"]] == [key] and last["attachments"][0]["url"]
    err = assert_error(ta.reply(t1["id"], "QA reuse key", [key]), 400, "VALIDATION_ERROR")
    assert "attachment_keys" in err["details"]


@pytest.mark.parametrize("name,content,mime", [
    ("a.gif", b"GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\x00\x00\x00\x00,"
              b"\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;", "image/gif"),
    ("a.pdf", b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF", "application/pdf"),
    ("a.png", b"<html><script>alert(1)</script></html>", "image/png"),
    ("a.png", b"", "image/png"),
    ("svg.png", b'<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>', "image/svg+xml"),
])
def test_p7_tc16_attachment_type_rejected(ta, name, content, mime):
    """P7-TC-16 GIF, PDF, HTML-as-PNG, empty, SVG → 400 VALIDATION_ERROR (never 500); nothing stored."""
    t = ta.create("OTHER", "QA P7-TC-16 bad attachment types").json()
    r = ta.upload(t["id"], content, name, mime)
    assert r.status_code == 400, describe(r)
    assert_error(r, 400, "VALIDATION_ERROR")
    assert db_query("select count(*) from support_ticketattachment where ticket_id=%s", (t["id"],))[0][0] == 0


def test_p7_tc17_attachment_over_5mb(ta):
    """P7-TC-17 a 5 MB + 1 KB PNG → 400 (or 413), never stored, never 500; a 4.5 MB PNG → 201."""
    t = ta.create("OTHER", "QA P7-TC-17 attachment size limit").json()
    big = png_with_exif(pad=5 * 1024 * 1024 + 1024)
    assert len(big) > 5 * 1024 * 1024
    r = ta.upload(t["id"], big)
    assert r.status_code in (400, 413), describe(r)
    assert db_query("select count(*) from support_ticketattachment where ticket_id=%s", (t["id"],))[0][0] == 0
    ok = ta.upload(t["id"], png_with_exif(pad=4_500_000))
    assert ok.status_code == 201, describe(ok)


@pytest.mark.smoke
def test_p7_tc18_staff_reply_status_and_inbox_link(ta):
    """P7-TC-18 🔥 staff reply (Support) → IN_PROGRESS, from_support message; customer inbox entry
    category support, link jivo://support/tickets/<id>, body not quoting the reply; RESOLVED +
    customer reply → OPEN; CLOSED → reply and upload 400 details.ticket; Finance cannot reply."""
    t = ta.create("OTHER", "QA P7-TC-18 staff reply flow ticket").json()
    secret = "QA-STAFF-REPLY-SECRET-TEXT"
    out = p7_ops({"op": "staff_reply", "as": SUPPORT, "ticket_id": t["id"], "body": secret},
                 {"op": "staff_reply", "as": FINANCE, "ticket_id": t["id"], "body": "finance"})
    assert out[0]["ok"], out[0]
    assert not out[1]["ok"] and out[1]["error"] == "PermissionDenied", out[1]
    d = ta.get(t["id"]).json()
    assert d["status"] == "IN_PROGRESS" and d["messages"][-1]["from_support"] is True
    link = f"jivo://support/tickets/{t['id']}"
    import time as _t

    entry = None
    for _ in range(30):
        r = httpx.get(f"{BASE_URL}/api/v1/me/notifications/", headers=ta.h, params={"page_size": 50}, timeout=30)
        entry = next((n for n in r.json()["results"] if n["link"] == link), None)
        if entry:
            break
        _t.sleep(1)
    assert entry is not None, "no inbox entry with the ticket link (worker running?)"
    assert entry["category"] == "support" and secret not in entry["body"] and secret not in entry["title"], entry
    assert p7_op(op="change_status", **{"as": SUPPORT}, ticket_id=t["id"], status="RESOLVED")["ok"]
    assert ta.reply(t["id"], "QA reopen by reply").json()["status"] == "OPEN"
    assert p7_op(op="change_status", **{"as": SUPPORT}, ticket_id=t["id"], status="CLOSED")["ok"]
    d = ta.get(t["id"]).json()
    assert d["status"] == "CLOSED" and d["can_reply"] is False
    err = assert_error(ta.reply(t["id"], "QA reply to closed"), 400, "VALIDATION_ERROR")
    assert "ticket" in err["details"]
    err = assert_error(ta.upload(t["id"], png_bytes()), 400, "VALIDATION_ERROR")
    assert "ticket" in err["details"]
    bad = p7_op(op="change_status", **{"as": SUPPORT}, ticket_id=t["id"], status="OPEN")
    assert not bad["ok"], bad


def test_p7_tc19_create_rate_limit():
    """P7-TC-19 create limit 10/hour per user (QA D, customer app) → the 11th is 429 RATE_LIMITED."""
    clear_throttle("support_tickets_create")
    td = Tickets(login(QA_PHONES["d"]))
    codes = [td.create("OTHER", f"QA P7-TC-19 rate limit ticket {i}").status_code for i in range(11)]
    assert codes[:10] == [201] * 10 and codes[10] == 429, codes
    clear_throttle("support_tickets_create")


def test_p7_tc20_no_ticket_text_in_logs():
    """P7-TC-20 PII: ticket bodies and rating comments never reach the instance log."""
    from qa_support import PRIVATE

    logs = list((PRIVATE / "logs").glob("instance-*-p5.log")) + list((PRIVATE / "logs").glob("p5-worker*.log"))
    text = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in logs)
    for needle in ("QA-STAFF-REPLY-SECRET-TEXT", "QA-SECRET-COMMENT", "QA P7-TC-10 where is my refund",
                   "QA P7 rating comment"):
        assert needle not in text, needle


# =========================================================================== reports

EXPECTED_REPORTS = {
    SUPER: "ALL", FINANCE: "ALL",
    OPS: {"sales_summary", "orders", "cancellations", "refunds", "cod_reconciliation", "product_sales",
          "inventory_stock", "inventory_movements"},
    MANAGER: {"sales_summary", "orders", "cancellations", "refunds", "cod_reconciliation", "product_sales",
              "inventory_stock", "inventory_movements"},
    CATALOG: {"product_sales", "inventory_stock", "inventory_movements"},
    STAFF: set(), SUPPORT: set(),
}
ALL_REPORTS = {"sales_summary", "orders", "cancellations", "refunds", "cod_reconciliation", "product_sales",
               "inventory_stock", "inventory_movements", "gst_invoices", "gst_hsn_summary", "rider_earnings",
               "payouts"}


@pytest.mark.smoke
def test_p7_tc21_report_role_matrix():
    """P7-TC-21 🔥 05 §3 Reports row: SA/FIN all, OPS/SM sales+catalog, CAT catalog only,
    SS/SUP none; running a report without the permission → PermissionDenied."""
    roles = list(EXPECTED_REPORTS)
    out = p7_ops(*[{"op": "available", "as": who} for who in roles],
                 {"op": "run", "as": SUPPORT, "key": "sales_summary"},
                 {"op": "run", "as": STAFF, "key": "orders"},
                 {"op": "run", "as": CATALOG, "key": "sales_summary"},
                 {"op": "run", "as": OPS, "key": "payouts"},
                 {"op": "run", "as": OPS, "key": "no_such_report"})
    for who, res in zip(roles, out):
        exp = ALL_REPORTS if EXPECTED_REPORTS[who] == "ALL" else EXPECTED_REPORTS[who]
        assert set(res["result"]) == exp, (who, res["result"])
    for res in out[len(roles):len(roles) + 4]:
        assert not res["ok"] and res["error"] == "PermissionDenied", res
    assert not out[-1]["ok"] and out[-1]["error"] == "ValidationError"


@pytest.mark.smoke
def test_p7_tc22_report_store_scoping():
    """P7-TC-22 🔥 Store Manager (GGN-01): store_id=QA-02 → PermissionDenied (not an empty report);
    unfiltered → no QA-02 row; OPS store_id=QA-02 → only QA-02 rows."""
    today = datetime.now(IST).date().isoformat()
    out = p7_ops({"op": "run", "as": MANAGER, "key": "orders", "store_id": QA02_ID, "start": today, "end": today},
                 {"op": "run", "as": MANAGER, "key": "sales_summary", "start": today, "end": today},
                 {"op": "run", "as": OPS, "key": "sales_summary", "store_id": QA02_ID, "start": today, "end": today},
                 {"op": "run", "as": MANAGER, "key": "inventory_stock", "store_id": QA02_ID},
                 {"op": "export", "as": MANAGER, "key": "orders", "store_id": QA02_ID})
    assert not out[0]["ok"] and out[0]["error"] == "PermissionDenied", out[0]
    qa02_code = db_query("select code from stores_darkstore where id=%s", (QA02_ID,))[0][0]
    assert all(row[1] != qa02_code for row in out[1]["result"]["rows"]), out[1]["result"]["rows"]
    assert out[2]["ok"] and all(row[1] == qa02_code for row in out[2]["result"]["rows"]), out[2]
    assert not out[3]["ok"] and out[3]["error"] == "PermissionDenied", out[3]
    assert not out[4]["ok"] and out[4]["error"] == "PermissionDenied", out[4]


def _oracle_sales(store_id: int, day) -> dict:
    since = datetime(day.year, day.month, day.day, tzinfo=IST)
    until = since + timedelta(days=1)
    row = db_query(
        """
        with o as (select * from orders_order where store_id=%s and placed_at >= %s and placed_at < %s)
        select count(*),
          count(*) filter (where status='DELIVERED'),
          count(*) filter (where status='CANCELLED'),
          coalesce(sum(item_total) filter (where status<>'CANCELLED'),0),
          coalesce(sum(product_discount) filter (where status<>'CANCELLED'),0),
          coalesce(sum(coupon_discount) filter (where status<>'CANCELLED'),0),
          coalesce(sum(delivery_fee+small_cart_fee+handling_fee) filter (where status<>'CANCELLED'),0),
          coalesce(sum(tip) filter (where status not in ('CANCELLED','DELIVERY_FAILED','RETURNED')),0),
          coalesce(sum(grand_total) filter (where status<>'CANCELLED'),0),
          coalesce(sum(amount_refunded) filter (where status<>'CANCELLED' and not
              (status in ('DELIVERY_FAILED','RETURNED') and payment_method='COD')),0),
          coalesce(sum(grand_total) filter (where status in ('DELIVERY_FAILED','RETURNED') and payment_method='COD'),0),
          coalesce(sum(amount_refunded) filter (where status='CANCELLED'),0),
          (select coalesce(sum(r.amount),0) from payments_refund r join o on o.id=r.order_id
             where r.reason='item_unavailable' and r.status='PROCESSED' and o.status<>'CANCELLED'
               and not (o.status in ('DELIVERY_FAILED','RETURNED') and o.payment_method='COD'))
        from o
        """,
        (store_id, since, until),
    )[0]
    keys = ["orders", "delivered", "cancelled", "item_total", "product_discount", "coupon_discount", "fees",
            "tips", "gmv", "live_refunded", "uncollected_cod", "cancelled_refunds", "unavailable_refunds"]
    o = dict(zip(keys, row))
    o["refunded"] = max(money(o["live_refunded"]) - money(o["unavailable_refunds"]), Decimal("0"))
    o["net_revenue"] = money(o["gmv"]) - money(o["tips"]) - o["refunded"] - money(o["uncollected_cod"])
    live = o["orders"] - o["cancelled"]
    o["aov"] = (money(o["gmv"]) / live).quantize(Decimal("0.01")) if live else Decimal("0.00")
    return o


@pytest.mark.smoke
def test_p7_tc23_sales_summary_oracle_dl65(r1, p5_shop_a):
    """P7-TC-23 🔥 sales_summary for QA-02 today equals an independent SQL oracle of 05 §4 (GMV,
    tips, refunded, uncollected COD, net revenue = GMV − tips − refunded − uncollected COD, AOV),
    after adding a COD order that fails at the door (DL-65: stays in GMV, not in net revenue)."""
    r1.online_at()
    ctx = bring_to("ATC", shop=p5_shop_a, rider=r1)
    assert r1.fail(ctx["task_id"], "CUSTOMER_REFUSED").status_code == 200
    gt = money(p5_shop_a.order(ctx["order_id"]).json()["grand_total"])
    day = datetime.now(IST).date()
    res = p7_op(op="run", **{"as": OPS}, key="sales_summary", store_id=QA02_ID, start=day.isoformat(),
                end=day.isoformat())
    assert res["ok"], res
    cols = res["result"]["columns"]
    rows = [dict(zip(cols, r)) for r in res["result"]["rows"]]
    assert len(rows) == 1, rows
    got = rows[0]
    o = _oracle_sales(QA02_ID, day)
    assert money(got["uncollected_cod"]) >= gt > 0, (got["uncollected_cod"], gt)
    for k in ("orders", "delivered", "cancelled"):
        assert int(got[k]) == o[k], (k, got[k], o[k])
    for k in ("item_total", "product_discount", "coupon_discount", "fees", "tips", "gmv", "refunded",
              "uncollected_cod", "cancelled_refunds", "unavailable_refunds", "net_revenue", "aov"):
        assert money(got[k]) == money(o[k]), (k, got[k], o[k])
    assert money(got["net_revenue"]) == money(got["gmv"]) - money(got["tips"]) - money(got["refunded"]) - money(
        got["uncollected_cod"])
    for k in ("gmv", "net_revenue", "aov", "tips"):
        assert re.fullmatch(r"-?\d+\.\d{2}", got[k]), (k, got[k])


@pytest.mark.smoke
def test_p7_tc24_csv_formula_escaping_and_bom():
    """P7-TC-24 🔥 report CSV: UTF-8 BOM; cells starting = + - @ TAB CR are prefixed with ' (plain
    numbers such as -3 and +91… untouched); every real report's CSV has no unescaped formula cell."""
    probe = p7_op(op="csv_probe", values=["=1+1", "+1+2", "-3", "@SUM(A1)", "\tx", "\r=1", "+919876543210",
                                          '=HYPERLINK("http://evil")', "-1.50", "-A1"])["result"]
    assert probe.startswith("﻿")
    cells = [r[0] for r in csv.reader(io.StringIO(probe.lstrip("﻿")))][1:]
    assert cells == ["'=1+1", "'+1+2", "-3", "'@SUM(A1)", "'\tx", "'\r=1", "+919876543210",
                     "'=HYPERLINK(\"http://evil\")", "-1.50", "'-A1"], cells
    day = datetime.now(IST).date().isoformat()
    for key in sorted(ALL_REPORTS):
        out = p7_op(op="csv", **{"as": SUPER}, key=key, start=day, end=day)
        assert out["ok"], (key, out)
        text = out["result"]
        assert text.startswith("﻿"), key
        for row in csv.reader(io.StringIO(text.lstrip("﻿"))):
            for cell in row:
                if cell[:1] in ("=", "+", "-", "@", "\t", "\r") and not re.fullmatch(r"[+-]?\d+(\.\d+)?", cell):
                    pytest.fail(f"{key}: unescaped formula cell {cell[:20]!r}")


def test_p7_tc25_report_ranges():
    """P7-TC-25 start > end and a range over 366 days → ValidationError; an empty day → no rows."""
    out = p7_ops({"op": "run", "as": OPS, "key": "orders", "start": "2026-11-09", "end": "2026-11-01"},
                 {"op": "run", "as": OPS, "key": "orders", "start": "2025-01-01", "end": "2026-11-09"},
                 {"op": "run", "as": OPS, "key": "orders", "start": "2020-01-01", "end": "2020-01-01"})
    assert not out[0]["ok"] and out[0]["error"] == "ValidationError", out[0]
    assert not out[1]["ok"] and out[1]["error"] == "ValidationError", out[1]
    assert out[2]["ok"] and out[2]["result"]["rows"] == [], out[2]


def test_p7_tc26_orders_report_no_pii():
    """P7-TC-26 orders / refunds / cod reports carry no customer phone, name or address (09 PII)."""
    day = datetime.now(IST).date().isoformat()
    out = p7_ops(*[{"op": "csv", "as": SUPER, "key": k, "start": day, "end": day}
                   for k in ("orders", "refunds", "cod_reconciliation", "cancellations")])
    for res in out:
        assert res["ok"], res
        assert not re.search(r"\+91[6-9]\d{9}", res["result"]), "phone in a report"
        assert "QA Flat 5" not in res["result"] and "QA P5 Lane" not in res["result"]


def test_p7_tc27_export_and_download_scope():
    """P7-TC-27 export (OPS) → DONE with rows; OPS download → signed URL; Finance downloading OPS's
    export → refused (own exports only)."""
    day = datetime.now(IST).date().isoformat()
    exp = p7_op(op="export", **{"as": OPS}, key="orders", store_id=QA02_ID, start=day, end=day)
    assert exp["ok"] and exp["result"]["status"] == "DONE", exp
    out = p7_ops({"op": "download", "as": OPS, "export_id": exp["result"]["id"]},
                 {"op": "download", "as": FINANCE, "export_id": exp["result"]["id"]})
    assert out[0]["ok"] and out[0]["result"]["signed"], out[0]
    assert not out[1]["ok"], out[1]


# =========================================================================== DPDP erasure


@pytest.mark.smoke
def test_p7_tc30_anonymisation_erases_comment_and_ticket_text(api, make_address, r1):
    """P7-TC-30 🔥 QA user E: delivered order rated with a comment, a ticket; E deletes the account
    (API); anonymise (the beat job, run on demand) → rating comment erased (stars/tags kept, rider
    average unchanged), E's ticket message bodies erased, staff replies kept."""
    shop = make_qa02_shop(api, make_address, "e")
    r1.online_at()
    ctx = deliver(shop, r1)
    oid = ctx["order_id"]
    assert rate(shop.session, oid, {"order_stars": 4, "rider_stars": 4, "tags": ["ON_TIME"],
                                    "comment": "QA-E-PERSONAL-COMMENT"}).status_code == 201
    te = Tickets(shop.session)
    t = te.create("MISSING_ITEMS", "QA-E-PERSONAL-TICKET-TEXT missing", order_id=oid).json()
    assert p7_op(op="staff_reply", **{"as": SUPPORT}, ticket_id=t["id"], body="QA staff reply kept")["ok"]
    rid = rider_id_of(R1_PHONE)
    avg_before = db_query("select rating_avg from delivery_rider where id=%s", (rid,))[0][0]
    user_id = shop.session.user["id"]
    assert request_otp(api, QA_PHONES["e"], purpose="delete_account").status_code == 200
    r = api.post("/api/v1/me/delete/", json={"otp": TEST_OTP, "reason": "QA P7 erasure"},
                 headers=bearer(shop.session.access))
    assert r.status_code == 200, describe(r)
    out = p7_op(op="anonymise", phone=QA_PHONES["e"])
    assert out["ok"] and out["result"]["anonymised"] is True and out["result"]["user_id"] == user_id, out
    rows = db_query("select target, stars, tags, comment from orders_rating where order_id=%s order by target", (oid,))
    assert rows and all(c in ("", ERASED) for _, _, _, c in rows), rows
    assert [s for _, s, _, _ in rows] == [4, 4]
    assert any(c == ERASED for *_, c in rows)
    msgs = db_query("select is_staff, body from support_ticketmessage where ticket_id=%s order by id", (t["id"],))
    assert [b for s, b in msgs if not s] == [ERASED], msgs
    assert [b for s, b in msgs if s] == ["QA staff reply kept"], msgs
    assert db_query("select rating_avg from delivery_rider where id=%s", (rid,))[0][0] == avg_before
    assert db_query("select phone, name from accounts_user where id=%s", (user_id,))[0] == (None, "")


def test_p7_tc22b_own_store_manager_reports():
    """P7-TC-22b 05 §3 Reports "own store": the QA-02 Store Manager runs sales_summary unfiltered →
    only QA-02 rows; store_id=GGN-01 → PermissionDenied; equals OPS filtered to QA-02."""
    today = datetime.now(IST).date().isoformat()
    ggn = db_query("select id from stores_darkstore where id<>%s order by id limit 1", (QA02_ID,))[0][0]
    out = p7_ops({"op": "run", "as": QA02_MANAGER, "key": "sales_summary", "start": today, "end": today},
                 {"op": "run", "as": QA02_MANAGER, "key": "orders", "store_id": ggn, "start": today, "end": today},
                 {"op": "run", "as": OPS, "key": "sales_summary", "store_id": QA02_ID, "start": today, "end": today})
    assert out[0]["ok"], out[0]
    qa02_code = db_query("select code from stores_darkstore where id=%s", (QA02_ID,))[0][0]
    assert all(row[1] == qa02_code for row in out[0]["result"]["rows"]), out[0]["result"]["rows"]
    assert not out[1]["ok"] and out[1]["error"] == "PermissionDenied", out[1]
    assert out[0]["result"]["rows"] == out[2]["result"]["rows"]


# =========================================================================== dashboard (05 §1.1)


def _oracle_kpis(store_id: int, day) -> dict:
    since = datetime(day.year, day.month, day.day, tzinfo=IST)
    until = since + timedelta(days=1)
    o = db_query(
        """
        select count(*), count(*) filter (where status='DELIVERED'), count(*) filter (where status='CANCELLED'),
          coalesce(sum(grand_total) filter (where status<>'CANCELLED'),0),
          extract(epoch from avg(accepted_at - placed_at) filter (where accepted_at is not null)),
          count(*) filter (where accepted_at > placed_at + interval '60 seconds'
                           or (status='PLACED' and placed_at < now() - interval '60 seconds'))
        from orders_order where store_id=%s and placed_at >= %s and placed_at < %s
        """, (store_id, since, until))[0]
    d = db_query(
        """
        select extract(epoch from avg(delivered_at - placed_at)),
               count(*) filter (where eta_at is not null and delivered_at > eta_at)
        from orders_order where store_id=%s and status='DELIVERED' and delivered_at >= %s and delivered_at < %s
        """, (store_id, since, until))[0]
    riders = db_query("select count(*) from delivery_rider where is_online and home_store_id=%s", (store_id,))[0][0]
    active = db_query("select count(*) from orders_order where store_id=%s and status not in "
                      "('DELIVERED','CANCELLED','PAYMENT_FAILED','RETURNED','PAYMENT_PENDING')", (store_id,))[0][0]
    outs, low = db_query(
        """
        select count(*) filter (where s.on_hand <= s.reserved or not s.is_available),
               count(*) filter (where s.on_hand > s.reserved and s.is_available
                                and s.low_stock_threshold > s.on_hand - s.reserved)
        from inventory_storeinventory s join catalog_productvariant v on v.id=s.variant_id
        where s.store_id=%s and v.is_active
        """, (store_id,))[0]
    orders, delivered, cancelled, gmv, avg_acc, late_acc = o
    live = orders - cancelled
    return {
        "orders": orders, "delivered": delivered, "cancelled": cancelled, "gmv": money(gmv),
        "aov": (money(gmv) / live).quantize(Decimal("0.01")) if live else Decimal("0.00"),
        "cancelled_pct": round(100 * cancelled / orders, 1) if orders else 0.0,
        "avg_acceptance_seconds": float(avg_acc) if avg_acc is not None else None,
        "avg_delivery_minutes": float(d[0]) / 60 if d[0] is not None else None,
        "late_deliveries": d[1], "late_acceptances": late_acc,
        "online_riders": riders, "active_orders": active, "stock_outs": outs, "low_stock": low,
    }


@pytest.mark.smoke
def test_p7_tc31_dashboard_kpis_oracle(r1, p5_shop_a):
    """P7-TC-31 🔥 05 §1.1 KPI cards for QA-02 today (OPS) equal an independent SQL oracle: orders,
    GMV, AOV, delivered, cancelled %, avg delivery / acceptance time, SLA breaches, online riders,
    active orders, stock-outs, low stock; GMV/orders/AOV agree with sales_summary; money is a
    2-decimal string."""
    r1.online_at()
    deliver(p5_shop_a, r1)
    day = datetime.now(IST).date()
    out = p7_ops({"op": "kpis", "as": OPS, "store_id": QA02_ID},
                 {"op": "run", "as": OPS, "key": "sales_summary", "store_id": QA02_ID,
                  "start": day.isoformat(), "end": day.isoformat()})
    assert out[0]["ok"], out[0]
    k = out[0]["result"]
    o = _oracle_kpis(QA02_ID, day)
    for key in ("orders", "delivered", "cancelled", "online_riders", "active_orders", "stock_outs", "low_stock"):
        assert k[key] == o[key], (key, k[key], o[key])
    assert money(k["gmv"]) == o["gmv"] and money(k["aov"]) == o["aov"], (k["gmv"], k["aov"], o)
    for key in ("gmv", "aov"):
        assert re.fullmatch(r"\d+\.\d{2}", k[key]), (key, k[key])
    assert k["cancelled_pct"] == pytest.approx(o["cancelled_pct"], abs=0.051)
    assert k["avg_acceptance_seconds"] == pytest.approx(o["avg_acceptance_seconds"], abs=0.051)
    assert k["avg_delivery_minutes"] == pytest.approx(o["avg_delivery_minutes"], abs=0.051)
    sb = k["sla_breaches"]
    assert sb["late_deliveries"] == o["late_deliveries"] and sb["late_acceptances"] == o["late_acceptances"], (sb, o)
    assert sb["total"] == sb["late_deliveries"] + sb["late_acceptances"]
    cols = out[1]["result"]["columns"]
    s = dict(zip(cols, out[1]["result"]["rows"][0]))
    assert int(s["orders"]) == k["orders"] and money(s["gmv"]) == money(k["gmv"]) and money(s["aov"]) == money(k["aov"])


@pytest.mark.smoke
def test_p7_tc32_dashboard_roles_and_store_scope():
    """P7-TC-32 🔥 dashboard (reports.view_reports, store-scoped): SA/OPS/FIN allowed; SUP/SS/CAT
    PermissionDenied; GGN-01 Store Manager with store_id=QA-02 → PermissionDenied; the QA-02 Store
    Manager unfiltered == OPS filtered to QA-02 (KPIs and alerts)."""
    out = p7_ops(*[{"op": "kpis", "as": who} for who in (SUPER, OPS, FINANCE, SUPPORT, STAFF, CATALOG)],
                 {"op": "kpis", "as": MANAGER, "store_id": QA02_ID},
                 {"op": "alerts", "as": MANAGER, "store_id": QA02_ID},
                 {"op": "kpis", "as": QA02_MANAGER},
                 {"op": "kpis", "as": OPS, "store_id": QA02_ID},
                 {"op": "alerts", "as": QA02_MANAGER},
                 {"op": "alerts", "as": OPS, "store_id": QA02_ID})
    for res in out[:3]:
        assert res["ok"], res
    for res in out[3:8]:
        assert not res["ok"] and res["error"] == "PermissionDenied", res
    assert out[8]["ok"] and out[8]["result"] == out[9]["result"], (out[8], out[9])
    assert out[10]["ok"] and out[10]["result"] == out[11]["result"]


def test_p7_tc33_dashboard_alert_no_rider(api, make_address, qa_worker):
    """P7-TC-33 05 §1.1 alert "orders without a rider > 3 min": a QA-02 order with no rider online
    is not listed at once, is listed (store QA-02, task SEARCHING/OFFERED/UNASSIGNED) when the
    service clock is 4 min ahead, and never reaches the GGN-01 Store Manager's alerts."""
    import time as _t

    from p5_support import cleanup_orders, reset_rider, wait_order_status

    for phone in (R1_PHONE, R2_PHONE):
        reset_rider(phone)
    shop = make_qa02_shop(api, make_address, "a")
    try:
        oid = shop.place_cod()["id"]
        wait_order_status(oid, "ACCEPTED")
        for _ in range(60):
            if db_query("select 1 from delivery_deliverytask where order_id=%s", (oid,)):
                break
            _t.sleep(0.5)
        out = p7_ops({"op": "alerts", "as": OPS, "store_id": QA02_ID},
                     {"op": "alerts", "as": OPS, "store_id": QA02_ID, "now_offset_s": 240},
                     {"op": "alerts", "as": MANAGER, "now_offset_s": 240})
        now_ids = [i["order_id"] for i in out[0]["result"]["no_rider"]["items"]]
        later = {i["order_id"]: i for i in out[1]["result"]["no_rider"]["items"]}
        assert oid not in now_ids, now_ids
        assert oid in later and later[oid]["store"] == "QA-02" and later[oid]["minutes"] >= 4.0, later.get(oid)
        assert later[oid]["task_status"] in ("SEARCHING", "OFFERED", "UNASSIGNED"), later[oid]
        assert all(i["order_id"] != oid for i in out[2]["result"]["no_rider"]["items"])
        assert out[1]["result"]["no_rider"]["count"] >= 1
    finally:
        cleanup_orders(shop)
        shop.cancel_pending()
        shop.clear()


def test_p7_tc34_dashboard_charts_consistent():
    """P7-TC-34 charts for QA-02 today: orders per hour sums to the KPI orders (24 IST hours);
    today's GMV trend point = KPI GMV; payment split (ONLINE, COD) sums to live orders and GMV;
    top products = SQL over live orders (units net of unavailable)."""
    out = p7_ops({"op": "charts", "as": OPS, "store_id": QA02_ID}, {"op": "kpis", "as": OPS, "store_id": QA02_ID})
    assert out[0]["ok"] and out[1]["ok"], out
    c, k = out[0]["result"], out[1]["result"]
    assert [h["hour"] for h in c["orders_per_hour"]] == list(range(24))
    assert sum(h["orders"] for h in c["orders_per_hour"]) == k["orders"]
    assert len(c["gmv_trend"]) == 7 and c["gmv_trend"][-1]["orders"] == k["orders"]
    assert money(c["gmv_trend"][-1]["gmv"]) == money(k["gmv"])
    split = {p["payment_method"]: p for p in c["payment_split"]}
    assert list(split) == ["ONLINE", "COD"]
    assert sum(p["orders"] for p in split.values()) == k["orders"] - k["cancelled"]
    assert sum(money(p["gmv"]) for p in split.values()) == money(k["gmv"])
    day = datetime.now(IST).date()
    since = datetime(day.year, day.month, day.day, tzinfo=IST)
    top = db_query(
        """
        select i.sku, sum(i.quantity - i.quantity_unavailable) u
        from orders_orderitem i join orders_order o on o.id=i.order_id
        where o.store_id=%s and o.placed_at >= %s and o.placed_at < %s and o.status<>'CANCELLED'
        group by i.sku having sum(i.quantity - i.quantity_unavailable) > 0 order by u desc, i.sku limit 10
        """, (QA02_ID, since, since + timedelta(days=1)))
    assert [(t["sku"], t["units"]) for t in c["top_products"]] == [(s, int(u)) for s, u in top]


# =========================================================================== support SLA


@pytest.mark.smoke
def test_p7_tc35_sla_priority_due_times(ta):
    """P7-TC-35 🔥 SLA targets per priority (PM default: URGENT 15 min / 4 h, HIGH 30 min / 8 h,
    NORMAL 60 min / 24 h, LOW 240 min / 72 h) from created_at; set by Support; Finance refused;
    unknown priority → ValidationError."""
    t = ta.create("OTHER", "QA P7-TC-35 sla priority ticket").json()
    targets = {"URGENT": (15, 4), "HIGH": (30, 8), "LOW": (240, 72), "NORMAL": (60, 24)}
    out = p7_ops(*[{"op": "set_priority", "as": SUPPORT, "ticket_id": t["id"], "priority": p} for p in targets],
                 {"op": "set_priority", "as": FINANCE, "ticket_id": t["id"], "priority": "URGENT"},
                 {"op": "set_priority", "as": SUPPORT, "ticket_id": t["id"], "priority": "CRITICAL"})
    for (prio, (mins, hours)), res in zip(targets.items(), out):
        assert res["ok"] and res["result"]["priority"] == prio, res
        created = datetime.fromisoformat(res["result"]["created_at"])
        assert datetime.fromisoformat(res["result"]["first_response_due_at"]) - created == timedelta(minutes=mins)
        assert datetime.fromisoformat(res["result"]["resolution_due_at"]) - created == timedelta(hours=hours)
    assert not out[4]["ok"] and out[4]["error"] == "PermissionDenied", out[4]
    assert not out[5]["ok"] and out[5]["error"] == "ValidationError", out[5]


@pytest.mark.smoke
def test_p7_tc36_sla_breach_first_response_and_resolution(ta):
    """P7-TC-36 🔥 SLA breach rules: no reply at +61 min → first response breached and listed in the
    breached queue (Support), never for Finance; an in-time staff reply clears the first-response
    breach; still open at +25 h → resolution breached; RESOLVED in time → no breach, off the queue."""
    t = ta.create("OTHER", "QA P7-TC-36 sla breach ticket").json()
    tid = t["id"]
    h61, h25 = 61 * 60, 25 * 3600
    out = p7_ops({"op": "sla_at", "ticket_id": tid},
                 {"op": "sla_at", "ticket_id": tid, "now_offset_s": h61},
                 {"op": "breached", "as": SUPPORT, "ids": [tid], "now_offset_s": h61},
                 {"op": "breached", "as": FINANCE, "ids": [tid], "now_offset_s": h61},
                 {"op": "staff_reply", "as": SUPPORT, "ticket_id": tid, "body": "QA first response"},
                 {"op": "sla_at", "ticket_id": tid, "now_offset_s": h61},
                 {"op": "sla_at", "ticket_id": tid, "now_offset_s": h25},
                 {"op": "breached", "as": SUPPORT, "ids": [tid], "now_offset_s": h25},
                 {"op": "change_status", "as": SUPPORT, "ticket_id": tid, "status": "RESOLVED"},
                 {"op": "sla_at", "ticket_id": tid, "now_offset_s": h25},
                 {"op": "breached", "as": SUPPORT, "ids": [tid], "now_offset_s": h25})
    assert out[0]["result"]["first_response_breached"] is False and out[0]["result"]["resolution_breached"] is False
    assert out[1]["result"]["first_response_breached"] is True, out[1]
    assert out[2]["result"]["breached"] == [tid] and out[2]["result"]["flags"] == {str(tid): True}, out[2]
    assert out[3]["result"]["breached"] == [] and out[3]["result"]["flags"] == {}, out[3]
    assert out[4]["ok"], out[4]
    assert out[5]["result"]["first_response_breached"] is False, out[5]
    assert out[6]["result"]["resolution_breached"] is True and out[6]["result"]["first_response_breached"] is False
    assert out[7]["result"]["breached"] == [tid], out[7]
    assert out[8]["ok"], out[8]
    assert out[9]["result"]["resolution_breached"] is False, out[9]
    assert out[10]["result"]["breached"] == [] and out[10]["result"]["flags"] == {str(tid): False}, out[10]
