"""Phase 0 foundation: probes, error envelope, API docs/schema, client info, security headers.

Each test names its case ID from qa/docs/02-test-case-repository.md.
"""

from __future__ import annotations

import json
import re
from datetime import datetime

import httpx
import pytest
import yaml

from qa_support import (
    APP_HEADERS,
    BASE_URL,
    assert_error,
    describe,
    openapi,
    profile,
    schema_path,
    validate_response,
)


@pytest.mark.smoke
@pytest.mark.any_profile
def test_p0_tc01_health_live(api):
    """P0-TC-01 🔥 GET /health/live -> 200 {"status": "ok"}, no auth, never cached."""
    r = httpx.get(f"{BASE_URL}/health/live")
    assert r.status_code == 200, describe(r)
    assert r.json() == {"status": "ok"}
    validate_response(r, "health_live")
    assert "no-cache" in r.headers.get("cache-control", "") or "max-age=0" in r.headers.get(
        "cache-control", ""
    )


@pytest.mark.smoke
def test_p0_tc02_health_ready(api):
    """P0-TC-02 🔥 GET /health/ready -> 200 with database ok and redis ok."""
    r = httpx.get(f"{BASE_URL}/health/ready")
    assert r.status_code == 200, describe(r)
    assert r.json() == {"status": "ok", "checks": {"database": "ok", "redis": "ok"}}
    validate_response(r, "health_ready")


def test_p0_tc03_probes_public_unthrottled_and_strict_paths():
    """P0-TC-03 Probes take no credentials (a garbage bearer is ignored), are not throttled
    (40 rapid calls all 200) and only exist without the trailing slash; wrong methods -> 405."""
    with httpx.Client(base_url=BASE_URL) as c:
        r = c.get("/health/live", headers={"Authorization": "Bearer garbage"})
        assert r.status_code == 200, describe(r)
        statuses = {c.get("/health/live").status_code for _ in range(40)}
        assert statuses == {200}
        r = c.post("/health/live")
        assert_error(r, 405, "METHOD_NOT_ALLOWED")
        r = c.get("/health/live/")
        assert r.status_code == 404, describe(r)


@pytest.mark.smoke
@pytest.mark.profile_staging
def test_p0_tc04_unknown_api_path_json_404_debug_off():
    """P0-TC-04 🔥 (DEBUG off) unmatched /api/... and /health/... URLs return the JSON envelope."""
    with httpx.Client(base_url=BASE_URL) as c:
        for path in ("/api/v1/does-not-exist/", "/api/v1/addresses/abc/", "/api/nothing", "/health/x"):
            r = c.get(path, headers=APP_HEADERS)
            assert_error(r, 404, "NOT_FOUND")
        r = c.get("/not-api/")
        assert r.status_code == 404
        assert "text/html" in r.headers.get("content-type", "")


def test_p0_tc04b_unknown_api_path_local_debug(api):
    """P0-TC-04 (local, DEBUG on) observation: unmatched /api/ URLs get Django's debug 404 page,
    by design only when DEBUG is on (06 §6 says the JSON envelope applies with DEBUG off)."""
    r = api.get("/api/v1/does-not-exist/")
    assert r.status_code == 404


def test_p0_tc05_method_not_allowed(user_a, api):
    """P0-TC-05 405 METHOD_NOT_ALLOWED envelope (PUT /me/, DELETE /config/app/, GET otp/request)."""
    assert_error(api.put("/api/v1/me/", json={}, headers=user_a.headers), 405, "METHOD_NOT_ALLOWED")
    assert_error(api.delete("/api/v1/config/app/"), 405, "METHOD_NOT_ALLOWED")
    assert_error(api.get("/api/v1/auth/otp/request/"), 405, "METHOD_NOT_ALLOWED")


def test_p0_tc06_unsupported_media_type(api):
    """P0-TC-06 415 UNSUPPORTED_MEDIA_TYPE for form-encoded and text bodies (API is JSON only)."""
    r = api.post("/api/v1/auth/otp/request/", data={"phone": "+919000000101", "app": "customer"})
    assert_error(r, 415, "UNSUPPORTED_MEDIA_TYPE")
    r = api.post(
        "/api/v1/auth/otp/request/", content=b"phone=1", headers={"Content-Type": "text/plain"}
    )
    assert_error(r, 415, "UNSUPPORTED_MEDIA_TYPE")


def test_p0_tc07_not_acceptable(api):
    """P0-TC-07 406 NOT_ACCEPTABLE when Accept asks for XML."""
    r = api.get("/api/v1/config/app/", headers={"Accept": "application/xml"})
    assert r.status_code == 406, describe(r)
    assert_error(r, 406, "NOT_ACCEPTABLE")


def test_p0_tc08_malformed_json(api):
    """P0-TC-08 Malformed JSON -> 400 VALIDATION_ERROR (details object, possibly empty, per
    06 §6; the message names the parse error); a bare NaN literal is rejected too."""
    r = api.post(
        "/api/v1/auth/otp/request/",
        content=b'{"phone": "+91900000',
        headers={"Content-Type": "application/json"},
    )
    err = assert_error(r, 400, "VALIDATION_ERROR")
    assert "JSON parse error" in err["message"]
    r = api.post(
        "/api/v1/auth/otp/request/",
        content=b'{"phone": NaN, "app": "customer"}',
        headers={"Content-Type": "application/json"},
    )
    assert_error(r, 400, "VALIDATION_ERROR")


def _oversized_post(api, path="/api/v1/auth/otp/verify/", headers=None):
    big = json.dumps({"phone": "+919999900099", "app": "customer", "pad": "x" * 3_000_000})
    return api.post(
        path,
        content=big.encode(),
        headers={"Content-Type": "application/json", **(headers or {})},
    )


@pytest.mark.xfail(strict=True, reason="BUG-0001: body > DATA_UPLOAD_MAX_MEMORY_SIZE -> 500")
def test_p0_tc08b_oversized_body_is_a_client_error(api):
    """P0-TC-08b A ~3 MB JSON body (over Django's 2.5 MB DATA_UPLOAD_MAX_MEMORY_SIZE) must be
    rejected as a client error (400/413), never a 500 SERVER_ERROR."""
    r = _oversized_post(api)
    assert r.status_code in (400, 413), describe(r)


def test_p0_tc09_server_error_hides_internals(api):
    """P0-TC-09 A 5xx (triggered here by BUG-0001) is the bare SERVER_ERROR envelope: no
    traceback, exception class, settings name or file path in the body."""
    r = _oversized_post(api)
    if r.status_code != 500:
        pytest.skip("no 500 trigger available (BUG-0001 fixed)")
    err = assert_error(r, 500, "SERVER_ERROR")
    assert err["details"] == {}
    for leak in ("Traceback", "RequestDataTooBig", "DATA_UPLOAD", "/tmp/", ".py"):
        assert leak not in r.text


def test_p0_tc10_api_docs_public_in_local(api):
    """P0-TC-10 (local) /api/schema/ and /api/docs/ are public when API_DOCS_PUBLIC (local)."""
    r = api.get("/api/schema/")
    assert r.status_code == 200, describe(r)
    assert r.json()["openapi"].startswith("3.")
    r = api.get("/api/docs/")
    assert r.status_code == 200


@pytest.mark.profile_staging
def test_p0_tc10b_api_docs_staff_only_outside_local():
    """P0-TC-10 (staging, DEBUG off) /api/schema/ and /api/docs/ refuse anonymous callers and
    JWT customers (staff only)."""
    from conftest import login
    from qa_support import QA_PHONES, bearer

    with httpx.Client(base_url=BASE_URL) as c:
        for path in ("/api/schema/", "/api/docs/"):
            r = c.get(path)
            assert r.status_code in (401, 403), describe(r)
        s = login(QA_PHONES["d"])
        r = c.get("/api/schema/", headers=bearer(s.access))
        assert r.status_code == 403, describe(r)


def test_p0_tc11_served_schema_matches_committed(api):
    """P0-TC-11 The served schema equals the committed backend/openapi/schema.yaml (no drift)."""
    served = api.get("/api/schema/").json()
    committed = yaml.safe_load(schema_path().read_text())
    assert served["paths"].keys() == committed["paths"].keys()
    assert served["components"]["schemas"] == committed["components"]["schemas"]
    assert served["paths"] == committed["paths"]


def test_p0_tc13_client_info_headers_tolerant(api):
    """P0-TC-13 Malformed / unknown client-info headers are ignored, never an error."""
    for headers in (
        {"X-App-Name": "hacker", "X-Platform": "windows", "X-App-Version": "abc"},
        {"X-App-Name": "", "X-Platform": "", "X-App-Version": ""},
        {"X-App-Version": "1.2.3.4.5.6"},
        {"X-App-Version": "9" * 500},
        {"X-App-Name": "CUSTOMER", "X-Platform": "ANDROID", "X-App-Version": "1.0.0+5"},
    ):
        r = api.get("/api/v1/config/app/", headers=headers)
        assert r.status_code == 200, describe(r)
        validate_response(r, "config_app")


def test_p0_tc14_security_headers(api):
    """P0-TC-14 API responses carry nosniff, frame denial and a referrer policy."""
    r = api.get("/api/v1/config/app/")
    assert r.headers.get("x-content-type-options") == "nosniff"
    assert r.headers.get("x-frame-options") in ("DENY", "SAMEORIGIN")
    assert r.headers.get("referrer-policy")


def test_p0_tc18_admin_requires_login():
    """P0-TC-18 /admin/ redirects anonymous users to the (unfold) login page."""
    with httpx.Client(base_url=BASE_URL) as c:
        r = c.get("/admin/")
        assert r.status_code == 302 and "/admin/login/" in r.headers["location"]
        r = c.get("/admin/login/")
        assert r.status_code == 200 and "csrfmiddlewaretoken" in r.text


_ISO_UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|\+00:00)$")


def test_p0_tc19_timestamps_utc_iso8601(user_a, api):
    """P0-TC-19 Timestamps are ISO 8601 in UTC (02 §5)."""
    me = api.get("/api/v1/me/", headers=user_a.headers).json()
    assert _ISO_UTC.match(me["created_at"]), me["created_at"]
    datetime.fromisoformat(me["created_at"].replace("Z", "+00:00"))


@pytest.mark.smoke
def test_p0_tc12_every_operation_is_documented():
    """P0-TC-12 Inventory: the committed contract has the 17 Phase 0/1 operations with the
    operationIds from 06 §2.1/§2.2 (exercised individually by the P1 suites)."""
    ids = {op.get("operationId") for ops in openapi()["paths"].values() for op in ops.values()}
    expected = {
        "health_live", "health_ready", "auth_otp_request", "auth_otp_verify",
        "auth_token_refresh", "auth_logout", "me_retrieve", "me_update", "me_delete_account",
        "me_device_register", "config_app", "addresses_list", "addresses_create",
        "addresses_retrieve", "addresses_update", "addresses_delete", "addresses_set_default",
    }  # fmt: skip
    assert expected <= ids, expected - ids


@pytest.mark.smoke
@pytest.mark.any_profile
def test_p0_tc_profile_marker():
    """Sanity: records which instance profile this run used."""
    assert profile() in ("local", "staging", "redis-down", "daylimit")
