"""Phase 2: catalog for one store (06 §2.4, 03 §2.5-2.7, 07 §2.3/§2.4, 09 §4).

Oracle: read-only SQL on the shared DB, with the contract's formulas re-implemented here
(effective price, discount rounded down, availability / LOW_STOCK <= 3, visibility rules), so the
API is never compared with itself. The QA instance's catalog cache is cleared first (changes made
through :8001 do not invalidate it).

Only one store (GGN-01, id 1) exists in the shared dev DB; cross-store and inactive-store cases
are deferred (see 02-test-case-repository).
"""

from __future__ import annotations

from decimal import ROUND_FLOOR, ROUND_HALF_UP, Decimal

import pytest

from conftest import login
from qa_support import (
    APP_HEADERS,
    QA_PHONES,
    STORE_HEADERS,
    assert_error,
    bearer,
    clear_catalog_cache,
    db_query,
    describe,
    validate_response,
)

LOW_STOCK_UNITS = 3  # DL-26 / D-09 proposed default (CATALOG_LOW_STOCK_UNITS)
CENT = Decimal("0.01")

ENDPOINTS = [
    ("home_retrieve", "/api/v1/home/", {}),
    ("categories_list", "/api/v1/categories/", {}),
    ("products_list", "/api/v1/products/", {}),
    ("products_retrieve", "/api/v1/products/1/", {}),
    ("search_products", "/api/v1/search/", {"q": "oil"}),
    ("search_suggest", "/api/v1/search/suggest/", {"q": "can"}),
    ("collections_retrieve", "/api/v1/collections/bestsellers/", {}),
]


# --------------------------------------------------------------------------- SQL oracle


def _money(value) -> str:
    return str(Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP))


def _effective(mrp: Decimal, selling: Decimal, override) -> Decimal:
    return override if override is not None and Decimal(0) < override <= mrp else selling


def _expected_variant(row) -> dict:
    vid, _pid, name, mrp, selling, max_qty, on_hand, reserved, avail_flag, override, *_ = row
    price = _effective(mrp, selling, override)
    pct = 0 if price >= mrp else int(((mrp - price) * 100 / mrp).to_integral_value(rounding=ROUND_FLOOR))
    available = max(on_hand - reserved, 0) if avail_flag else 0
    if available == 0:
        stock = ("OUT_OF_STOCK", 0, None)
    elif available <= LOW_STOCK_UNITS:
        stock = ("LOW_STOCK", min(available, max_qty), available)
    else:
        stock = ("IN_STOCK", min(available, max_qty), None)
    return {
        "id": vid,
        "name": name,
        "mrp": _money(mrp),
        "selling_price": _money(price),
        "discount_amount": _money(max(mrp - price, Decimal(0))),
        "discount_percent": pct,
        "stock_status": stock[0],
        "orderable_quantity": stock[1],
        "units_left": stock[2],
        "max_qty_per_order": max_qty,
    }


@pytest.fixture(scope="module")
def oracle():
    clear_catalog_cache()
    variants = db_query(
        """
        select v.id, v.product_id, v.name, v.mrp, v.selling_price, v.max_qty_per_order,
               i.on_hand, i.reserved, i.is_available, i.price_override, v.sort_order, i.on_hand
        from catalog_productvariant v
        join inventory_storeinventory i on i.variant_id = v.id and i.store_id = 1
        where v.is_active
        order by v.sort_order, v.id
        """
    )
    visible = db_query(
        """
        select p.id, p.slug, p.category_id, c.parent_id
        from catalog_product p join catalog_category c on c.id = p.category_id
        left join catalog_category pc on pc.id = c.parent_id
        where p.is_active and c.is_active and (c.parent_id is null or pc.is_active)
        """
    )
    sold = {row[1] for row in variants}
    products = {pid: (slug, cat, parent) for pid, slug, cat, parent in visible if pid in sold}
    unsold = db_query(
        "select p.id, p.slug from catalog_product p where not exists (select 1 from "
        "catalog_productvariant v join inventory_storeinventory i on i.variant_id = v.id "
        "and i.store_id = 1 where v.product_id = p.id and v.is_active)"
    )
    on_hands = {row[6] for row in variants}
    return {
        "variants": {row[0]: _expected_variant(row) for row in variants},
        "by_product": {pid: [row[0] for row in variants if row[1] == pid] for pid in products},
        "products": products,
        "unsold": unsold,
        "on_hands": on_hands,
    }


def _all_cards(api, **params) -> list[dict]:
    out, page = [], 1
    while True:
        r = api.get("/api/v1/products/", params={"page_size": 100, "page": page, **params}, headers=STORE_HEADERS)
        assert r.status_code == 200, describe(r)
        validate_response(r, "products_list")
        body = r.json()
        out += body["results"]
        if not body["next"]:
            return out
        page += 1


def _default(card) -> dict:
    return next(v for v in card["variants"] if v["id"] == card["default_variant_id"])


def _walk_numbers(node, path=""):
    if isinstance(node, dict):
        for k, v in node.items():
            yield from _walk_numbers(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _walk_numbers(v, f"{path}[{i}]")
    else:
        yield path, node


# --------------------------------------------------------------------------- X-Store-Id


@pytest.mark.smoke
@pytest.mark.parametrize("op, path, params", ENDPOINTS, ids=[e[0] for e in ENDPOINTS])
def test_p2_tc21_store_header_rules(api, op, path, params):
    """P2-TC-21 🔥 X-Store-Id on all 7 catalog operations: missing/blank -> 400 "This header is
    required."; malformed (letters, 0, -1, 1.0, +1, 1e0, 0x1, full-width/Arabic digits, 19 digits,
    "1,2", two headers) -> 400 "A valid store id is required."; unknown -> 404 STORE_NOT_FOUND
    with details.store_id; "01" -> the store."""
    r = api.get(path, params=params, headers=APP_HEADERS)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert err["details"] == {"X-Store-Id": ["This header is required."]}
    validate_response(r, op)
    for bad in ["abc", "0", "-1", "1.0", "+1", "1e0", "0x1", "１", "١", "9" * 19, "1,2", "1 1"]:
        r = api.get(path, params=params, headers={"X-Store-Id": bad.encode()})
        err = assert_error(r, 400, "VALIDATION_ERROR")
        assert err["details"] == {"X-Store-Id": ["A valid store id is required."]}, bad
    r = api.get(path, params=params, headers=[("X-Store-Id", "1"), ("X-Store-Id", "2")])
    assert_error(r, 400, "VALIDATION_ERROR")
    for unknown in ("9999999", "9" * 18):
        r = api.get(path, params=params, headers={"X-Store-Id": unknown})
        err = assert_error(r, 404, "STORE_NOT_FOUND")
        assert err["details"] == {"store_id": int(unknown)}
        validate_response(r, op)
    r = api.get(path, params=params, headers={"X-Store-Id": "01"})
    assert r.status_code == 200, describe(r)


def test_p2_tc22_inactive_store_not_found():
    """P2-TC-22 Deactivated store -> 404 STORE_NOT_FOUND."""
    pytest.skip("⏭ No inactive store in the shared DB; deactivating GGN-01 would break the PM's phone test.")


# --------------------------------------------------------------------------- home


@pytest.mark.smoke
def test_p2_tc23_home_feed(api, oracle):
    """P2-TC-23 🔥 Home (anonymous): strict schema; store status of store 1; banners active for
    the store with link types and https url; top-level categories only, without children;
    collection rails <= 10 products, out-of-stock (default variant) last, has_more correct;
    buy_again []. Every product on home is sold at the store."""
    r = api.get("/api/v1/home/", headers=STORE_HEADERS)
    assert r.status_code == 200, describe(r)
    validate_response(r, "home_retrieve")
    body = r.json()
    assert body["store"]["id"] == 1
    assert body["buy_again"] == []
    for banner in body["banners"]:
        assert banner["link_type"] in ("category", "collection", "product", "url", "none")
        if banner["link_type"] == "url":
            assert banner["link_value"].startswith("https://"), banner
    top = {row[0] for row in db_query("select id from catalog_category where parent_id is null and is_active")}
    assert {c["id"] for c in body["categories"]} <= top
    assert all("children" not in c for c in body["categories"])
    for rail in body["collections"]:
        assert 1 <= len(rail["products"]) <= 10
        stock = [_default(card)["stock_status"] == "OUT_OF_STOCK" for card in rail["products"]]
        assert stock == sorted(stock), rail["slug"]
        full = api.get(f"/api/v1/collections/{rail['slug']}/", headers=STORE_HEADERS).json()
        assert rail["has_more"] == (len(full["products"]) > 10)
        assert [c["id"] for c in rail["products"]] == [c["id"] for c in full["products"]][:10]
        for card in rail["products"]:
            assert card["id"] in oracle["products"]


def test_p2_tc24_optional_auth(api):
    """P2-TC-24 Home is optionally authenticated: a valid token -> 200 (buy_again [] until orders
    exist); a garbage or tampered token -> 401 TOKEN_INVALID (never silently anonymous). The other
    six catalog operations ignore credentials: 200 with a garbage token."""
    s = login(QA_PHONES["a"])
    r = api.get("/api/v1/home/", headers={**STORE_HEADERS, **s.headers})
    assert r.status_code == 200 and r.json()["buy_again"] == [], describe(r)
    for token in ("garbage", s.access[:-4] + "AAAA"):
        r = api.get("/api/v1/home/", headers={**STORE_HEADERS, **bearer(token)})
        assert_error(r, 401, "TOKEN_INVALID")
    for op, path, params in ENDPOINTS[1:]:
        r = api.get(path, params=params, headers={**STORE_HEADERS, **bearer("garbage")})
        assert r.status_code == 200, f"{op}: {describe(r)}"


# --------------------------------------------------------------------------- categories


@pytest.mark.smoke
def test_p2_tc25_category_tree(api, oracle):
    """P2-TC-25 🔥 Category tree: two levels; a category is listed only if it (or, for a top
    level, a child) has products sold at the store; children belong to their parent; admin order."""
    r = api.get("/api/v1/categories/", headers=STORE_HEADERS)
    assert r.status_code == 200, describe(r)
    validate_response(r, "categories_list")
    used = {cat for _, cat, _ in oracle["products"].values()}
    parents = dict(db_query("select id, parent_id from catalog_category"))
    expected_top = {c if parents[c] is None else parents[c] for c in used}
    tree = r.json()["results"]
    assert {n["id"] for n in tree} == expected_top
    for node in tree:
        assert parents[node["id"]] is None
        for child in node["children"]:
            assert parents[child["id"]] == node["id"] and child["id"] in used
            assert "children" not in child
    expected_children = {c for c in used if parents[c] is not None}
    assert {c["id"] for n in tree for c in n["children"]} == expected_children
    order = dict(db_query("select id, sort_order from catalog_category"))
    assert [order[n["id"]] for n in tree] == sorted(order[n["id"]] for n in tree)


# --------------------------------------------------------------------------- products


@pytest.mark.smoke
def test_p2_tc26_product_list_scope_and_pagination(api, oracle):
    """P2-TC-26 🔥 /products/ lists exactly the visible products sold at the store (no unsold,
    no duplicates); pages of 5 chain through next/previous to the same set; count matches."""
    cards = _all_cards(api)
    ids = [c["id"] for c in cards]
    assert len(ids) == len(set(ids))
    assert set(ids) == set(oracle["products"])
    r = api.get("/api/v1/products/", params={"page_size": 5}, headers=STORE_HEADERS)
    body = r.json()
    assert body["count"] == len(ids) and len(body["results"]) == 5 and body["previous"] is None
    seen = [c["id"] for c in body["results"]]
    while body["next"]:
        body = api.get(body["next"], headers=STORE_HEADERS).json()
        seen += [c["id"] for c in body["results"]]
        assert body["previous"]
    assert seen == ids  # same order with page_size 5 and 100


@pytest.mark.parametrize(
    "params",
    [{"page": 0}, {"page": 999}, {"page": -1}, {"page": "abc"}, {"category": "nope"}, {"category": "999999"},
     {"collection": "nope"}, {"category": "１"}, {"collection": "best%00"}],
)
def test_p2_tc26b_product_list_not_found(api, params):
    """P2-TC-26 Invalid or out-of-range page, unknown category/collection (id, slug, Unicode
    digit, NUL): 404 NOT_FOUND documented in products_list (BUG-0004 lesson), never 500."""
    r = api.get("/api/v1/products/", params=params, headers=STORE_HEADERS)
    assert_error(r, 404, "NOT_FOUND")
    validate_response(r, "products_list")


@pytest.mark.parametrize(
    "params", [{"sort": "cheapest"}, {"sort": "PRICE_ASC"}, {"category": "x" * 121}, {"category": "edible\x00oils"}]
)
def test_p2_tc26c_product_list_bad_query(api, params):
    """P2-TC-26 Invalid sort / over-long filter / NUL in a filter ("Null characters are not
    allowed."): 400 VALIDATION_ERROR naming the field. A blank `sort=` is treated as not sent
    (DRF query-parameter semantics): 200 with the default order."""
    r = api.get("/api/v1/products/", params=params, headers=STORE_HEADERS)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert set(err["details"]) <= {"sort", "category"}, describe(r)
    validate_response(r, "products_list")
    r = api.get("/api/v1/products/", params={"sort": ""}, headers=STORE_HEADERS)
    assert r.status_code == 200, describe(r)


@pytest.mark.smoke
def test_p2_tc27_money_and_discount(api, oracle):
    """P2-TC-27 🔥 Every variant on every tile: mrp/selling_price/discount_amount are 2-decimal
    strings equal to the SQL values (store override rule applied), discount_percent = floor of
    the percent off MRP, unit_price.amount a 2-decimal string; never a float anywhere."""
    seen = 0
    for card in _all_cards(api):
        for v in card["variants"]:
            exp = oracle["variants"][v["id"]]
            got = {k: v[k] for k in exp}
            assert got == exp, (card["slug"], got, exp)
            for key in ("mrp", "selling_price", "discount_amount"):
                assert isinstance(v[key], str) and len(v[key].split(".")[1]) == 2
            if v["unit_price"] is not None:
                assert isinstance(v["unit_price"]["amount"], str)
                assert len(v["unit_price"]["amount"].split(".")[1]) == 2
            seen += 1
    assert seen == len(oracle["variants"])
    for path, value in _walk_numbers(_all_cards(api)):
        assert not isinstance(value, float), path


@pytest.mark.smoke
def test_p2_tc28_stock_never_exact(api, oracle):
    """P2-TC-28 🔥 Stock: stock_status / orderable_quantity / units_left follow the contract (LOW
    when 1..3 available); no on_hand/reserved/available/stock keys anywhere; the exact on_hand of
    an IN_STOCK variant (40 in the seed) never appears as a stock value."""
    cards = _all_cards(api)
    statuses = set()
    for card in cards:
        for v in card["variants"]:
            exp = oracle["variants"][v["id"]]
            statuses.add(v["stock_status"])
            assert (v["stock_status"], v["orderable_quantity"], v["units_left"]) == (
                exp["stock_status"],
                exp["orderable_quantity"],
                exp["units_left"],
            )
            assert v["orderable_quantity"] <= v["max_qty_per_order"]
            if v["stock_status"] == "IN_STOCK":
                assert v["units_left"] is None
    assert statuses == {"IN_STOCK", "LOW_STOCK", "OUT_OF_STOCK"}, "seed should cover all three"
    for path, _value in _walk_numbers(cards):
        key = path.rsplit(".", 1)[-1]
        assert key not in ("on_hand", "reserved", "available", "stock", "quantity"), path
    # IN_STOCK publishes only the per-order cap: never the larger exact stock (40 in the seed)
    big = {row[0]: row[1] for row in db_query(
        "select variant_id, on_hand - reserved from inventory_storeinventory where store_id = 1 and is_available")}
    for card in cards:
        for v in card["variants"]:
            if v["stock_status"] == "IN_STOCK" and big[v["id"]] > v["max_qty_per_order"]:
                assert v["orderable_quantity"] == v["max_qty_per_order"] != big[v["id"]]


def test_p2_tc29_default_variant(api, oracle):
    """P2-TC-29 default_variant_id: the first in-stock variant in display order (kachi ghani
    mustard: the 1 L is out of stock, so the 5 L is the default); in a collection, the collection
    item's variant; always one of the card's variants; variants never empty."""
    for card in _all_cards(api):
        assert card["variants"]
        ids = [v["id"] for v in card["variants"]]
        assert card["default_variant_id"] in ids
        assert ids == oracle["by_product"][card["id"]]  # every store variant, display order
        in_stock = [v["id"] for v in card["variants"] if v["stock_status"] != "OUT_OF_STOCK"]
        assert card["default_variant_id"] == (in_stock[0] if in_stock else ids[0]), card["slug"]
    mustard = api.get("/api/v1/products/jivo-kachi-ghani-mustard-oil/", headers=STORE_HEADERS).json()
    statuses = {v["id"]: v["stock_status"] for v in mustard["variants"]}
    assert statuses[mustard["default_variant_id"]] != "OUT_OF_STOCK"
    items = db_query(
        "select c.slug, v.product_id, ci.variant_id from catalog_collectionitem ci "
        "join catalog_collection c on c.id = ci.collection_id join catalog_productvariant v on v.id = ci.variant_id"
    )
    for slug, product_id, variant_id in items:
        if variant_id not in oracle["variants"]:
            continue
        body = api.get(f"/api/v1/collections/{slug}/", headers=STORE_HEADERS).json()
        card = next((c for c in body["products"] if c["id"] == product_id), None)
        assert card is not None and card["default_variant_id"] == variant_id, (slug, product_id)


@pytest.mark.parametrize("sort", ["price_asc", "price_desc", "discount", "relevance"])
def test_p2_tc26d_sorting(api, sort):
    """P2-TC-26 Sorts by the default variant: in-stock first for every sort, then price
    ascending/descending or discount (percent off MRP) descending."""
    cards = _all_cards(api, sort=sort)
    defaults = [_default(c) for c in cards]
    out = [d["stock_status"] == "OUT_OF_STOCK" for d in defaults]
    assert out == sorted(out)
    live = [d for d in defaults if d["stock_status"] != "OUT_OF_STOCK"]
    if sort == "price_asc":
        prices = [Decimal(d["selling_price"]) for d in live]
        assert prices == sorted(prices)
    elif sort == "price_desc":
        prices = [Decimal(d["selling_price"]) for d in live]
        assert prices == sorted(prices, reverse=True)
    elif sort == "discount":
        pct = [(Decimal(d["mrp"]) - Decimal(d["selling_price"])) / Decimal(d["mrp"]) for d in live]
        assert pct == sorted(pct, reverse=True)


def test_p2_tc26e_category_and_collection_filters(api, oracle):
    """P2-TC-26 ?category= by slug and by id gives the same set; a top-level category includes its
    sub-categories; ?collection= lists the collection's products sold at the store."""
    parents = dict(db_query("select id, parent_id from catalog_category"))
    for cat_id, slug in db_query("select id, slug from catalog_category where is_active"):
        expected = {
            pid for pid, (_, cat, parent) in oracle["products"].items() if cat == cat_id or parent == cat_id
        }
        by_slug = {c["id"] for c in _all_cards(api, category=slug)}
        by_id = {c["id"] for c in _all_cards(api, category=str(cat_id))}
        assert by_slug == by_id == expected, slug
        if parents[cat_id] is None:
            assert expected >= {p for p, (_, cat, _) in oracle["products"].items() if parents[cat] == cat_id}
    for slug, in db_query("select slug from catalog_collection where is_active"):
        listed = [c["id"] for c in _all_cards(api, collection=slug)]
        page = [c["id"] for c in api.get(f"/api/v1/collections/{slug}/", headers=STORE_HEADERS).json()["products"]]
        assert set(listed) == set(page), slug


# --------------------------------------------------------------------------- detail


@pytest.mark.smoke
def test_p2_tc30_product_detail(api, oracle):
    """P2-TC-30 🔥 Detail by id and by slug are identical; strict schema; label fields (09 §4:
    ingredients, nutrition, shelf life, storage, origin, manufacturer, marketer, importer,
    consumer care, FSSAI) present as strings ("" when n/a) or nutrition object/null; variants =
    the store's variants with sku, net_quantity, images; similar products <= 10, same category,
    never itself, all sold at the store."""
    for pid, (slug, cat, _) in oracle["products"].items():
        by_id = api.get(f"/api/v1/products/{pid}/", headers=STORE_HEADERS)
        assert by_id.status_code == 200, describe(by_id)
        validate_response(by_id, "products_retrieve")
        by_slug = api.get(f"/api/v1/products/{slug}/", headers=STORE_HEADERS)
        assert by_slug.json() == by_id.json()
        body = by_id.json()
        for key in ("ingredients", "shelf_life", "storage_instructions", "country_of_origin", "manufacturer",
                    "marketer", "importer", "consumer_care", "fssai_license_no"):
            assert isinstance(body[key], str), key
        assert [v["id"] for v in body["variants"]] == oracle["by_product"][pid]
        for v in body["variants"]:
            exp = oracle["variants"][v["id"]]
            assert {k: v[k] for k in exp} == exp
            assert v["sku"] and v["net_quantity"] and isinstance(v["images"], list)
        sim = body["similar_products"]
        assert len(sim) <= 10 and pid not in [s["id"] for s in sim]
        for s in sim:
            assert s["id"] in oracle["products"] and oracle["products"][s["id"]][1] == cat


def test_p2_tc30b_label_compliance_fields_filled(api, oracle):
    """P2-TC-30 09 §4 Legal Metrology / FSSAI: MRP, net quantity, manufacturer, country of origin,
    consumer care and the FSSAI licence are non-empty for every seeded product (data check)."""
    gaps = []
    for pid, (slug, _, _) in oracle["products"].items():
        body = api.get(f"/api/v1/products/{pid}/", headers=STORE_HEADERS).json()
        for key in ("manufacturer", "country_of_origin", "consumer_care", "fssai_license_no"):
            if not body[key]:
                gaps.append((slug, key))
    assert gaps == [], gaps


@pytest.mark.smoke
def test_p2_tc31_unsold_product_never_shown(api, oracle):
    """P2-TC-31 🔥 A product with no variant sold at the store (pumpkin seeds in the seed): 404 by id
    and by slug; absent from the product list, search, suggest, collections and category counts."""
    assert oracle["unsold"], "seed should contain a product not sold at store 1"
    listed = {c["id"] for c in _all_cards(api)}
    for pid, slug in oracle["unsold"]:
        for key in (pid, slug):
            r = api.get(f"/api/v1/products/{key}/", headers=STORE_HEADERS)
            assert_error(r, 404, "NOT_FOUND")
            validate_response(r, "products_retrieve")
        assert pid not in listed
        word = slug.split("-")[-2] if "-" in slug else slug
        r = api.get("/api/v1/search/", params={"q": word, "page_size": 100}, headers=STORE_HEADERS)
        assert pid not in {c["id"] for c in r.json()["results"]}
        r = api.get("/api/v1/search/suggest/", params={"q": word}, headers=STORE_HEADERS)
        assert pid not in {s["id"] for s in r.json()["suggestions"] if s["type"] == "product"}
        for (cslug,) in db_query("select slug from catalog_collection where is_active"):
            body = api.get(f"/api/v1/collections/{cslug}/", headers=STORE_HEADERS).json()
            assert pid not in {c["id"] for c in body["products"]}


# --------------------------------------------------------------------------- search


@pytest.mark.parametrize(
    "params, field",
    [({}, "q"), ({"q": ""}, "q"), ({"q": "   "}, "q"), ({"q": "x" * 101}, "q"), ({"q": "oil", "sort": "x"}, "sort")],
)
def test_p2_tc32_search_validation(api, params, field):
    """P2-TC-32 q missing/blank/whitespace/101 chars, bad sort: 400 naming the field."""
    r = api.get("/api/v1/search/", params=params, headers=STORE_HEADERS)
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert field in err["details"], describe(r)
    validate_response(r, "search_products")


def test_p2_tc32b_search_results(api, oracle):
    """P2-TC-32 "oil" matches the oil products (name/category); terms are ANDed ("olive oil" is a
    subset of "oil"); case-insensitive; 100 chars accepted; no results = 200 count 0; LIKE
    wildcards are literal (q=% and q=_ do not match everything); only store products."""
    names = dict(db_query("select id, lower(name) from catalog_product"))
    oil = {c["id"] for c in api.get("/api/v1/search/", params={"q": "oil", "page_size": 100}, headers=STORE_HEADERS).json()["results"]}
    assert oil and oil <= set(oracle["products"])
    assert {pid for pid in oracle["products"] if "oil" in names[pid]} <= oil
    olive = {c["id"] for c in api.get("/api/v1/search/", params={"q": "OLIVE   oil", "page_size": 100}, headers=STORE_HEADERS).json()["results"]}
    assert olive and olive <= oil and all("olive" in names[p] for p in olive)
    for q in ("%", "_", "zzzz-no-such-product", "x" * 100, "oil\x00"):
        r = api.get("/api/v1/search/", params={"q": q}, headers=STORE_HEADERS)
        assert r.status_code in (200, 400), describe(r)
        if r.status_code == 200 and q in ("%", "_", "zzzz-no-such-product", "x" * 100):
            assert r.json()["count"] == 0, (q, r.json()["count"])
        validate_response(r, "search_products")


def test_p2_tc33_suggest(api, oracle):
    """P2-TC-33 Suggest: blank/missing q -> the active trending searches in admin order as keyword
    items; "can" -> product and category items <= 10 with slugs that open (200); q > 100 -> 400."""
    trending = [t for t, in db_query("select term from catalog_trendingsearch where is_active order by sort_order, term")]
    for params in ({}, {"q": ""}, {"q": "   "}):
        r = api.get("/api/v1/search/suggest/", params=params, headers=STORE_HEADERS)
        assert r.status_code == 200, describe(r)
        validate_response(r, "search_suggest")
        items = r.json()["suggestions"]
        assert [i["text"] for i in items] == trending[:10]
        assert all(i["type"] == "keyword" and i["id"] is None for i in items)
    r = api.get("/api/v1/search/suggest/", params={"q": "can"}, headers=STORE_HEADERS)
    validate_response(r, "search_suggest")
    items = r.json()["suggestions"]
    assert 0 < len(items) <= 10 and {"product", "category"} <= {i["type"] for i in items}
    for item in items:
        if item["type"] == "product":
            assert item["id"] in oracle["products"]
            assert api.get(f"/api/v1/products/{item['slug']}/", headers=STORE_HEADERS).status_code == 200
        if item["type"] == "category":
            assert api.get("/api/v1/products/", params={"category": item["slug"]}, headers=STORE_HEADERS).status_code == 200
    r = api.get("/api/v1/search/suggest/", params={"q": "x" * 101}, headers=STORE_HEADERS)
    assert_error(r, 400, "VALIDATION_ERROR")


# --------------------------------------------------------------------------- collections


def test_p2_tc34_collection_page(api, oracle):
    """P2-TC-34 Collection page: strict schema; products in item order with out-of-stock last;
    <= 100; unknown or wrong-case slug -> 404 NOT_FOUND; an id is not a slug (404)."""
    items = db_query(
        "select c.slug, v.product_id from catalog_collectionitem ci join catalog_collection c on c.id = ci.collection_id "
        "join catalog_productvariant v on v.id = ci.variant_id where c.is_active order by c.slug, ci.sort_order, ci.id"
    )
    by_slug: dict[str, list] = {}
    for slug, pid in items:
        if pid in oracle["products"] and pid not in by_slug.setdefault(slug, []):
            by_slug[slug].append(pid)
    for slug, expected in by_slug.items():
        r = api.get(f"/api/v1/collections/{slug}/", headers=STORE_HEADERS)
        assert r.status_code == 200, describe(r)
        validate_response(r, "collections_retrieve")
        cards = r.json()["products"]
        assert len(cards) <= 100
        got = [c["id"] for c in cards]
        oos = [c["id"] for c in cards if _default(c)["stock_status"] == "OUT_OF_STOCK"]
        assert got == [p for p in expected if p not in oos] + [p for p in expected if p in oos]
    for bad in ("nope", "BESTSELLERS", "1"):
        r = api.get(f"/api/v1/collections/{bad}/", headers=STORE_HEADERS)
        assert_error(r, 404, "NOT_FOUND")
        validate_response(r, "collections_retrieve")
