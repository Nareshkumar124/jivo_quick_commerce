"""Admin UI settings (django-unfold), imported by `config/settings/base.py`.

Owned by the admin panel track (docs/admin-panel-architecture.md). Must not import models: it is
loaded while settings are read, before the app registry is ready.
"""

from django.urls import reverse_lazy

from apps.ops_console.navigation import unfold_sidebar

UNFOLD = {
    "SITE_TITLE": "Jivo Admin",
    "SITE_HEADER": "Jivo Quick Commerce",
    "SITE_SUBHEADER": "Admin & Ops",
    "SITE_SYMBOL": "local_shipping",
    # Header badge: Local / Test / Staging / Production.
    "ENVIRONMENT": "apps.core.admin.environment_callback",
    "SHOW_HISTORY": True,
    # Switch between the two panel layers (05 intro): /admin/ and /ops/.
    "SITE_DROPDOWN": [
        {"icon": "monitoring", "title": "Ops Console", "link": reverse_lazy("ops:dashboard")},
        {"icon": "database", "title": "Admin", "link": reverse_lazy("admin:index")},
    ],
    "SIDEBAR": {
        "show_search": True,
        # Django's own app list, already filtered by the user's permissions: reaches models that
        # have no module entry (token blacklist, beat schedules, axes logs).
        "show_all_applications": True,
        # Grouped by panel module; each link is shown only to roles allowed by 05 §3.
        "navigation": unfold_sidebar(),
    },
}
