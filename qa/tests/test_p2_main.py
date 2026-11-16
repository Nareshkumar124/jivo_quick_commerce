"""Phase 2 cases added on main (2026-11-16): the second store, the T-814 serviceability throttle, the
05 §3 role matrix for the P2 admin modules (T-213) and stock adjustment through the admin on the
QA-only store QA-02 (05 §2 Inventory; 07 §2.4 ledger).

Writes: only stock adjustments on QA-02 through the admin (the inventory service), which net to
zero (+1 inward, then -1 damage). Nothing else is written. Seeded staff accounts, one login per role.
"""

from __future__ import annotations

import re

import httpx
import pytest
from p3_admin import ROLES, staff_login
from qa_support import APP_HEADERS, STORE_POINT, clear_throttle, db_query, describe

QA02_ID = 2
QA02_POINT = (26.9124, 75.7873)  # QA-02 Jaipur (the P5 store); checked against PostGIS below
SMQ = "qa02.manager@jivo.test"
_CSRF = re.compile(r'name="csrfmiddlewaretoken" value="([^"]+)"')

# 05 §3 rows "Stores & service areas", "Catalog, collections, banners", "Inventory view/adjust".
VIEW_STORES = {"Super Admin", "Ops / Dispatch", "Store Manager"}
VIEW_CATALOG = {"Super Admin", "Ops / Dispatch", "Store Manager", "Store Staff", "Catalog Manager", "Support"}
MANAGE_CATALOG = {"Super Admin", "Catalog Manager"}
VIEW_INVENTORY = {"Super Admin", "Ops / Dispatch", "Store Manager", "Store Staff", "Catalog Manager", "Finance"}
MATRIX = {
    "/admin/stores/darkstore/": VIEW_STORES,
    "/admin/stores/darkstore/add/": {"Super Admin"},
    "/admin/catalog/category/": VIEW_CATALOG,
    "/admin/catalog/category/add/": MANAGE_CATALOG,
    "/admin/catalog/product/": VIEW_CATALOG,
    "/admin/catalog/product/add/": MANAGE_CATALOG,
    "/admin/catalog/collection/": VIEW_CATALOG,
    "/admin/catalog/collection/add/": MANAGE_CATALOG,
    "/admin/catalog/banner/": VIEW_CATALOG,
    "/admin/catalog/banner/add/": MANAGE_CATALOG,
    "/admin/inventory/storeinventory/": VIEW_INVENTORY,
    "/admin/inventory/stockmovement/": VIEW_INVENTORY,
}


def _check(api: httpx.Client, lat: float, lng: float) -> httpx.Response:
    return api.get("/api/v1/serviceability/", params={"lat": lat, "lng": lng}, headers=APP_HEADERS)


# =========================================================================== P2-TC-08


def test_p2_tc08_second_store_serviceability(api):
    """P2-TC-08 With two active stores, a point inside QA-02's polygon is served by QA-02 (id 2) and
    GGN-01's point by GGN-01 (id 1): the answer names the store whose polygon contains the point
    (oracle: PostGIS ST_Contains)."""
    for (lat, lng), want in ((QA02_POINT, QA02_ID), (STORE_POINT, 1)):
        rows = db_query("select id from stores_darkstore where is_active and "
                        "ST_Contains(service_area, ST_SetSRID(ST_MakePoint(%s, %s), 4326)) order by id", (lng, lat))
        assert [r[0] for r in rows] == [want], rows
        r = _check(api, lat, lng)
        assert r.status_code == 200, describe(r)
        body = r.json()
        assert body["serviceable"] is True and body["store"]["id"] == want, body


# =========================================================================== P2-TC-52


@pytest.mark.limits
@pytest.mark.keep_throttles
def test_p2_tc52_serviceability_throttle(api):
    """P2-TC-52 06 §2 (T-814): serviceability is limited per IP (`serviceability` scope, 60/min). The
    61st request inside a minute → 429 RATE_LIMITED with details.retry_after_seconds and a
    Retry-After header; nothing else is affected (config/app still 200)."""
    clear_throttle("serviceability")
    codes = [_check(api, *STORE_POINT).status_code for _ in range(60)]
    assert set(codes) == {200}, codes
    r = _check(api, *STORE_POINT)
    assert r.status_code == 429, describe(r)
    err = r.json()["error"]
    assert err["code"] == "RATE_LIMITED" and err["details"]["retry_after_seconds"] > 0, err
    assert int(r.headers["Retry-After"]) > 0
    assert api.get("/api/v1/config/app/", headers=APP_HEADERS).status_code == 200
    clear_throttle("serviceability")


# =========================================================================== P2-TC-53 / 54


@pytest.fixture(scope="module")
def staff():
    sessions = {role: staff_login(email) for role, email in ROLES.items()}
    yield sessions
    for c in sessions.values():
        c.close()


@pytest.mark.smoke
def test_p2_tc53_admin_role_matrix(staff):
    """P2-TC-53 🔥 (T-213) For the 7 seeded roles, every P2 admin list and add page is 200 exactly
    for the roles of 05 §3 and 403 otherwise (server-side). Inventory rows can never be added or
    deleted by anyone (the ledger must sum to on_hand)."""
    wrong = []
    for path, allowed in MATRIX.items():
        for role, c in staff.items():
            code = c.get(path).status_code
            expected = 200 if role in allowed else 403
            if code != expected:
                wrong.append((path, role, code, expected))
    for role, c in staff.items():
        code = c.get("/admin/inventory/storeinventory/add/").status_code
        if code != 403:
            wrong.append(("/admin/inventory/storeinventory/add/", role, code, 403))
    assert wrong == [], wrong


def _qa02_row() -> tuple[int, int, int, int]:
    rows = db_query("select id, variant_id, on_hand, reserved from inventory_storeinventory where store_id=%s "
                    "and on_hand - reserved >= 5 order by id limit 1", (QA02_ID,))
    if not rows:
        pytest.skip("no QA-02 inventory row with 5 available units")
    return rows[0]


def _adjust(c: httpx.Client, inv_id: int, kind: str, qty: int, reason: str) -> httpx.Response:
    path = f"/admin/inventory/storeinventory/{inv_id}/adjust/"
    page = c.get(path)
    if page.status_code != 200:
        return page
    token = _CSRF.search(page.text).group(1)
    return c.post(path, data={"kind": kind, "quantity": str(qty), "reason": reason, "csrfmiddlewaretoken": token},
                  headers={"Referer": f"{c.base_url}{path}"})


def _movements(inv_store: int, variant: int) -> list[tuple]:
    return db_query("select id, type, delta, on_hand_after, reason from inventory_stockmovement where store_id=%s "
                    "and variant_id=%s order by id desc limit 5", (inv_store, variant))


def test_p2_tc54_stock_adjustment_through_admin(staff):
    """P2-TC-54 05 §2/§3 Inventory adjust: QA-02's Store Manager adds 1 (INWARD) and removes 1
    (DAMAGE) with a reason: each writes one StockMovement (delta, on_hand_after, reason) and on_hand
    returns to the start. A damage above the available stock is refused with nothing written.
    GGN-01's manager → 404 on the QA-02 row (store scoping); Ops, Finance, Catalog and Store
    Staff (no adjust right) → 403."""
    inv_id, variant, on_hand0, reserved = _qa02_row()
    sm = staff_login(SMQ)
    try:
        before = _movements(QA02_ID, variant)
        r = _adjust(sm, inv_id, "inward", 1, "QA P2-TC-54 inward")
        assert r.status_code == 302, describe(r)
        r = _adjust(sm, inv_id, "damage", 1, "QA P2-TC-54 damage (undo)")
        assert r.status_code == 302, describe(r)
        after = _movements(QA02_ID, variant)
        new = [m for m in after if m not in before]
        assert [(t, d) for _, t, d, _, _ in sorted(new)] == [("INWARD", 1), ("DAMAGE", -1)], new
        assert all(m[4].startswith("QA P2-TC-54") for m in new), new
        assert sorted(new)[0][3] == on_hand0 + 1 and sorted(new)[1][3] == on_hand0, new
        ((on_hand,),) = db_query("select on_hand from inventory_storeinventory where id=%s", (inv_id,))
        assert on_hand == on_hand0, (on_hand, on_hand0)
        # over-removal: more than the available stock (on_hand - reserved)
        r = _adjust(sm, inv_id, "damage", on_hand0 - reserved + 1, "QA P2-TC-54 too much")
        assert r.status_code == 200, describe(r)  # the form is shown again with the error
        assert _movements(QA02_ID, variant)[0] == after[0], "a refused adjustment wrote a movement"
    finally:
        sm.close()
    codes = {role: _adjust(staff[role], inv_id, "inward", 1, "QA P2-TC-54 must be refused").status_code
             for role in ("Store Manager", "Ops / Dispatch", "Finance", "Catalog Manager", "Store Staff", "Support")}
    assert codes["Store Manager"] == 404, codes  # GGN-01 manager: the QA-02 row is outside their stores
    assert all(codes[r] in (403, 404) for r in codes), codes
    assert db_query("select count(*) from inventory_stockmovement where reason=%s",
                    ("QA P2-TC-54 must be refused",))[0][0] == 0


# =========================================================================== P2-TC-55


def test_p2_tc55_min_qty_and_price_tiers_on_tiles(api):
    """P2-TC-55 06 §2.4 VariantSummary (2026-11-13, ADR 0001): every tile variant carries
    `min_qty_per_order` (= the DB value, >= 1, <= max_qty_per_order) and `price_tiers` (= the DB
    tiers ordered by units, price as a 2-dp string, [] when none); a variant whose available stock
    is below its minimum shows orderable_quantity 0 / OUT_OF_STOCK. Tier pricing in the bill needs
    tier data (none in the shared DB on 2026-11-16): reported as not covered."""
    from qa_support import STORE_HEADERS

    db_min = dict(db_query("select id, min_qty_per_order from catalog_productvariant"))
    tiers: dict[int, list] = {}
    for vid, units, price in db_query("select variant_id, min_order_units, price from catalog_variantpricetier "
                                      "order by variant_id, min_order_units"):
        tiers.setdefault(vid, []).append({"min_order_units": units, "price": f"{price:.2f}"})
    seen, page = 0, 1
    while True:
        r = api.get("/api/v1/products/", params={"page": page, "page_size": 50}, headers=STORE_HEADERS)
        assert r.status_code == 200, describe(r)
        for card in r.json()["results"]:
            for v in card["variants"]:
                seen += 1
                assert v["min_qty_per_order"] == db_min[v["id"]] >= 1, v
                assert v["min_qty_per_order"] <= v["max_qty_per_order"], v
                assert v["price_tiers"] == tiers.get(v["id"], []), (v["id"], v["price_tiers"])
                if v["orderable_quantity"]:
                    assert v["orderable_quantity"] >= v["min_qty_per_order"], v
        if not r.json().get("next"):
            break
        page += 1
    assert seen > 0
    print(f"TC-55: {seen} variants checked; tiers in DB: {sum(map(len, tiers.values()))}; "
          f"variants with min > 1: {sum(1 for m in db_min.values() if m > 1)}")


# =========================================================================== P2-TC-57


LEADS = "/admin/stores/serviceabilityrequest/"
# PM default (2026-11-16) until Jivo decides; 05 §3 has no row for the notify-me leads screen.
LEADS_ROLES = {"Super Admin", "Ops / Dispatch", "Store Manager"}


def test_p2_tc57_leads_screen_roles(staff):
    """P2-TC-57 Notify-me leads (05 §2 "Serviceability requests"): the list opens (200) for the PM
    default roles Super Admin, Ops and Store Manager, and is refused (403) for the others; nobody
    can add a lead through the admin (leads come from the app)."""
    wrong = []
    for role, c in staff.items():
        code = c.get(LEADS).status_code
        expected = 200 if role in LEADS_ROLES else 403
        if code != expected:
            wrong.append((role, code, expected))
        add = c.get(f"{LEADS}add/").status_code
        if add != 403:
            wrong.append((role, "add", add, 403))
    assert wrong == [], wrong
