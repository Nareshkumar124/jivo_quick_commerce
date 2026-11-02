"""Shared helpers for the admin and Ops Console role-matrix tests (05 §3)."""

from django.contrib.auth.models import Group

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory

ROLES = tuple(roles.ROLE_PERMISSIONS)  # the seven 05 §3 roles

# Who is asking: the seven roles (group membership only, never is_superuser), a superuser flag
# without groups, a signed-in non-staff user (a customer) and an anonymous visitor.
SUPERUSER = "superuser flag"
NON_STAFF = "non-staff"
ANONYMOUS = "anonymous"
PRINCIPALS = (*ROLES, SUPERUSER, NON_STAFF, ANONYMOUS)

# Phase 1 holders of `accounts.view_customer` / `change_customer` (05 §3 "Customers (PII)").
CUSTOMER_ROLES = frozenset({roles.SUPER_ADMIN, roles.OPS, roles.SUPPORT, SUPERUSER})
# Phase 1 "Manage staff users & roles" and "App config, global settings": Super Admin only.
ADMIN_SETTINGS_ROLES = frozenset({roles.SUPER_ADMIN, SUPERUSER})
STAFF_PRINCIPALS = frozenset({*ROLES, SUPERUSER})


def staff_in_role(role: str, **kwargs):
    user = StaffUserFactory(**kwargs)
    user.groups.add(Group.objects.get(name=role))
    return user


def make_principal(principal: str):
    """The user for a principal, or None for an anonymous visitor."""
    if principal == ANONYMOUS:
        return None
    if principal == NON_STAFF:
        return UserFactory()
    if principal == SUPERUSER:
        return SuperUserFactory()
    return staff_in_role(principal)


def login_as(client, principal: str):
    user = make_principal(principal)
    if user is not None:
        client.force_login(user)
    return user
