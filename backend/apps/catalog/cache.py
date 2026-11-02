"""Per-store Redis cache for catalog responses (09 §1: home/catalog cached per store, invalidated
on change).

Keys embed two version counters: a global catalog version (bumped by any catalog change) and a
per-store version (stock, availability, price override, store changes). Invalidation = bump,
always after commit, so a concurrent request can never cache pre-commit data under the new key.
Signals cover model saves/deletes (including the admin); services that use `update()` or
`bulk_*` bump explicitly. If Redis is down, everything is served from the database.

Only shared, non-personal bodies are cached: never `store` status (time-dependent) or
`buy_again` (per user). Keys that hold pagination URLs include the request host.
"""

import hashlib
import logging
from collections.abc import Callable
from typing import Any

from django.conf import settings
from django.core.cache import cache
from django.db import transaction

logger = logging.getLogger(__name__)

GLOBAL_VERSION_KEY = "catalog:version"
STORE_VERSION_KEY = "catalog:store:{store_id}:version"


def _version(key: str) -> int:
    value = cache.get(key)
    if value is None:
        cache.add(key, 1, timeout=None)
        value = cache.get(key) or 1
    return int(value)


def _bump(key: str) -> None:
    try:
        cache.add(key, 1, timeout=None)
        cache.incr(key)
    except Exception:  # Redis down: entries expire within CATALOG_CACHE_SECONDS anyway
        logger.warning("catalog cache: could not bump %s", key, exc_info=True)


def bump_global_version() -> None:
    _bump(GLOBAL_VERSION_KEY)


def bump_store_version(store_id: int) -> None:
    _bump(STORE_VERSION_KEY.format(store_id=store_id))


def invalidate_catalog_on_commit(**kwargs) -> None:
    """Signal receiver for catalog models: bump the global version after commit."""
    transaction.on_commit(bump_global_version)


def invalidate_store_on_commit(store_id: int) -> None:
    transaction.on_commit(lambda: bump_store_version(store_id))


def cached(kind: str, store_id: int, parts: tuple, build: Callable[[], Any]) -> Any:
    """`build()` cached under (kind, store, versions, parts). Falls back to `build()` on errors."""
    try:
        versions = (
            _version(GLOBAL_VERSION_KEY),
            _version(STORE_VERSION_KEY.format(store_id=store_id)),
        )
    except Exception:
        logger.warning("catalog cache unavailable; serving from the database", exc_info=True)
        return build()
    digest = hashlib.sha256(repr(parts).encode()).hexdigest()[:32]
    key = f"catalog:{kind}:{store_id}:{versions[0]}:{versions[1]}:{digest}"
    try:
        hit = cache.get(key)
    except Exception:
        logger.warning("catalog cache read failed", exc_info=True)
        return build()
    if hit is not None:
        return hit
    value = build()
    try:
        cache.set(key, value, timeout=settings.CATALOG_CACHE_SECONDS)
    except Exception:
        logger.warning("catalog cache write failed", exc_info=True)
    return value
