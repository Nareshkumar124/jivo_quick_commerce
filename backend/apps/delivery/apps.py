from django.apps import AppConfig


class DeliveryConfig(AppConfig):
    name = "apps.delivery"
    label = "delivery"
    verbose_name = "Riders & delivery"

    def ready(self) -> None:
        from apps.delivery import (
            checks,  # noqa: F401 - registers the system checks
            live,  # noqa: F401 - task changes to the live sockets (T-612)
        )
