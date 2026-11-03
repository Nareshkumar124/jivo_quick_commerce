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


def inventory_change_is_published(inventory) -> bool:
    """Did this `StoreInventory` save change anything the catalog publishes? Compares the
    values before the save (`inventory.loaded_values`) with the new ones (review #6):

    - the availability switch or the price override changed: yes;
    - otherwise only if `availability()` (stock status, orderable quantity, units left) differs.

    So an order reservation that moves `available` from 40 to 39 on an item limited to 5 per
    order does not empty the store's catalog cache (from Phase 3, every order saves rows)."""
    from apps.inventory.services import availability

    before = inventory.loaded_values
    if (
        before["is_available"] != inventory.is_available
        or before["price_override"] != inventory.price_override
    ):
        return True
    if (before["on_hand"], before["reserved"]) == (inventory.on_hand, inventory.reserved):
        return False
    max_qty = inventory.variant.max_qty_per_order

    def published(on_hand: int, reserved: int):
        return availability(
            on_hand=on_hand,
            reserved=reserved,
            is_available=inventory.is_available,
            max_qty_per_order=max_qty,
        )

    return published(before["on_hand"], before["reserved"]) != published(
        inventory.on_hand, inventory.reserved
    )


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
