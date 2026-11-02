"""Fixed-window rate limits as Redis counters (09 §3.1).

    retry_after = hit(OTP_SEND_PER_PHONE_10_MIN, phone)
    if retry_after: raise OtpRateLimited(retry_after)

Identifiers are hashed before they become Redis keys, so phone numbers are never stored in Redis.

Fail-closed: if Redis is unreachable, `hit()` raises RateLimitUnavailable instead of allowing the
event. Callers turn that into 503 SERVICE_UNAVAILABLE (e.g. OTP sends: without counters there is
no SMS-pumping protection, and the SMS task queue lives in the same Redis anyway).
"""

import hashlib
import logging
from dataclasses import dataclass

import redis
from django.conf import settings

logger = logging.getLogger(__name__)

_clients: dict[str, redis.Redis] = {}


class RateLimitUnavailable(Exception):
    """The counter store is unreachable; the limited action must not proceed."""


def _client() -> redis.Redis:
    url = settings.REDIS_URL
    if url not in _clients:
        _clients[url] = redis.Redis.from_url(url, socket_connect_timeout=2, socket_timeout=2)
    return _clients[url]


@dataclass(frozen=True)
class Limit:
    scope: str
    limit: int
    window_seconds: int


def _key(limit: Limit, ident: str) -> str:
    digest = hashlib.sha256(ident.encode()).hexdigest()[:24]
    return f"jqc:rl:{limit.scope}:{digest}"


def hit(limit: Limit, ident: str) -> int:
    """Count one event. Returns 0 if allowed, else the seconds until the window resets."""
    key = _key(limit, ident)
    try:
        pipe = _client().pipeline()
        pipe.set(key, 0, ex=limit.window_seconds, nx=True)
        pipe.incr(key)
        pipe.ttl(key)
        _, count, ttl = pipe.execute()
    except redis.RedisError as exc:
        logger.error("Rate limiter unavailable (scope %s)", limit.scope, exc_info=True)
        raise RateLimitUnavailable(limit.scope) from exc
    if count > limit.limit:
        return max(int(ttl), 1)
    return 0
