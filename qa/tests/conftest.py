from __future__ import annotations

import itertools
import os
import random
from dataclasses import dataclass

import httpx
import pytest

from qa_support import (
    APP_HEADERS,
    BASE_URL,
    NONTEST_PREFIX,
    QA_PHONES,
    TEST_OTP,
    bearer,
    clear_rate_limits,
    client,
    describe,
    mask_phone,
    profile,
    redact,
)

TERMS_VERSION = "2026-11-01"


def pytest_report_header(config):
    return f"QA target: {BASE_URL}  profile: {profile()}"


def pytest_collection_modifyitems(config, items):
    """Profile-specific tests run only against an instance started with that profile, and the
    default (local) suites are skipped on the special profiles."""
    current = profile()
    for item in items:
        needed = [m.name.removeprefix("profile_") for m in item.iter_markers() if m.name.startswith("profile_")]
        needed = [n.replace("_", "-") for n in needed]
        if needed and current not in needed:
            item.add_marker(pytest.mark.skip(reason=f"needs instance profile {needed[0]}"))
        elif (
            not needed
            and current != "local"
            and not item.get_closest_marker("any_profile")
            and os.environ.get("QA_FORCE_ALL") != "1"
        ):
            item.add_marker(pytest.mark.skip(reason=f"local-profile test (instance is {current})"))


def pytest_configure(config):
    config.addinivalue_line("markers", "any_profile: runs on every instance profile")


@pytest.fixture(scope="session", autouse=True)
def _instance_up():
    try:
        r = httpx.get(f"{BASE_URL}/health/live", timeout=5)
    except httpx.HTTPError:
        pytest.exit(f"QA instance not reachable at {BASE_URL}: run qa/tools/instance.sh start", 2)
    assert r.status_code == 200


@pytest.fixture(scope="session", autouse=True)
def _fresh_counters():
    """Start every run with no QA rate-limit counters (QA Redis DB only)."""
    if os.environ.get("QA_KEEP_COUNTERS") != "1" and profile() != "redis-down":
        clear_rate_limits()
    yield


_nontest_counter = itertools.count(random.randint(0, 40))


@pytest.fixture
def nontest_phone():
    """A fresh non-test Indian mobile in the QA block +9199999000xx (no SMS is ever sent)."""

    def make() -> str:
        return f"{NONTEST_PREFIX}{next(_nontest_counter) % 100:02d}"

    return make


class _RedactedDict(dict):
    """Headers dict whose repr (shown in pytest failure output) hides the token."""

    def __repr__(self) -> str:
        return redact(dict.__repr__(self))


@dataclass(repr=False)
class Session:
    phone: str
    access: str
    refresh: str
    user: dict
    body: dict

    def __repr__(self) -> str:
        return f"Session(user_id={self.user.get('id')}, phone={mask_phone(self.phone)})"

    @property
    def headers(self) -> dict:
        return _RedactedDict(bearer(self.access))


def request_otp(c: httpx.Client, phone: str, app: str = "customer", purpose: str | None = None):
    body = {"phone": phone, "app": app}
    if purpose:
        body["purpose"] = purpose
    return c.post("/api/v1/auth/otp/request/", json=body)


def verify_otp(c: httpx.Client, phone: str, otp: str = TEST_OTP, app: str = "customer"):
    return c.post(
        "/api/v1/auth/otp/verify/",
        json={"phone": phone, "otp": otp, "app": app, "terms_version": TERMS_VERSION},
    )


def login(phone: str, app: str = "customer") -> Session:
    headers = {**APP_HEADERS, "X-App-Name": app}
    with client(headers) as c:
        r = request_otp(c, phone, app)
        assert r.status_code == 200, describe(r)
        r = verify_otp(c, phone, TEST_OTP, app)
        assert r.status_code == 200, describe(r)
        body = r.json()
    return Session(phone, body["access"], body["refresh"], body["user"], body)


@pytest.fixture
def api():
    with client() as c:
        yield c


@pytest.fixture
def user_a() -> Session:
    return login(QA_PHONES["a"])


@pytest.fixture
def user_b() -> Session:
    return login(QA_PHONES["b"])


ADDRESS = {
    "label": "home",
    "custom_label": "",
    "house": "QA Flat 1",
    "building_street": "QA Tower, Test Street",
    "landmark": "Near QA Park",
    "area": "Sector 1",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.4595,
    "lng": 77.0266,
}


@pytest.fixture
def make_address(api):
    created: list[tuple[int, dict]] = []

    def make(session: Session, **overrides) -> dict:
        r = api.post("/api/v1/addresses/", json={**ADDRESS, **overrides}, headers=session.headers)
        assert r.status_code == 201, describe(r)
        body = r.json()
        created.append((body["id"], session.headers))
        return body

    yield make
    for address_id, headers in created:  # soft-delete what the test created
        api.delete(f"/api/v1/addresses/{address_id}/", headers=headers)
