"""09 §2 graceful degradation: Redis down must not take the app API down.

- The force-update/maintenance guard and `config/app` read the config from the database.
- OTP rate limiting is fail-closed: real numbers get 503 SERVICE_UNAVAILABLE (no SMS without
  counters). Fixed-OTP test numbers skip the counters and keep working.
"""

import pytest
from django.urls import reverse

from apps.accounts.tests.factories import SuperUserFactory
from apps.cms.models import AppConfig, AppVersionPolicy

pytestmark = pytest.mark.django_db

UNREACHABLE = "redis://localhost:1/0"  # nothing listens on port 1


@pytest.fixture
def cache_down(settings):
    settings.CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.redis.RedisCache",
            "LOCATION": UNREACHABLE,
            "OPTIONS": {"socket_connect_timeout": 0.2, "socket_timeout": 0.2},
        }
    }


@pytest.fixture
def limiter_down(settings):
    settings.REDIS_URL = UNREACHABLE


def test_config_and_guard_fall_back_to_the_database(api_client, cache_down, caplog):
    config = AppConfig.load()
    config.maintenance = True  # invalidation fails quietly while Redis is down
    config.maintenance_message = "Back at 6 AM"
    config.save()

    body = api_client.get("/api/v1/config/app/").json()
    assert (body["maintenance"], body["maintenance_message"]) == (True, "Back at 6 AM")
    response = api_client.get("/api/v1/me/")
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "MAINTENANCE"
    assert "App config cache unavailable" in caplog.text


def test_force_update_still_enforced_without_cache(api_client, cache_down):
    AppVersionPolicy.objects.create(
        config=AppConfig.load(),
        app="customer",
        platform="android",
        min_supported_version="2.0.0",
        latest_version="2.0.0",
        store_url="https://play.google.com/store/apps/details?id=in.jivo.quick",
    )
    headers = {"X-App-Name": "customer", "X-Platform": "android", "X-App-Version": "1.9.0"}
    assert api_client.get("/api/v1/me/", headers=headers).status_code == 426


def test_admin_config_page_renders_while_cache_is_down(client, cache_down):
    client.force_login(SuperUserFactory())
    AppConfig.load()
    url = reverse("admin:cms_appconfig_change", args=[1])
    page = client.get(url)
    assert page.status_code == 200


def test_otp_send_is_fail_closed(api_client, limiter_down):
    response = api_client.post(
        "/api/v1/auth/otp/request/", {"phone": "+919876543210", "app": "customer"}, format="json"
    )
    assert response.status_code == 503
    assert response.json()["error"] == {
        "code": "SERVICE_UNAVAILABLE",
        "message": "Sign-in is temporarily unavailable. Please try again in a minute.",
        "details": {},
    }


def test_otp_verify_is_fail_closed(api_client, limiter_down):
    response = api_client.post(
        "/api/v1/auth/otp/verify/",
        {"phone": "+919876543210", "otp": "123456", "app": "customer", "terms_version": "v1"},
        format="json",
    )
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"


def test_fixed_otp_test_numbers_work_without_redis(api_client, limiter_down, cache_down):
    phone = "+919000000003"
    assert (
        api_client.post(
            "/api/v1/auth/otp/request/", {"phone": phone, "app": "rider"}, format="json"
        ).status_code
        == 200
    )
    response = api_client.post(
        "/api/v1/auth/otp/verify/",
        {"phone": phone, "otp": "123456", "app": "rider", "terms_version": "v1"},
        format="json",
    )
    assert response.status_code == 200
