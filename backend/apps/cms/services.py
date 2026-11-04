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


# --------------------------------------------------------------------------- P7: pages and FAQs
# Public, read-mostly content: the API body is cached per slug / per app and dropped whenever a
# page or FAQ is saved or deleted (apps.cms.apps). Like the app config, the cache is best-effort.

PAGE_CACHE_SECONDS = 300
FAQ_CACHE_SECONDS = 300
PAGE_CACHE_KEY = "cms:page:v1:{slug}"
FAQ_CACHE_KEY = "cms:faqs:v1:{app}"
_MISSING = "__missing__"  # cached "no such page", so unknown slugs do not hit the DB each time


def _cache_get(key: str):
    try:
        return cache.get(key)
    except redis.RedisError:
        logger.warning("CMS cache unavailable; reading from the database", exc_info=True)
        return None


def _cache_set(key: str, value, seconds: int) -> None:
    try:
        cache.set(key, value, seconds)
    except redis.RedisError:
        logger.warning("CMS cache unavailable; not caching", exc_info=True)


def _cache_delete_many(keys: list[str]) -> None:
    try:
        cache.delete_many(keys)
    except redis.RedisError:
        logger.warning("CMS cache unavailable; could not invalidate", exc_info=True)


def page_body(slug: str) -> dict | None:
    """`{slug, title, html, updated_at}` of a published page, or None (404)."""
    from apps.cms.html import sanitize_html
    from apps.cms.models import Page

    key = PAGE_CACHE_KEY.format(slug=slug)
    cached = _cache_get(key)
    if cached == _MISSING:
        return None
    if cached is not None:
        return cached
    page = Page.objects.filter(slug=slug, is_published=True).first()
    if page is None:
        _cache_set(key, _MISSING, PAGE_CACHE_SECONDS)
        return None
    body = {
        "slug": page.slug,
        "title": page.title,
        # Already sanitised on save; again here in case a row was written around save().
        "html": sanitize_html(page.body_html),
        "updated_at": page.updated_at,
    }
    _cache_set(key, body, PAGE_CACHE_SECONDS)
    return body


def faq_list(app: str) -> list[dict]:
    """Active FAQs of one app, grouped by category (categories by their smallest `sort_order`,
    then name; entries by `sort_order`, then id)."""
    from apps.cms.models import FAQ

    key = FAQ_CACHE_KEY.format(app=app)
    cached = _cache_get(key)
    if cached is not None:
        return cached
    rows = list(
        FAQ.objects.filter(app=app, is_active=True)
        .order_by("sort_order", "id")
        .values("id", "category", "question", "answer", "sort_order")
    )
    first_seen: dict[str, int] = {}
    for row in rows:
        first_seen.setdefault(row["category"], row["sort_order"])
    rows.sort(key=lambda row: (first_seen[row["category"]], row["category"]))
    body = [
        {
            "id": row["id"],
            "category": row["category"],
            "question": row["question"],
            "answer": row["answer"],
        }
        for row in rows
    ]
    _cache_set(key, body, FAQ_CACHE_SECONDS)
    return body


def _drop_content_cache(keys: list[str]) -> None:
    _cache_delete_many(keys)
    transaction.on_commit(lambda: _cache_delete_many(keys))


def invalidate_page(sender, instance, **kwargs) -> None:
    """post_save / post_delete of a Page. A renamed slug leaves its old key to expire, so also
    drop the slugs the apps link to."""
    from apps.cms.models import PAGE_SLUGS

    slugs = {instance.slug, *PAGE_SLUGS}
    _drop_content_cache([PAGE_CACHE_KEY.format(slug=slug) for slug in sorted(slugs)])


def invalidate_faqs(sender, instance=None, **kwargs) -> None:
    """post_save / post_delete of a FAQ: drop both apps (an entry may have moved app)."""
    from apps.accounts.choices import AppName

    _drop_content_cache([FAQ_CACHE_KEY.format(app=app) for app in AppName.values])
