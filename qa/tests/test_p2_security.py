"""Phase 2 security: cache poisoning, Host-header handling in cached pagination links, image URLs,
PII in catalog/serviceability bodies, Unicode/NUL input on ids, slugs and query parameters, and
the P2 contract inventory (06 §2.3/§2.4, 09 §3.2/§3.3/§3.6, 07 §2.3).

Tests marked `any_profile` also run on the staging profile (DEBUG off), where unroutable paths
must answer the JSON envelope instead of Django's HTML debug 404.
"""

from __future__ import annotations

import re
import struct
from urllib.parse import parse_qsl, urlsplit

import httpx
import pytest

from qa_support import (
    APP_HEADERS,
    BASE_URL,
    STORE_HEADERS,
    STORE_POINT,
    assert_error,
    clear_catalog_cache,
    describe,
    openapi,
    profile,
    redis_keys,
    validate_response,
)

P2_OPERATIONS = {
    "serviceability_check",
    "serviceability_notify_me",
    "home_retrieve",
    "categories_list",
    "products_list",
    "products_retrieve",
    "search_products",
    "search_suggest",
    "collections_retrieve",
}


@pytest.mark.any_profile
def test_p2_tc41_contract_inventory(api):
    """P2-TC-41 The 9 P2 operationIds exist; ErrorCodeEnum has STORE_NOT_FOUND and (BUG-0001)
    PAYLOAD_TOO_LARGE; the catalog operations document X-Store-Id as a required header and the
    400/404 errors; the served schema equals the committed one (local profile)."""
    ops = {op.get("operationId"): op for ops in openapi()["paths"].values() for op in ops.values() if isinstance(op, dict)}
    assert P2_OPERATIONS <= set(ops)
    enum = openapi()["components"]["schemas"]["ErrorCodeEnum"]["enum"]
    assert {"STORE_NOT_FOUND", "PAYLOAD_TOO_LARGE"} <= set(enum)
    for op_id in P2_OPERATIONS - {"serviceability_check", "serviceability_notify_me"}:
        params = {p["name"]: p for p in ops[op_id].get("parameters", [])}
        assert params["X-Store-Id"]["in"] == "header" and params["X-Store-Id"]["required"] is True
        assert {"400", "404"} <= set(ops[op_id]["responses"]), op_id
    if profile() == "local":
        served = api.get("/api/schema/").json()
        assert served["paths"].keys() == openapi()["paths"].keys()
        assert served["components"]["schemas"].keys() == openapi()["components"]["schemas"].keys()


# --------------------------------------------------------------------------- cache poisoning


def _links(body: dict) -> list[str]:
    return [link for link in (body.get("next"), body.get("previous")) if link]


@pytest.mark.parametrize(
    "path, params",
    [
        ("/api/v1/products/", {"page": 2, "page_size": 5}),
        ("/api/v1/search/", {"q": "oil", "page": 2, "page_size": 3}),
    ],
)
def test_p2_tc37_pagination_links_canonical(api, path, params):
    """P2-TC-37 Junk and reordered query parameters, a junk utm/callback value and an injected
    X-Forwarded-Host never reach the cached body: next/previous are built only from validated
    parameters, the same for every caller, and point at the requested host."""
    clear_catalog_cache()
    junk = {"utm": "<script>alert(1)</script>", "callback": "evil", "zz": "1", **params}
    poisoned = api.get(path, params=junk, headers={**STORE_HEADERS, "X-Forwarded-Host": "evil.example"})
    assert poisoned.status_code == 200, describe(poisoned)
    clean = api.get(path, params=dict(reversed(list(params.items()))), headers=STORE_HEADERS)
    assert clean.json() == poisoned.json()
    for link in _links(clean.json()):
        parts = urlsplit(link)
        assert parts.netloc == urlsplit(BASE_URL).netloc, link
        keys = {k for k, _ in parse_qsl(parts.query)}
        assert keys <= {"q", "sort", "category", "collection", "page", "page_size"}, link
        assert "evil" not in link and "script" not in link


def test_p2_tc37b_host_header_variants(api):
    """P2-TC-37 Host header: bodies cached for one host are not served with another host's links
    (the cache key includes the host); an unlisted Host is refused (400, ALLOWED_HOSTS)."""
    clear_catalog_cache()
    params = {"page": 2, "page_size": 5}
    a = api.get("/api/v1/products/", params=params, headers=STORE_HEADERS)
    b = api.get("/api/v1/products/", params=params, headers={**STORE_HEADERS, "Host": "localhost:8004"})
    assert a.status_code == b.status_code == 200
    assert all(urlsplit(link).netloc == "127.0.0.1:8004" for link in _links(a.json()))
    assert all(urlsplit(link).netloc == "localhost:8004" for link in _links(b.json()))
    r = api.get("/api/v1/products/", params=params, headers={**STORE_HEADERS, "Host": "evil.example"})
    assert r.status_code == 400, describe(r)
    if profile() != "local":  # DEBUG on (local) shows Django's DisallowedHost debug page
        assert "evil.example" not in r.text


def test_p2_tc37c_cache_key_amplification(api):
    """P2-TC-37 (observation OBS-11) Product detail is cached under the raw path segment: "1",
    "01", "001" ... and padded slugs each build and store a separate copy of the same body.
    Recorded as a hardening observation (cache-busting / Redis growth), not as poisoning: every
    copy is the correct body. List and search keys are canonical (TC-37)."""
    clear_catalog_cache()
    variants = ["1", "01", "001", "0001", "00001"]
    for v in variants:
        assert api.get(f"/api/v1/products/{v}/", headers=STORE_HEADERS).status_code == 200
    keys = redis_keys("jqc:1:catalog:product:1:*")
    print(f"detail cache entries for one product after {len(variants)} spellings: {len(keys)}")
    assert len(keys) >= 1


# --------------------------------------------------------------------------- input handling


@pytest.mark.any_profile
@pytest.mark.parametrize(
    "path",
    [
        "/api/v1/products/%EF%BC%91/",  # full-width 1
        "/api/v1/products/%D9%A3/",  # Arabic-Indic 3
        "/api/v1/products/%C2%B2/",  # superscript 2
        "/api/v1/products/1%00/",
        "/api/v1/products/%00/",
        "/api/v1/products/99999999999999999999999/",
        "/api/v1/products/%E2%80%8B1/",  # zero-width space
        "/api/v1/collections/%EF%BC%91/",
        "/api/v1/collections/best%00/",
        "/api/v1/collections/%F0%9F%98%80/",
    ],
)
def test_p2_tc39_unicode_and_nul_in_paths(path):
    """P2-TC-39 Unicode digits, NUL, zero-width and overflow in product ids/slugs and collection
    slugs: 404, never 500. With DEBUG off (staging profile) the body is the JSON envelope."""
    with httpx.Client(base_url=BASE_URL, headers=STORE_HEADERS, timeout=30) as c:
        r = c.get(path)
    assert r.status_code == 404, describe(r)
    if profile() == "staging" or r.headers.get("content-type", "").startswith("application/json"):
        assert_error(r, 404, "NOT_FOUND")


@pytest.mark.any_profile
@pytest.mark.parametrize(
    "path, params",
    [
        ("/api/v1/products/", {"category": "edible\x00oils"}),
        ("/api/v1/products/", {"collection": "\x00"}),
        ("/api/v1/products/", {"category": "２"}),
        ("/api/v1/products/", {"page": "２"}),
        ("/api/v1/products/", {"page_size": "２"}),
        ("/api/v1/search/", {"q": "oil\x00"}),
        ("/api/v1/search/", {"q": "\x00"}),
        ("/api/v1/search/suggest/", {"q": "can\x00"}),
        ("/api/v1/search/", {"q": "oil", "page": "1\x00"}),
        ("/api/v1/search/", {"q": "' or 1=1 --"}),
        ("/api/v1/search/", {"q": "%' union select 1 --"}),
    ],
)
def test_p2_tc39b_nul_unicode_injection_in_query(path, params):
    """P2-TC-39 NUL bytes, non-ASCII digits and SQL-looking text in query parameters: a 200/400/404
    envelope, never 500 (psycopg refuses NUL; it must not reach the database)."""
    with httpx.Client(base_url=BASE_URL, headers=STORE_HEADERS, timeout=30) as c:
        r = c.get(path, params=params)
    assert r.status_code in (200, 400, 404), describe(r)
    assert r.headers["content-type"].startswith("application/json"), describe(r)


# --------------------------------------------------------------------------- images


def _webp_size(data: bytes) -> tuple[int, int]:
    assert data[:4] == b"RIFF" and data[8:12] == b"WEBP", data[:16]
    chunk = data[12:16]
    if chunk == b"VP8 ":
        w, h = struct.unpack("<HH", data[26:30])
        return w & 0x3FFF, h & 0x3FFF
    if chunk == b"VP8L":
        b = data[21:25]
        bits = int.from_bytes(b, "little")
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if chunk == b"VP8X":
        w = int.from_bytes(data[24:27], "little") + 1
        h = int.from_bytes(data[27:30], "little") + 1
        return w, h
    raise AssertionError(f"unknown WebP chunk {chunk!r}")


def _image_sets(node):
    if isinstance(node, dict):
        if {"thumbnail", "medium", "large"} <= set(node):
            yield node
        for v in node.values():
            yield from _image_sets(v)
    elif isinstance(node, list):
        for v in node:
            yield from _image_sets(v)


def test_p2_tc38_image_urls(api):
    """P2-TC-38 ImageSet URLs (09 §3.6, 07 §2.3): absolute; on the public media bucket; random
    32-hex keys with -256/-512/-1024 renditions; no signature, credential or private-bucket
    parameters. Fetching a sample: 200 image/webp, RIFF/WEBP, width 256/512/1024 (product images
    padded square), no EXIF chunk."""
    home = api.get("/api/v1/home/", headers=STORE_HEADERS).json()
    detail = api.get("/api/v1/products/1/", headers=STORE_HEADERS).json()
    sets = list(_image_sets(home)) + list(_image_sets(detail))
    assert sets
    key_re = re.compile(r"/catalog/(products|categories|banners)/[0-9a-f]{32}-(256|512|1024)\.webp$")
    for s in sets:
        for size, name in ((256, "thumbnail"), (512, "medium"), (1024, "large")):
            url = s[name]
            parts = urlsplit(url)
            assert parts.scheme in ("http", "https") and parts.netloc, url
            assert not parts.query, url  # no X-Amz-Signature / credentials
            assert "private" not in url and "kyc" not in url.lower()
            assert key_re.search(parts.path) and parts.path.endswith(f"-{size}.webp"), url
    if profile() != "local":
        return  # deployed-style settings without S3_* point at the real bucket: shape checks only
    sample = [(sets[0], "banner"), (next(_image_sets(detail["variants"])), "product")]
    with httpx.Client(timeout=30) as c:
        for s, kind in sample:
            for size, name in ((256, "thumbnail"), (512, "medium"), (1024, "large")):
                r = c.get(s[name])
                assert r.status_code == 200, (s[name], r.status_code)
                assert r.headers["content-type"] == "image/webp"
                w, h = _webp_size(r.content)
                assert w == size, (s[name], w, h)
                if kind == "product":
                    assert w == h, (s[name], w, h)
                assert b"EXIF" not in r.content[:4096] and b"Exif\x00\x00" not in r.content


# --------------------------------------------------------------------------- PII


def test_p2_tc40_no_pii_in_public_bodies(api):
    """P2-TC-40 Serviceability and every catalog body carry no phone numbers, emails, user ids or
    staff fields; the store block is {id, name, is_open, opens_at} only (no phone, GSTIN, address)."""
    bodies = [
        api.get("/api/v1/serviceability/", params=dict(zip(("lat", "lng"), STORE_POINT))).text,
        api.get("/api/v1/home/", headers=STORE_HEADERS).text,
        api.get("/api/v1/categories/", headers=STORE_HEADERS).text,
        api.get("/api/v1/products/", params={"page_size": 100}, headers=STORE_HEADERS).text,
        api.get("/api/v1/products/1/", headers=STORE_HEADERS).text,
        api.get("/api/v1/search/", params={"q": "oil"}, headers=STORE_HEADERS).text,
        api.get("/api/v1/search/suggest/", headers=STORE_HEADERS).text,
        api.get("/api/v1/collections/bestsellers/", headers=STORE_HEADERS).text,
    ]
    for text in bodies:
        # consumer_care is the brand's public contact, required on the label (09 §4): not PII
        text = re.sub(r'"consumer_care":"[^"]*"', '"consumer_care":""', text)
        assert not re.search(r"\+91[0-9]{10}", text)
        assert not re.search(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}", text)
        for key in ('"phone"', '"email"', '"gstin"', '"user', '"created_by"', '"rack_location"', '"price_override"', '"sap_item_code"', '"barcode"'):
            assert key not in text, key


def test_p2_tc07b_catalog_methods(api):
    """P2-TC-07 Catalog endpoints are read-only: POST/PUT/PATCH/DELETE -> 405 METHOD_NOT_ALLOWED."""
    for path in ("/api/v1/home/", "/api/v1/products/", "/api/v1/products/1/", "/api/v1/collections/bestsellers/"):
        for method in ("POST", "PUT", "PATCH", "DELETE"):
            r = api.request(method, path, headers=STORE_HEADERS, json={})
            assert_error(r, 405, "METHOD_NOT_ALLOWED")


def test_p2_tc41b_validate_every_p2_response_shape(api):
    """P2-TC-41 Strict response-schema validation (no undocumented fields) for one 200 of each
    catalog operation and serviceability (others are validated inside the functional tests)."""
    calls = [
        ("serviceability_check", "/api/v1/serviceability/", {"lat": STORE_POINT[0], "lng": STORE_POINT[1]}, APP_HEADERS),
        ("home_retrieve", "/api/v1/home/", {}, STORE_HEADERS),
        ("categories_list", "/api/v1/categories/", {}, STORE_HEADERS),
        ("products_list", "/api/v1/products/", {"sort": "discount"}, STORE_HEADERS),
        ("products_retrieve", "/api/v1/products/jivo-kachi-ghani-mustard-oil/", {}, STORE_HEADERS),
        ("search_products", "/api/v1/search/", {"q": "juice"}, STORE_HEADERS),
        ("search_suggest", "/api/v1/search/suggest/", {"q": "wheat"}, STORE_HEADERS),
        ("collections_retrieve", "/api/v1/collections/offers/", {}, STORE_HEADERS),
    ]
    for op, path, params, headers in calls:
        r = api.get(path, params=params, headers=headers)
        assert r.status_code == 200, describe(r)
        validate_response(r, op)


STAFF_P2_PATHS = [
    "/ops/",
    "/ops/dashboard/customer-kpis/",
    "/ops/dashboard/signups/",
    "/ops/dashboard/operations/",
    "/admin/stores/darkstore/",
    "/admin/stores/darkstore/1/change/",
    "/admin/stores/serviceabilityrequest/",
    "/admin/catalog/product/",
    "/admin/catalog/productvariant/",
    "/admin/catalog/category/",
    "/admin/catalog/collection/",
    "/admin/catalog/banner/",
    "/admin/catalog/trendingsearch/",
    "/admin/inventory/storeinventory/",
    "/admin/inventory/stockmovement/",
]


@pytest.mark.smoke
def test_p2_tc44_staff_paths_refuse_anonymous_and_customer_jwt(api, user_a):
    """P2-TC-44 🔥 Unauthorised access to the P2 staff surfaces (05 §2): every Ops Console page and
    every P2 admin changelist/change page redirects an anonymous caller to a login page and does
    not accept a customer JWT (staff use Django sessions only); no data in the body. The per-role
    matrix (store scoping through stores_for) is T-213, deferred to the admin QA run."""
    for path in STAFF_P2_PATHS:
        for headers in ({}, user_a.headers):
            r = api.get(path, headers=headers)
            assert r.status_code == 302, f"{path}: {describe(r)}"
            assert "login" in r.headers["location"], (path, r.headers["location"])
            assert "Jivo Sector" not in r.text and "JV-" not in r.text
        r = api.post(path, data={"is_accepting_orders": "off"})
        assert r.status_code in (302, 403, 405), f"POST {path}: {describe(r)}"
