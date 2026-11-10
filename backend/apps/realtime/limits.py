"""WebSocket abuse limits (P8 OWASP review L5).

- **Sockets per user:** at most WS_MAX_SOCKETS_PER_USER at once, counted in Redis (a sorted set
  per user of channel name -> lease expiry). A lease lasts WS_SOCKET_LEASE_SECONDS and is
  renewed on auth, ping and re-check, so a socket lost with a crashed server stops counting
  when its lease runs out. Fails open (logged) when Redis is unreachable: the channel layer is
  down then anyway, and refusing every socket would turn a Redis blip into an outage.
- **Bad messages and size:** enforced in the consumers (WS_MAX_BAD_MESSAGES,
  WS_MAX_MESSAGE_BYTES). The ASGI server caps the frame size before the app sees it: uvicorn
  `--ws-max-size` / daphne `--websocket_max_size` (06 §4.1, DevOps).
"""

import logging
import time

from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)


def _key(user_id: int) -> str:
    return cache.make_key(f"ws:sockets:{int(user_id)}")


def _client():
    return cache._cache.get_client(None, write=True)


def acquire(user_id: int, channel_name: str) -> bool:
    """Take a socket slot for `user_id`; False when the user already has the maximum."""
    now = time.time()
    lease = settings.WS_SOCKET_LEASE_SECONDS
    key = _key(user_id)
    try:
        client = _client()
        pipe = client.pipeline()
        pipe.zremrangebyscore(key, "-inf", now)
        pipe.zadd(key, {channel_name: now + lease})
        pipe.zcard(key)
        pipe.expire(key, int(lease) + 60)
        _, _, count, _ = pipe.execute()
        if count > settings.WS_MAX_SOCKETS_PER_USER:
            client.zrem(key, channel_name)
            return False
    except Exception:
        logger.exception("Socket limit check failed for user %s: allowing", user_id)
    return True


def renew(user_id: int, channel_name: str) -> None:
    try:
        lease = settings.WS_SOCKET_LEASE_SECONDS
        client = _client()
        client.zadd(_key(user_id), {channel_name: time.time() + lease}, xx=True)
        client.expire(_key(user_id), int(lease) + 60)
    except Exception:
        logger.exception("Socket lease renewal failed for user %s", user_id)


def release(user_id: int, channel_name: str) -> None:
    try:
        _client().zrem(_key(user_id), channel_name)
    except Exception:
        logger.exception("Socket slot release failed for user %s", user_id)


def count(user_id: int) -> int:
    client = _client()
    client.zremrangebyscore(_key(user_id), "-inf", time.time())
    return int(client.zcard(_key(user_id)))
