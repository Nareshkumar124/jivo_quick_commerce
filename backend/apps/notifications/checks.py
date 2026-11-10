from django.conf import settings
from django.core.checks import Error, register

# Log or keep push texts (which can hold a delivery OTP): local development and tests only.
DEV_PUSH_BACKENDS = frozenset(
    {
        "apps.notifications.push.ConsolePushBackend",
        "apps.notifications.push.LocmemPushBackend",
    }
)


@register()
def check_push_backend(app_configs, **kwargs):
    """Code review of f08c329: deployed environments never use a push backend that logs or keeps
    message texts (like payments.E001 for the fake gateway). No opt-in."""
    from apps.payments.gateways import DEPLOYED_ENVIRONMENTS

    path = getattr(settings, "PUSH_BACKEND", "")
    environment = settings.APP_ENVIRONMENT
    if environment in DEPLOYED_ENVIRONMENTS and path in DEV_PUSH_BACKENDS:
        return [
            Error(
                f"PUSH_BACKEND {path.rsplit('.', 1)[-1]} is for local development and tests and "
                f"is not allowed in {environment}.",
                hint=(
                    "Use apps.notifications.push.DisabledPushBackend (the default) until the FCM "
                    "backend exists (D-19)."
                ),
                id="notifications.E001",
            )
        ]
    return []
