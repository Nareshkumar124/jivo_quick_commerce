"""T-821 server-side maps: the provider interface, the Google Routes / Geocoding provider (HTTP
mocked, never called for real), the straight-line fallback, the provider cooldown and the route
cache with its recompute throttle."""

import io
import json
import urllib.error
from datetime import timedelta

import pytest
from django.core.cache import cache
from django.core.checks import run_checks
from django.utils import timezone

from apps.delivery.services.eta import travel_minutes
from apps.maps import polyline, providers, services
from apps.maps.providers import GoogleMapsProvider, HaversineProvider, MapsProviderError, Route

STORE = (28.45, 77.05)
DROP = (28.468, 77.05)


@pytest.fixture(autouse=True)
def _clean_cache():
    cache.clear()
    yield
    cache.clear()


class FakeHTTP:
    """Replaces `open_no_redirect`: records requests, answers from a queue."""

    def __init__(self, *answers):
        self.answers = list(answers)
        self.requests = []

    def __call__(self, request, timeout):
        self.requests.append((request, timeout))
        answer = self.answers.pop(0) if len(self.answers) > 1 else self.answers[0]
        if isinstance(answer, BaseException):
            raise answer
        return io.BytesIO(answer if isinstance(answer, bytes) else json.dumps(answer).encode())


def google_route(distance=2600, duration="540s", encoded="_p~iF~ps|U_ulLnnqC"):
    return {
        "routes": [
            {
                "distanceMeters": distance,
                "duration": duration,
                "polyline": {"encodedPolyline": encoded},
            }
        ]
    }


@pytest.fixture
def http(monkeypatch):
    def install(*answers):
        fake = FakeHTTP(*answers)
        monkeypatch.setattr(providers, "open_no_redirect", fake)
        return fake

    return install


@pytest.fixture
def google(settings):
    settings.MAPS_PROVIDER = "auto"
    settings.GOOGLE_MAPS_SERVER_KEY = "test-key-not-real"
    return settings


# --------------------------------------------------------------------------- polyline


def test_polyline_round_trip_matches_googles_reference():
    # Google's documented example.
    points = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]
    assert polyline.encode(points) == "_p~iF~ps|U_ulLnnqC_mqNvxq`@"
    assert polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@") == points


# --------------------------------------------------------------------------- providers


def test_haversine_route_equals_the_08_eta_terms():
    route = HaversineProvider().route(STORE, DROP)
    assert route.provider == "haversine"
    assert not route.traffic_aware
    assert route.duration_s / 60 == pytest.approx(travel_minutes(*STORE, *DROP))
    assert route.distance_m == pytest.approx(2600, rel=0.05)  # ~2 km x 1.3
    assert polyline.decode(route.polyline) == [STORE, DROP]


def test_get_provider_selection(settings):
    settings.MAPS_PROVIDER = "auto"
    settings.GOOGLE_MAPS_SERVER_KEY = ""
    assert isinstance(services.get_provider(), HaversineProvider)
    settings.GOOGLE_MAPS_SERVER_KEY = "k"
    assert isinstance(services.get_provider(), GoogleMapsProvider)
    settings.MAPS_PROVIDER = "haversine"
    assert isinstance(services.get_provider(), HaversineProvider)
    settings.MAPS_PROVIDER = "google"
    settings.GOOGLE_MAPS_SERVER_KEY = " "
    assert isinstance(services.get_provider(), HaversineProvider)
    with pytest.raises(MapsProviderError):
        GoogleMapsProvider("")


def test_google_route_request_and_parse(google, http):
    fake = http(google_route())
    route = GoogleMapsProvider("test-key-not-real").route(STORE, DROP)
    assert route == Route(
        distance_m=2600,
        duration_s=540.0,
        polyline="_p~iF~ps|U_ulLnnqC",
        provider="google",
        traffic_aware=True,
    )
    request, timeout = fake.requests[0]
    assert request.full_url == providers.ROUTES_URL
    assert request.get_method() == "POST"
    assert request.get_header("X-goog-api-key") == "test-key-not-real"
    assert request.get_header("X-goog-fieldmask") == providers.ROUTES_FIELD_MASK
    body = json.loads(request.data)
    assert body["travelMode"] == "TWO_WHEELER"
    assert body["routingPreference"] == "TRAFFIC_AWARE"
    assert body["origin"]["location"]["latLng"] == {"latitude": 28.45, "longitude": 77.05}
    assert timeout == 3.0


def test_google_route_same_point_and_missing_polyline(google, http):
    http({"routes": [{"duration": "0s"}]})
    route = GoogleMapsProvider("k").route(STORE, STORE)
    assert route.distance_m == 0
    assert polyline.decode(route.polyline) == [STORE, STORE]


@pytest.mark.parametrize(
    "answer",
    [
        b"x" * (providers.MAX_RESPONSE_BYTES + 1),
        urllib.error.HTTPError(providers.ROUTES_URL, 403, "Forbidden", {}, None),
        urllib.error.URLError("down"),
        TimeoutError(),
        b"not json",
        {"routes": []},
        {},
        google_route(duration="soon"),
        google_route(duration=12),
        google_route(distance=-5),
    ],
)
def test_google_route_errors_raise(google, http, answer):
    http(answer)
    with pytest.raises(MapsProviderError):
        GoogleMapsProvider("k").route(STORE, DROP)


# --------------------------------------------------------------------------- fallback


def test_provider_error_falls_back_and_cools_down(google, http, settings, caplog):
    settings.MAPS_PROVIDER_COOLDOWN_SECONDS = 60
    fake = http(urllib.error.HTTPError(providers.ROUTES_URL, 500, "boom", {}, None))
    route = services.compute_route(STORE, DROP)
    assert route.provider == "haversine"
    assert len(fake.requests) == 1
    # Cooling down: no second call, still the fallback.
    assert services.compute_route(STORE, DROP).provider == "haversine"
    assert len(fake.requests) == 1
    # No coordinates or key in the log line.
    text = caplog.text
    assert "28.45" not in text
    assert "test-key-not-real" not in text
    cache.clear()
    http(google_route())
    assert services.compute_route(STORE, DROP).provider == "google"


def test_provider_bug_falls_back(google, monkeypatch):
    def broken(self, origin, destination):
        raise RuntimeError("bug")

    monkeypatch.setattr(GoogleMapsProvider, "route", broken)
    assert services.compute_route(STORE, DROP).provider == "haversine"


def test_cache_outage_still_routes(monkeypatch):
    def boom(*args, **kwargs):
        raise ConnectionError("redis down")

    monkeypatch.setattr(services.cache, "get", boom)
    monkeypatch.setattr(services.cache, "set", boom)
    monkeypatch.setattr(services.cache, "delete", boom)
    assert services.tracked_route("t", STORE, DROP).fresh
    assert services.fixed_route("f", STORE, DROP).provider == "haversine"
    services.forget("t")


# --------------------------------------------------------------------------- cache & throttle


def test_tracked_route_throttle(google, http, settings):
    """Recompute only after moving > N m or after M s, never within the minimum interval; in
    between the cached route is scaled by the straight-line progress."""
    settings.MAPS_ROUTE_RECOMPUTE_DISTANCE_M = 150
    settings.MAPS_ROUTE_MAX_AGE_SECONDS = 120
    settings.MAPS_ROUTE_MIN_INTERVAL_SECONDS = 20
    fake = http(google_route(distance=3000, duration="600s"))
    t0 = timezone.now()
    first = services.tracked_route("task:1:TO_CUSTOMER", STORE, DROP, t0)
    assert first.fresh
    assert first.route.distance_m == 3000
    # 30 s later, moved ~50 m: cached (scaled).
    near = (28.45045, 77.05)
    second = services.tracked_route("task:1:TO_CUSTOMER", near, DROP, t0 + timedelta(seconds=30))
    assert not second.fresh
    assert second.computed_at.timestamp() == pytest.approx(t0.timestamp())
    assert second.route.distance_m < 3000
    assert second.route.polyline == first.route.polyline
    assert len(fake.requests) == 1
    # 10 s after the first, moved ~500 m: still within the minimum interval.
    far = (28.4545, 77.05)
    third = services.tracked_route("task:1:TO_CUSTOMER", far, DROP, t0 + timedelta(seconds=10))
    assert not third.fresh
    # 25 s, moved ~500 m: recomputed.
    fourth = services.tracked_route("task:1:TO_CUSTOMER", far, DROP, t0 + timedelta(seconds=25))
    assert fourth.fresh
    assert len(fake.requests) == 2
    # Not moving, but older than the max age: recomputed.
    t1 = t0 + timedelta(seconds=25)
    assert not services.tracked_route(
        "task:1:TO_CUSTOMER", far, DROP, t1 + timedelta(seconds=60)
    ).fresh
    assert services.tracked_route(
        "task:1:TO_CUSTOMER", far, DROP, t1 + timedelta(seconds=121)
    ).fresh
    # Another destination for the same key: recomputed at once.
    assert services.tracked_route(
        "task:1:TO_CUSTOMER", far, STORE, t1 + timedelta(seconds=122)
    ).fresh
    services.forget("task:1:TO_CUSTOMER")
    assert services.tracked_route(
        "task:1:TO_CUSTOMER", far, STORE, t1 + timedelta(seconds=123)
    ).fresh


def test_tracked_route_scaling_at_the_destination(settings):
    t0 = timezone.now()
    services.tracked_route("k", DROP, DROP, t0)  # computed at the destination
    again = services.tracked_route("k", DROP, DROP, t0 + timedelta(seconds=5))
    assert not again.fresh
    assert again.route.distance_m == 0
    # Moved off the destination: recomputed at once, even within the minimum interval.
    away = services.tracked_route("k", STORE, DROP, t0 + timedelta(seconds=6))
    assert away.fresh
    assert away.route.distance_m > 0


def test_tracked_route_ignores_a_corrupt_cache_entry():
    cache.set(services.ROUTE_KEY.format(key="bad"), {"origin": "x"}, 60)
    assert services.tracked_route("bad", STORE, DROP).fresh
    cache.set(services.ROUTE_KEY.format(key="bad2"), {"origin": [1, 2]}, 60)
    assert services.fixed_route("bad2", STORE, DROP).provider == "haversine"


def test_fixed_route_is_cached(google, http):
    fake = http(google_route())
    assert services.fixed_route("order:1:store-drop", STORE, DROP).provider == "google"
    assert services.fixed_route("order:1:store-drop", STORE, DROP).provider == "google"
    assert len(fake.requests) == 1
    services.fixed_route("order:1:store-drop", STORE, (28.47, 77.06))  # the drop moved
    assert len(fake.requests) == 2


def test_a_fallback_is_cached_only_for_the_cooldown(google, http, settings, monkeypatch):
    """Review fix 2: a straight line computed because Google failed must not stay cached for
    MAPS_ROUTE_CACHE_SECONDS; a road route does."""
    settings.MAPS_PROVIDER_COOLDOWN_SECONDS = 60
    settings.MAPS_ROUTE_CACHE_SECONDS = 3600
    writes = []
    real = services._cache_set

    def record(key, value, timeout):
        if key.startswith("maps:route:"):
            writes.append((key, value["route"]["provider"], timeout))
        real(key, value, timeout)

    monkeypatch.setattr(services, "_cache_set", record)
    http(urllib.error.HTTPError(providers.ROUTES_URL, 500, "boom", {}, None))
    services.fixed_route("order:9:store-drop", STORE, DROP)
    services.tracked_route("task:9:TO_CUSTOMER", STORE, DROP)
    assert writes == [
        ("maps:route:order:9:store-drop", "haversine", 60),
        ("maps:route:task:9:TO_CUSTOMER", "haversine", 60),
    ]
    cache.clear()
    writes.clear()
    http(google_route())
    services.fixed_route("order:9:store-drop", STORE, DROP)
    assert writes == [("maps:route:order:9:store-drop", "google", 3600)]


def test_cached_only_never_calls_the_provider(google, http):
    """Review fix 3: bulk readers read the cache or get the straight line."""
    fake = http(google_route())
    assert services.fixed_route("f", STORE, DROP, cached_only=True).provider == "haversine"
    tracked = services.tracked_route("t", STORE, DROP, cached_only=True)
    assert (tracked.fresh, tracked.route.provider) == (False, "haversine")
    assert fake.requests == []
    # Nothing was cached by those reads; a normal call computes and caches the road route.
    assert services.fixed_route("f", STORE, DROP).provider == "google"
    assert services.fixed_route("f", STORE, DROP, cached_only=True).provider == "google"
    t0 = timezone.now()
    services.tracked_route("t", STORE, DROP, t0)
    stale = services.tracked_route("t", STORE, DROP, t0 + timedelta(seconds=600), cached_only=True)
    assert (stale.fresh, stale.route.provider) == (False, "google")
    assert len(fake.requests) == 2


def test_a_held_lock_avoids_a_stampede(google, http):
    """Review fix 3: while another caller computes a key, the others do not call Google."""
    fake = http(google_route())
    cache.add("maps:route:f:lock", 1, 30)
    assert services.fixed_route("f", STORE, DROP).provider == "haversine"
    t0 = timezone.now()
    cache.delete("maps:route:t:lock")
    services.tracked_route("t", STORE, DROP, t0)  # cached road route
    assert len(fake.requests) == 1
    cache.add("maps:route:t:lock", 1, 30)
    later = services.tracked_route("t", (28.4545, 77.05), DROP, t0 + timedelta(seconds=600))
    assert (later.fresh, later.route.provider) == (False, "google")  # the old one, scaled
    cache.add("maps:route:u:lock", 1, 30)
    assert services.tracked_route("u", STORE, DROP, t0).route.provider == "haversine"
    assert len(fake.requests) == 1
    # The lock is released after a computation.
    cache.delete("maps:route:f:lock")
    services.fixed_route("f", STORE, DROP)
    assert cache.get("maps:route:f:lock") is None


def test_the_haversine_provider_takes_no_lock(settings):
    cache.add("maps:route:h:lock", 1, 30)
    assert services.tracked_route("h", STORE, DROP).fresh


# --------------------------------------------------------------------------- checks


def test_checks_warn_on_misconfiguration(settings):
    settings.MAPS_PROVIDER = "mappls"
    assert "maps.W001" in [m.id for m in run_checks()]
    settings.MAPS_PROVIDER = "google"
    settings.GOOGLE_MAPS_SERVER_KEY = ""
    assert "maps.W002" in [m.id for m in run_checks()]
    settings.GOOGLE_MAPS_SERVER_KEY = "k"
    assert not {"maps.W001", "maps.W002"} & {m.id for m in run_checks()}
