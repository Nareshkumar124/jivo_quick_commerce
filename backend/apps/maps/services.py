"""Server-side routes for live tracking (T-821). Callers use only these functions:

- `get_provider()`: the configured provider (`MAPS_PROVIDER`: auto / google / haversine).
- `compute_route(origin, destination)`: one route now. Never raises: a provider error falls back
  to the straight line, and a remote provider that failed is skipped for
  `MAPS_PROVIDER_COOLDOWN_SECONDS` (one failure does not turn every ping into a slow timeout).
- `tracked_route(key, origin, destination)`: a moving origin (the rider). Cached in Redis under
  `key`; recomputed only when the rider moved more than `MAPS_ROUTE_RECOMPUTE_DISTANCE_M` or the
  route is older than `MAPS_ROUTE_MAX_AGE_SECONDS`, and never more often than
  `MAPS_ROUTE_MIN_INTERVAL_SECONDS` (unless it was computed at the destination). In between,
  the cached route's distance and duration are scaled by the rider's straight-line progress.
  `fresh` says whether it was just computed.
- `fixed_route(key, origin, destination)`: a leg that does not move (store -> drop), cached for
  `MAPS_ROUTE_CACHE_SECONDS`.
- `geocode(address)` / `reverse_geocode(lat, lng)`: optional helpers, None when unknown or on
  any error (the apps use the platform geocoder, DL-80).

Redis is a cache here: when it is down the route is computed without it. Logs carry the key and
the reason only, never coordinates or addresses.
"""

import logging
from dataclasses import dataclass
from datetime import UTC, datetime

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from apps.maps.providers import (
    GoogleMapsProvider,
    HaversineProvider,
    LatLng,
    MapsProvider,
    MapsProviderError,
    Route,
    straight_route,
)
from apps.stores.services import haversine_km

logger = logging.getLogger(__name__)

COOLDOWN_KEY = "maps:provider-down:{name}"
ROUTE_KEY = "maps:route:{key}"
# Two points closer than this are the same point (cache comparisons, ~1 m).
SAME_POINT_M = 1.0


@dataclass(frozen=True)
class TrackedRoute:
    route: Route
    computed_at: datetime
    fresh: bool  # computed by this call (else: the cached route, scaled)


def get_provider() -> MapsProvider:
    name = (settings.MAPS_PROVIDER or "auto").strip().lower()
    key = (settings.GOOGLE_MAPS_SERVER_KEY or "").strip()
    if name in ("auto", "google") and key:
        return GoogleMapsProvider(key)
    return HaversineProvider()


def _meters(a: LatLng, b: LatLng) -> float:
    return haversine_km(a[0], a[1], b[0], b[1]) * 1000


def _cache_get(key: str):
    try:
        return cache.get(key)
    except Exception:
        logger.warning("maps: cache read failed for %s", key)
        return None


def _cache_set(key: str, value, timeout: int) -> None:
    try:
        cache.set(key, value, timeout)
    except Exception:
        logger.warning("maps: cache write failed for %s", key)


def _cooling_down(provider: MapsProvider) -> bool:
    return bool(_cache_get(COOLDOWN_KEY.format(name=provider.name)))


def compute_route(origin: LatLng, destination: LatLng, provider: MapsProvider | None = None):
    """One route now (see the module doc). Always returns a `Route`."""
    provider = provider or get_provider()
    if not provider.remote:
        return provider.route(origin, destination)
    if _cooling_down(provider):
        return straight_route(origin, destination)
    try:
        return provider.route(origin, destination)
    except MapsProviderError as exc:
        reason = str(exc)
    except Exception as exc:  # never let a provider bug break tracking
        reason = type(exc).__name__
    logger.warning("maps: %s route failed (%s); straight-line fallback", provider.name, reason)
    _cache_set(COOLDOWN_KEY.format(name=provider.name), 1, settings.MAPS_PROVIDER_COOLDOWN_SECONDS)
    return straight_route(origin, destination)


def _scaled(route: Route, cached_origin: LatLng, origin: LatLng, destination: LatLng) -> Route:
    """The cached route, its distance and duration scaled by the straight-line progress since it
    was computed (the polyline stays: the apps draw it from the rider's marker)."""
    before = _meters(cached_origin, destination)
    now = _meters(origin, destination)
    ratio = now / before if before >= SAME_POINT_M else 1.0
    return Route(
        distance_m=max(0, round(route.distance_m * ratio)),
        duration_s=max(0.0, route.duration_s * ratio),
        polyline=route.polyline,
        provider=route.provider,
        traffic_aware=route.traffic_aware,
    )


def _entry(origin: LatLng, destination: LatLng, route: Route, now: datetime) -> dict:
    return {
        "origin": [origin[0], origin[1]],
        "destination": [destination[0], destination[1]],
        "computed_at": now.timestamp(),
        "route": route.as_dict(),
    }


def tracked_route(key: str, origin: LatLng, destination: LatLng, now=None) -> TrackedRoute:
    """The route from a moving `origin` (see the module doc). `key` names the leg, e.g.
    `task:42:TO_CUSTOMER`."""
    now = now or timezone.now()
    cache_key = ROUTE_KEY.format(key=key)
    entry = _cache_get(cache_key)
    if isinstance(entry, dict):
        try:
            cached_origin = tuple(entry["origin"])
            same_destination = _meters(tuple(entry["destination"]), destination) < SAME_POINT_M
            age = now.timestamp() - float(entry["computed_at"])
            cached = Route.from_dict(entry["route"])
        except (KeyError, TypeError, ValueError):
            same_destination = False
        if same_destination and age >= 0:
            moved = _meters(cached_origin, origin)
            small_move = moved <= settings.MAPS_ROUTE_RECOMPUTE_DISTANCE_M
            # A route computed at its destination cannot be scaled: a real move recomputes it
            # at once (e.g. the rider accepted while standing at the store, then rode off).
            scalable = _meters(cached_origin, destination) >= SAME_POINT_M
            if (age < settings.MAPS_ROUTE_MIN_INTERVAL_SECONDS and (scalable or small_move)) or (
                small_move and age < settings.MAPS_ROUTE_MAX_AGE_SECONDS
            ):
                computed_at = datetime.fromtimestamp(float(entry["computed_at"]), tz=UTC)
                return TrackedRoute(
                    route=_scaled(cached, cached_origin, origin, destination),
                    computed_at=computed_at,
                    fresh=False,
                )
    route = compute_route(origin, destination)
    _cache_set(
        cache_key, _entry(origin, destination, route, now), settings.MAPS_ROUTE_CACHE_SECONDS
    )
    return TrackedRoute(route=route, computed_at=now, fresh=True)


def fixed_route(key: str, origin: LatLng, destination: LatLng, now=None) -> Route:
    """A leg whose ends do not move (store -> drop), cached for MAPS_ROUTE_CACHE_SECONDS."""
    now = now or timezone.now()
    cache_key = ROUTE_KEY.format(key=key)
    entry = _cache_get(cache_key)
    if isinstance(entry, dict):
        try:
            if (
                _meters(tuple(entry["origin"]), origin) < SAME_POINT_M
                and _meters(tuple(entry["destination"]), destination) < SAME_POINT_M
            ):
                return Route.from_dict(entry["route"])
        except (KeyError, TypeError, ValueError):
            pass
    route = compute_route(origin, destination)
    _cache_set(
        cache_key, _entry(origin, destination, route, now), settings.MAPS_ROUTE_CACHE_SECONDS
    )
    return route


def forget(key: str) -> None:
    """Drop a cached route (e.g. a leg that ended)."""
    try:
        cache.delete(ROUTE_KEY.format(key=key))
    except Exception:
        logger.warning("maps: cache delete failed for %s", key)


def geocode(address: str) -> LatLng | None:
    provider = get_provider()
    if not address or not provider.remote or _cooling_down(provider):
        return None
    try:
        return provider.geocode(address)
    except Exception as exc:
        logger.warning("maps: %s geocode failed (%s)", provider.name, type(exc).__name__)
        return None


def reverse_geocode(lat: float, lng: float) -> str | None:
    provider = get_provider()
    if not provider.remote or _cooling_down(provider):
        return None
    try:
        return provider.reverse_geocode(lat, lng)
    except Exception as exc:
        logger.warning("maps: %s reverse geocode failed (%s)", provider.name, type(exc).__name__)
        return None


__all__ = [
    "MapsProviderError",
    "Route",
    "TrackedRoute",
    "compute_route",
    "fixed_route",
    "forget",
    "geocode",
    "get_provider",
    "reverse_geocode",
    "tracked_route",
]
