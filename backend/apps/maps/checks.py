from django.conf import settings
from django.core.checks import Warning, register

PROVIDERS = ("auto", "google", "haversine")


@register()
def check_maps_provider(app_configs, **kwargs):
    """T-821: an unknown MAPS_PROVIDER, or "google" without a key, falls back to the straight
    line at runtime; say so at start-up instead of failing silently."""
    provider = (settings.MAPS_PROVIDER or "").strip().lower()
    if provider not in PROVIDERS:
        return [
            Warning(
                f"MAPS_PROVIDER={settings.MAPS_PROVIDER!r} is unknown: routes use the straight "
                "line.",
                hint=f"Use one of {', '.join(PROVIDERS)}.",
                id="maps.W001",
            )
        ]
    if provider == "google" and not settings.GOOGLE_MAPS_SERVER_KEY.strip():
        return [
            Warning(
                "MAPS_PROVIDER=google but GOOGLE_MAPS_SERVER_KEY is empty: routes use the "
                "straight line.",
                hint="Set GOOGLE_MAPS_SERVER_KEY (Routes API enabled, restricted to server IPs).",
                id="maps.W002",
            )
        ]
    return []
