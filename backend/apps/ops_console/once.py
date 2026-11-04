"""One-time form tokens for money actions (QA OBS-P4-01).

A double-submitted refund form (a double tap, a browser retry, the back button) must not reach
the refund service twice. Every rendered money form carries a fresh signed token; the first POST
that presents it consumes it, and any later POST with the same token is refused before the
service is called.

- `new_token(purpose)`: a signed, random token for one rendered form (use as a callable
  `initial`, so each render gets its own).
- `consume(user, purpose, token)`: True exactly once per (user, token). The check-and-set is a
  cache `add` (Redis `SET NX`), so two requests racing with the same token cannot both pass. A
  token that is missing, forged, for another purpose or older than `MAX_AGE` is refused.

This guards the panel's forms; the services stay the authority on what may be refunded.
"""

import secrets

from django.core import signing
from django.core.cache import cache

SALT = "ops-console.once"
MAX_AGE = 6 * 60 * 60  # a form left open longer must be reloaded
FIELD = "once"
MSG_REUSED = "This form was already sent. Reload the page to see the result before trying again."

REFUND_RETRY = "refund-retry"
MANUAL_REFUND = "manual-refund"


def new_token(purpose: str) -> str:
    return signing.dumps({"p": purpose, "n": secrets.token_urlsafe(16)}, salt=SALT)


def consume(user, purpose: str, token: str | None) -> bool:
    if not token or user is None or user.pk is None:
        return False
    try:
        data = signing.loads(token, salt=SALT, max_age=MAX_AGE)
    except signing.BadSignature:  # also SignatureExpired
        return False
    if not isinstance(data, dict) or data.get("p") != purpose or not data.get("n"):
        return False
    key = f"ops-once:{purpose}:{user.pk}:{data['n']}"
    return bool(cache.add(key, 1, timeout=MAX_AGE))
