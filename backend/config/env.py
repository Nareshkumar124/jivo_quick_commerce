"""Typed helpers for reading configuration from environment variables.

Values come from the process environment. For local development, ``backend/.env`` is loaded first
(without overriding variables that are already set, and without ``$VAR`` interpolation, so
passwords containing ``$`` or ``@`` are read verbatim).

Error messages name the missing variable but never echo a value.
"""

import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

_NOTSET = object()
_TRUE = {"1", "true", "yes", "on"}
_FALSE = {"0", "false", "no", "off"}


def load_env_file(path: Path) -> None:
    """Load ``path`` into ``os.environ`` if it exists. Real environment variables win."""
    if path.is_file():
        from dotenv import load_dotenv

        load_dotenv(path, override=False, interpolate=False)


def _raw(name: str, default: object) -> str | None:
    value = os.environ.get(name)
    if value is None:
        if default is _NOTSET:
            raise ImproperlyConfigured(f"Set the {name} environment variable.")
        return None
    return value


def env_str(name: str, default: object = _NOTSET) -> str:
    value = _raw(name, default)
    return default if value is None else value  # type: ignore[return-value]


def env_bool(name: str, default: object = _NOTSET) -> bool:
    value = _raw(name, default)
    if value is None:
        return default  # type: ignore[return-value]
    lowered = value.strip().lower()
    if lowered in _TRUE:
        return True
    if lowered in _FALSE:
        return False
    raise ImproperlyConfigured(f"{name} must be a boolean (true/false).")


def env_int(name: str, default: object = _NOTSET) -> int:
    value = _raw(name, default)
    if value is None:
        return default  # type: ignore[return-value]
    try:
        return int(value.strip())
    except ValueError as exc:
        raise ImproperlyConfigured(f"{name} must be an integer.") from exc


def env_float(name: str, default: object = _NOTSET) -> float:
    value = _raw(name, default)
    if value is None:
        return default  # type: ignore[return-value]
    try:
        return float(value.strip())
    except ValueError as exc:
        raise ImproperlyConfigured(f"{name} must be a number.") from exc


def env_list(name: str, default: object = _NOTSET) -> list[str]:
    """Comma-separated list. Blank items are dropped."""
    value = _raw(name, default)
    if value is None:
        return list(default)  # type: ignore[call-overload]
    return [item.strip() for item in value.split(",") if item.strip()]


def env_dict(name: str, default: object = _NOTSET) -> dict[str, str]:
    """`key:value,key:value`. Keys and values are stripped; blank items are dropped."""
    value = _raw(name, default)
    if value is None:
        return dict(default)  # type: ignore[call-overload]
    result = {}
    for item in value.split(","):
        if not item.strip():
            continue
        key, sep, val = item.partition(":")
        if not sep:
            raise ImproperlyConfigured(f"{name} items must look like key:value.")
        result[key.strip()] = val.strip()
    return result
