"""Versioned static files for deployed settings (T-817).

nginx serves `/static/` with a 7-day cache, so file names must change when their content does:
`ManifestStaticFilesStorage` gives each file a content hash (`admin/css/base.<hash>.css`) and
`{% static %}` reads the names from `staticfiles.json`, written by `collectstatic`.

The image build must therefore run `collectstatic` with this storage (`DJANGO_STATIC_MANIFEST=
true`, see `config/settings/base.py`). If it did not (no manifest at all), names fall back to the
plain, unversioned ones with a logged error instead of every admin page failing with a 500. A
manifest that exists but lacks a referenced file stays strict (Django's default): that is a bug
to fix, not to hide. `check --deploy` warns (core.W001) when the manifest is missing.
"""

import logging
from pathlib import Path

from django.conf import settings
from django.contrib.staticfiles.storage import ManifestStaticFilesStorage
from django.core import checks
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class VersionedStaticFilesStorage(ManifestStaticFilesStorage):
    _warned = False

    def stored_name(self, name):
        if not self.hashed_files:  # no staticfiles.json: collectstatic used another storage
            if not VersionedStaticFilesStorage._warned:
                VersionedStaticFilesStorage._warned = True
                logger.error(
                    "Static manifest %s missing: serving unversioned static names. Run "
                    "collectstatic with DJANGO_STATIC_MANIFEST=true.",
                    self.manifest_name,
                )
            return name
        return super().stored_name(name)


MANIFEST_MISSING = "core.W001"


@checks.register(checks.Tags.staticfiles, deploy=True)
def check_static_manifest(app_configs=None, **kwargs) -> list[checks.CheckMessage]:
    """`check --deploy`: the manifest storage is active (deployed settings) but `collectstatic`
    has not written `staticfiles.json` into STATIC_ROOT, so pages would use unversioned names."""
    backend = settings.STORAGES.get("staticfiles", {}).get("BACKEND", "")
    try:
        storage_class = import_string(backend)
    except ImportError:
        return []
    if not issubclass(storage_class, ManifestStaticFilesStorage):
        return []
    root = settings.STATIC_ROOT
    if root and (Path(root) / storage_class.manifest_name).is_file():
        return []
    return [
        checks.Warning(
            f"The static manifest {storage_class.manifest_name} is missing from STATIC_ROOT "
            f"({root}): static files are served with unversioned names.",
            hint=(
                "Run `manage.py collectstatic` with these settings (the image build: "
                "DJANGO_STATIC_MANIFEST=true) before starting the server."
            ),
            id=MANIFEST_MISSING,
        )
    ]
