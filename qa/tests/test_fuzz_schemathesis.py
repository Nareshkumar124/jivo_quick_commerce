"""Property-based fuzzing of the Phase 0/1 contract with schemathesis (low example counts).

Excluded on purpose:
- auth_otp_request / auth_otp_verify: generated phones would be valid +91 numbers that may belong
  to real people and would land in the shared DB (covered by the hand-written suites instead).
- me_delete_account: could delete the fuzz user; health_ready: covered elsewhere.
Generated receiver phones are replaced with a QA number before sending. The fuzz user is QA
user D; its addresses are soft-deleted and its profile restored afterwards."""

from __future__ import annotations

import httpx
import pytest
import schemathesis
from hypothesis import HealthCheck, settings
from schemathesis.checks import not_a_server_error
from schemathesis.specs.openapi.checks import (
    content_type_conformance,
    response_schema_conformance,
    status_code_conformance,
)

from conftest import login
from qa_support import APP_HEADERS, BASE_URL, QA_PHONES, bearer, schema_path

pytestmark = pytest.mark.fuzz

FUZZED = [
    "health_live",
    "config_app",
    "me_retrieve",
    "me_update",
    "me_device_register",
    "auth_token_refresh",
    "auth_logout",
    "addresses_list",
    "addresses_create",
    "addresses_retrieve",
    "addresses_update",
    "addresses_delete",
    "addresses_set_default",
]

schema = schemathesis.openapi.from_path(str(schema_path())).include(operation_id=FUZZED)

_session = {}


def _token() -> str:
    if "access" not in _session:
        s = login(QA_PHONES["d"])
        _session.update(access=s.access, refresh=s.refresh)
    return _session["access"]


@pytest.fixture(scope="module", autouse=True)
def _cleanup():
    yield
    if "access" not in _session:
        return
    s = login(QA_PHONES["d"])
    with httpx.Client(base_url=BASE_URL, headers={**APP_HEADERS, **bearer(s.access)}) as c:
        while True:
            results = c.get("/api/v1/addresses/?page_size=100").json()["results"]
            if not results:
                break
            for a in results:
                c.delete(f"/api/v1/addresses/{a['id']}/")
        c.patch("/api/v1/me/", json={"name": "QA User D", "email": None, "marketing_opt_in": False})


@schema.parametrize()
@settings(max_examples=12, deadline=None, suppress_health_check=list(HealthCheck), derandomize=True)
def test_p1_tc79_fuzz_contract(case):
    """P1-TC-79 For schema-generated requests: no 5xx, documented status codes, JSON content
    type and responses that match the documented schema."""
    if isinstance(case.body, dict) and "receiver_phone" in case.body:
        case.body["receiver_phone"] = "+919000000199"
    headers = {**APP_HEADERS, **bearer(_token())}
    checks = [not_a_server_error, status_code_conformance, content_type_conformance, response_schema_conformance]
    raw_id = (case.path_parameters or {}).get("id")
    if raw_id is not None and (not isinstance(raw_id, int) or raw_id < 0):
        # A non-integer id does not route; with DEBUG on (local) Django answers its HTML debug 404
        # (JSON envelope with DEBUG off: P0-TC-04). Only "no 5xx" applies here.
        checks = [not_a_server_error]
    if case.operation.label == "GET /api/v1/addresses/" and (case.query or {}).get("page") is not None:
        # Invalid/out-of-range page -> 404 NOT_FOUND by design (pagination), but 404 is not
        # documented for addresses_list: BUG-0004. Keep the other checks.
        checks = [c for c in checks if c is not status_code_conformance]
    case.call_and_validate(base_url=BASE_URL, headers=headers, checks=checks)
