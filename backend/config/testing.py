"""Test-only Redis isolation for parallel (pytest-xdist) runs. Used by config/settings/test.py and
the root conftest.py; never by local, staging or production settings.

pytest-xdist workers (`PYTEST_XDIST_WORKER` = gw0, gw1, ...) share one test Redis DB
(`TEST_REDIS_DB`). Each worker gets its own key namespace instead of its own DB (DB numbers are
scarce, docs/dev-environment.md):

- the cache `KEY_PREFIX` is the namespace (`jqc-test` serially, `jqc-test-gw0` under xdist);
- the channel layer prefix is `<namespace>:asgi`;
- rate-limit counters (apps.core.ratelimit, raw Redis) are re-keyed under `<namespace>:` by
  conftest.py;
- `cache.clear()` deletes only `<namespace>:*`. Django's RedisCache would `FLUSHDB`, wiping every
  other worker's cache, counters and channel groups mid-test.
"""

import os
import re

from django.core.cache.backends.redis import RedisCache

TEST_REDIS_NAMESPACE_BASE = "jqc-test"
_WORKER_ID = re.compile(r"gw\d+")


def xdist_worker() -> str:
    """The pytest-xdist worker id (`gw0`, ...), or "" in a serial run."""
    worker = os.environ.get("PYTEST_XDIST_WORKER", "")
    if worker and not _WORKER_ID.fullmatch(worker):
        raise ValueError(f"Unexpected PYTEST_XDIST_WORKER value {worker!r}.")
    return worker


def worker_redis_namespace() -> str:
    worker = xdist_worker()
    return f"{TEST_REDIS_NAMESPACE_BASE}-{worker}" if worker else TEST_REDIS_NAMESPACE_BASE


class NamespacedRedisCache(RedisCache):
    """RedisCache whose `clear()` deletes only this cache's `KEY_PREFIX:*` keys, not the DB."""

    _BATCH = 500

    def clear(self) -> bool:
        prefix = self.key_prefix
        if not prefix or any(ch in prefix for ch in "*?[]\\:"):
            raise ValueError("NamespacedRedisCache needs a plain, non-empty KEY_PREFIX.")
        client = self._cache.get_client(None, write=True)
        batch: list[bytes] = []
        for key in client.scan_iter(match=f"{prefix}:*", count=self._BATCH):
            batch.append(key)
            if len(batch) >= self._BATCH:
                client.unlink(*batch)
                batch.clear()
        if batch:
            client.unlink(*batch)
        return True
