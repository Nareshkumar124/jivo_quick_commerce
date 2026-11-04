"""Staff roles (05 §3) as Django Groups. `sync_roles()` is idempotent: it runs after every
`migrate` and from `seed_demo`, and sets each group's permissions to exactly this list.

Each phase grants permissions for the models it adds (Phase 2: stores, catalog, inventory;
Phase 3: coupons, orders and payments, read-only except coupons).
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
    "promotions",
    "cart",
    "orders",
    "payments",
    "delivery",
    "core",  # audit log: view only (see _permissions_for)
    "support",
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

# Phase 3 (05 §3 rows Coupons, Refund, Live order board, Packing console; PM default ⚠ until the
# order and refund screens of Phase 4 refine them). Orders are read-only here: state changes go
# through orders.services.transition(), never through model permissions.
COUPON_VIEW = ["promotions.view_coupon", "promotions.view_couponredemption"]
COUPON_MANAGE = [
    *[f"promotions.{action}_coupon" for action in ("add", "change", "delete", "view")],
    "promotions.view_couponredemption",
]
ORDER_VIEW = [
    "orders.view_order",
    "orders.view_orderitem",
    "orders.view_orderstatushistory",
    "orders.view_invoice",
]
PAYMENT_VIEW = ["payments.view_payment", "payments.view_refund"]
# Phase 4 (05 §3): state changes through apps.orders.store_ops, which re-check these permissions
# and the store scope (stores_for). Refund limits are settings (SUPPORT_REFUND_LIMIT).
ORDER_PROCESS = "orders.process_order"  # packing console: accept, pack, items unavailable
ORDER_CANCEL = "orders.cancel_order"  # 08 T12 (store manager: own stores, before pickup)
REFUND_ISSUE = "payments.issue_refund"  # manual refund / retry (Support up to the limit)
AUDIT_VIEW = "core.view_auditlog"
# Phase 5 (05 §3 "Rider approval / suspend": Super Admin, Ops ✔; Store Manager view own). State
# changes go through apps.delivery.services.kyc, which re-checks these and the store scope.
RIDER_VIEW = ["delivery.view_rider", "delivery.view_riderdocument", "delivery.view_ridershift"]
RIDER_REVIEW = ["delivery.review_rider", "delivery.view_kyc_document_file"]
# Phase 7 (05 §3 "Support tickets": Super Admin, Ops, Support). Ticket changes go through
# apps.support.services, which re-check `support.handle_ticket`. FAQs are part of the Support
# module (05 §2), so Support also edits them (PM default); pages stay Super Admin (CMS).
SUPPORT_TICKETS = [
    "support.view_supportticket",
    "support.view_ticketmessage",
    "support.handle_ticket",
]
FAQ_MANAGE = [f"cms.{action}_faq" for action in ("add", "change", "delete", "view")]

ROLE_PERMISSIONS: dict[str, list[str]] = {
    SUPER_ADMIN: [],  # all permissions of SUPER_ADMIN_APPS (see _permissions_for)
    # 05 §3: Customers (PII) ✔; stores view; catalog view; inventory view; notify-me leads.
    OPS: [
        *CUSTOMER_CARE,
        *STORE_VIEW,
        *CATALOG_VIEW,
        *INVENTORY_VIEW,
        "stores.view_serviceabilityrequest",
        *ORDER_VIEW,
        ORDER_PROCESS,
        ORDER_CANCEL,
        *RIDER_VIEW,
        *RIDER_REVIEW,
        *SUPPORT_TICKETS,
    ],
    STORE_MANAGER: [
        *STORE_VIEW,
        *CATALOG_VIEW,
        *INVENTORY_VIEW,
        *INVENTORY_ADJUST,
        *ORDER_VIEW,
        ORDER_PROCESS,
        ORDER_CANCEL,
        *RIDER_VIEW,
    ],
    STORE_STAFF: [*CATALOG_VIEW, *INVENTORY_VIEW, *ORDER_VIEW, ORDER_PROCESS],
    CATALOG_MANAGER: [*CATALOG_MANAGE, *INVENTORY_VIEW, *COUPON_MANAGE],
    # 05 §3: Customers (PII) ✔; coupons view; order board view; refunds (payments view).
    SUPPORT: [
        *CUSTOMER_CARE,
        *CATALOG_VIEW,
        *COUPON_VIEW,
        *ORDER_VIEW,
        *PAYMENT_VIEW,
        ORDER_CANCEL,
        REFUND_ISSUE,
        *SUPPORT_TICKETS,
        *FAQ_MANAGE,
    ],
    FINANCE: [
        *INVENTORY_VIEW,
        "stores.view_pricingconfig",
        *COUPON_VIEW,
        *ORDER_VIEW,
        *PAYMENT_VIEW,
        "payments.view_paymentwebhookevent",
        REFUND_ISSUE,
        AUDIT_VIEW,
    ],
}
# Roles limited to the stores in StaffStoreAccess.
STORE_SCOPED_ROLES = frozenset({STORE_MANAGER, STORE_STAFF})
# Roles that see every store (05 §3). An explicit allow-list: any other group (unknown, or a
# future role not yet classified) never widens store access. See stores.services.stores_for.
GLOBAL_ROLES = frozenset({SUPER_ADMIN, OPS, CATALOG_MANAGER, SUPPORT, FINANCE})


def is_store_staff_only(user) -> bool:
    """Staff session policy (05 §5, BUG-0006): True when every role of the user is a store role
    (Store Manager / Store Staff), so the 8-hour session applies without the 2-hour idle
    timeout. Superusers, global roles, mixed roles and staff with no role get the stricter
    admin-role policy."""
    if user.is_superuser:
        return False
    groups = set(user.groups.values_list("name", flat=True))
    return bool(groups) and groups <= STORE_SCOPED_ROLES


def _permissions_for(role: str) -> list[Permission]:
    if role == SUPER_ADMIN:
        # The audit log is read-only for everyone (05 §2): Super Admin gets only its view
        # permission, never add/change/delete (P4 review Minor 4).
        perms = Permission.objects.filter(content_type__app_label__in=SUPER_ADMIN_APPS)
        perms = perms.exclude(content_type__app_label="core", content_type__model="auditlog")
        audit = Permission.objects.filter(content_type__app_label="core", codename="view_auditlog")
        return [*perms, *audit]
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
