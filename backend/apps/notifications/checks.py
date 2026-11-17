from django.conf import settings
from django.core.checks import Error, Warning, register

# Log or keep push texts (which can hold a delivery OTP): local development and tests only.
DEV_PUSH_BACKENDS = frozenset(
    {
        "apps.notifications.push.ConsolePushBackend",
        "apps.notifications.push.LocmemPushBackend",
    }
)
FCM_PUSH_BACKEND = "apps.notifications.push.FcmPushBackend"
DISABLED_PUSH_BACKEND = "apps.notifications.push.DisabledPushBackend"
REQUIRED_KEY_FIELDS = ("type", "client_email", "private_key", "token_uri")


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
                    f"Use {FCM_PUSH_BACKEND} with FCM_CREDENTIALS_FILE (D-19), or "
                    "apps.notifications.push.DisabledPushBackend."
                ),
                id="notifications.E001",
            )
        ]
    return []


@register(deploy=True)
def check_push_disabled(app_configs, **kwargs):
    """Code review 2026-11-17: a deployed environment without push (no FCM key) is shown by
    `check --deploy`. A Warning, so a deploy without the key still starts."""
    from apps.payments.gateways import DEPLOYED_ENVIRONMENTS

    environment = settings.APP_ENVIRONMENT
    if environment in DEPLOYED_ENVIRONMENTS and settings.PUSH_BACKEND == DISABLED_PUSH_BACKEND:
        return [
            Warning(
                f"Push notifications are disabled in {environment} (DisabledPushBackend): "
                "customers and riders get no FCM pushes.",
                hint=(
                    "Set FCM_CREDENTIALS_FILE (and leave PUSH_BACKEND empty or "
                    f"{FCM_PUSH_BACKEND})."
                ),
                id="notifications.W001",
            )
        ]
    return []


@register()
def check_fcm_credentials(app_configs, **kwargs):
    """D-19: the FCM backend needs a readable Firebase service-account key file and a project id.
    The message names the setting and the kind of problem only, never the file's contents."""
    if getattr(settings, "PUSH_BACKEND", "") != FCM_PUSH_BACKEND:
        return []
    from apps.notifications.push import read_service_account

    path = getattr(settings, "FCM_CREDENTIALS_FILE", "")
    hint = (
        "Set FCM_CREDENTIALS_FILE to the path of the Firebase service-account JSON key "
        "(a read-only mounted secret file on servers; docs/09 §3)."
    )

    def error(problem: str) -> list[Error]:
        return [Error(f"FCM push: {problem}", hint=hint, id="notifications.E002")]

    if not path:
        return error("FCM_CREDENTIALS_FILE is not set.")
    try:
        info = read_service_account(path)
    except FileNotFoundError:
        return error("the FCM_CREDENTIALS_FILE file does not exist.")
    except OSError as exc:
        return error(f"the FCM_CREDENTIALS_FILE file cannot be read ({type(exc).__name__}).")
    except ValueError:
        return error("the FCM_CREDENTIALS_FILE file is not valid JSON.")
    missing = [key for key in REQUIRED_KEY_FIELDS if not info.get(key)]
    if missing or info.get("type") != "service_account":
        return error(
            "the FCM_CREDENTIALS_FILE file is not a service-account key "
            f"(missing or wrong: {', '.join(missing) or 'type'})."
        )
    if not (getattr(settings, "FCM_PROJECT_ID", "") or info.get("project_id")):
        return error("no project id: the key has no project_id and FCM_PROJECT_ID is not set.")
    return []
