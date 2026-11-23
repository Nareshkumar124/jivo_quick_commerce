"""Google Maps provider for the Ops live delivery map (05 §1.4, T-821 follow-up).

`OPS_MAP_PROVIDER` (auto / google / openlayers) with `GOOGLE_MAPS_WEB_KEY`; the browser key is
rendered only on `/ops/riders/map/` and only for roles that may open it; the page's CSP gains the
Google Maps sources only there; the provider script falls back to OpenLayers in the browser.
"""

import json
import re
from pathlib import Path

import pytest
from django.conf import settings as django_settings
from django.urls import reverse

from apps.accounts import roles
from apps.ops_console import csp, live_map
from apps.ops_console.tests.helpers import (
    LIVE_BOARD_ROLES,
    PRINCIPALS,
    expected_status,
    login_with_stores,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

PAGE = "ops:live-map"
KEY = "AIza-test-web-key-123"
CSP_HEADER = (csp.HEADER_REPORT_ONLY, csp.HEADER_ENFORCE)


@pytest.fixture
def google(settings):
    settings.OPS_MAP_PROVIDER = "auto"
    settings.GOOGLE_MAPS_WEB_KEY = KEY
    return settings


@pytest.fixture
def no_key(settings):
    settings.OPS_MAP_PROVIDER = "auto"
    settings.GOOGLE_MAPS_WEB_KEY = ""
    return settings


def _config(response) -> dict:
    match = re.search(
        r'<script id="live-map-config" type="application/json">(.*?)</script>',
        response.content.decode(),
        re.S,
    )
    assert match, "live-map-config missing"
    return json.loads(match.group(1))


def _csp(response) -> str:
    for header in CSP_HEADER:
        if header in response:
            return response[header]
    raise AssertionError("no CSP header")


def _static(path: str) -> str:
    for base in django_settings.STATICFILES_DIRS:
        file = Path(base) / path
        if file.exists():
            return file.read_text(encoding="utf-8")
    raise AssertionError(path)


# ------------------------------------------------------------------ provider selection


@pytest.mark.parametrize(
    ("setting", "key", "expected"),
    [
        ("auto", KEY, "google"),
        ("auto", "", "openlayers"),
        ("auto", "   ", "openlayers"),
        ("google", KEY, "google"),
        ("google", "", "openlayers"),  # Google without a key cannot work
        ("openlayers", KEY, "openlayers"),
        ("nope", KEY, "openlayers"),
        ("", KEY, "google"),  # empty = auto
    ],
)
def test_provider_selection(settings, setting, key, expected):
    settings.OPS_MAP_PROVIDER = setting
    settings.GOOGLE_MAPS_WEB_KEY = key
    name, assets = live_map.map_provider()
    assert name == expected
    if expected == "google":
        assert assets["js"] == ("ops/js/map_provider_google.js",)
    else:
        assert "ops/js/map_provider_ol.js" in assets["js"]


def test_default_setting_is_auto():
    from config import admin_ui

    assert hasattr(django_settings, "OPS_MAP_PROVIDER")
    assert hasattr(django_settings, "GOOGLE_MAPS_WEB_KEY")
    source = Path(admin_ui.__file__).read_text(encoding="utf-8")
    assert 'env_str("OPS_MAP_PROVIDER", default="auto")' in source
    assert 'env_str("GOOGLE_MAPS_WEB_KEY", default="")' in source


def test_google_config_only_for_google():
    assert live_map.google_config("openlayers") is None


# ------------------------------------------------------------------ the page


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_key_only_for_roles_that_may_open_the_map(client, google, principal):
    store = DarkStoreFactory()
    login_with_stores(client, principal, store)
    response = client.get(reverse(PAGE))
    status = expected_status(principal, LIVE_BOARD_ROLES)
    assert response.status_code == status
    if status == 200:
        assert KEY.encode() in response.content
        cfg = _config(response)["googleMaps"]
        assert cfg["key"] == KEY
        assert cfg["src"] == "https://maps.googleapis.com/maps/api/js"
        # The OpenLayers fallback assets go with it (same-origin static URLs).
        assert any("ol-7.2.2.min.js" in src for src in cfg["fallback"]["js"])
        assert any("map_provider_ol.js" in src for src in cfg["fallback"]["js"])
        assert all(src.startswith("/") for src in cfg["fallback"]["js"])
        assert b'data-map-provider="google"' in response.content
        assert b"ops/js/map_provider_google.js" in response.content
        assert b"data-map-notice" in response.content
        # OpenLayers is not loaded up front; the provider loads it only on fallback.
        assert b'ol-7.2.2.min.js" defer' not in response.content
    else:
        assert KEY.encode() not in response.content


def test_page_without_key_uses_openlayers(client, no_key):
    login_with_stores(client, roles.OPS)
    response = client.get(reverse(PAGE))
    assert response.status_code == 200
    assert _config(response)["googleMaps"] is None
    assert b'data-map-provider="openlayers"' in response.content
    assert b"ops/js/map_provider_ol.js" in response.content
    assert b"map_provider_google.js" not in response.content
    assert b"maps.googleapis.com" not in response.content
    assert "googleapis" not in _csp(response)


@pytest.mark.parametrize(
    "name",
    ["ops:dashboard", "ops:live-board", "ops:dispatch", "ops:live-map-data", "admin:index"],
)
def test_key_never_on_other_pages(client, google, name):
    login_with_stores(client, roles.SUPER_ADMIN)
    response = client.get(reverse(name))
    assert response.status_code == 200
    assert KEY.encode() not in response.content
    assert b"maps.googleapis.com" not in response.content
    if any(h in response for h in CSP_HEADER):
        assert "googleapis" not in _csp(response)


def test_key_not_in_route_json(client, google):
    login_with_stores(client, roles.OPS)
    response = client.get(reverse("ops:live-map-route", args=[999999]))
    assert KEY.encode() not in response.content


# ------------------------------------------------------------------ CSP


def test_csp_adds_google_sources_only_on_the_google_map_page(client, google):
    login_with_stores(client, roles.OPS)
    header = _csp(client.get(reverse(PAGE)))
    directives = dict(
        [*part.split(" ", 1), ""][:2] for part in (p.strip() for p in header.split(";"))
    )
    assert "https://*.googleapis.com" in directives["script-src"]
    assert "https://*.gstatic.com" in directives["script-src"]
    assert "'nonce-" in directives["script-src"]  # the base policy stays
    assert "https://tile.openstreetmap.org" in directives["img-src"]  # OpenLayers fallback
    assert "https://*.googleapis.com" in directives["img-src"]
    assert "https://*.googleapis.com" in directives["connect-src"]
    assert "https://fonts.gstatic.com" in directives["font-src"]
    assert "https://fonts.googleapis.com" in directives["style-src"]
    assert directives["frame-ancestors"] == "'none'"
    assert directives["report-uri"] == csp.REPORT_PATH
    assert header.count("script-src") == 1


def test_csp_enforce_mode_uses_the_enforcing_header(client, google, settings):
    settings.CSP_REPORT_ONLY = False
    login_with_stores(client, roles.OPS)
    response = client.get(reverse(PAGE))
    assert "googleapis" in response[csp.HEADER_ENFORCE]
    assert csp.HEADER_REPORT_ONLY not in response


def test_base_policy_unchanged_without_extra():
    policy = csp.policy("abc")
    assert policy.startswith("default-src 'self'; script-src 'self' 'unsafe-eval' 'nonce-abc';")
    assert "google" not in policy
    assert policy.endswith(f"report-uri {csp.REPORT_PATH}")


# ------------------------------------------------------------------ the script


def test_google_provider_script_contract():
    source = _static("ops/js/map_provider_google.js")
    assert "window.OpsMapProviders.google" in source
    for method in ("setStores", "setRiders", "setDrops", "setRoute", "focus", "fitAll"):
        assert method + ":" in source
    # Loader: async + geometry + callback; fallback on auth failure, load error and timeout.
    assert '"loading=async"' in source
    assert '"libraries=geometry"' in source
    assert '"callback=" + CALLBACK' in source
    assert "window.gm_authFailure" in source
    assert "script.onerror" in source
    assert "LOAD_TIMEOUT_MS" in source
    assert "fallback()" in source
    assert "OpenStreetMap" in source
    # Stale riders are styled apart; encoded polylines decode with the geometry library.
    assert '"STALE"' in source
    assert "geometry.encoding.decodePath" in source
    # No third-party clusterer is loaded (CSP allows only our scripts + Google Maps).
    assert "markerclusterer" not in source.lower()
    assert "unpkg" not in source
    assert "jsdelivr" not in source
    # The key is never written into the source or the console.
    assert "AIza" not in source
    assert "console." not in source
