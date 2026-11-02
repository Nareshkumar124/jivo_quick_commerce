from django.apps import AppConfig


class OpsConsoleConfig(AppConfig):
    """The Ops Console at /ops/ (05 §1): server-rendered views, HTMX partials and Alpine.js.
    Read-only selectors live here; state changes call the owning app's services."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "apps.ops_console"
    label = "ops_console"
    verbose_name = "Ops Console"
