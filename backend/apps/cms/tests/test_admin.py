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
        "customer_login_methods": config.customer_login_methods,
        "rider_login_methods": config.rider_login_methods,
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


# --------------------------------------------------------------------------- login methods
# 2026-11-28 (email OTP): the per-app login switch is saved only through
# `cms.services.set_login_methods` (audited), and only by Super Admin / superusers.


def _spy_service(monkeypatch) -> list:
    """Record calls to `cms.services.set_login_methods` and still run it."""
    from apps.cms import services as cms_services

    calls = []
    real = cms_services.set_login_methods

    def spy(app, setting, **kwargs):
        calls.append((app, setting, kwargs))
        return real(app, setting, **kwargs)

    monkeypatch.setattr(cms_services, "set_login_methods", spy)
    return calls


def _change_page(client, user):
    from apps.ops_console.tests.helpers import admin_form_data

    config = AppConfig.load()
    client.force_login(user)
    url = reverse("admin:cms_appconfig_change", args=[config.pk])
    page = client.get(url)
    assert page.status_code == 200
    return url, page, admin_form_data(page)


@pytest.mark.parametrize("superuser", [False, True])
def test_super_admin_switches_login_methods_through_the_service(client, superuser, monkeypatch):
    if superuser:
        from apps.accounts.models import User

        user = User.objects.create_superuser(email="root-lm@example.com", password="x-Pass-12345")
    else:
        user = staff_in_role(roles.SUPER_ADMIN)
    url, page, data = _change_page(client, user)
    html = page.content.decode()
    assert "Phone needs SMS, which is not live yet; use Email." in html
    spy = _spy_service(monkeypatch)
    data["customer_login_methods"] = "email"
    data["rider_login_methods"] = "both"
    response = client.post(url, data)
    assert response.status_code == 302, response.context["adminform"].form.errors
    assert {(app, setting) for app, setting, _kw in spy} == {
        ("customer", "email"),
        ("rider", "both"),
    }
    assert all(kw["actor"] == user for _app, _setting, kw in spy)
    config = AppConfig.load()
    assert (config.customer_login_methods, config.rider_login_methods) == ("email", "both")


def test_login_switch_change_is_audited(client):
    from apps.core.models import AuditLog

    user = staff_in_role(roles.SUPER_ADMIN)
    url, _page, data = _change_page(client, user)
    data["customer_login_methods"] = "email"
    assert client.post(url, data).status_code == 302
    entry = AuditLog.objects.filter(action="config.login_methods").latest("pk")
    assert entry.actor == user


def test_saving_other_fields_does_not_call_the_login_service(client, monkeypatch):
    url, _page, data = _change_page(client, staff_in_role(roles.SUPER_ADMIN))
    spy = _spy_service(monkeypatch)
    data["maintenance_message"] = "Short break"
    assert client.post(url, data).status_code == 302
    assert spy == []


@pytest.mark.parametrize("role", [role for role in ROLES if role != roles.SUPER_ADMIN])
def test_other_roles_cannot_switch_login_methods(client, role, monkeypatch):
    spy = _spy_service(monkeypatch)
    config = AppConfig.load()
    client.force_login(staff_in_role(role))
    url = reverse("admin:cms_appconfig_change", args=[config.pk])
    assert client.get(url).status_code == 403
    response = client.post(url, {"customer_login_methods": "email"})
    assert response.status_code == 403
    assert spy == []
    config.refresh_from_db()
    assert config.customer_login_methods == "phone"


def test_login_fields_read_only_without_super_admin_role():
    """A staff user who somehow holds `change_appconfig` without the Super Admin role still
    cannot edit the switch (05 §3 matrix, server side)."""
    from django.contrib.admin.sites import site
    from django.contrib.auth.models import Permission
    from django.test import RequestFactory

    user = staff_in_role(roles.SUPPORT)
    user.user_permissions.add(Permission.objects.get(codename="change_appconfig"))
    request = RequestFactory().get("/")
    request.user = user
    model_admin = site._registry[AppConfig]
    readonly = model_admin.get_readonly_fields(request, AppConfig.load())
    assert {"customer_login_methods", "rider_login_methods"} <= set(readonly)
