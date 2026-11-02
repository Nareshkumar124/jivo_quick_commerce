from django.conf import settings

_ENVIRONMENT_BADGES = {
    "local": ("Local", "info"),
    "test": ("Test", "info"),
    "staging": ("Staging", "warning"),
    "production": ("Production", "danger"),
}


def environment_callback(request) -> list[str] | None:
    """Unfold header badge so staff always know which environment they are editing."""
    badge = _ENVIRONMENT_BADGES.get(settings.APP_ENVIRONMENT)
    return list(badge) if badge else None
