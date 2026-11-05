"""GET /config/app/ and the force-update (426) / maintenance (503) guard (03 §2.1, 04 §2.1)."""

import pytest
from asgiref.sync import async_to_sync
from django.http import HttpResponse
from django.test import RequestFactory
from django.urls import reverse

from apps.accounts.services.auth import issue_tokens
from apps.cms.middleware import app_guard_middleware
from apps.cms.models import AppConfig, AppVersionPolicy
from apps.cms.services import get_app_config, parse_version
from apps.core.middleware import ClientInfo

pytestmark = pytest.mark.django_db

CONFIG = "/api/v1/config/app/"
ANDROID_CUSTOMER = {"X-App-Name": "customer", "X-Platform": "android"}


@pytest.fixture
def policy():
    return AppVersionPolicy.objects.create(
        config=AppConfig.load(),
        app="customer",
        platform="android",
        min_supported_version="1.2.0",
        latest_version="1.4.0",
        store_url="https://play.google.com/store/apps/details?id=in.jivo.quick",
    )


def headers(version):
    return {**ANDROID_CUSTOMER, "X-App-Version": version}


class TestConfigEndpoint:
    def test_without_app_headers(self, api_client):
        body = api_client.get(CONFIG).json()
        assert body == {
            "min_supported_version": None,
            "latest_version": None,
            "store_url": None,
            "maintenance": False,
            "maintenance_message": "",
            "support": {"phone": "", "email": "support@jivo.in"},
            "policy_urls": {
                "terms": "https://jivo.in/terms",
                "privacy": "https://jivo.in/privacy",
                "refund": "https://jivo.in/refund-policy",
            },
            "terms_version": "2026-11-01",
            "otp": {"length": 6, "resend_after_seconds": 30},
            "rider_location": {
                "active_interval_seconds": 10,
                "idle_interval_seconds": 30,
                "active_sample_seconds": 5,
                "idle_sample_seconds": 30,
                "max_batch": 50,
            },
            "feature_flags": {},
        }

    def test_versions_for_the_calling_app(self, api_client, policy):
        body = api_client.get(CONFIG, headers=headers("1.0.0")).json()  # below min: still 200
        assert body["min_supported_version"] == "1.2.0"
        assert body["latest_version"] == "1.4.0"
        assert body["store_url"] == policy.store_url
        other = api_client.get(CONFIG, headers={"X-App-Name": "rider", "X-Platform": "android"})
        assert other.json()["min_supported_version"] is None

    def test_reflects_admin_changes_immediately(self, api_client):
        api_client.get(CONFIG)  # cached
        config = AppConfig.load()
        config.maintenance = True
        config.maintenance_message = "Back at 6 AM"
        config.feature_flags = {"new_home": 1}
        config.save()
        body = api_client.get(CONFIG).json()  # maintenance never blocks config
        assert (body["maintenance"], body["maintenance_message"]) == (True, "Back at 6 AM")
        assert body["feature_flags"] == {"new_home": True}

    def test_cache_is_dropped_again_after_commit(self, django_capture_on_commit_callbacks):
        from django.core.cache import cache

        from apps.cms.services import CACHE_KEY

        with django_capture_on_commit_callbacks(execute=True):
            config = AppConfig.load()
            config.maintenance = True
            config.save()
            get_app_config()  # a request re-caches inside the transaction
            assert cache.get(CACHE_KEY) is not None
        assert cache.get(CACHE_KEY) is None

    def test_ignores_a_stale_token(self, api_client):
        api_client.credentials(HTTP_AUTHORIZATION="Bearer stale")
        assert api_client.get(CONFIG).status_code == 200


class TestGuard:
    def test_maintenance_blocks_the_app_api(self, api_client, user):
        config = AppConfig.load()
        config.maintenance = True
        config.maintenance_message = "Back at 6 AM"
        config.save()
        response = api_client.get("/api/v1/me/")
        assert response.status_code == 503
        assert response.json() == {
            "error": {"code": "MAINTENANCE", "message": "Back at 6 AM", "details": {}}
        }
        # Exempt: config, token refresh, health
        _, refresh = issue_tokens(user, "customer")
        assert (
            api_client.post("/api/v1/auth/token/refresh/", {"refresh": refresh}).status_code == 200
        )
        assert api_client.get("/health/live").status_code == 200

    def test_maintenance_without_message_uses_the_default(self, api_client):
        AppConfig.objects.update_or_create(pk=1, defaults={"maintenance": True})
        response = api_client.post("/api/v1/auth/otp/request/", {})
        assert response.json()["error"]["message"] == "The service is under maintenance."

    @pytest.mark.parametrize("version", ["1.1.9", "1.1.9+99", "0.9"])
    def test_old_version_gets_426(self, api_client, policy, version):
        response = api_client.get("/api/v1/me/", headers=headers(version))
        assert response.status_code == 426
        assert response.json()["error"] == {
            "code": "APP_UPDATE_REQUIRED",
            "message": "Please update the app to continue.",
            "details": {
                "min_supported_version": "1.2.0",
                "latest_version": "1.4.0",
                "store_url": policy.store_url,
            },
        }

    @pytest.mark.parametrize("version", ["1.2", "1.2.0", "1.2.0+1", "1.10.0", "2.0.0"])
    def test_supported_versions_pass(self, api_client, policy, version):
        response = api_client.get("/api/v1/me/", headers=headers(version))
        assert response.status_code == 401  # reached the view: no token

    @pytest.mark.parametrize(
        "extra",
        [
            {},  # no headers at all
            {"X-App-Name": "customer", "X-App-Version": "0.1.0"},  # no platform
            {"X-App-Name": "rider", "X-Platform": "android", "X-App-Version": "0.1.0"},  # no policy
            {**ANDROID_CUSTOMER, "X-App-Version": "garbage"},
        ],
    )
    def test_no_426_without_complete_headers_or_policy(self, api_client, policy, extra):
        assert api_client.get("/api/v1/me/", headers=extra).status_code == 401

    def test_refresh_and_config_are_exempt_from_426(self, api_client, policy, user):
        _, refresh = issue_tokens(user, "customer")
        old = headers("0.1.0")
        assert api_client.get(CONFIG, headers=old).status_code == 200
        response = api_client.post("/api/v1/auth/token/refresh/", {"refresh": refresh}, headers=old)
        assert response.status_code == 200

    def test_async_stack(self):
        AppConfig.objects.update_or_create(pk=1, defaults={"maintenance": True})

        async def view(request):
            return HttpResponse("ok")

        request = RequestFactory().get("/api/v1/me/")
        request.client_info = ClientInfo()
        response = async_to_sync(app_guard_middleware(view))(request)
        assert response.status_code == 503
        other = RequestFactory().get("/admin/")
        assert async_to_sync(app_guard_middleware(view))(other).status_code == 200


class TestModelAndServices:
    def test_singleton(self):
        first = AppConfig.load()
        again = AppConfig(support_phone="+911800000000")
        again.save()
        assert AppConfig.objects.count() == 1
        assert again.pk == first.pk
        assert str(first) == "App configuration"

    def test_snapshot_and_versions(self, policy):
        snapshot = get_app_config()
        assert snapshot.version_policy("customer", "android").min_supported_version == "1.2.0"
        assert snapshot.version_policy(None, "android") is None
        assert str(policy) == "customer / android"

    def test_parse_version(self):
        assert parse_version("1.2") == (1, 2, 0, 0)
        assert parse_version("1.2.0.7") == (1, 2, 0, 7)
        assert parse_version(None) is None
        assert parse_version("1.10") > parse_version("1.9.9")


class TestAdmin:
    @pytest.fixture
    def admin_client(self, client, superuser):
        client.force_login(superuser)
        return client

    def test_changelist_opens_the_singleton(self, admin_client):
        response = admin_client.get(reverse("admin:cms_appconfig_changelist"))
        assert response.status_code == 302
        assert response["Location"] == reverse("admin:cms_appconfig_change", args=[1])
        page = admin_client.get(response["Location"])
        assert page.status_code == 200
        assert b"min_supported_version" in page.content

    def test_no_add_or_delete(self, admin_client):
        AppConfig.load()
        assert admin_client.get(reverse("admin:cms_appconfig_add")).status_code == 403
        assert admin_client.get(reverse("admin:cms_appconfig_delete", args=[1])).status_code == 403
