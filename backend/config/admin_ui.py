"""Admin UI settings (django-unfold), imported by `config/settings/base.py`.

Owned by the admin panel track (docs/admin-panel-architecture.md). Must not import models: it is
loaded while settings are read, before the app registry is ready.
"""

from django.templatetags.static import static
from django.urls import reverse_lazy

from apps.ops_console.navigation import unfold_sidebar
from config.env import env_str

# Ops live delivery map (05 §1.4, apps/ops_console/live_map.py). OPS_MAP_PROVIDER: "auto" (Google
# Maps JS when GOOGLE_MAPS_WEB_KEY is set, else OpenLayers + OpenStreetMap), "google" or
# "openlayers". GOOGLE_MAPS_WEB_KEY is a *browser* key (Maps JavaScript API only, restricted by
# HTTP referrer in Google Cloud); it is sent to the live map page only, never the server key.
OPS_MAP_PROVIDER = env_str("OPS_MAP_PROVIDER", default="auto")
GOOGLE_MAPS_WEB_KEY = env_str("GOOGLE_MAPS_WEB_KEY", default="")

# Jivo brand (design/incoming/brand-2026-11-23, sizes generated into static/brand/). Callables,
# so `static()` runs per request (manifest-hashed names in production).
BRAND_LOGO = "brand/logo.png"  # dark-green wordmark, 2x of a 40 px header
BRAND_LOGO_WHITE = "brand/logo-white.png"  # the same on dark backgrounds
BRAND_MARK = "brand/mark-64.png"  # round green mark
BRAND_FAVICONS = (
    ("icon", "48x48", "image/x-icon", "brand/favicon.ico"),
    ("icon", "32x32", "image/png", "brand/favicon-32.png"),
    ("icon", "192x192", "image/png", "brand/icon-192.png"),
    ("apple-touch-icon", "180x180", "image/png", "brand/apple-touch-icon.png"),
)
# Jivo green (logo #2E572A as 700); unfold's primary scale, used by /admin/ and /ops/ alike.
BRAND_PRIMARY = {
    "50": "#f2f7f1",
    "100": "#e0ecde",
    "200": "#c2d9be",
    "300": "#9abf94",
    "400": "#6c9f65",
    "500": "#4a8143",
    "600": "#386a32",
    "700": "#2e572a",
    "800": "#274624",
    "900": "#213a1f",
    "950": "#0f1f0e",
}


def _static(path):
    return lambda request: static(path)


UNFOLD = {
    "SITE_TITLE": "Jivo Admin",
    "SITE_HEADER": "Jivo Quick Commerce",
    "SITE_SUBHEADER": "Admin & Ops",
    "SITE_SYMBOL": "local_shipping",
    "SITE_LOGO": {"light": _static(BRAND_LOGO), "dark": _static(BRAND_LOGO_WHITE)},
    "SITE_ICON": {"light": _static(BRAND_MARK), "dark": _static(BRAND_MARK)},
    "SITE_FAVICONS": [
        {"rel": rel, "sizes": sizes, "type": kind, "href": _static(path)}
        for rel, sizes, kind, path in BRAND_FAVICONS
    ],
    "COLORS": {"primary": dict(BRAND_PRIMARY)},
    # Header badge: Local / Test / Staging / Production.
    "ENVIRONMENT": "apps.core.admin.environment_callback",
    "SHOW_HISTORY": True,
    # Switch between the two panel layers (05 intro): /admin/ and /ops/.
    "SITE_DROPDOWN": [
        {"icon": "monitoring", "title": "Ops Console", "link": reverse_lazy("ops:dashboard")},
        {"icon": "database", "title": "Admin", "link": reverse_lazy("admin:index")},
    ],
    "SIDEBAR": {
        # No "Search apps and models" box: the user turned the command search off (2026-11-14).
        # Its popup (and Ctrl+K) is removed by templates/unfold/helpers/command.html.
        "show_search": False,
        # Django's own app list, already filtered by the user's permissions: reaches models that
        # have no module entry (token blacklist, beat schedules, axes logs).
        "show_all_applications": True,
        # Grouped by panel module; each link is shown only to roles allowed by 05 §3.
        "navigation": unfold_sidebar(),
    },
}
