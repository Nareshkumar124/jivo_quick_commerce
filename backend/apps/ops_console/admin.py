"""Audit screens (05 §2 "Audit log", P4 -> P8), both read-only for everyone, superusers included.

1. **Audit log** (`core.AuditLog`, the backend's append-only trail of staff mutations on orders,
   stock, prices, refunds, riders and config; `apps.core.audit.record()`): gated on
   `core.view_auditlog` (Super Admin, Finance). Entries hold ids, statuses, amounts and reason
   codes only (no personal data by contract). The panel shows the actor as a staff name (a
   non-staff actor as "Customer 42"), never the IP address, and searches by record id only.
   Registered only once the model is on this branch.
2. **Admin history** (Django's `LogEntry`): every admin add / change / delete plus what the
   services still record there (customer block / unblock and COD block, store pause / resume).
   Capability `audit_log`. Entries about people are masked for roles without full PII access:
   - `object_repr` of accounts.User / Customer and of stores.StaffStoreAccess (its `str()` is
     "<user phone or email> @ <store>") becomes "<type> <id>";
   - their change message is rebuilt without the related objects' names (a staff-access row
     added on a user page is logged as `Added store access "<phone> @ GGN-01"`).
   Search is by object id only, so a phone can never be probed through the search box.
"""

import json

from django.apps import apps
from django.contrib import admin
from django.contrib.admin.models import ADDITION, CHANGE, DELETION, LogEntry
from django.contrib.auth import get_user_model
from django.db.models import BooleanField, Value
from django.urls import NoReverseMatch, reverse
from django.utils.html import format_html
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.ops_console import capabilities
from apps.ops_console.pii import can_view_full_phone

ACTIONS = {
    ADDITION: ("Added", "success"),
    CHANGE: ("Changed", "info"),
    DELETION: ("Deleted", "danger"),
}
# Records whose text (`object_repr`, related-object names in the change message) can carry a
# person's phone or email.
PERSON_MODELS = frozenset(
    {("accounts", "user"), ("accounts", "customer"), ("stores", "staffstoreaccess")}
)
AUDIT_VIEW = "core.view_auditlog"


class ReadOnlyModelAdmin(ModelAdmin):
    def has_add_permission(self, request) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    def get_actions(self, request):
        return {}

    def get_queryset(self, request):
        # The PII decision travels on each row (admin instances are shared between requests).
        full = Value(can_view_full_phone(request.user), output_field=BooleanField())
        return super().get_queryset(request).annotate(full_pii=full)


def _staff_name(user) -> str:
    if user is None:
        return "System"
    return (user.name or "").strip() or user.email or f"User {user.pk}"


class StaffActorFilter(admin.SimpleListFilter):
    """Staff who have entries (never customers: the list would show their phones)."""

    title = "staff member"
    parameter_name = "actor"
    relation = "logentry"
    field = "user_id"

    def lookups(self, request, model_admin):
        users = (
            get_user_model()
            .objects.filter(is_staff=True, **{f"{self.relation}__isnull": False})
            .distinct()
            .only("pk", "name", "email")
            .order_by("name", "email")
        )
        return [(str(user.pk), _staff_name(user)) for user in users]

    def queryset(self, request, queryset):
        value = self.value()
        if not value:
            return queryset
        if not value.isdigit():
            return queryset.none()
        return queryset.filter(**{self.field: int(value)})


VERBS = {"added": "Added", "changed": "Changed", "deleted": "Deleted"}


def masked_change_message(entry) -> str:
    """The admin's structured change message without related objects' names: `Added store
    access.`, `Changed groups and name.`. Plain-text messages are written by the services and
    hold no personal data by contract (e.g. "Customer blocked ..."), so they stay as they are."""
    try:
        parts = json.loads(entry.change_message)
    except (TypeError, ValueError):
        return entry.change_message or ""
    if not isinstance(parts, list):
        return ""
    lines = []
    for part in parts:
        if not isinstance(part, dict):
            continue
        for key, detail in part.items():
            verb = VERBS.get(key)
            if verb is None or not isinstance(detail, dict):
                continue
            if key == "changed" and "name" not in detail:
                fields = detail.get("fields") or []
                lines.append(f"{verb} {' and '.join(str(f) for f in fields)}." if fields else "")
            else:
                lines.append(f"{verb} {detail.get('name', 'a related record')}.")
    return " ".join(line for line in lines if line) or "No fields changed."


def _masked(entry) -> bool:
    content_type = entry.content_type
    key = (content_type.app_label, content_type.model) if content_type else None
    return key in PERSON_MODELS and not getattr(entry, "full_pii", False)


@admin.register(LogEntry)
class AdminHistoryAdmin(ReadOnlyModelAdmin):
    list_display = ("action_time", "actor", "action_badge", "record_type", "record", "summary")
    list_display_links = ("action_time",)
    list_filter = (
        "action_flag",
        StaffActorFilter,
        "content_type",
        ("action_time", admin.DateFieldListFilter),
    )
    list_select_related = ("user", "content_type")
    search_fields = ("object_id",)
    search_help_text = "Record id"
    ordering = ("-action_time", "-id")
    list_per_page = 100
    show_full_result_count = False
    fields = ("action_time", "actor", "action_badge", "record_type", "record", "summary")
    readonly_fields = fields

    def has_module_permission(self, request) -> bool:
        return capabilities.allowed(request.user, capabilities.AUDIT_LOG)

    def has_view_permission(self, request, obj=None) -> bool:
        return capabilities.allowed(request.user, capabilities.AUDIT_LOG)

    @display(description="Staff member")
    def actor(self, obj) -> str:
        return _staff_name(obj.user)

    @display(description="Action", ordering="action_flag", label=dict(ACTIONS.values()))
    def action_badge(self, obj) -> str:
        return ACTIONS.get(obj.action_flag, (str(obj.action_flag), "info"))[0]

    @display(description="Record type", ordering="content_type")
    def record_type(self, obj) -> str:
        content_type = obj.content_type
        return content_type.name.capitalize() if content_type else "-"

    @display(description="Record")
    def record(self, obj) -> str:
        if _masked(obj):
            text = f"{obj.content_type.name.capitalize()} {obj.object_id}"
        else:
            text = obj.object_repr or f"#{obj.object_id}"
        url = obj.get_admin_url() if obj.action_flag != DELETION else None
        if url:
            return format_html(
                '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>', url, text
            )
        return text

    @display(description="What changed")
    def summary(self, obj) -> str:
        message = masked_change_message(obj) if _masked(obj) else obj.get_change_message()
        return message or "-"


# --------------------------------------------------------------------------- core.AuditLog


def _object_link(object_type: str, object_id: str) -> str:
    """`orders.order` + id -> a link to the record's admin page (which checks its own access)."""
    app_label, _, model = (object_type or "").partition(".")
    text = f"{object_type} {object_id}"
    try:
        url = reverse(f"admin:{app_label}_{model}_change", args=[object_id])
    except NoReverseMatch:
        return text
    return format_html(
        '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>', url, text
    )


class AuditActorFilter(StaffActorFilter):
    relation = "audit_entries"
    field = "actor_id"


def _changes_text(changes) -> str:
    if not isinstance(changes, dict) or not changes:
        return "-"
    return ", ".join(f"{key}: {value}" for key, value in changes.items())


class AuditLogAdmin(ReadOnlyModelAdmin):
    list_display = ("created_at", "actor_name", "action", "record", "changes_text")
    list_display_links = ("created_at",)
    list_filter = (
        "action",
        AuditActorFilter,
        "object_type",
        ("created_at", admin.DateFieldListFilter),
    )
    list_select_related = ("actor",)
    search_fields = ("object_id",)
    search_help_text = "Record id"
    ordering = ("-created_at", "-id")
    list_per_page = 100
    show_full_result_count = False
    fields = ("created_at", "actor_name", "action", "record", "changes_text")
    readonly_fields = fields  # never `ip`

    def _allowed(self, request) -> bool:
        user = request.user
        return bool(user.is_active and user.is_staff and user.has_perm(AUDIT_VIEW))

    def has_module_permission(self, request) -> bool:
        return self._allowed(request)

    def has_view_permission(self, request, obj=None) -> bool:
        return self._allowed(request)

    @display(description="By")
    def actor_name(self, obj) -> str:
        actor = obj.actor
        if actor is None:
            return "System"
        if actor.is_staff or actor.is_superuser:
            return _staff_name(actor)
        return f"Customer {actor.pk}"  # never a customer's name or phone

    @display(description="Record")
    def record(self, obj) -> str:
        return _object_link(obj.object_type, obj.object_id)

    @display(description="Details")
    def changes_text(self, obj) -> str:
        return _changes_text(obj.changes)


def _register_audit_log() -> None:
    try:
        model = apps.get_model("core", "AuditLog")
    except LookupError:  # the backend's Phase 4 model is not on this branch yet
        return
    if not admin.site.is_registered(model):
        admin.site.register(model, AuditLogAdmin)


_register_audit_log()


def _unregister_otp_admins() -> None:
    """django-otp registers admins that show device keys (the TOTP secret, recovery codes).
    Devices are managed only through the enrolment pages and the Super Admin reset action."""
    from django_otp.plugins.otp_static.models import StaticDevice
    from django_otp.plugins.otp_totp.models import TOTPDevice

    for model in (TOTPDevice, StaticDevice):
        if admin.site.is_registered(model):
            admin.site.unregister(model)


_unregister_otp_admins()
