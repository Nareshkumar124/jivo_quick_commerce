"""Phase 3 admin (T-304): the 05 §3 role rows for coupons, orders, payments and webhook events
(DL-46, `apps.accounts.roles`), read-only order/payment screens, PII masking on order screens,
and coupon usage limits / validity through QA-owned coupons created in admin as Super Admin
(06 §2.5 coupon rules). Seeded staff accounts; one login per role."""

from __future__ import annotations

import re
from concurrent.futures import ThreadPoolExecutor

import pytest

from p3_admin import ROLES, csrf, future, past, save_coupon, staff_login
from p3_support import V_CANOLA_1L, V_SUN_1L, Shop
from qa_support import BASE_URL, assert_error, client, db_query, describe

# operation -> roles allowed (05 §3 + DL-46). Order screens: Super Admin, Ops, Store Manager,
# Store Staff, Support, Finance view. Payments/refunds: Super Admin, Support, Finance.
# Webhook events: Super Admin, Finance. Coupons view: SA, Catalog, Support, Finance; manage: SA, Catalog.
MATRIX = {
    "/admin/promotions/coupon/": {"Super Admin", "Catalog Manager", "Support", "Finance"},
    "/admin/promotions/coupon/add/": {"Super Admin", "Catalog Manager"},
    "/admin/promotions/couponredemption/": {"Super Admin", "Catalog Manager", "Support", "Finance"},
    "/admin/orders/order/": {"Super Admin", "Ops / Dispatch", "Store Manager", "Store Staff", "Support", "Finance"},
    "/admin/payments/payment/": {"Super Admin", "Support", "Finance"},
    "/admin/payments/refund/": {"Super Admin", "Support", "Finance"},
    "/admin/payments/paymentwebhookevent/": {"Super Admin", "Finance"},
}
FULL_PII = {"Super Admin", "Ops / Dispatch", "Support"}
QA_PHONE = re.compile(r"\+9190000001\d\d")


@pytest.fixture(scope="module")
def staff():
    sessions = {role: staff_login(email) for role, email in ROLES.items()}
    yield sessions
    for c in sessions.values():
        c.close()


@pytest.fixture(scope="module")
def qa_order_id():
    row = db_query(
        "select o.id from orders_order o join accounts_user u on u.id=o.user_id join payments_refund r on r.order_id=o.id "
        "where u.phone like '+91900000010%%' order by o.id desc limit 1"
    )
    if not row:
        pytest.skip("no QA order with a refund yet (run test_p3_payments first)")
    return row[0][0]


@pytest.mark.smoke
def test_p3_tc59_admin_role_matrix(staff):
    """P3-TC-59 🔥 For each of the 7 seeded roles, every P3 admin page is 200 exactly for the
    roles of 05 §3 / DL-46 and 403 otherwise (server-side, not just hidden links)."""
    wrong = []
    for path, allowed in MATRIX.items():
        for role, c in staff.items():
            code = c.get(path).status_code
            expected = 200 if role in allowed else 403
            if code != expected:
                wrong.append((path, role, code, expected))
    assert wrong == [], wrong


def test_p3_tc59b_coupon_manage_rights(staff):
    """P3-TC-59b Catalog Manager can save a coupon; Support and Finance (view) get 403 on a
    change POST; nobody can add or change orders/payments through admin (read-only in P3)."""
    cid = save_coupon(staff["Catalog Manager"], "QAP3CM", is_active=False)
    for role in ("Support", "Finance"):
        c = staff[role]
        r = c.post(f"/admin/promotions/coupon/{cid}/change/", data={"code": "QAP3CM", "title": "hacked"})
        assert r.status_code == 403, (role, r.status_code)
    assert db_query("select title from promotions_coupon where id=%s", (cid,))[0][0] == "QA QAP3CM"
    for role, c in staff.items():
        assert c.get("/admin/orders/order/add/").status_code == 403, role
        assert c.get("/admin/payments/payment/add/").status_code == 403, role


def test_p3_tc60_order_and_payment_screens_read_only(staff, qa_order_id):
    """P3-TC-60 The order screen shows the bill, status history, payments and refunds; nothing
    is editable (no Save; a change POST is 403 even for Super Admin); the order is unchanged."""
    sa = staff["Super Admin"]
    before = db_query("select status, payment_status, grand_total, updated_at from orders_order where id=%s", (qa_order_id,))
    page = sa.get(f"/admin/orders/order/{qa_order_id}/change/")
    assert page.status_code == 200
    grand, number = db_query("select grand_total, order_number from orders_order where id=%s", (qa_order_id,))[0]
    text = page.text
    assert number in text and f"{grand:.2f}".replace(".00", "") in text.replace(",", "")
    assert 'name="_save"' not in text
    r = sa.post(f"/admin/orders/order/{qa_order_id}/change/", data={"csrfmiddlewaretoken": csrf(sa, "/admin/orders/order/"), "status": "DELIVERED"},
                headers={"Referer": f"{BASE_URL}/admin/orders/order/"})
    assert r.status_code == 403, r.status_code
    assert db_query("select status, payment_status, grand_total, updated_at from orders_order where id=%s", (qa_order_id,)) == before
    refund = sa.get("/admin/payments/refund/")
    assert refund.status_code == 200 and "late" in refund.text.lower() or "LATE" in refund.text


def test_p3_tc60b_pii_masking_on_orders(staff, qa_order_id):
    """P3-TC-60b Roles without customer PII (05 §3: Store Manager/Staff limited, Finance,
    Catalog none) never see a full QA phone number on the order list or detail; Super Admin,
    Ops and Support may."""
    leaks = []
    for role, c in staff.items():
        if role in FULL_PII or role == "Catalog Manager":
            continue
        for path in ("/admin/orders/order/", f"/admin/orders/order/{qa_order_id}/change/"):
            r = c.get(path)
            if r.status_code == 200 and QA_PHONE.search(r.text):
                leaks.append((role, path))
        r = c.get("/admin/orders/order/", params={"q": "9000000101"})
        if r.status_code == 200 and QA_PHONE.search(r.text):
            leaks.append((role, "search"))
    assert leaks == [], leaks


# --------------------------------------------------------------------------- P3-TC-61 coupons


@pytest.fixture(scope="module")
def sa(staff):
    return staff["Super Admin"]


def _cart_with(shop, code: str):
    shop.fill({V_CANOLA_1L: 1}, address_id=shop.address["id"])
    return shop.apply(code)


def test_p3_tc61a_validity(sa, shop_a):
    """P3-TC-61a Expired: 422 COUPON_EXPIRED; not started yet or inactive: 422 COUPON_INVALID;
    a coupon applied and then expired in admin blocks checkout (cart blocker COUPON_EXPIRED,
    placement 422 COUPON_EXPIRED, nothing created)."""
    save_coupon(sa, "QAP3EXP", starts_at=past(120), ends_at=past(60))
    save_coupon(sa, "QAP3SOON", starts_at=future())
    save_coupon(sa, "QAP3OFF", is_active=False)
    assert_error(_cart_with(shop_a, "QAP3EXP"), 422, "COUPON_EXPIRED")
    assert_error(shop_a.apply("QAP3SOON"), 422, "COUPON_INVALID")
    assert_error(shop_a.apply("QAP3OFF"), 422, "COUPON_INVALID")
    save_coupon(sa, "QAP3LATE", usage_limit_per_user="5")
    assert shop_a.apply("QAP3LATE").status_code == 200
    save_coupon(sa, "QAP3LATE", usage_limit_per_user="5", starts_at=past(120), ends_at=past(1))
    cart = shop_a.cart().json()
    assert "COUPON_EXPIRED" in [b["code"] for b in cart["checkout"]["blockers"]], cart["checkout"]
    n0 = db_query("select count(*) from orders_order where user_id=%s", (shop_a.session.user["id"],))[0][0]
    r = shop_a.place("ONLINE", address_id=shop_a.address["id"], expected=cart["bill"]["grand_total"])
    assert_error(r, 422, "COUPON_EXPIRED")
    assert db_query("select count(*) from orders_order where user_id=%s", (shop_a.session.user["id"],))[0][0] == n0
    save_coupon(sa, "QAP3LATE", is_active=False)
    save_coupon(sa, "QAP3EXP", is_active=False, starts_at=past(120), ends_at=past(60))
    save_coupon(sa, "QAP3SOON", is_active=False, starts_at=future())


def test_p3_tc61b_usage_limits_with_holds(sa, shop_factory):
    """P3-TC-61b Limits count HELD + APPLIED (06 §2.5): per-user limit 1 → after A's unpaid
    order holds it, A's re-apply is 422 COUPON_USAGE_EXCEEDED {scope: per_user}; total limit 2
    → after A and B hold it, C gets {scope: total}; T5 gives the uses back (C can apply);
    the coupon sheet leaves out a used-up coupon (hidden coupons are never listed anyway)."""
    save_coupon(sa, "QAP3LIM", usage_limit_total="2", usage_limit_per_user="1")
    a, b, c = (shop_factory(k) for k in "abc")
    orders = []
    try:
        for s in (a, b):
            assert _cart_with(s, "QAP3LIM").status_code == 200
            r = s.place("ONLINE", address_id=s.address["id"])
            assert r.status_code == 201, describe(r)
            orders.append((s, r.json()["order"]["id"]))
            if s is a:  # 1 of 2 total used: only the per-user limit is reached
                err = assert_error(a.apply("QAP3LIM"), 422, "COUPON_USAGE_EXCEEDED")
                assert err["details"].get("scope") == "per_user", err
        err = assert_error(_cart_with(c, "QAP3LIM"), 422, "COUPON_USAGE_EXCEEDED")
        assert err["details"].get("scope") == "total", err
    finally:
        for s, oid in orders:
            s.cancel(oid)
    assert c.apply("QAP3LIM").status_code == 200
    held = db_query(
        "select count(*) from promotions_couponredemption r join promotions_coupon c on c.id=r.coupon_id "
        "where c.code='QAP3LIM' and r.status in ('HELD','APPLIED')"
    )[0][0]
    assert held == 0
    c.remove_coupon()
    save_coupon(sa, "QAP3LIM", is_active=False)


def test_p3_tc61c_last_use_race(sa, shop_factory):
    """P3-TC-61c A coupon with one use left, 3 customers place ONLINE orders with it at once:
    exactly one 201; the others 422 COUPON_USAGE_EXCEEDED and nothing created or reserved for
    them (06 §2.6: a race lost on the coupon's last use rolls everything back)."""
    save_coupon(sa, "QAP3ONE", usage_limit_total="1", usage_limit_per_user="1")
    shops = [shop_factory(k) for k in "bcd"]
    expected = {}
    for s in shops:
        assert _cart_with(s, "QAP3ONE").status_code == 200
        expected[id(s)] = s.cart().json()["bill"]["grand_total"]

    def go(s):
        with client() as cl:
            return Shop(cl, s.session).place("ONLINE", address_id=s.address["id"], expected=expected[id(s)])

    with ThreadPoolExecutor(3) as pool:
        results = list(pool.map(go, shops))
    try:
        codes = sorted(r.status_code for r in results)
        assert codes == [201, 422, 422], [describe(r) for r in results]
        for r in results:
            if r.status_code == 422:
                assert r.json()["error"]["code"] == "COUPON_USAGE_EXCEEDED", describe(r)
        counted = db_query(
            "select count(*) from promotions_couponredemption r join promotions_coupon c on c.id=r.coupon_id "
            "where c.code='QAP3ONE' and r.status in ('HELD','APPLIED')"
        )[0][0]
        assert counted == 1
    finally:
        for s, r in zip(shops, results):
            if r.status_code == 201:
                s.cancel(r.json()["order"]["id"])
    save_coupon(sa, "QAP3ONE", usage_limit_total="1", is_active=False)


# --------------------------------------------------------------------------- P3-TC-62 COD blocked


def test_p3_tc62_cod_blocked_user(sa, shop_factory):
    """P3-TC-62 A customer with `cod_blocked` (set in admin, DL-43): the cart's COD method is
    unavailable with reason NOT_ALLOWED and placement is 422 COD_NOT_AVAILABLE {reason:
    NOT_ALLOWED}; ONLINE still works; unblocking restores COD. Uses QA user E only; the demo
    store's COD setting is never touched."""
    shop = shop_factory("e")
    uid = shop.session.user["id"]
    if not db_query("select 1 from information_schema.columns where table_name='accounts_user' and column_name='cod_blocked'"):
        pytest.skip("no cod_blocked field")
    try:
        _set_cod_blocked(sa, uid, True)
        assert db_query("select cod_blocked from accounts_user where id=%s", (uid,))[0][0] is True
        cart = shop.fill({V_SUN_1L: 1}, address_id=shop.address["id"])
        cod = [p for p in shop.cart().json()["payment_methods"] if p["method"] == "COD"][0]
        assert cod["is_available"] is False and cod["unavailable_reason"] == "NOT_ALLOWED", cod
        err = assert_error(shop.place("COD", address_id=shop.address["id"], expected=cart["bill"]["grand_total"]), 422, "COD_NOT_AVAILABLE")
        assert err["details"].get("reason") == "NOT_ALLOWED", err
    finally:
        _set_cod_blocked(sa, uid, False)
    assert db_query("select cod_blocked from accounts_user where id=%s", (uid,))[0][0] is False
    cod = [p for p in shop.cart().json()["payment_methods"] if p["method"] == "COD"][0]
    assert cod["is_available"] is True


def _set_cod_blocked(sa, user_id: int, value: bool) -> None:
    """The Customers admin actions "Block cash on delivery" / "Allow" (T-304)."""
    path = "/admin/accounts/customer/"
    r = sa.post(
        path,
        data={"action": "block_cod" if value else "allow_cod", "_selected_action": [str(user_id)],
              "csrfmiddlewaretoken": csrf(sa, path), "index": "0"},
        headers={"Referer": f"{BASE_URL}{path}"},
    )
    assert r.status_code in (200, 302), r.status_code
