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

from django.urls import NoReverseMatch, reverse
from django.utils.functional import lazy

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
    # A 05 §3 capability (apps.ops_console.capabilities) instead of / on top of `perms`.
    capability: str = ""

    def url(self) -> str:
        base = reverse(self.url_name)
        return f"{base}?{self.query}" if self.query else base

    def lazy_url(self):
        """For the unfold sidebar (built at settings time). A target that is not installed
        resolves to "#"; `allowed()` hides such an item anyway."""
        return lazy(self._url_or_hash, str)()

    def _url_or_hash(self) -> str:
        try:
            return self.url()
        except NoReverseMatch:
            return "#"

    def exists(self) -> bool:
        """The target is installed (a module whose backend model is not merged yet is not)."""
        try:
            reverse(self.url_name)
        except NoReverseMatch:
            return False
        return True

    def allowed(self, user) -> bool:
        if not (user.is_active and user.is_staff) or not self.exists():
            return False
        if self.capability:
            from apps.ops_console.capabilities import allowed

            if not allowed(user, self.capability):
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
                "Live order board",
                "view_kanban",
                "ops:live-board",
                surface=OPS,
                capability="live_board",
            ),
            NavItem(
                "Packing console",
                "package_2",
                "ops:packing-index",
                surface=OPS,
                capability="packing",
            ),
            NavItem(
                "Orders",
                "receipt",
                "admin:orders_order_changelist",
                ("orders.view_order",),
            ),
        ),
    ),
    NavSection(
        "Riders",
        (
            NavItem(
                "Dispatch",
                "route",
                "ops:dispatch",
                surface=OPS,
                capability="dispatch",
            ),
            NavItem(
                "Riders",
                "two_wheeler",
                "admin:delivery_rider_changelist",
                ("delivery.view_rider",),
            ),
            NavItem(
                "KYC documents",
                "badge",
                "admin:delivery_riderdocument_changelist",
                ("delivery.view_riderdocument",),
                query="status__exact=PENDING",
            ),
            NavItem(
                "Shifts",
                "schedule",
                "admin:delivery_ridershift_changelist",
                ("delivery.view_ridershift",),
            ),
            NavItem(
                "Delivery tasks",
                "local_shipping",
                "admin:delivery_deliverytask_changelist",
                ("delivery.view_deliverytask",),
            ),
            NavItem(
                "Rider offers",
                "notifications",
                "admin:delivery_deliveryoffer_changelist",
                ("delivery.view_deliveryoffer",),
            ),
            NavItem(
                "Location history",
                "location_on",
                "admin:delivery_riderlocation_changelist",
                ("delivery.view_riderlocation",),
            ),
            # Slice 5.4 (hidden until its services / models are merged: capability service gate,
            # admin URL not installed).
            NavItem(
                "Cash deposits",
                "account_balance_wallet",
                "ops:cash",
                surface=OPS,
                capability="cash_deposit",
            ),
            NavItem(
                "Cash ledger",
                "receipt_long",
                "admin:delivery_ridercashledger_changelist",
                ("delivery.view_ridercashledger",),
            ),
            NavItem(
                "Payouts",
                "payments",
                "ops:payouts",
                surface=OPS,
                capability="payouts",
            ),
            NavItem(
                "Rider earnings",
                "savings",
                "admin:delivery_riderearning_changelist",
                ("delivery.view_riderearning",),
            ),
            NavItem(
                "Earning rules",
                "rule",
                "admin:delivery_earningrule_changelist",
                ("delivery.view_earningrule",),
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
        "Notifications",
        (
            NavItem(
                "Sent notifications",
                "notifications",
                "admin:notifications_notification_changelist",
                ("notifications.view_notification",),
            ),
            NavItem(
                "Notification templates",
                "edit_notifications",
                "admin:notifications_notificationtemplate_changelist",
                ("notifications.view_notificationtemplate",),
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
                "Audit log",
                "history",
                "admin:core_auditlog_changelist",
                ("core.view_auditlog",),
            ),
            NavItem(
                "Admin history",
                "manage_history",
                "admin:admin_logentry_changelist",
                capability="audit_log",
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
