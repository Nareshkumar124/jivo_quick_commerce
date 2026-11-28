"""Which sign-in methods an app offers (2026-11-28). The switch lives on `cms.AppConfig`
(`customer_login_methods` / `rider_login_methods`: phone, email or both) and is read through the
cached app config (`apps.cms.services.login_methods`)."""

from apps.accounts.choices import AppName, LoginMethod
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError


def methods_for(app: str) -> list[str]:
    from apps.cms.services import login_methods

    return login_methods(AppName(app))


def ensure_login_method(app: str, method: str) -> None:
    """403 `LOGIN_METHOD_DISABLED` when `method` is switched off for `app`. `details.methods`
    lists what the app may use instead (same body as `GET /auth/methods/`)."""
    methods = methods_for(app)
    if method not in methods:
        raise ApiError(
            ErrorCode.LOGIN_METHOD_DISABLED,
            details={"app": str(app), "method": LoginMethod(method).value, "methods": methods},
        )
