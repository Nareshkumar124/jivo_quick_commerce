from django.contrib import admin
from django.db import models
from django.shortcuts import redirect
from django.urls import reverse
from unfold.admin import ModelAdmin, TabularInline

from apps.cms.models import AppConfig, AppVersionPolicy


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
            "Rider app",
            {
                "fields": (
                    "rider_location_active_interval_seconds",
                    "rider_location_idle_interval_seconds",
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
