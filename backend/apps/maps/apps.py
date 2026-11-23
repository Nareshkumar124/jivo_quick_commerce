from django.apps import AppConfig


class MapsConfig(AppConfig):
    name = "apps.maps"
    label = "maps"
    verbose_name = "Maps (server side)"

    def ready(self) -> None:
        from apps.maps import checks  # noqa: F401 - registers the system checks
