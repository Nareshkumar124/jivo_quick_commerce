"""Staff roles (05 §3) as Django Groups. `sync_roles()` is idempotent: it runs after every
`migrate` and from `seed_demo`, and sets each group's permissions to exactly this list.

Each phase grants permissions for the models it adds (Phase 2: stores, catalog, inventory).
Store scoping: StaffStoreAccess + apps.stores.services.stores_for().
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
SUPER_ADMIN_APPS = (
    "accounts",
    "auth",
    "cms",
    "axes",
    "django_celery_beat",
    "token_blacklist",
    "stores",
    "catalog",
    "inventory",
)

CUSTOMER_CARE = ["accounts.view_customer", "accounts.change_customer"]

# Phase 2 (05 §3). Store Manager / Store Staff see only their stores: scope querysets with
# apps.stores.services.stores_for(user). Prices (variant prices, store price override) stay
# Super Admin / Catalog Manager only.
CATALOG_MODELS = (
    "category",
    "product",
    "productvariant",
    "productimage",
    "collection",
    "collectionitem",
    "banner",
    "trendingsearch",
)
CATALOG_VIEW = [f"catalog.view_{model}" for model in CATALOG_MODELS]
CATALOG_MANAGE = [
    f"catalog.{action}_{model}"
    for model in CATALOG_MODELS
    for action in ("add", "change", "delete", "view")
]
STORE_VIEW = ["stores.view_darkstore", "stores.view_storetiming"]
INVENTORY_VIEW = ["inventory.view_storeinventory", "inventory.view_stockmovement"]
INVENTORY_ADJUST = ["inventory.adjust_stock", "inventory.toggle_availability"]

ROLE_PERMISSIONS: dict[str, list[str]] = {
    SUPER_ADMIN: [],  # all permissions of SUPER_ADMIN_APPS (see _permissions_for)
    # 05 §3: Customers (PII) ✔; stores view; catalog view; inventory view; notify-me leads.
    OPS: [
        *CUSTOMER_CARE,
        *STORE_VIEW,
        *CATALOG_VIEW,
        *INVENTORY_VIEW,
        "stores.view_serviceabilityrequest",
    ],
    STORE_MANAGER: [*STORE_VIEW, *CATALOG_VIEW, *INVENTORY_VIEW, *INVENTORY_ADJUST],
    STORE_STAFF: [*CATALOG_VIEW, *INVENTORY_VIEW],
    CATALOG_MANAGER: [*CATALOG_MANAGE, *INVENTORY_VIEW],
    SUPPORT: [*CUSTOMER_CARE, *CATALOG_VIEW],  # 05 §3: Customers (PII) ✔
    FINANCE: [*INVENTORY_VIEW, "stores.view_pricingconfig"],
}
# Roles limited to the stores in StaffStoreAccess; every other role sees all stores.
STORE_SCOPED_ROLES = frozenset({STORE_MANAGER, STORE_STAFF})


def _permissions_for(role: str) -> list[Permission]:
    if role == SUPER_ADMIN:
        return list(Permission.objects.filter(content_type__app_label__in=SUPER_ADMIN_APPS))
    perms = []
    for dotted in ROLE_PERMISSIONS[role]:
        app_label, codename = dotted.split(".", 1)
        perms.append(Permission.objects.get(content_type__app_label=app_label, codename=codename))
    return perms


def _referenced_apps() -> set[str]:
    labels = set(SUPER_ADMIN_APPS)
    for perms in ROLE_PERMISSIONS.values():
        labels.update(dotted.split(".", 1)[0] for dotted in perms)
    return labels


def sync_roles(**kwargs) -> list[Group]:
    # post_migrate for `accounts` runs before the later apps' own permission creation, so make
    # sure every referenced app's permissions (incl. custom Meta.permissions) exist first.
    for app_label in sorted(_referenced_apps()):
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
