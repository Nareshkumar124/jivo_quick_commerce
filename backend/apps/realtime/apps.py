from django.apps import AppConfig, apps


class RealtimeConfig(AppConfig):
    name = "apps.realtime"
    label = "realtime"
    verbose_name = "Real-time"

    def ready(self) -> None:
        if apps.is_installed("daphne"):
            from apps.realtime import daphne_compat

            daphne_compat.install()  # daphne (runserver) can then send 1009 (BUG-0020)
