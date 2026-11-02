"""Cached app configuration, read on every app request by the force-update/maintenance guard.

The cache is best-effort (09 §2: Redis holds only cache, broker and ephemeral data). If Redis is
unreachable, the snapshot is read from the database on every request and the API keeps working.
"""

import logging
from dataclasses import dataclass, field

import redis
from django.core.cache import cache
from django.db import transaction

from apps.cms.models import AppConfig

logger = logging.getLogger(__name__)

CACHE_KEY = "cms:app-config:v1"
CACHE_SECONDS = 60


def parse_version(version: str | None) -> tuple[int, ...] | None:
    """`"1.4"` -> `(1, 4, 0, 0)`: padded so versions of different lengths compare correctly."""
    if not version:
        return None
    parts = [int(part) for part in version.split(".")]
    return tuple(parts + [0] * (4 - len(parts)))


@dataclass(frozen=True)
class VersionPolicy:
    min_supported_version: str
    latest_version: str
    store_url: str


@dataclass(frozen=True)
class ConfigSnapshot:
    maintenance: bool
    maintenance_message: str
    support_phone: str
    support_email: str
    terms_url: str
    privacy_url: str
    refund_url: str
    terms_version: str
    rider_location_active_interval_seconds: int
    rider_location_idle_interval_seconds: int
    feature_flags: dict = field(default_factory=dict)
    versions: dict[tuple[str, str], VersionPolicy] = field(default_factory=dict)

    def version_policy(self, app: str | None, platform: str | None) -> VersionPolicy | None:
        if not app or not platform:
            return None
        return self.versions.get((app, platform))


def _build_snapshot() -> ConfigSnapshot:
    config = AppConfig.load()
    return ConfigSnapshot(
        maintenance=config.maintenance,
        maintenance_message=config.maintenance_message,
        support_phone=config.support_phone,
        support_email=config.support_email,
        terms_url=config.terms_url,
        privacy_url=config.privacy_url,
        refund_url=config.refund_url,
        terms_version=config.terms_version,
        rider_location_active_interval_seconds=config.rider_location_active_interval_seconds,
        rider_location_idle_interval_seconds=config.rider_location_idle_interval_seconds,
        feature_flags={str(k): bool(v) for k, v in (config.feature_flags or {}).items()},
        versions={
            (row.app, row.platform): VersionPolicy(
                row.min_supported_version, row.latest_version, row.store_url
            )
            for row in config.versions.all()
        },
    )


def get_app_config() -> ConfigSnapshot:
    try:
        snapshot = cache.get(CACHE_KEY)
    except redis.RedisError:
        logger.warning("App config cache unavailable; reading from the database", exc_info=True)
        return _build_snapshot()
    if snapshot is None:
        snapshot = _build_snapshot()
        try:
            cache.set(CACHE_KEY, snapshot, CACHE_SECONDS)
        except redis.RedisError:
            logger.warning("App config cache unavailable; not caching", exc_info=True)
    return snapshot


def _drop_cached_snapshot() -> None:
    try:
        cache.delete(CACHE_KEY)
    except redis.RedisError:
        # Redis down: nothing is being served from it either; entries expire in CACHE_SECONDS.
        logger.warning("App config cache unavailable; could not invalidate", exc_info=True)


def invalidate_app_config(**kwargs) -> None:
    """Drop the cached snapshot now and again after commit, so a request that re-cached the old
    row before the admin's transaction committed cannot keep it for CACHE_SECONDS."""
    _drop_cached_snapshot()
    transaction.on_commit(_drop_cached_snapshot)
