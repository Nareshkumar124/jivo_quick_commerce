"""Panel navigation: one registry of the panel modules (05 §2), shared by the unfold admin
sidebar (`config/admin_ui.py`) and the Ops Console sidebar.

Loaded by the settings module, so it must not import models or anything that needs the app
registry. Links are resolved lazily and permissions are checked per request.

A module appears here only once its phase has landed (docs/admin-panel-architecture.md §7).
Showing a link is never the permission check: every target view and ModelAdmin enforces the
05 §3 matrix itself.
"""

from dataclasses import dataclass
from functools import partial

from django.urls import reverse, reverse_lazy
from django.utils.text import format_lazy

ADMIN = "admin"
OPS = "ops"


@dataclass(frozen=True)
class NavItem:
    title: str
    icon: str  # Material Symbols name (unfold ships the font)
    url_name: str
    # Any one of these permissions shows the link. Empty: every active staff member.
    perms: tuple[str, ...] = ()
    query: str = ""
    surface: str = ADMIN  # ADMIN (/admin/) or OPS (/ops/)

    def url(self) -> str:
        base = reverse(self.url_name)
        return f"{base}?{self.query}" if self.query else base

    def lazy_url(self):
        base = reverse_lazy(self.url_name)
        return format_lazy("{}?{}", base, self.query) if self.query else base

    def allowed(self, user) -> bool:
        if not (user.is_active and user.is_staff):
            return False
        return not self.perms or any(user.has_perm(perm) for perm in self.perms)


@dataclass(frozen=True)
class NavSection:
    title: str
    items: tuple[NavItem, ...]


# Order follows the 12 panel modules: dashboard, products, inventory, stores, orders, riders,
# dispatch, customers, payments & finance, promotions, reports, admin settings.
MODULES: tuple[NavSection, ...] = (
    NavSection(
        "Dashboard",
        (NavItem("Dashboard", "dashboard", "ops:dashboard", surface=OPS),),
    ),
    NavSection(
        "Products",
        (
            NavItem(
                "Products",
                "inventory_2",
                "admin:catalog_product_changelist",
                ("catalog.view_product",),
            ),
            NavItem(
                "SKUs (variants)",
                "barcode",
                "admin:catalog_productvariant_changelist",
                ("catalog.view_productvariant",),
            ),
            NavItem(
                "Categories",
                "category",
                "admin:catalog_category_changelist",
                ("catalog.view_category",),
            ),
            NavItem(
                "Collections",
                "collections_bookmark",
                "admin:catalog_collection_changelist",
                ("catalog.view_collection",),
            ),
            NavItem(
                "Banners",
                "view_carousel",
                "admin:catalog_banner_changelist",
                ("catalog.view_banner",),
            ),
            NavItem(
                "Trending searches",
                "trending_up",
                "admin:catalog_trendingsearch_changelist",
                ("catalog.view_trendingsearch",),
            ),
        ),
    ),
    NavSection(
        "Inventory",
        (
            NavItem(
                "Stock per store",
                "warehouse",
                "admin:inventory_storeinventory_changelist",
                ("inventory.view_storeinventory",),
            ),
            NavItem(
                "Low stock",
                "warning",
                "admin:inventory_storeinventory_changelist",
                ("inventory.view_storeinventory",),
                query="stock=low&on_sale=1",
            ),
            NavItem(
                "Stock inward (CSV)",
                "upload_file",
                "admin:inventory_storeinventory_inward",
                ("inventory.adjust_stock",),
            ),
            NavItem(
                "Stock ledger",
                "receipt_long",
                "admin:inventory_stockmovement_changelist",
                ("inventory.view_stockmovement",),
            ),
        ),
    ),
    NavSection(
        "Stores",
        (
            NavItem(
                "Dark stores",
                "store",
                "admin:stores_darkstore_changelist",
                ("stores.view_darkstore",),
            ),
            NavItem(
                "Notify-me leads",
                "person_pin_circle",
                "admin:stores_serviceabilityrequest_changelist",
                ("stores.view_serviceabilityrequest",),
            ),
        ),
    ),
    NavSection(
        "Orders",
        (
            NavItem(
                "Orders",
                "receipt",
                "admin:orders_order_changelist",
                ("orders.view_order",),
            ),
        ),
    ),
    NavSection(
        "Customers",
        (
            NavItem(
                "Customers",
                "group",
                "admin:accounts_customer_changelist",
                ("accounts.view_customer",),
            ),
        ),
    ),
    NavSection(
        "Payments & finance",
        (
            NavItem(
                "Payments",
                "payments",
                "admin:payments_payment_changelist",
                ("payments.view_payment",),
            ),
            NavItem(
                "Refunds",
                "currency_exchange",
                "admin:payments_refund_changelist",
                ("payments.view_refund",),
            ),
            NavItem(
                "Payment webhooks",
                "webhook",
                "admin:payments_paymentwebhookevent_changelist",
                ("payments.view_paymentwebhookevent",),
            ),
        ),
    ),
    NavSection(
        "Promotions",
        (
            NavItem(
                "Coupons",
                "sell",
                "admin:promotions_coupon_changelist",
                ("promotions.view_coupon",),
            ),
            NavItem(
                "Coupon redemptions",
                "redeem",
                "admin:promotions_couponredemption_changelist",
                ("promotions.view_couponredemption",),
            ),
            NavItem(
                "Pricing config",
                "price_change",
                "admin:stores_pricingconfig_changelist",
                ("stores.view_pricingconfig",),
            ),
        ),
    ),
    NavSection(
        "Admin settings",
        (
            NavItem(
                "Staff users",
                "badge",
                "admin:accounts_user_changelist",
                ("accounts.view_user",),
                query="is_staff__exact=1",
            ),
            NavItem(
                "Roles & permissions",
                "admin_panel_settings",
                "admin:auth_group_changelist",
                ("auth.view_group",),
            ),
            NavItem(
                "App configuration",
                "settings",
                "admin:cms_appconfig_changelist",
                ("cms.view_appconfig",),
            ),
            NavItem(
                "Login lockouts",
                "lock_person",
                "admin:axes_accessattempt_changelist",
                ("axes.view_accessattempt",),
            ),
            NavItem(
                "Scheduled jobs",
                "schedule",
                "admin:django_celery_beat_periodictask_changelist",
                ("django_celery_beat.view_periodictask",),
            ),
        ),
    ),
)


def visible_sections(user) -> list[dict]:
    """The Ops Console sidebar for `user`: sections with at least one allowed item."""
    sections = []
    for section in MODULES:
        items = [
            {"title": item.title, "icon": item.icon, "url": item.url(), "surface": item.surface}
            for item in section.items
            if item.allowed(user)
        ]
        if items:
            sections.append({"title": section.title, "items": items})
    return sections


def _unfold_permission(item: NavItem, request) -> bool:
    return item.allowed(request.user)


def unfold_sidebar() -> list[dict]:
    """`UNFOLD["SIDEBAR"]["navigation"]`: the same registry in unfold's format. Unfold hides a
    group whose items are all refused."""
    return [
        {
            "title": section.title,
            "separator": index > 0,
            "collapsible": False,
            "items": [
                {
                    "title": item.title,
                    "icon": item.icon,
                    "link": item.lazy_url(),
                    "permission": partial(_unfold_permission, item),
                }
                for item in section.items
            ],
        }
        for index, section in enumerate(MODULES)
    ]
