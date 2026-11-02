"""Phase 1 app configuration and the 426/503 guard (06 §2.1, 03 §2.1, 04 §2.1).

AppConfig / AppVersionPolicy live in the shared DB and are NOT changed by QA (they drive the
user's phone testing on 8001). Today min_supported_version is 0.0.0 and maintenance is off, so
only the negative guard cases can run; the positive 426/503 cases are deferred (⏭)."""

from __future__ import annotations

import pytest

from conftest import login
from qa_support import QA_PHONES, assert_error, client, describe, validate_response


@pytest.mark.smoke
@pytest.mark.parametrize(
    "app,platform,store",
    [("customer", "android", "in.jivo.quick"), ("rider", "android", "in.jivo.rider")],
)
def test_p1_tc58_config_with_headers(app, platform, store):
    """P1-TC-58 🔥 GET /config/app/ with X-App-Name/X-Platform returns that app's version policy
    and store URL plus maintenance, support, policy URLs, terms_version, otp, rider_location and
    feature_flags (exact schema)."""
    with client({"X-App-Name": app, "X-Platform": platform}) as c:
        r = c.get("/api/v1/config/app/")
    assert r.status_code == 200, describe(r)
    validate_response(r, "config_app")
    cfg = r.json()
    assert cfg["min_supported_version"] and cfg["latest_version"]
    assert store in (cfg["store_url"] or "")
    assert cfg["otp"] == {"length": 6, "resend_after_seconds": 30}
    assert isinstance(cfg["maintenance"], bool) and isinstance(cfg["feature_flags"], dict)
    assert cfg["terms_version"]


def test_p1_tc58b_config_without_headers():
    """P1-TC-58 Without client headers the version fields are null (06 §2.1)."""
    with client({"X-App-Name": "", "X-Platform": "", "X-App-Version": ""}) as c:
        r = c.get("/api/v1/config/app/")
    assert r.status_code == 200
    validate_response(r, "config_app")
    cfg = r.json()
    assert cfg["min_supported_version"] is None and cfg["latest_version"] is None
    assert cfg["store_url"] is None


def test_p1_tc58c_config_ios_customer():
    """P1-TC-58 customer/ios: whatever policy exists is returned in the documented shape."""
    with client({"X-Platform": "ios"}) as c:
        r = c.get("/api/v1/config/app/")
    assert r.status_code == 200
    validate_response(r, "config_app")


def test_p1_tc59_config_public_and_never_guarded():
    """P1-TC-59 config/app is public, ignores a garbage Bearer token and answers 200 even for an
    ancient X-App-Version (it is exempt from 426); other methods -> 405."""
    with client({"X-App-Version": "0.0.0+1", "Authorization": "Bearer x.y.z"}) as c:
        r = c.get("/api/v1/config/app/")
        assert r.status_code == 200, describe(r)
        assert_error(c.post("/api/v1/config/app/", json={}), 405, "METHOD_NOT_ALLOWED")


@pytest.mark.smoke
def test_p1_tc60_no_426_without_full_client_info(user_a):
    """P1-TC-60 🔥 No 426 when any of X-App-Name / X-Platform / X-App-Version is missing or
    malformed, nor when the version equals the minimum (0.0.0 today)."""
    variants = [
        {"X-App-Name": "", "X-Platform": "", "X-App-Version": ""},
        {"X-App-Version": "0.0.0"},
        {"X-App-Name": "", "X-App-Version": "0.0.0"},
        {"X-Platform": "", "X-App-Version": "0.0.0"},
        {"X-App-Version": "abc"},
        {"X-App-Version": "0"},
        {"X-App-Name": "rider", "X-App-Version": "0.0.0+0"},
        {"X-Platform": "ios", "X-App-Version": "0.0.0"},
    ]
    for headers in variants:
        with client(headers) as c:
            r = c.get("/api/v1/me/", headers=user_a.headers)
            assert r.status_code == 200, f"{headers}: {describe(r)}"
            r = c.post("/api/v1/auth/otp/request/", json={"phone": QA_PHONES["d"], "app": "customer"})
            assert r.status_code == 200, f"{headers}: {describe(r)}"


def test_p1_tc61_force_update_426():
    """P1-TC-61 426 APP_UPDATE_REQUIRED below min_supported_version."""
    pytest.skip(
        "⏭ min_supported_version is 0.0.0 for every app/platform and QA may not change AppConfig "
        "(shared DB, user's phone testing). Needs a QA-owned DB or staging."
    )


def test_p1_tc62_maintenance_503_and_refresh_exempt():
    """P1-TC-62 503 MAINTENANCE on app endpoints; token/refresh and config/app exempt."""
    pytest.skip("⏭ maintenance is off and QA may not toggle it on the shared DB.")


def test_p1_tc60b_guard_does_not_block_refresh(user_a):
    """P1-TC-60 token/refresh with an old version and full headers still works (exempt path)."""
    with client({"X-App-Version": "0.0.0"}) as c:
        r = c.post("/api/v1/auth/token/refresh/", json={"refresh": user_a.refresh})
        assert r.status_code == 200, describe(r)


_ = login
