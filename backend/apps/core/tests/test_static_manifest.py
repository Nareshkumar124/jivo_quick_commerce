"""Versioned static files (T-817): deployed settings use content-hashed names, the admin and Ops
Console render with them, and a missing manifest degrades to plain names instead of a 500."""

import importlib
import re
import sys

import pytest
from django.contrib.staticfiles.storage import staticfiles_storage
from django.core.management import call_command
from django.templatetags.static import static

from apps.accounts.tests.factories import StaffUserFactory

pytestmark = pytest.mark.django_db

MANIFEST = {"BACKEND": "apps.core.staticfiles.VersionedStaticFilesStorage"}
HASHED_CSS = re.compile(r"/static/[\w/.-]+\.[0-9a-f]{12}\.css")


@pytest.fixture
def manifest_storage(settings, tmp_path):
    settings.STATIC_ROOT = tmp_path / "static"
    settings.STORAGES = {**settings.STORAGES, "staticfiles": MANIFEST}
    return settings


@pytest.fixture(scope="module")
def collected(tmp_path_factory):
    """One collectstatic run (post-processing every file) for the module."""
    from django.conf import settings
    from django.test import override_settings

    root = tmp_path_factory.mktemp("collected")
    storages = {**settings.STORAGES, "staticfiles": MANIFEST}
    with override_settings(STATIC_ROOT=root, STORAGES=storages):
        call_command("collectstatic", interactive=False, verbosity=0)
    return root


def test_deployed_settings_use_the_manifest(monkeypatch):
    monkeypatch.setenv("DJANGO_SECRET_KEY", "s" * 64)
    monkeypatch.setenv("JWT_SIGNING_KEY", "j" * 64)
    monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
    monkeypatch.setenv("NUM_PROXIES", "1")
    monkeypatch.delenv("OTP_TEST_NUMBERS", raising=False)
    monkeypatch.delenv("SEED_DEMO_ALLOWED", raising=False)
    monkeypatch.delenv("SENTRY_DSN", raising=False)
    try:
        for name in ("config.settings.production", "config.settings.deployed"):
            sys.modules.pop(name, None)
        production = importlib.import_module("config.settings.production")
        assert production.STORAGES["staticfiles"] == MANIFEST
        # Media storages are untouched.
        assert production.STORAGES["public"]["BACKEND"] == "storages.backends.s3.S3Storage"
    finally:
        for name in ("config.settings.production", "config.settings.deployed"):
            sys.modules.pop(name, None)


def test_test_settings_never_use_it(settings):
    backend = settings.STORAGES["staticfiles"]["BACKEND"]
    assert backend == "django.contrib.staticfiles.storage.StaticFilesStorage"


def test_names_are_hashed(manifest_storage, collected):
    manifest_storage.STATIC_ROOT = collected
    url = static("admin/css/base.css")
    assert re.fullmatch(r"/static/admin/css/base\.[0-9a-f]{12}\.css", url)
    assert (collected / url.removeprefix("/static/")).exists()


@pytest.mark.parametrize("path", ["/admin/login/", "/ops/"])
def test_pages_render_with_hashed_names(client, manifest_storage, collected, path):
    """The admin and the Ops Console reference only files that exist (strict manifest)."""
    manifest_storage.STATIC_ROOT = collected
    client.force_login(StaffUserFactory(is_superuser=True))
    response = client.get(path, follow=True)
    assert response.status_code == 200
    assert HASHED_CSS.search(response.content.decode())


def test_missing_manifest_falls_back_to_plain_names(manifest_storage):
    """The image was built without DJANGO_STATIC_MANIFEST: unversioned, logged, never a 500."""
    assert not staticfiles_storage.hashed_files
    assert static("admin/css/base.css") == "/static/admin/css/base.css"


class TestManifestCheck:
    """core.W001 (`check --deploy`): manifest storage active but no staticfiles.json."""

    def test_warns_when_the_manifest_is_missing(self, manifest_storage):
        from apps.core.staticfiles import MANIFEST_MISSING, check_static_manifest

        messages = check_static_manifest()
        assert [m.id for m in messages] == [MANIFEST_MISSING]
        assert "collectstatic" in messages[0].hint

    def test_silent_after_collectstatic(self, manifest_storage, collected):
        from apps.core.staticfiles import check_static_manifest

        manifest_storage.STATIC_ROOT = collected
        assert check_static_manifest() == []

    def test_silent_without_the_manifest_storage(self, settings):
        from apps.core.staticfiles import check_static_manifest

        assert check_static_manifest() == []  # test settings: plain storage

    def test_is_a_deploy_check(self, manifest_storage):
        from django.core.checks import run_checks

        assert "core.W001" not in [m.id for m in run_checks()]
        assert "core.W001" in [m.id for m in run_checks(include_deployment_checks=True)]
