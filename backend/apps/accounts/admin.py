from django.contrib import admin, messages
from django.contrib.auth.admin import GroupAdmin as BaseGroupAdmin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.contrib.auth.models import Group
from unfold.admin import ModelAdmin, TabularInline
from unfold.decorators import action
from unfold.forms import AdminPasswordChangeForm

from apps.accounts.forms import UserChangeForm, UserCreationForm
from apps.accounts.models import Address, Customer, User
from apps.accounts.services.auth import anonymise_user, revoke_all_tokens

# Re-register Group with Unfold styling (roles per 05 §3 arrive in Phase 1).
admin.site.unregister(Group)


@admin.register(Group)
class GroupAdmin(BaseGroupAdmin, ModelAdmin):
    pass


@admin.register(User)
class UserAdmin(BaseUserAdmin, ModelAdmin):
    form = UserChangeForm
    add_form = UserCreationForm
    change_password_form = AdminPasswordChangeForm

    list_display = ("id", "phone", "email", "name", "is_staff", "is_active", "created_at")
    list_filter = ("is_staff", "is_superuser", "is_active", "groups")
    search_fields = ("phone", "email", "name")
    ordering = ("-created_at",)
    readonly_fields = ("auth_id", "last_login", "created_at", "updated_at", "deleted_at")
    filter_horizontal = ("groups", "user_permissions")

    fieldsets = (
        (None, {"fields": ("phone", "email", "password")}),
        ("Profile", {"fields": ("name", "marketing_opt_in")}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
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


class AddressInline(TabularInline):
    model = Address
    extra = 0
    can_delete = False
    fields = ("label", "house", "building_street", "area", "city", "pincode", "is_default")
    readonly_fields = fields
    show_change_link = False

    def get_queryset(self, request):
        return super().get_queryset(request).filter(is_deleted=False)

    def has_add_permission(self, request, obj=None) -> bool:
        return False


@admin.register(Customer)
class CustomerAdmin(ModelAdmin):
    """05 §2 Customers: list/search by phone or name, addresses, block/unblock, anonymise on
    deletion request. Read-only except through the actions (no edit of staff fields)."""

    list_display = ("id", "phone", "name", "email", "is_active", "deleted_at", "created_at")
    list_filter = ("is_active", ("deleted_at", admin.EmptyFieldListFilter))
    search_fields = ("phone", "name", "email")
    ordering = ("-created_at",)
    inlines = [AddressInline]
    actions = ["block", "unblock", "anonymise_now"]
    fields = (
        "phone",
        "name",
        "email",
        "is_active",
        "marketing_opt_in",
        "terms_version",
        "terms_accepted_at",
        "created_at",
        "last_login",
        "deleted_at",
        "anonymised_at",
    )
    readonly_fields = fields

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
        ids = queryset.filter(deleted_at__isnull=False).values_list("pk", flat=True)
        count = sum(anonymise_user(pk) for pk in list(ids))
        self.message_user(request, f"Anonymised {count} customer(s).", messages.SUCCESS)
