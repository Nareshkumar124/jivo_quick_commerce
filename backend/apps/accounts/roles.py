"""Staff roles (05 §3) as Django Groups. `sync_roles()` is idempotent: it runs after every
`migrate` and from `seed_demo`, and sets each group's permissions to exactly this list.

Phase 1 grants only permissions for models that exist now. Later phases extend the lists
(catalog, inventory, orders, ...). Store scoping (StaffStoreAccess) arrives with stores in Phase 2.
"""

from django.apps import apps
from django.contrib.auth.management import create_permissions
from django.contrib.auth.models import Group, Permission

SUPER_ADMIN = "Super Admin"
OPS = "Ops / Dispatch"
STORE_MANAGER = "Store Manager"
STORE_STAFF = "Store Staff"
CATALOG_MANAGER = "Catalog Manager"
SUPPORT = "Support"
FINANCE = "Finance"

# Apps whose every permission belongs to Super Admin.
SUPER_ADMIN_APPS = ("accounts", "auth", "cms", "axes", "django_celery_beat", "token_blacklist")

CUSTOMER_CARE = ["accounts.view_customer", "accounts.change_customer"]

ROLE_PERMISSIONS: dict[str, list[str]] = {
    SUPER_ADMIN: [],  # all permissions of SUPER_ADMIN_APPS (see _permissions_for)
    OPS: CUSTOMER_CARE,  # 05 §3: Customers (PII) ✔
    STORE_MANAGER: [],
    STORE_STAFF: [],
    CATALOG_MANAGER: [],
    SUPPORT: CUSTOMER_CARE,  # 05 §3: Customers (PII) ✔
    FINANCE: [],
}


def _permissions_for(role: str) -> list[Permission]:
    if role == SUPER_ADMIN:
        return list(Permission.objects.filter(content_type__app_label__in=SUPER_ADMIN_APPS))
    perms = []
    for dotted in ROLE_PERMISSIONS[role]:
        app_label, codename = dotted.split(".", 1)
        perms.append(Permission.objects.get(content_type__app_label=app_label, codename=codename))
    return perms


def sync_roles(**kwargs) -> list[Group]:
    for app_label in SUPER_ADMIN_APPS:
        try:
            app_config = apps.get_app_config(app_label)
        except LookupError:  # pragma: no cover - every listed app is installed
            continue
        create_permissions(app_config, verbosity=0)
    groups = []
    for role in ROLE_PERMISSIONS:
        group, _ = Group.objects.get_or_create(name=role)
        group.permissions.set(_permissions_for(role))
        groups.append(group)
    return groups
