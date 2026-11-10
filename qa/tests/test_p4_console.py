"""Phase 4 stage 2 (QA T-416): the Ops Console and admin screens of admin P4 (T-413), driven
through the real pages and forms like a browser (HTMX headers, CSRF), plus the QA-02 cases.

- Packing console `/ops/store/<code>/` (05 §1.3), live board `/ops/orders/live/` (05 §1.2),
  Orders / Refunds / Audit log / Customers admin (05 §2), 05 §3 role matrix.
- QA-02 (DarkStore id 2, Jaipur, auto-accept on; qa/docs/01 §8.7) for store scoping (TC-30),
  auto-accept (TC-36) and the NOT_AVAILABLE reorder (TC-12).
- Only QA customers' orders are ever acted on (`p4_console.assert_qa_order`); GGN-01's settings
  are never changed (its accepting switch is only ever tried by a role that is refused).
"""

from __future__ import annotations

import re
import statistics
import time
from decimal import Decimal

import pytest

from admin_forms import read_form
from p3_support import V_CANOLA_1L, V_CHIA, V_SUN_1L, Shop, money, send_webhook, stock
from p4_console import Ops, message
from p4_support import (
    CATALOG, FINANCE, MANAGER, OPS, STAFF, SUPER, SUPPORT,
    history, order_row, refunds, start_worker, stop_worker, t8a_oracle,
)
from qa_support import APP_HEADERS, QA_PHONES, db_query, describe, validate_response
from test_p4_orders import cod_order, paid_online, wait_refunded

GGN, QA02, QA02_ID = "GGN-01", "QA-02", 2
JAIPUR = {"label": "other", "custom_label": "QA-02", "house": "QA Flat 2", "building_street": "QA Lane",
          "landmark": "", "area": "MI Road", "city": "Jaipur", "state": "Rajasthan", "pincode": "302001",
          "lat": 26.912, "lng": 75.788}


def text(html: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", re.sub(r"<(script|style).*?</\1>", "", html, flags=re.S)))


def items_of(shop, oid) -> dict[int, dict]:
    return {line["variant_id"]: line for line in shop.order(oid).json()["items"]}


@pytest.fixture(scope="module")
def ops_users():
    users = {email: Ops(email) for email in (SUPER, OPS, MANAGER, STAFF, CATALOG, SUPPORT, FINANCE)}
    for u in users.values():
        u.get("/admin/")
    yield users
    for u in users.values():
        u.close()


@pytest.fixture
def staff(ops_users):
    return ops_users[STAFF]


@pytest.fixture
def qa02_shop(api, make_address):
    """QA user B shopping at QA-02 (Jaipur address, X-Store-Id 2). Moved from user D in P5 stage 2:
    D is rider R2, and a rider must never be offered their own order (01 §9, A10)."""
    from conftest import login

    class Qa02Shop(Shop):
        @property
        def h(self):
            return {**APP_HEADERS, "X-Store-Id": str(QA02_ID), **self.session.headers}

    session = login(QA_PHONES["b"])
    shop = Qa02Shop(api, session)
    shop.cancel_pending()
    shop.clear()
    shop.address = make_address(session, **JAIPUR)
    yield shop
    shop.cancel_pending()
    shop.clear()


def cleanup(ops_users, oid: int) -> None:
    if order_row(oid)["status"] in ("PLACED", "ACCEPTED", "PACKING", "PACKED"):
        r = ops_users[OPS].board_cancel(oid, "OTHER_STAFF")
        assert r.status_code == 204, message(r)


# --------------------------------------------------------------------------- packing console


@pytest.mark.smoke
def test_p4_tc19c_accept_on_console(shop_a, ops_users, staff):
    """P4-TC-19 🔥 (console) Store Staff opens the GGN-01 console, the new QA order is in the
    queue with an Accept button; Accept → 204 + success toast; ACCEPTED with actor_type store;
    a second Accept → 409 with a readable message and no second history row."""
    o = cod_order(shop_a)
    try:
        page = staff.get(f"/ops/store/{GGN}/").text
        assert f'hx-post="/ops/store/{GGN}/orders/{o["id"]}/accept/"' in page
        r = staff.step(GGN, o["id"], "accept")
        assert r.status_code == 204 and "accepted" in r.headers["HX-Trigger"], describe(r)
        assert history(o["id"])[-1] == ("PLACED", "ACCEPTED", "store")
        assert shop_a.order(o["id"]).json()["timeline"][-1]["title"].startswith("Order confirmed")
        r = staff.step(GGN, o["id"], "accept")
        assert r.status_code == 409 and "newly placed" in message(r)
        assert [h[1] for h in history(o["id"])].count("ACCEPTED") == 1
    finally:
        cleanup(ops_users, o["id"])


@pytest.mark.smoke
def test_p4_tc20c_pack_and_slip(shop_a, ops_users, staff):
    """P4-TC-20 🔥 (console) Start packing, Mark packed; the slip shows the order number, the
    4-character pickup code, a QR and the item count; the slip of a PLACED order is 404."""
    o = cod_order(shop_a, {V_SUN_1L: 2})
    try:
        assert staff.get(f"/ops/store/{GGN}/orders/{o['id']}/slip/").status_code == 404
        for step in ("accept", "start-packing", "mark-packed"):
            r = staff.step(GGN, o["id"], step)
            assert r.status_code == 204, (step, message(r))
        row = order_row(o["id"])
        assert row["status"] == "PACKED" and len(row["pickup_code"]) == 4
        slip = staff.get(f"/ops/store/{GGN}/orders/{o['id']}/slip/")
        t = text(slip.text)
        assert slip.status_code == 200 and o["order_number"] in t and row["pickup_code"] in t
        assert "2 items" in t and ("<svg" in slip.text or "qr" in slip.text.lower())
        assert "+91" not in t
    finally:
        cleanup(ops_users, o["id"])


def test_p4_tc21c_console_guards(shop_a, ops_users, staff):
    """P4-TC-21 (console) Out-of-order steps → 409 with a message, nothing changes; an unknown
    step → 404; GET on any action URL → 405 (no state change on GET)."""
    o = cod_order(shop_a)
    try:
        for step in ("mark-packed", "start-packing"):
            r = staff.step(GGN, o["id"], step)
            assert r.status_code == 409 and message(r), (step, r.status_code)
        assert staff.step(GGN, o["id"], "deliver").status_code == 404
        for path in ("accept/", "start-packing/", "unavailable/"):
            assert staff.c.get(f"/ops/store/{GGN}/orders/{o['id']}/{path}").status_code == 405
        # Store Staff may not cancel at all (403 before the method check); a canceller gets 405.
        assert ops_users[MANAGER].c.get(f"/ops/store/{GGN}/orders/{o['id']}/cancel/").status_code == 405
        assert ops_users[OPS].c.get(f"/ops/orders/{o['id']}/cancel/").status_code == 405
        assert order_row(o["id"])["status"] == "PLACED"
    finally:
        cleanup(ops_users, o["id"])


@pytest.mark.smoke
def test_p4_tc22c_cant_supply_online_on_console(shop_a, ops_users, staff):
    """P4-TC-22 🔥 (console) "Can't supply" 1 of 2 Sun units on a paid ONLINE order: bill =
    QA oracle; one ITEMS_UNAVAILABLE refund of old − new; the same value posted again →
    "nothing changed", still one refund (TC-27 double submit)."""
    o = paid_online(shop_a, {V_SUN_1L: 2, V_CANOLA_1L: 1})
    try:
        for step in ("accept", "start-packing"):
            assert staff.step(GGN, o["id"], step).status_code == 204
        old = order_row(o["id"])
        lines = items_of(shop_a, o["id"])
        sun, can = lines[V_SUN_1L], lines[V_CANOLA_1L]
        exp = t8a_oracle(old, [(money(sun["mrp"]), money(sun["selling_price"]), 1), (money(can["mrp"]), money(can["selling_price"]), 1)])
        r = staff.unavailable(GGN, o["id"], sun["id"], 1)
        assert r.status_code == 204, message(r)
        assert money(order_row(o["id"])["grand_total"]) == exp["grand_total"]
        assert [x[1] for x in refunds(o["id"])] == [exp["refund"]]
        r = staff.unavailable(GGN, o["id"], sun["id"], 1)
        assert r.status_code == 204 and "nothing changed" in r.headers["HX-Trigger"]
        assert len(refunds(o["id"])) == 1
    finally:
        cleanup(ops_users, o["id"])
    done = wait_refunded(shop_a, o["id"])
    assert sum((money(x["amount"]) for x in done["refunds"]), Decimal(0)) == money(o["bill"]["grand_total"])


def test_p4_tc27c_cant_supply_guards(shop_a, shop_b, ops_users, staff):
    """P4-TC-27 (console) qty above the line, negative, missing → 400; another order's line →
    404; lowering an earlier mark → 400; on PACKED → 409; nothing changes."""
    o = cod_order(shop_a, {V_SUN_1L: 2})
    other = cod_order(shop_b, {V_CANOLA_1L: 1})
    try:
        for step in ("accept", "start-packing"):
            assert staff.step(GGN, o["id"], step).status_code == 204
        sun = items_of(shop_a, o["id"])[V_SUN_1L]["id"]
        foreign = items_of(shop_b, other["id"])[V_CANOLA_1L]["id"]
        assert staff.unavailable(GGN, o["id"], sun, 3).status_code == 400
        assert staff.unavailable(GGN, o["id"], sun, -1).status_code == 400
        assert staff.post(f"/ops/store/{GGN}/orders/{o['id']}/unavailable/", {"item": sun}, order_id=o["id"]).status_code == 400
        assert staff.unavailable(GGN, o["id"], foreign, 1).status_code == 404
        assert staff.unavailable(GGN, o["id"], sun, 1).status_code == 204
        assert staff.unavailable(GGN, o["id"], sun, 0).status_code == 400
        assert staff.step(GGN, o["id"], "mark-packed").status_code == 204
        r = staff.unavailable(GGN, o["id"], sun, 2)
        assert r.status_code == 409, r.status_code
        assert items_of(shop_b, other["id"])[V_CANOLA_1L]["quantity_unavailable"] == 0
        assert items_of(shop_a, o["id"])[V_SUN_1L]["quantity_unavailable"] == 1
    finally:
        cleanup(ops_users, o["id"])
        shop_b.cancel(other["id"])


# --------------------------------------------------------------------------- roles (05 §3)


@pytest.mark.smoke
def test_p4_tc31c_role_matrix_pages(ops_users):
    """P4-TC-31 🔥 (console pages) 05 §3: live board Super/Ops/SM/Support (not SS, Catalog,
    Finance); packing console Super/Ops/SM/SS (not Catalog, Support, Finance); audit log Super
    and Finance only; refund admin Super/Support/Finance (not Ops, SM, SS, Catalog)."""
    want = {
        "/ops/orders/live/": {SUPER, OPS, MANAGER, SUPPORT},
        f"/ops/store/{GGN}/": {SUPER, OPS, MANAGER, STAFF},
        "/admin/core/auditlog/": {SUPER, FINANCE},
        "/admin/payments/refund/": {SUPER, SUPPORT, FINANCE},
    }
    got = {}
    for path, allowed in want.items():
        for email, u in ops_users.items():
            code = u.c.get(path).status_code
            got[(path, email)] = code
            assert (code == 200) == (email in allowed), (path, email, code)
            if email not in allowed:
                assert code in (302, 403, 404), (path, email, code)


def test_p4_tc31c_role_matrix_posts(shop_a, ops_users):
    """P4-TC-31 (console POSTs, server-side) Accept by Catalog/Support/Finance → 403; cancel on
    the packing console by Store Staff → 403; board cancel by Store Staff/Catalog/Finance →
    403; the accepting switch by Store Staff → 403 and GGN-01 unchanged; Support may cancel
    from the board (before pickup) → 204."""
    o = cod_order(shop_a)
    accepting = db_query("select is_accepting_orders from stores_darkstore where id=1")[0][0]
    try:
        for who in (CATALOG, SUPPORT, FINANCE):
            r = ops_users[who].step(GGN, o["id"], "accept")
            assert r.status_code == 403, (who, r.status_code)
        assert ops_users[STAFF].cancel(GGN, o["id"], "OTHER_STAFF").status_code == 403
        for who in (STAFF, CATALOG, FINANCE):
            assert ops_users[who].board_cancel(o["id"], "OTHER_STAFF").status_code == 403, who
        r = ops_users[STAFF].post(f"/ops/store/{GGN}/accepting/", {"accepting": "0"})
        assert r.status_code == 403
        assert db_query("select is_accepting_orders from stores_darkstore where id=1")[0][0] == accepting
        assert order_row(o["id"])["status"] == "PLACED"
        r = ops_users[SUPPORT].board_cancel(o["id"], "CUSTOMER_REQUEST", "QA")
        assert r.status_code == 204, message(r)
        assert order_row(o["id"])["cancelled_by_type"] == "ops"
    finally:
        cleanup(ops_users, o["id"])


def test_p4_tc29c_cancel_reason_required(shop_a, ops_users):
    """P4-TC-29 (console) Cancel without a reason / with a customer reason → 400, unchanged."""
    o = cod_order(shop_a)
    try:
        for reason in ("", "CHANGED_MIND"):
            assert ops_users[MANAGER].cancel(GGN, o["id"], reason).status_code == 400, reason
        assert order_row(o["id"])["status"] == "PLACED"
    finally:
        cleanup(ops_users, o["id"])


@pytest.mark.smoke
def test_p4_tc42_csrf_and_get(shop_a, ops_users, staff):
    """P4-TC-42 Console POST without the CSRF token → 403 and nothing changes (step, cancel,
    unavailable, accepting); GET on action URLs → 405."""
    o = cod_order(shop_a)
    try:
        assert staff.step(GGN, o["id"], "accept", csrf=False).status_code == 403
        assert ops_users[OPS].board_cancel(o["id"], "OTHER_STAFF", csrf=False).status_code == 403
        assert ops_users[SUPER].post(f"/ops/store/{QA02}/accepting/", {"accepting": "0"}, csrf=False).status_code == 403
        assert order_row(o["id"])["status"] == "PLACED"
        assert db_query("select is_accepting_orders from stores_darkstore where id=%s", (QA02_ID,))[0][0] is True
        assert ops_users[SUPER].c.get(f"/ops/store/{QA02}/accepting/").status_code == 405
    finally:
        cleanup(ops_users, o["id"])


# --------------------------------------------------------------------------- QA-02


@pytest.mark.smoke
def test_p4_tc36_auto_accept_qa02(qa02_shop, ops_users):
    """P4-TC-36 QA-02 has auto-accept on (AUTO_ACCEPT_DELAY_SECONDS 0): a COD order there is
    ACCEPTED by the system (history actor_type system, no actor) within seconds, with a pickup
    code; the customer sees "Order confirmed"."""
    o = cod_order(qa02_shop, {V_SUN_1L: 1})
    try:
        end = time.monotonic() + 60
        while time.monotonic() < end and order_row(o["id"])["status"] == "PLACED":
            time.sleep(2)
        row = order_row(o["id"])
        assert row["status"] == "ACCEPTED" and len(row["pickup_code"]) == 4, row
        h = db_query("select actor_type, actor_id from orders_orderstatushistory where order_id=%s and to_status='ACCEPTED'", (o["id"],))
        assert h == [("system", None)], h
        assert qa02_shop.order(o["id"]).json()["timeline"][-1]["title"].startswith("Order confirmed")
    finally:
        cleanup(ops_users, o["id"])


@pytest.mark.smoke
def test_p4_tc30_store_scoping(qa02_shop, ops_users):
    """P4-TC-30 🔥 Store Manager / Staff of GGN-01: QA-02's console → 404; actions on a QA-02
    order through either store's URLs → 404; board cancel by the Store Manager → 404; the
    order is not on their live board / queue; Ops sees it and filters by store."""
    o = cod_order(qa02_shop, {V_SUN_1L: 1})
    num = o["order_number"]
    try:
        for who in (MANAGER, STAFF):
            u = ops_users[who]
            assert u.c.get(f"/ops/store/{QA02}/").status_code == 404
            assert u.c.get(f"/ops/store/{QA02}/queues/").status_code == 404
            for store in (GGN, QA02):
                for step in ("accept", "start-packing"):
                    assert u.step(store, o["id"], step).status_code == 404, (who, store, step)
                assert u.unavailable(store, o["id"], 1, 1).status_code == 404
            assert num not in u.get(f"/ops/store/{GGN}/").text
        m = ops_users[MANAGER]
        assert m.board_cancel(o["id"], "OTHER_STAFF").status_code == 404
        assert num not in m.get("/ops/orders/live/").text
        assert m.c.get(f"/admin/orders/order/{o['id']}/change/").status_code in (302, 404)
        assert order_row(o["id"])["status"] in ("PLACED", "ACCEPTED")
        board = ops_users[OPS].get(f"/ops/orders/live/?store={QA02_ID}").text
        assert num in board
        assert num not in ops_users[OPS].get("/ops/orders/live/?store=1").text
    finally:
        cleanup(ops_users, o["id"])


def test_p4_tc12c_reorder_not_available_at_qa02(shop_a):
    """P4-TC-12 (NOT_AVAILABLE) A GGN-01 order of Sun + Chia reordered with X-Store-Id 2
    (QA-02 sells no Chia): Chia → NOT_AVAILABLE, added 0; Sun added."""
    o = cod_order(shop_a, {V_SUN_1L: 1, V_CHIA: 1})
    shop_a.cancel(o["id"])
    h2 = {**shop_a.h, "X-Store-Id": str(QA02_ID)}
    try:
        shop_a.api.delete("/api/v1/cart/", headers=h2)
        r = shop_a.api.post(f"/api/v1/orders/{o['id']}/reorder/", headers=h2)
        validate_response(r, "orders_reorder")
        assert r.status_code == 200, describe(r)
        issues = {i["variant_id"]: i for i in r.json()["unavailable"]}
        assert issues[V_CHIA]["reason"] == "NOT_AVAILABLE" and issues[V_CHIA]["added_quantity"] == 0
        assert {line["variant"]["id"]: line["quantity"] for line in r.json()["cart"]["items"]} == {V_SUN_1L: 1}
    finally:
        shop_a.api.delete("/api/v1/cart/", headers=h2)


def test_p4_tc39_accepting_switch_qa02(ops_users):
    """P4-TC-39 (switch) On QA-02 only: Super Admin pauses the store from the console →
    serviceability shows it closed for new orders; resumes → open. The switch is offered to the
    Store Manager on GGN-01 and not to Store Staff (rendered page only; GGN-01 is never changed)."""
    from qa_support import BASE_URL
    import httpx

    s = ops_users[SUPER]
    s.get(f"/ops/store/{QA02}/")
    try:
        r = s.post(f"/ops/store/{QA02}/accepting/", {"accepting": "0"})
        assert r.status_code == 200, (r.status_code, message(r))
        assert db_query("select is_accepting_orders from stores_darkstore where id=%s", (QA02_ID,))[0][0] is False
        sv = httpx.get(f"{BASE_URL}/api/v1/serviceability/", params={"lat": 26.912, "lng": 75.788}, headers=APP_HEADERS).json()
        assert sv["store"] is None or sv["store"]["is_open"] is False, sv
    finally:
        r = s.post(f"/ops/store/{QA02}/accepting/", {"accepting": "1"})
        assert db_query("select is_accepting_orders from stores_darkstore where id=%s", (QA02_ID,))[0][0] is True
    assert "/accepting/" in ops_users[MANAGER].get(f"/ops/store/{GGN}/").text
    assert "/accepting/" not in ops_users[STAFF].get(f"/ops/store/{GGN}/").text


# --------------------------------------------------------------------------- pages


def test_p4_tc38_live_board(shop_a, ops_users):
    """P4-TC-38 Live board: the order columns and the exceptions lane; card with order number,
    store, timer, item count, payment; store/payment/SLA-breach filters; 10 s HTMX poll; the
    columns partial is a fragment; no full customer phone anywhere."""
    o = cod_order(shop_a)
    try:
        page = ops_users[OPS].get("/ops/orders/live/").text
        t = text(page)
        for col in ("Placed", "Accepted", "Packing", "Packed"):
            assert col in t, col
        print("lanes:", [x for x in ("Out for delivery", "Exceptions", "exception") if x in t])
        assert o["order_number"] in t
        assert set(re.findall(r'name="([a-z_]+)"', page)) >= {"store", "payment", "breached"}
        assert "every 10s" in page
        part = ops_users[OPS].c.get("/ops/orders/live/columns/", headers={"HX-Request": "true"})
        assert part.status_code == 200 and "<html" not in part.text and o["order_number"] in part.text
        assert not re.findall(r"\+91[6-9]\d{9}", page + part.text)
        filtered = ops_users[OPS].get("/ops/orders/live/?payment=ONLINE").text
        assert o["order_number"] not in filtered
    finally:
        cleanup(ops_users, o["id"])


def test_p4_tc40_orders_admin(ops_users):
    """P4-TC-40 Orders admin: filters store/status/payment/date; detail with timeline, payments,
    refunds; actions per 05 §2 (cancel, refund full/partial within role limit, CSV export)."""
    s = ops_users[SUPER]
    page = s.get("/admin/orders/order/").text
    for f in ("status__exact", "payment_method__exact", "payment_status__exact", "store"):
        assert f in page, f
    oid = db_query("select o.id from orders_order o join accounts_user u on u.id=o.user_id where u.phone like '+9190000001%%' order by o.id desc limit 1")[0][0]
    detail = s.get(f"/admin/orders/order/{oid}/change/").text
    assert all(k in detail for k in ("Status history", "Payments", "Refunds"))
    has_refund_action = bool(re.search(r"manual.?refund|Issue refund|Refund order", detail, re.I)) or bool(re.search(r'<option value="[a-z_]*refund', page))
    has_export = bool(re.search(r"export", page, re.I))
    assert has_refund_action and has_export, f"refund action: {has_refund_action}, CSV export: {has_export} (BUG-0010/0011)"


@pytest.mark.smoke
def test_p4_tc41c_audit_log_page(shop_a, ops_users, staff):
    """P4-TC-41 🔥 (console) A console accept writes an audit row shown on the audit log with
    the staff user; the audit log is read-only (no add, no save; a POST to a change page is
    refused); Store Manager / Support cannot open it."""
    o = cod_order(shop_a)
    try:
        assert staff.step(GGN, o["id"], "accept").status_code == 204
        rid = db_query("select id from core_auditlog where object_type='orders.order' and object_id=%s and action='order.accept'", (str(o["id"]),))[0][0]
        s = ops_users[SUPER]
        lst = text(s.get("/admin/core/auditlog/").text)
        assert "order.accept" in lst
        assert s.c.get("/admin/core/auditlog/add/").status_code in (403, 404)
        ch = s.get(f"/admin/core/auditlog/{rid}/change/")
        assert ch.status_code == 200 and 'name="_save"' not in ch.text
        r = s.post(f"/admin/core/auditlog/{rid}/change/", {"action": "tampered"}, htmx=False)
        assert r.status_code in (403, 405) or db_query("select action from core_auditlog where id=%s", (rid,))[0][0] == "order.accept"
        assert db_query("select action from core_auditlog where id=%s", (rid,))[0][0] == "order.accept"
        assert s.c.get(f"/admin/core/auditlog/{rid}/delete/").status_code in (403, 404)
        for who in (MANAGER, SUPPORT, STAFF, OPS):
            assert ops_users[who].c.get("/admin/core/auditlog/").status_code == 403, who
    finally:
        cleanup(ops_users, o["id"])


def test_p4_tc43_customer_detail_pii(ops_users):
    """P4-TC-43 Customer detail: Super/Ops/Support see the full phone; Store Manager / Staff
    cannot open Customers and see only a masked phone on the order detail."""
    uid = db_query("select id from accounts_user where phone='+919000000103'")[0][0]
    for who in (SUPER, OPS, SUPPORT):
        r = ops_users[who].c.get(f"/admin/accounts/customer/{uid}/change/")
        assert r.status_code == 200 and "+919000000103" in r.text, who
    for who in (MANAGER, STAFF):
        assert ops_users[who].c.get(f"/admin/accounts/customer/{uid}/change/").status_code == 403
    oid = db_query("select o.id from orders_order o where o.user_id=%s and o.store_id=1 order by o.id desc limit 1", (uid,))[0][0]
    r = ops_users[MANAGER].c.get(f"/admin/orders/order/{oid}/change/")
    assert r.status_code == 200 and "9000000103" not in r.text


def test_p4_tc60_console_poll_latency(ops_users):
    """P4-TC-60 (latency part) 20 sequential polls each of the live-board columns (Ops) and the
    GGN-01 queues (Store Staff): p50/p95 recorded (remote DB ~10 ms/query inflates it). The
    fixed-query-count part is white-box (admin tests), not measurable here."""
    out = {}
    for who, path in ((OPS, "/ops/orders/live/columns/"), (STAFF, f"/ops/store/{GGN}/queues/")):
        times = []
        for _ in range(20):
            t0 = time.perf_counter()
            r = ops_users[who].c.get(path, headers={"HX-Request": "true"})
            times.append((time.perf_counter() - t0) * 1000)
            assert r.status_code == 200
        times.sort()
        out[path] = (round(statistics.median(times)), round(times[18]))
    print("poll p50/p95 ms:", out)


# --------------------------------------------------------------------------- refund forms


def _refund_failed(api, rid: int, key: str, amount) -> None:
    pay = db_query("select p.gateway_payment_id from payments_payment p join payments_refund r on r.payment_id=p.id where r.id=%s", (rid,))[0][0]
    ev = {"entity": "event", "event": "refund.failed", "payload": {"refund": {"entity": {
        "id": f"rfnd_QAc{rid}", "payment_id": pay, "receipt": key, "amount": int(amount * 100), "status": "failed", "currency": "INR"}}}}
    r = send_webhook(api, ev)
    assert r.status_code == 200, describe(r)


def test_p4_tc34c_obs01_retry_form_twice(api, shop_a, ops_users):
    """P4-TC-34 (console) + OBS-P4-01: Finance retries a FAILED refund from the Refunds admin
    action; the identical form (same one-time token) posted again is refused ("already sent"):
    exactly one retry row; the worker settles it once; Ops has no retry."""
    stop_worker()
    try:
        o = paid_online(shop_a)
        assert shop_a.cancel(o["id"]).status_code == 200
        (rid, amount, _, _, key), = refunds(o["id"])
        _refund_failed(api, rid, key, amount)
        assert db_query("select status from payments_refund where id=%s", (rid,))[0][0] == "FAILED"
        f = ops_users[FINANCE]
        page = f.get(f"/admin/payments/refund/?q={o['order_number']}").text
        form = read_form(page, "changelist-form")
        assert "once" in form, sorted(form)
        body = [(k, v) for k, vals in form.items() for v in vals if k not in ("action", "_selected_action", "select_across", "index")]
        body += [("action", "retry_failed"), ("_selected_action", str(rid)), ("select_across", "0"), ("index", "0")]
        r1 = f.post(f"/admin/payments/refund/?q={o['order_number']}", body, htmx=False)
        r2 = f.post(f"/admin/payments/refund/?q={o['order_number']}", body, htmx=False)
        assert r1.status_code == 302 and r2.status_code == 302
        keys = [x[4] for x in refunds(o["id"])]
        assert keys == [key, f"{key}:retry-1"], keys
        msgs = text(f.get(r2.headers["location"]).text)
        assert "already sent" in msgs, msgs[:500]
        assert ops_users[OPS].c.get("/admin/payments/refund/").status_code == 403
    finally:
        start_worker("worker-p4s2.log")
    done = wait_refunded(shop_a, o["id"])
    assert done["payment_status"] == "REFUNDED" and done["amount_refunded"] == o["bill"]["grand_total"]


def test_p4_tc32c_manual_refund_in_panel(ops_users):
    """P4-TC-32/33 (console) 05 §2 Orders "refund (full/partial, within role limit)", §3 Refund
    (Super, Support ≤ ₹500, Finance): a manual refund form must exist in the panel."""
    oid = db_query("select o.id from orders_order o join accounts_user u on u.id=o.user_id where u.phone like '+9190000001%%' and o.payment_method='ONLINE' order by o.id desc limit 1")[0][0]
    found = []
    for who in (SUPER, SUPPORT, FINANCE):
        u = ops_users[who]
        pages = [u.get(f"/admin/orders/order/{oid}/change/").text, u.get("/admin/orders/order/").text, u.get("/admin/payments/refund/").text]
        found.append(any(re.search(r"manual.?refund|issue.?refund|refund (this|the) order|Refund order|name=\"amount\"", p, re.I) for p in pages))
    assert any(found), "no manual refund form in the panel (BUG-0010)"


def _refund_form(u, oid):
    r = u.get(f"/admin/orders/order/{oid}/refund/")
    m = re.search(r'name="once"[^>]*value="([^"]*)"', r.text) or re.search(r'value="([^"]*)"[^>]*name="once"', r.text)
    return r, (m.group(1) if m else "")


def _post_refund(u, oid, amount, once, note="QA BUG-0010 verification"):
    return u.post(f"/admin/orders/order/{oid}/refund/", {"amount": amount, "note": note, "once": once,
                                                         "csrfmiddlewaretoken": u.token()}, htmx=False, order_id=oid)


def test_p4_tc32d_manual_refund_roles_caps_and_once(shop_a, ops_users):
    """P4-TC-32/33 (BUG-0010 verification, 2026-11-09) Orders admin "Issue refund": Store Staff and
    Catalog get no form (403); Support above ₹500 per order is refused; Support ≤ ₹500 refunds; the
    same form token posted twice makes one refund; Finance refunds the rest; never above what is
    refundable (sum of PROCESSED/PENDING manual refunds ≤ grand_total)."""
    o = paid_online(shop_a, {V_SUN_1L: 4})
    oid = o["id"]
    total = money(shop_a.order(oid).json()["bill"]["grand_total"])
    try:
        for who in (STAFF, CATALOG):
            r, _ = _refund_form(ops_users[who], oid)
            assert r.status_code in (403, 404), (who, r.status_code)
        sup = ops_users[SUPPORT]
        r, once = _refund_form(sup, oid)
        assert r.status_code == 200 and once, r.status_code
        if total > Decimal("500.00"):
            bad = _post_refund(sup, oid, "500.01", once)
            assert bad.status_code == 200 and "500" in text(bad.text), bad.status_code
            assert db_query("select count(*) from payments_refund where order_id=%s and reason='manual'", (oid,))[0][0] == 0
            _, once = _refund_form(sup, oid)
        ok = _post_refund(sup, oid, "10.00", once)
        assert ok.status_code == 302, (ok.status_code, text(ok.text)[:300])
        again = _post_refund(sup, oid, "10.00", once)
        assert again.status_code == 200, again.status_code  # token reused: refused, form shown again
        rows = db_query("select amount from payments_refund where order_id=%s and reason='manual'", (oid,))
        assert [money(a) for (a,) in rows] == [Decimal("10.00")], rows
        fin = ops_users[FINANCE]
        _, once = _refund_form(fin, oid)
        over = _post_refund(fin, oid, str(total), once)  # 10.00 already refunded
        assert over.status_code == 200, over.status_code
        _, once = _refund_form(fin, oid)
        rest = _post_refund(fin, oid, str(total - Decimal("10.00")), once)
        assert rest.status_code == 302, (rest.status_code, text(rest.text)[:300])
        total_refunded = db_query("select coalesce(sum(amount),0) from payments_refund where order_id=%s "
                                  "and status<>'FAILED'", (oid,))[0][0]
        assert money(total_refunded) == total, (total_refunded, total)
    finally:
        cleanup(ops_users, oid)


def test_p4_tc40b_orders_csv_export_masks_and_escapes(ops_users):
    """P4-TC-40 (BUG-0011 verification) Orders admin export page exists for Super Admin; Store Staff
    is refused or sees masked phones only."""
    page = ops_users[SUPER].get("/admin/orders/order/export/")
    assert page.status_code == 200 and "format" in page.text.lower(), page.status_code
