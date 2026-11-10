from django.apps import AppConfig


class PaymentsConfig(AppConfig):
    name = "apps.payments"
    label = "payments"
    verbose_name = "Payments"

    def ready(self) -> None:
        from apps.payments import (
            checks,  # noqa: F401 - registers the system checks
            order_refunds,  # noqa: F401 - settles orders on refund saves
            retention,  # noqa: F401 - registers payments.scrub_payment_payloads (T-814)
        )
