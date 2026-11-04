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


# Phase 2 (05 §3, as granted by apps/accounts/roles.py). Store Manager / Store Staff are limited to
# their StaffStoreAccess stores on top of these.
_SA = {roles.SUPER_ADMIN, SUPERUSER}
CATALOG_VIEW_ROLES = frozenset(
    {*_SA, roles.OPS, roles.STORE_MANAGER, roles.STORE_STAFF, roles.CATALOG_MANAGER, roles.SUPPORT}
)
CATALOG_EDIT_ROLES = frozenset({*_SA, roles.CATALOG_MANAGER})
STORE_VIEW_ROLES = frozenset({*_SA, roles.OPS, roles.STORE_MANAGER})
STORE_EDIT_ROLES = frozenset(_SA)
INVENTORY_VIEW_ROLES = frozenset(
    {
        *_SA,
        roles.OPS,
        roles.STORE_MANAGER,
        roles.STORE_STAFF,
        roles.CATALOG_MANAGER,
        roles.FINANCE,
    }
)
INVENTORY_ADJUST_ROLES = frozenset({*_SA, roles.STORE_MANAGER})
LEADS_ROLES = frozenset({*_SA, roles.OPS})
STORE_SCOPED = frozenset({roles.STORE_MANAGER, roles.STORE_STAFF})

# Phase 3 (05 §3 Pricing config, Coupons, Refund, order board / packing rows; DL-46 PM default).
PRICING_VIEW_ROLES = frozenset({*_SA, roles.FINANCE})
PRICING_EDIT_ROLES = frozenset(_SA)
COUPON_VIEW_ROLES = frozenset({*_SA, roles.CATALOG_MANAGER, roles.SUPPORT, roles.FINANCE})
COUPON_EDIT_ROLES = frozenset({*_SA, roles.CATALOG_MANAGER})
ORDER_VIEW_ROLES = frozenset(
    {*_SA, roles.OPS, roles.STORE_MANAGER, roles.STORE_STAFF, roles.SUPPORT, roles.FINANCE}
)
PAYMENT_VIEW_ROLES = frozenset({*_SA, roles.SUPPORT, roles.FINANCE})
WEBHOOK_ROLES = frozenset({*_SA, roles.FINANCE})
# Roles that see customers in full (`accounts.view_customer`); everyone else gets masked PII.
FULL_PII_ROLES = CUSTOMER_ROLES


def expected_status(principal, allowed, allowed_status: int = 200) -> int:
    """Admin and Ops: allowed -> `allowed_status`; not staff or signed out -> 302 to the login;
    staff without the permission -> 403."""
    if principal in allowed:
        return allowed_status
    if principal in (NON_STAFF, ANONYMOUS):
        return 302
    return 403


def login_with_stores(client, principal: str, *stores):
    """Like `login_as`, and store-scoped roles get access to `stores` (StaffStoreAccess)."""
    from apps.stores.services import grant_store_access

    user = make_principal(principal)
    if user is not None:
        if principal in STORE_SCOPED:
            for store in stores:
                grant_store_access(user, store)
        client.force_login(user)
    return user


def _form_values(form, data: dict) -> None:
    from django import forms
    from django.contrib.gis.geos import GEOSGeometry

    def put(key, value):
        if isinstance(value, bool):
            if value:
                data[key] = "on"
        elif value is None:
            data[key] = ""
        elif isinstance(value, GEOSGeometry):
            data[key] = value.ewkt
        elif isinstance(value, list | tuple):
            data[key] = [str(getattr(item, "pk", item)) for item in value]
        else:
            data[key] = str(getattr(value, "pk", value))

    for name, field in form.fields.items():
        key = form.add_prefix(name)
        value = form[name].value()
        if isinstance(field.widget, forms.MultiWidget):
            parts = value if isinstance(value, list | tuple) else field.widget.decompress(value)
            for index, part in enumerate(parts):
                put(f"{key}_{index}", part)
        else:
            put(key, value)


def admin_form_data(response) -> dict:
    """The admin add/change form on `response` as the browser would post it unchanged: the main
    form, every inline (management form included) and the save button."""
    data: dict = {}
    _form_values(response.context["adminform"].form, data)
    for inline in response.context["inline_admin_formsets"]:
        formset = inline.formset
        management = formset.management_form
        for name in management.fields:
            data[management.add_prefix(name)] = management[name].value()
        for form in formset.forms:
            _form_values(form, data)
    data["_save"] = "Save"
    return data
