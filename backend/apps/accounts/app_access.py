"""Which app's tokens may call which `/api/v1/` endpoint (T-219; 02 §6, 06 §2.1 "App tokens").

The access token's `app` claim is the authority on which app a session belongs to. It is set at
OTP verify from the body `app` and copied into every access token and every rotated refresh
token. `X-App-Name` only names the calling app and must agree with the claim.

`check()` runs for every JWT-authenticated request (`apps.accounts.authentication`), so no view
can skip it, whatever its permission classes:

1. `X-App-Name` names the other app (`customer`/`rider`, parsed like `ClientInfo`): 403
   `PERMISSION_DENIED`, `details.reason` = `APP_HEADER_MISMATCH`. An absent, empty or unknown
   header names no app and is ignored (unknown client-info values are never an error, P0-TC-13).
2. Rider endpoints need a rider-app token, customer endpoints a customer-app token
   (`APP_ONLY_PREFIXES`), else 403 `PERMISSION_DENIED`, `details.reason` = `WRONG_APP_TOKEN`.
   A token without a valid `app` claim fits neither (none is issued; see `issue_tokens`).
3. Every other endpoint is shared: both apps may call it, and the views that keep per-app data
   (inbox, support tickets) scope it by the claim.

Public views (`authentication_classes = []`) never authenticate, so they never run this. Staff
sessions (admin, Ops Console) do not use JWTs and are unaffected. The WebSocket rule
(`/ws/v1/rider/` needs `app` = rider) lives in `apps.realtime.consumers.RiderConsumer`.
"""

from apps.accounts.choices import AppName
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.middleware import ClientInfo

API_PREFIX = "/api/v1/"

# Path prefixes under /api/v1/ that only one app's tokens may call. Every other endpoint is
# shared. 06 §2.1 "App tokens" lists every endpoint group with its class.
APP_ONLY_PREFIXES: tuple[tuple[str, str], ...] = (
    ("rider/", AppName.RIDER),
    ("cart/", AppName.CUSTOMER),
    ("orders/", AppName.CUSTOMER),
    ("payments/", AppName.CUSTOMER),  # the gateway webhook is public (no token), never checked
    ("account/", AppName.CUSTOMER),  # referral (refer a friend), added 2026-11-13
)

REASON_WRONG_APP_TOKEN = "WRONG_APP_TOKEN"  # noqa: S105 - a reason code, not a secret
REASON_APP_HEADER_MISMATCH = "APP_HEADER_MISMATCH"

MSG_WRONG_APP_TOKEN = {
    AppName.RIDER: "This is for the Jivo Rider app. Sign in to the rider app to use it.",
    AppName.CUSTOMER: "This is for the Jivo customer app. Sign in to the customer app to use it.",
}
MSG_APP_HEADER_MISMATCH = (
    "X-App-Name does not match the app this session was signed in to. Sign in again in this app."
)


def required_app(path: str) -> str | None:
    """The only app whose tokens may call `path`, or None for a shared endpoint."""
    if not path.startswith(API_PREFIX):
        return None
    rest = path[len(API_PREFIX) :]
    for prefix, app in APP_ONLY_PREFIXES:
        if rest.startswith(prefix):
            return app
    return None


def token_app(token) -> str | None:
    """The token's `app` claim, or None when it is missing or not an app name."""
    app = token.get("app")
    return app if app in AppName.values else None


def header_app(request) -> str | None:
    """The app `X-App-Name` names (`customer`/`rider`), or None when absent or unknown."""
    info = getattr(request, "client_info", None)  # client_info_middleware
    if info is None:
        info = ClientInfo.from_headers(request.headers)
    return info.app_name


def wrong_app_token_error(required: str, claim: str | None) -> ApiError:
    return ApiError(
        ErrorCode.PERMISSION_DENIED,
        MSG_WRONG_APP_TOKEN[required],
        details={"reason": REASON_WRONG_APP_TOKEN, "required_app": required, "token_app": claim},
    )


def app_header_mismatch_error(header: str, claim: str | None) -> ApiError:
    return ApiError(
        ErrorCode.PERMISSION_DENIED,
        MSG_APP_HEADER_MISMATCH,
        details={"reason": REASON_APP_HEADER_MISMATCH, "header_app": header, "token_app": claim},
    )


def check(request, token) -> None:
    """Raise 403 `PERMISSION_DENIED` unless the token's app may make this request."""
    claim = token_app(token)
    header = header_app(request)
    if header is not None and header != claim:
        raise app_header_mismatch_error(header, claim)
    required = required_app(request.path_info)
    if required is not None and claim != required:
        raise wrong_app_token_error(required, claim)
