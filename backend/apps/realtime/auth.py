"""Socket authentication (06 §4): the access JWT from the first message or the subprotocol, with
the same checks as the REST API (`apps.accounts.authentication.JWTAuthentication`: signature,
expiry, token type, active and not deleted). Never from the URL."""

from dataclasses import dataclass
from datetime import UTC, datetime

from rest_framework.exceptions import AuthenticationFailed
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

from apps.accounts.authentication import JWTAuthentication
from apps.realtime.contract import SUBPROTOCOL, TOKEN_SUBPROTOCOL_PREFIX


@dataclass(frozen=True)
class SocketIdentity:
    user: object
    app: str | None
    expires_at: datetime | None


def authenticate_token(raw: str) -> SocketIdentity | None:
    """The token's user, or None for anything invalid. Runs the ORM: call it from a thread."""
    if not isinstance(raw, str) or not raw or len(raw) > 4096:
        return None
    backend = JWTAuthentication()
    try:
        token = backend.get_validated_token(raw.encode())
        user = backend.get_user(token)
    except (InvalidToken, TokenError, AuthenticationFailed):
        return None
    exp = token.get("exp")
    expires_at = datetime.fromtimestamp(exp, UTC) if isinstance(exp, int | float) else None
    return SocketIdentity(user=user, app=token.get("app"), expires_at=expires_at)


def token_from_subprotocols(subprotocols) -> tuple[str | None, bool]:
    """`(token, offered_jivo_v1)` from the offered Sec-WebSocket-Protocol values."""
    token = None
    offered = False
    for value in subprotocols or ():
        if value == SUBPROTOCOL:
            offered = True
        elif value.startswith(TOKEN_SUBPROTOCOL_PREFIX) and token is None:
            token = value[len(TOKEN_SUBPROTOCOL_PREFIX) :]
    return token, offered
