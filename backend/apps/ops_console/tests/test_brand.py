"""Jivo branding on the panel: the generated assets in static/brand/ exist and stay small, the
admin (unfold), its login page, the Ops Console and the MFA pages reference them, the primary
colour is Jivo green, and every brand file survives the hashed-name (manifest) storage."""

import re

import pytest
from django.conf import settings
from django.core.management import call_command
from django.template.loader import render_to_string
from django.templatetags.static import static
from django.test import override_settings
from PIL import Image

from apps.accounts import roles
from apps.accounts.tests.factories import SuperUserFactory
from apps.ops_console.tests.helpers import staff_in_role
from config import admin_ui

pytestmark = pytest.mark.django_db

BRAND = settings.BASE_DIR / "static" / "brand"
FILES = {
    "favicon.ico": None,
    "favicon-32.png": (32, 32),
    "apple-touch-icon.png": (180, 180),
    "icon-192.png": (192, 192),
    "icon-512.png": (512, 512),
    "mark-64.png": (64, 64),
    "logo.png": None,
    "logo-white.png": None,
}
MANIFEST = {"BACKEND": "apps.core.staticfiles.VersionedStaticFilesStorage"}


def test_assets_exist_with_their_sizes_and_stay_small():
    for name, size in FILES.items():
        path = BRAND / name
        assert path.exists(), name
        assert path.stat().st_size < 20_000, name
        if size:
            assert Image.open(path).size == size, name
    ico = Image.open(BRAND / "favicon.ico")
    assert {(16, 16), (32, 32), (48, 48)} <= set(ico.info["sizes"])
    logo = Image.open(BRAND / "logo.png")
    assert logo.size[1] == 80  # 2x of a 40 px header
    assert Image.open(BRAND / "logo-white.png").size == logo.size


def test_unfold_config_points_at_the_brand():
    unfold = settings.UNFOLD
    assert unfold["SITE_LOGO"]["light"](None) == static("brand/logo.png")
    assert unfold["SITE_LOGO"]["dark"](None) == static("brand/logo-white.png")
    hrefs = [item["href"](None) for item in unfold["SITE_FAVICONS"]]
    assert static("brand/favicon.ico") in hrefs
    assert static("brand/apple-touch-icon.png") in hrefs
    assert unfold["COLORS"]["primary"]["700"] == admin_ui.BRAND_PRIMARY["700"] == "#2e572a"


def _assert_branded(body: str, *, logo=True):
    assert static("brand/favicon.ico") in body
    assert static("brand/apple-touch-icon.png") in body
    if logo:
        assert static("brand/logo.png") in body
        assert static("brand/logo-white.png") in body


def test_admin_login_page_is_branded(client):
    response = client.get("/admin/login/")
    assert response.status_code == 200
    _assert_branded(response.content.decode())


def test_admin_index_is_branded_and_green(client):
    client.force_login(SuperUserFactory())
    body = client.get("/admin/").content.decode()
    _assert_branded(body)
    assert "--color-primary-700: rgb(46, 87, 42)" in body or "46, 87, 42" in body


@pytest.mark.parametrize("role", [roles.OPS, roles.FINANCE, roles.STORE_STAFF])
def test_ops_console_is_branded(client, role):
    client.force_login(staff_in_role(role))
    response = client.get("/ops/")
    assert response.status_code == 200
    body = response.content.decode()
    _assert_branded(body)
    assert "46, 87, 42" in body  # theme colours shared with the admin


def test_mfa_pages_are_branded():
    body = render_to_string("ops/mfa/base.html", {"title": "Two-step sign-in"})
    _assert_branded(body)


@pytest.fixture(scope="module")
def collected(tmp_path_factory):
    root = tmp_path_factory.mktemp("brand-collected")
    storages = {**settings.STORAGES, "staticfiles": MANIFEST}
    with override_settings(STATIC_ROOT=root, STORAGES=storages):
        call_command("collectstatic", interactive=False, verbosity=0)
    return root


def test_brand_files_get_hashed_names_and_pages_use_them(client, collected):
    storages = {**settings.STORAGES, "staticfiles": MANIFEST}
    with override_settings(STATIC_ROOT=collected, STORAGES=storages):
        for name in FILES:
            url = static(f"brand/{name}")
            assert re.fullmatch(
                rf"/static/brand/{re.escape(name.rsplit('.', 1)[0])}\.[0-9a-f]{{12}}\.\w+", url
            ), url
            assert (collected / url.removeprefix("/static/")).exists()
        login = client.get("/admin/login/").content.decode()
        assert static("brand/logo.png") in login
        client.force_login(SuperUserFactory())
        ops = client.get("/ops/").content.decode()
        assert static("brand/favicon.ico") in ops
        assert static("brand/logo.png") in ops
