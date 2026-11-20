from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = "apps.core"
    label = "core"
    verbose_name = "Core"

    def ready(self) -> None:
        from apps.core import staticfiles  # noqa: F401 - registers the core.W001 system check
