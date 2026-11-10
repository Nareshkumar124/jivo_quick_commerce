from django.contrib import admin
from django.db import models
from django.shortcuts import redirect
from django.urls import reverse
from unfold.admin import ModelAdmin, TabularInline
from unfold.widgets import UnfoldAdminTextareaWidget

from apps.cms.models import FAQ, AppConfig, AppVersionPolicy, Page


def _https_urls(overrides: dict) -> dict:
    """Unfold's widget overrides plus Django 6's https default for scheme-less URLs."""
    return {
        **overrides,
        models.URLField: {**overrides.get(models.URLField, {}), "assume_scheme": "https"},
    }


class AppVersionPolicyInline(TabularInline):
    """Force-update policy per app and platform: below the minimum, the API answers 426."""

    model = AppVersionPolicy
    formfield_overrides = _https_urls(TabularInline.formfield_overrides)
    extra = 0
    fields = ("app", "platform", "min_supported_version", "latest_version", "store_url")


@admin.register(AppConfig)
class AppConfigAdmin(ModelAdmin):
    """05 §2 CMS & app config: versions per app and platform, maintenance, contacts."""

    inlines = [AppVersionPolicyInline]
    formfield_overrides = _https_urls(ModelAdmin.formfield_overrides)
    readonly_fields = ("updated_at",)
    fieldsets = (
        (
            "Maintenance",
            {
                "fields": ("maintenance", "maintenance_message"),
                "description": (
                    "While on, every app API call answers 503 (MAINTENANCE) and the apps show "
                    "this message. The API applies changes as soon as they are saved."
                ),
            },
        ),
        ("Support", {"fields": ("support_phone", "support_email")}),
        ("Policies", {"fields": ("terms_url", "privacy_url", "refund_url", "terms_version")}),
        (
            "Orders and payments",
            {
                "fields": ("payment_window_minutes",),
                "description": (
                    "How long an online order waits for payment before it fails and its stock "
                    "is released (5 to 60 minutes). Orders already placed keep their window."
                ),
            },
        ),
        (
            "Rider app",
            {
                "fields": (
                    "rider_location_active_interval_seconds",
                    "rider_location_idle_interval_seconds",
                    "rider_location_active_sample_seconds",
                    "rider_location_idle_sample_seconds",
                    "rider_location_max_batch",
                )
            },
        ),
        ("Feature flags", {"fields": ("feature_flags",)}),
        ("Record", {"fields": ("updated_at",)}),
    )

    def changelist_view(self, request, extra_context=None):
        """A singleton: the list page opens the one configuration row."""
        config = AppConfig.load()
        return redirect(reverse("admin:cms_appconfig_change", args=[config.pk]))

    def has_add_permission(self, request) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False


# --------------------------------------------------------------------------- P7: pages and FAQs


@admin.register(Page)
class PageAdmin(ModelAdmin):
    """05 §2 CMS: About, Terms, Privacy, Refund policy (Super Admin only, T-711 PM default; by
    model permissions). `Page.save()` sanitises `body_html` to the allow-list in
    `apps.cms.html`, so whatever is pasted here, only safe markup is stored and served; saving
    refreshes the API cache (`cms.services.invalidate_page`). Changes are in Admin history."""

    list_display = ("title", "slug", "is_published", "updated_at")
    list_filter = ("is_published",)
    search_fields = ("title", "slug")
    ordering = ("slug",)
    readonly_fields = ("updated_at",)
    fields = ("slug", "title", "body_html", "is_published", "updated_at")
    formfield_overrides = {
        **ModelAdmin.formfield_overrides,
        models.TextField: {"widget": UnfoldAdminTextareaWidget(attrs={"rows": 24})},
    }


@admin.register(FAQ)
class FAQAdmin(ModelAdmin):
    """05 §2 Support FAQs per app (Super Admin and Support, T-711 PM default; by model
    permissions). Plain text only (the model validators refuse HTML). Saving refreshes the API
    cache (`cms.services.invalidate_faqs`)."""

    list_display = ("question", "app", "category", "sort_order", "is_active", "updated_at")
    list_editable = ("sort_order", "is_active")
    list_filter = ("app", "is_active", "category")
    search_fields = ("question", "category")
    ordering = ("app", "sort_order", "id")
    fields = ("app", "category", "question", "answer", "sort_order", "is_active")
    list_per_page = 50
