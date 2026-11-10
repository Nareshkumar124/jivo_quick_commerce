from django.conf import settings
from django.core.checks import Error, register


@register()
def check_loadtest_data_allowed(app_configs, **kwargs):
    """T-812: the load-test data commands (`loadtest_seed`, `loadtest_cleanup`) create and delete
    customers, orders and stock movements. They are never allowed in production; staging and
    local need the explicit opt-in LOADTEST_DATA_ALLOWED=true."""
    if getattr(settings, "LOADTEST_DATA_ALLOWED", False) and settings.APP_ENVIRONMENT == (
        "production"
    ):
        return [
            Error(
                "LOADTEST_DATA_ALLOWED must be false in production.",
                hint="Load tests run on staging only (docs/09 §1, loadtest/README.md).",
                id="loadtest.E001",
            )
        ]
    return []
