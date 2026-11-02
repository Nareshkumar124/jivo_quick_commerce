"""Client-info middleware (02 §5).

The apps send `X-App-Name` (customer/rider), `X-App-Version` (e.g. 1.4.2 or 1.4.2+37) and
`X-Platform` (android/ios) on every request. They are parsed once into `request.client_info`.
Unknown or malformed values become None, so later code never trusts raw header text.

Phase 1 adds the force-update check here (426 APP_UPDATE_REQUIRED below the minimum version).
"""

import re
from dataclasses import dataclass

from asgiref.sync import iscoroutinefunction
from django.utils.decorators import sync_and_async_middleware

APP_NAMES = frozenset({"customer", "rider"})
PLATFORMS = frozenset({"android", "ios"})
# "1.4.2" or "1.4.2+37" (Flutter version+build).
# APP_VERSION_PATTERN: the same rule without named groups, portable to the OpenAPI contract
# (Dart/JS regex engines reject Python's (?P<name>...)). Used to validate request fields.
APP_VERSION_PATTERN = r"^\d{1,5}(?:\.\d{1,5}){0,3}(?:\+\d{1,9})?$"
APP_VERSION_RE = re.compile(r"^(?P<version>\d{1,5}(?:\.\d{1,5}){0,3})(?:\+(?P<build>\d{1,9}))?$")


@dataclass(frozen=True, slots=True)
class ClientInfo:
    app_name: str | None = None
    app_version: str | None = None
    build_number: int | None = None
    platform: str | None = None

    @property
    def version_tuple(self) -> tuple[int, ...] | None:
        """`"1.4.2"` -> `(1, 4, 2)`, for minimum-version comparisons."""
        if self.app_version is None:
            return None
        return tuple(int(part) for part in self.app_version.split("."))

    @property
    def is_app(self) -> bool:
        return self.app_name is not None

    @classmethod
    def from_headers(cls, headers) -> "ClientInfo":
        app_name = (headers.get("X-App-Name") or "").strip().lower()
        platform = (headers.get("X-Platform") or "").strip().lower()
        version_match = APP_VERSION_RE.match((headers.get("X-App-Version") or "").strip())
        build = version_match.group("build") if version_match else None
        return cls(
            app_name=app_name if app_name in APP_NAMES else None,
            app_version=version_match.group("version") if version_match else None,
            build_number=int(build) if build else None,
            platform=platform if platform in PLATFORMS else None,
        )


@sync_and_async_middleware
def client_info_middleware(get_response):
    if iscoroutinefunction(get_response):

        async def async_middleware(request):
            request.client_info = ClientInfo.from_headers(request.headers)
            return await get_response(request)

        return async_middleware

    def middleware(request):
        request.client_info = ClientInfo.from_headers(request.headers)
        return get_response(request)

    return middleware
