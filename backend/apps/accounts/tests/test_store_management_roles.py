"""ADR 0004: the "Store management" permissions (bottle prices, offers, delivery pincodes) belong
to Super Admin only (and Django superusers), granted by `roles.sync_roles()`."""

import pytest
from django.contrib.auth.models import Group

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory

pytestmark = pytest.mark.django_db

PERMISSIONS = {
    "catalog.manage_prices",
    "promotions.manage_offers",
    "stores.manage_delivery_pincodes",
}


def granted(group: Group) -> set[str]:
    return {
        f"{app}.{codename}"
        for app, codename in group.permissions.values_list("content_type__app_label", "codename")
    }


def test_the_three_permissions_are_named_in_roles():
    assert set(roles.STORE_MANAGEMENT) == PERMISSIONS
    for role, perms in roles.ROLE_PERMISSIONS.items():
        assert not set(perms) & PERMISSIONS, role


def test_only_super_admin_gets_them():
    roles.sync_roles()
    for group in Group.objects.filter(name__in=[*roles.ROLE_PERMISSIONS]):
        has = granted(group) & PERMISSIONS
        assert has == (PERMISSIONS if group.name == roles.SUPER_ADMIN else set()), group.name


@pytest.mark.parametrize("role", sorted(set(roles.ROLE_PERMISSIONS) - {roles.SUPER_ADMIN}))
def test_staff_of_other_roles_lack_them(role):
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    assert not any(user.has_perm(perm) for perm in PERMISSIONS)


def test_super_admin_and_superuser_have_them():
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=roles.SUPER_ADMIN))
    assert user.has_perms(PERMISSIONS)
    assert SuperUserFactory().has_perms(PERMISSIONS)
