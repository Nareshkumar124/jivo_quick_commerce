"""App configuration admin (05 §2 "CMS & app config", 05 §3 "App config": Super Admin only)."""

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.cms.models import AppConfig
from apps.ops_console.tests.helpers import ROLES, staff_in_role

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


def test_changelist_opens_the_singleton(client):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    response = client.get(reverse("admin:cms_appconfig_changelist"))
    assert response.status_code == 302
    assert response["Location"] == reverse("admin:cms_appconfig_change", args=[1])


def test_super_admin_turns_maintenance_on(client):
    config = AppConfig.load()
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    url = reverse("admin:cms_appconfig_change", args=[config.pk])
    html = client.get(url).content.decode()
    assert "every app API call answers 503" in html
    data = {
        "maintenance": "on",
        "maintenance_message": "Back at 6 AM",
        "support_phone": "",
        "support_email": config.support_email,
        "terms_url": config.terms_url,
        "privacy_url": config.privacy_url,
        "refund_url": config.refund_url,
        "terms_version": config.terms_version,
        "payment_window_minutes": config.payment_window_minutes,
        "rider_location_active_interval_seconds": 10,
        "rider_location_idle_interval_seconds": 30,
        "rider_location_active_sample_seconds": config.rider_location_active_sample_seconds,
        "rider_location_idle_sample_seconds": config.rider_location_idle_sample_seconds,
        "rider_location_max_batch": config.rider_location_max_batch,
        "feature_flags": "{}",
        "versions-TOTAL_FORMS": "0",
        "versions-INITIAL_FORMS": "0",
        "versions-MIN_NUM_FORMS": "0",
        "versions-MAX_NUM_FORMS": "1000",
    }
    response = client.post(url, data)
    assert response.status_code == 302, response.content
    config.refresh_from_db()
    assert config.maintenance is True
    assert config.maintenance_message == "Back at 6 AM"


@pytest.mark.parametrize("role", [role for role in ROLES if role != roles.SUPER_ADMIN])
def test_other_roles_cannot_change_app_config(client, role):
    config = AppConfig.load()
    client.force_login(staff_in_role(role))
    url = reverse("admin:cms_appconfig_change", args=[config.pk])
    assert client.get(url).status_code == 403
    assert client.post(url, {"maintenance": "on"}).status_code == 403
    config.refresh_from_db()
    assert config.maintenance is False


@pytest.mark.parametrize(("minutes", "saved"), [("20", True), ("4", False), ("61", False)])
def test_super_admin_sets_the_payment_window(client, minutes, saved):
    """DL-43: the online payment window (5-60 minutes) is app configuration (Super Admin)."""
    from apps.ops_console.tests.helpers import admin_form_data

    config = AppConfig.load()
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    url = reverse("admin:cms_appconfig_change", args=[config.pk])
    page = client.get(url)
    assert "How long an online order waits for payment" in page.content.decode()
    data = admin_form_data(page)
    data["payment_window_minutes"] = minutes
    response = client.post(url, data)
    config.refresh_from_db()
    if saved:
        assert response.status_code == 302, response.context["adminform"].form.errors
        assert config.payment_window_minutes == 20
    else:
        assert response.status_code == 200
        assert "payment_window_minutes" in response.context["adminform"].form.errors
        assert config.payment_window_minutes == 15
