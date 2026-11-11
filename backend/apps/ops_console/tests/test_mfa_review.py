"""Review fixes for the staff two-step sign-in (P8 part B): allow expiry, a concurrent reset
at the confirm step, sessions ended on reset, and who counts as a Super Admin."""

from datetime import timedelta

import pytest
from django.contrib.admin.sites import site
from django.contrib.auth.models import Group
from django.contrib.sessions.models import Session
from django.core.management import CommandError, call_command
from django.urls import reverse
from django.utils import timezone
from django_otp.plugins.otp_static.models import StaticDevice
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.models import AuditLog
from apps.ops_console import mfa
from apps.ops_console.tests.helpers import login_as, staff_in_role
from apps.ops_console.tests.test_mfa_csp import _mfa_on, code_for  # noqa: F401

pytestmark = pytest.mark.django_db


def age_the_allowance(user, hours):
    """AuditLog is append-only (no update); move the entry back with a raw queryset update."""
    AuditLog.objects.model._base_manager.filter(
        action="staff.mfa_setup_allowed", object_id=str(user.pk)
    ).update(created_at=timezone.now() - timedelta(hours=hours))


def test_allowed_setup_expires(client, settings):
    settings.STAFF_MFA_SETUP_ALLOW_HOURS = 72
    user = login_as(client, roles.FINANCE)
    mfa.allow_setup(user, by=None)
    assert client.get(reverse("ops:mfa-setup")).status_code == 200
    age_the_allowance(user, 71)
    assert client.get(reverse("ops:mfa-setup")).status_code == 200
    age_the_allowance(user, 73)
    response = client.get(reverse("ops:mfa-setup"))
    assert response.status_code == 403
    assert "Ask a Super Admin" in response.content.decode()
    assert mfa.setup_state(user) == "none"
    # Allowing again starts a fresh window.
    mfa.allow_setup(user, by=None)
    assert client.get(reverse("ops:mfa-setup")).status_code == 200


def test_expiry_is_checked_at_confirm_too(client):
    user = login_as(client, roles.FINANCE)
    mfa.allow_setup(user, by=None)
    device = TOTPDevice.objects.get(user=user)
    client.get(reverse("ops:mfa-setup"))
    age_the_allowance(user, 100)
    response = client.post(reverse("ops:mfa-setup"), {"code": code_for(device)})
    assert response.status_code == 403
    assert not TOTPDevice.objects.filter(confirmed=True).exists()


def test_confirm_after_a_concurrent_reset_is_the_403_page(client, monkeypatch):
    user = login_as(client, roles.FINANCE)
    mfa.allow_setup(user, by=None)
    device = TOTPDevice.objects.get(user=user)
    real = mfa.allowed_device

    def then_reset(u):
        found = real(u)
        TOTPDevice.objects.filter(user=u).delete()  # another Super Admin resets meanwhile
        return found

    monkeypatch.setattr(mfa, "allowed_device", then_reset)
    response = client.post(reverse("ops:mfa-setup"), {"code": code_for(device)})
    assert response.status_code == 403
    assert not TOTPDevice.objects.filter(confirmed=True).exists()


def test_reset_ends_the_persons_sessions_only(client, django_user_model):
    from django.test import Client

    target = staff_in_role(roles.SUPPORT)
    other = staff_in_role(roles.FINANCE)
    for _ in range(2):
        Client().force_login(target)
    Client().force_login(other)
    mfa.allow_setup(target, by=None)
    assert Session.objects.count() == 3
    mfa.reset_devices(target, by=staff_in_role(roles.SUPER_ADMIN))
    remaining = [s.get_decoded().get("_auth_user_id") for s in Session.objects.all()]
    assert remaining == [str(other.pk)]
    log = AuditLog.objects.filter(action="staff.mfa_reset", object_id=str(target.pk)).get()
    assert log.changes["sessions"] == 2


def test_reset_with_another_session_engine_is_a_no_op(settings):
    settings.SESSION_ENGINE = "django.contrib.sessions.backends.cache"
    assert mfa.end_sessions(staff_in_role(roles.SUPPORT)) == 0


def test_otp_devices_are_not_registered_in_the_admin():
    for model in (TOTPDevice, StaticDevice):
        assert model not in site._registry


def test_custom_group_is_not_a_super_admin():
    user = StaffUserFactory()
    group = Group.objects.create(name="Super Admins (custom)")
    user.groups.add(group)
    assert not mfa.is_super_admin(user)
    user.groups.add(Group.objects.get_or_create(name=roles.SUPER_ADMIN)[0])
    assert mfa.is_super_admin(user)


def test_command_refuses_store_staff():
    user = staff_in_role(roles.STORE_STAFF)
    with pytest.raises(CommandError, match="does not need two-step"):
        call_command("allow_mfa_setup", user.email)
    assert not TOTPDevice.objects.filter(user=user).exists()
