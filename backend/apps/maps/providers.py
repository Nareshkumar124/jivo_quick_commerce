"""Map providers behind one small interface (T-821), so the backend can switch provider without
touching the tracking code:

- `HaversineProvider`: no network. The straight line x `ETA_ROAD_FACTOR` at `ETA_AVG_SPEED_KMPH`
  (the same terms as the 08 §8 ETA), with a two-point polyline. Used without a key, in tests and
  while Google is failing.
- `GoogleMapsProvider`: Routes API `computeRoutes` (road distance, traffic-aware duration,
  encoded polyline).

Providers raise `MapsProviderError` on any failure; `apps.maps.services` falls back. Nothing
here logs coordinates, addresses or the key (09 §3: no PII in logs).
"""

import json
import urllib.error
import urllib.request
from dataclasses import asdict, dataclass

from django.conf import settings

from apps.core.http import open_no_redirect
from apps.maps import polyline
from apps.stores.services import haversine_km

LatLng = tuple[float, float]

ROUTES_URL = "https://routes.googleapis.com/directions/v2:computeRoutes"
MAX_RESPONSE_BYTES = 1024 * 1024  # a route answer is a few KB
ROUTES_FIELD_MASK = "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline"


class MapsProviderError(Exception):
    """The provider could not answer (network, HTTP status, quota, bad body, no route)."""


@dataclass(frozen=True)
class Route:
    distance_m: int
    duration_s: float
    polyline: str  # Google encoded polyline (precision 5), origin -> destination
    provider: str  # "google" | "haversine"
    traffic_aware: bool

    def as_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Route":
        return cls(**{key: data[key] for key in cls.__dataclass_fields__})


def straight_route(origin: LatLng, destination: LatLng) -> Route:
    """The fallback route: straight line x road factor, at the 08 §8 average speed. Its duration
    equals `apps.delivery.services.eta.travel_minutes` x 60 exactly."""
    km = haversine_km(origin[0], origin[1], destination[0], destination[1]) * float(
        settings.ETA_ROAD_FACTOR
    )
    speed = max(float(settings.ETA_AVG_SPEED_KMPH), 1.0)
    return Route(
        distance_m=round(km * 1000),
        duration_s=km / speed * 3600,
        polyline=polyline.encode([origin, destination]),
        provider="haversine",
        traffic_aware=False,
    )


class MapsProvider:
    name = "base"
    remote = False  # True: calls a paid network API (results are cached and throttled)

    def route(self, origin: LatLng, destination: LatLng) -> Route:
        raise NotImplementedError


class HaversineProvider(MapsProvider):
    name = "haversine"

    def route(self, origin: LatLng, destination: LatLng) -> Route:
        return straight_route(origin, destination)


def _parse_duration(value) -> float:
    """Routes API durations are strings like "754s"."""
    if not isinstance(value, str) or not value.endswith("s"):
        raise MapsProviderError("bad duration")
    try:
        return float(value[:-1])
    except ValueError as exc:
        raise MapsProviderError("bad duration") from exc


class GoogleMapsProvider(MapsProvider):
    name = "google"
    remote = True

    def __init__(self, key: str, timeout: float | None = None, travel_mode: str | None = None):
        if not key:
            raise MapsProviderError("no key")
        self._key = key
        self.timeout = timeout if timeout is not None else settings.MAPS_HTTP_TIMEOUT_SECONDS
        self.travel_mode = travel_mode or settings.MAPS_TRAVEL_MODE

    def _send(self, request: urllib.request.Request) -> dict:
        try:
            with open_no_redirect(request, timeout=self.timeout) as response:
                raw = response.read(MAX_RESPONSE_BYTES + 1)
        except urllib.error.HTTPError as exc:
            exc.close()
            # The status only: Google's error body may echo the request.
            raise MapsProviderError(f"HTTP {exc.code}") from None
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise MapsProviderError(type(exc).__name__) from None
        if len(raw) > MAX_RESPONSE_BYTES:
            raise MapsProviderError("response too large")
        try:
            return json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise MapsProviderError("bad JSON") from None

    def route(self, origin: LatLng, destination: LatLng) -> Route:
        body = {
            "origin": {"location": {"latLng": {"latitude": origin[0], "longitude": origin[1]}}},
            "destination": {
                "location": {"latLng": {"latitude": destination[0], "longitude": destination[1]}}
            },
            "travelMode": self.travel_mode,
            "routingPreference": "TRAFFIC_AWARE",
            "polylineEncoding": "ENCODED_POLYLINE",
            "computeAlternativeRoutes": False,
            "languageCode": "en-IN",
            "units": "METRIC",
        }
        request = urllib.request.Request(
            ROUTES_URL,
            data=json.dumps(body).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "X-Goog-Api-Key": self._key,
                "X-Goog-FieldMask": ROUTES_FIELD_MASK,
            },
            method="POST",
        )
        data = self._send(request)
        routes = data.get("routes") if isinstance(data, dict) else None
        if not routes:
            raise MapsProviderError("no route")
        first = routes[0]
        encoded = (first.get("polyline") or {}).get("encodedPolyline")
        if not isinstance(encoded, str) or not encoded:
            encoded = polyline.encode([origin, destination])
        distance = first.get("distanceMeters", 0)  # absent when origin == destination
        if not isinstance(distance, int | float) or distance < 0:
            raise MapsProviderError("bad distance")
        duration = _parse_duration(first.get("duration", "0s"))
        return Route(
            distance_m=int(distance),
            duration_s=duration,
            polyline=encoded,
            provider=self.name,
            traffic_aware=True,
        )
