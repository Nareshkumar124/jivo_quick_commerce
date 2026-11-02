"""Admin for accounts: 05 §2 "Users & roles" (Super Admin) and "Customers" (Super Admin, Ops,
Support). Permissions follow 05 §3 through the Groups synced by `apps.accounts.roles`."""

from django.contrib import admin, messages
from django.contrib.admin import helpers
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group
from django.db.models import Count, Q
from django.template.response import TemplateResponse
from django.utils.html import format_html_join
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import action, display
from unfold.forms import AdminPasswordChangeForm

from apps.accounts import roles
from apps.accounts.forms import UserChangeForm, UserCreationForm
from apps.accounts.models import Address, Customer, Device, User
from apps.accounts.services.auth import anonymise_user, revoke_all_tokens
from apps.ops_console import status
from apps.ops_console.pii import can_view_full_phone
from apps.ops_console.selectors import CUSTOMER_STATUS_FILTERS

# --------------------------------------------------------------------------- roles (Groups)

admin.site.unregister(Group)


def is_managed_role(group: Group) -> bool:
    """The seven 05 §3 roles: their permissions are reset by `sync_roles()` on every migrate."""
    return group.name in roles.ROLE_PERMISSIONS


@admin.register(Group)
class GroupAdmin(BaseGroupAdmin, ModelAdmin):
    """Roles. The seven 05 §3 roles are read-only here: `apps.accounts.roles.sync_roles()` sets
    their permissions after every migrate, so edits made in the admin would be silently lost.
    Change them in code (a backend change). Other groups stay editable."""

    list_display = ("name", "kind", "member_count", "permission_count")
    search_fields = ("name",)
    ordering = ("name",)

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(
                members=Count("user", filter=Q(user__is_active=True), distinct=True),
                permission_total=Count("permissions", distinct=True),
            )
        )

    @display(description="Kind", label={"Managed by code": "info", "Custom": "warning"})
    def kind(self, obj) -> str:
        return "Managed by code" if is_managed_role(obj) else "Custom"

    @display(description="Active members", ordering="members")
    def member_count(self, obj) -> int:
        return obj.members

    @display(description="Permissions", ordering="permission_total")
    def permission_count(self, obj) -> int:
        return obj.permission_total

    def get_fields(self, request, obj=None):
        if obj is not None and is_managed_role(obj):
            return ("name", "managed_note", "permission_summary")
        return super().get_fields(request, obj)

    def get_readonly_fields(self, request, obj=None):
        if obj is not None and is_managed_role(obj):
            return ("name", "managed_note", "permission_summary")
        return super().get_readonly_fields(request, obj)

    def has_delete_permission(self, request, obj=None) -> bool:
        if obj is not None and is_managed_role(obj):
            return False
        return super().has_delete_permission(request, obj)

    def get_actions(self, request):
        # Bulk delete could remove a managed role; custom groups are deleted one by one.
        actions = super().get_actions(request)
        actions.pop("delete_selected", None)
        return actions

    @display(description="Managed")
    def managed_note(self, obj) -> str:
        return (
            "This role is defined in code (apps/accounts/roles.py) and re-synced after every "
            "deployment. Its permissions cannot be edited here; assign people to it from Staff "
            "users."
        )

    @display(description="Permissions")
    def permission_summary(self, obj) -> str:
        by_app: dict[str, list[str]] = {}
        for perm in obj.permissions.select_related("content_type").order_by(
            "content_type__app_label", "content_type__model", "codename"
        ):
            by_app.setdefault(perm.content_type.app_label, []).append(perm.name)
        if not by_app:
            return "No permissions."
        return format_html_join(
            "",
            "<p class='mb-2'><strong>{}</strong> ({}): {}</p>",
            ((app, len(names), ", ".join(names)) for app, names in sorted(by_app.items())),
        )


# --------------------------------------------------------------------------- staff users


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    """Every account (Super Admin only). The sidebar's "Staff users" link opens it filtered to
    staff. Customers are managed in the Customers admin below."""

    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm

    list_display = (
        "id",
        "email",
        "phone",
        "name",
        "role_list",
        "is_staff",
        "is_superuser",
        "is_active",
        "last_login",
    )
    list_display_links = ("id", "email", "phone")
    list_filter = ("is_staff", "is_superuser", "is_active", "groups")
    search_fields = ("phone", "email", "name")
    search_help_text = "Email, phone or name"
    ordering = ("-created_at",)
    list_per_page = 50
    readonly_fields = ("auth_id", "last_login", "created_at", "updated_at", "deleted_at")
    filter_horizontal = ("groups", "user_permissions")

    fieldsets = (
        (None, {"fields": ("phone", "email", "password")}),
        ("Profile", {"fields": ("name", "marketing_opt_in")}),
        (
            "Roles and access",
            {
                "fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions"),
                "description": (
                    "Staff need “Staff status” and one role (group) from 05 §3. Prefer roles "
                    "over individual permissions. Store assignment arrives with stores."
                ),
            },
        ),
        ("Jivo Auth (reserved)", {"fields": ("auth_id",)}),
        ("Dates", {"fields": ("last_login", "created_at", "updated_at", "deleted_at")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "phone", "name", "usable_password", "password1", "password2"),
            },
        ),
    )

    def get_queryset(self, request):
        return super().get_queryset(request).prefetch_related("groups")

    @display(description="Roles")
    def role_list(self, obj) -> str:
        return ", ".join(sorted(group.name for group in obj.groups.all())) or "-"


# --------------------------------------------------------------------------- customers


class CustomerDataInline(TabularInline):
    """Read-only rows that belong to the customer. Visible to whoever may view the customer in
    full (05 §3 "Customers (PII)"); roles get no separate address/device permissions."""

    extra = 0
    can_delete = False
    show_change_link = False

    def has_view_permission(self, request, obj=None) -> bool:
        return can_view_full_phone(request.user)

    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False


class AddressInline(CustomerDataInline):
    model = Address
    fields = ("label", "house", "building_street", "area", "city", "pincode", "is_default")
    readonly_fields = fields
    verbose_name_plural = "Saved addresses"

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_deleted=False)


class DeviceInline(CustomerDataInline):
    """Which app builds the customer uses (support questions, force-update checks). The push
    token is never shown."""

    model = Device
    fields = ("app", "platform", "app_version", "is_active", "last_seen_at")
    readonly_fields = fields
    verbose_name_plural = "Devices"


class CustomerStatusFilter(admin.SimpleListFilter):
    title = "status"
    parameter_name = "status"

    def lookups(self, request, model_admin):
        return [(code, badge.label) for code, badge in status.BADGES[status.CUSTOMER].items()]

    def queryset(self, request, queryset):
        condition = CUSTOMER_STATUS_FILTERS.get(self.value() or "")
        return queryset.filter(condition) if condition is not None else queryset


_STATUS_LABELS = {badge.label: badge.tone for badge in status.BADGES[status.CUSTOMER].values()}


@admin.register(Customer)
class CustomerAdmin(ModelAdmin):
    """05 §2 Customers: list/search by phone or name, addresses, block/unblock, anonymise on
    deletion request. Read-only except through the actions (no edit of staff fields).

    Orders (Phase 4) and tickets (Phase 7) are added to the detail page with their phases.
    """

    list_display = (
        "id",
        "name",
        "phone",
        "email",
        "status_badge",
        "address_count",
        "created_at",
        "last_login",
    )
    list_display_links = ("id", "name")
    list_filter = (
        CustomerStatusFilter,
        ("created_at", admin.DateFieldListFilter),
        "marketing_opt_in",
    )
    search_fields = ("phone", "name", "email")
    search_help_text = "Phone (any part), name or email"
    ordering = ("-created_at",)
    list_per_page = 50
    show_full_result_count = False  # one COUNT less on big lists
    inlines = [AddressInline, DeviceInline]
    actions = ["block", "unblock", "anonymise_now"]
    fieldsets = (
        ("Customer", {"fields": ("name", "phone", "email", "status_badge")}),
        (
            "Account",
            {
                "fields": (
                    "is_active",
                    "created_at",
                    "last_login",
                    "deleted_at",
                    "deletion_reason",
                    "anonymised_at",
                )
            },
        ),
        ("Consent", {"fields": ("marketing_opt_in", "terms_version", "terms_accepted_at")}),
    )

    def get_queryset(self, request):
        return (
            super()
            .get_queryset(request)
            .annotate(live_addresses=Count("addresses", filter=Q(addresses__is_deleted=False)))
        )

    # 05 §3 "Customers (PII)": this screen shows customers in full (phone in the title,
    # breadcrumbs and search), so only roles with full PII access open it, even if a "limited"
    # role (Store Manager, Store Staff) is ever granted a customer permission. Limited roles
    # see a name and a masked phone on orders (Phase 4, `ops_console.pii`).
    def has_view_permission(self, request, obj=None) -> bool:
        return can_view_full_phone(request.user) and super().has_view_permission(request, obj)

    def has_change_permission(self, request, obj=None) -> bool:
        return can_view_full_phone(request.user) and super().has_change_permission(request, obj)

    def get_readonly_fields(self, request, obj=None):
        return [name for _title, options in self.fieldsets for name in options["fields"]]

    @display(description="Status", label=_STATUS_LABELS)
    def status_badge(self, obj) -> str:
        return status.BADGES[status.CUSTOMER][status.customer_status(obj)].label

    @display(description="Addresses", ordering="live_addresses")
    def address_count(self, obj) -> int:
        return obj.live_addresses

    def has_add_permission(self, request) -> bool:
        return False  # customers sign up in the app

    def has_delete_permission(self, request, obj=None) -> bool:
        return False  # deletion is the anonymisation flow (07 §4)

    @action(description="Block: deactivate and sign out everywhere", permissions=["change"])
    def block(self, request, queryset):
        count = 0
        for customer in queryset.filter(is_active=True):
            customer.is_active = False
            customer.save(update_fields=["is_active", "updated_at"])
            revoke_all_tokens(customer)
            count += 1
        self.message_user(request, f"Blocked {count} customer(s).", messages.SUCCESS)

    @action(description="Unblock", permissions=["change"])
    def unblock(self, request, queryset):
        count = queryset.filter(is_active=False, anonymised_at__isnull=True).update(is_active=True)
        self.message_user(request, f"Unblocked {count} customer(s).", messages.SUCCESS)

    @action(description="Anonymise now (deletion requested only)", permissions=["change"])
    def anonymise_now(self, request, queryset):
        """Irreversible, so it asks for confirmation first (like Django's bulk delete)."""
        eligible = queryset.filter(deleted_at__isnull=False, anonymised_at__isnull=True)
        if request.POST.get("confirm") != "yes":
            context = {
                **self.admin_site.each_context(request),
                "title": "Anonymise customers",
                "opts": self.model._meta,
                "eligible": list(eligible.order_by("deleted_at")),
                "skipped": queryset.count() - eligible.count(),
                "queryset": queryset,
                "action_checkbox_name": helpers.ACTION_CHECKBOX_NAME,
            }
            request.current_app = self.admin_site.name
            return TemplateResponse(
                request, "admin/accounts/customer/anonymise_confirmation.html", context
            )
        ids = list(eligible.values_list("pk", flat=True))
        count = sum(anonymise_user(pk) for pk in ids)
        self.message_user(request, f"Anonymised {count} customer(s).", messages.SUCCESS)
        return None
