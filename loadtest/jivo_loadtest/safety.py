"""Where a load test may run. Checked by the CLI before Locust starts and again inside the
locustfile (so a plain `locust -f locustfile.py` is refused too).

Rules:
- A target host is required (`--host`); there is no default.
- The host must match an entry of LOADTEST_ALLOWED_HOSTS exactly (`host` or `host:port`,
  comma-separated). Without that variable nothing is allowed.
- Loopback hosts on the shared dev and QA ports (8000, 8001, 8004) are always refused, even if
  listed: :8001 is the PM's develop server on the shared dev DB, :8004 is QA's instance.
"""

import ipaddress
import os
from urllib.parse import urlsplit

ALLOWED_HOSTS_ENV = "LOADTEST_ALLOWED_HOSTS"
DENIED_LOOPBACK_PORTS = frozenset({8000, 8001, 8004})
DEFAULT_PORTS = {"http": 80, "https": 443}
LOOPBACK_NAMES = frozenset({"localhost", "localhost.localdomain", "0.0.0.0"})  # noqa: S104


class UnsafeTarget(Exception):
    """The load test must not run against this host."""


def _is_loopback(hostname: str) -> bool:
    if hostname in LOOPBACK_NAMES:
        return True
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        return False
    return address.is_loopback or address.is_unspecified


def _entries(raw: str) -> set[str]:
    entries = set()
    for item in raw.split(","):
        item = item.strip().lower().rstrip("/")
        if "://" in item:
            item = item.split("://", 1)[1]
        if item:
            entries.add(item)
    return entries


def check_target(host: str | None, allowed: str | None = None) -> str:
    """Return the normalised `hostname:port` of `host`, or raise UnsafeTarget.
    `allowed` defaults to the LOADTEST_ALLOWED_HOSTS environment variable."""
    if not host or not host.strip():
        raise UnsafeTarget("--host is required (for example --host https://staging-api.example).")
    parts = urlsplit(host.strip())
    if parts.scheme not in DEFAULT_PORTS or not parts.hostname:
        raise UnsafeTarget(f"--host must be an http(s) URL with a host name, not {host!r}.")
    if parts.path not in ("", "/") or parts.query or parts.fragment:
        raise UnsafeTarget("--host must be the server root (no path); the flows add /api/v1/.")
    hostname = parts.hostname.lower()
    try:
        port = parts.port or DEFAULT_PORTS[parts.scheme]
    except ValueError as exc:
        raise UnsafeTarget(f"Invalid port in {host!r}.") from exc
    target = f"{hostname}:{port}"

    if _is_loopback(hostname) and port in DENIED_LOOPBACK_PORTS:
        raise UnsafeTarget(
            f"Refusing {target}: port {port} on this machine is a shared server (8001 is the "
            "develop server on the shared dev DB, 8004 is QA). Start a throwaway server on its "
            "own database and port instead."
        )
    raw = os.environ.get(ALLOWED_HOSTS_ENV, "") if allowed is None else allowed
    entries = _entries(raw)
    if not entries:
        raise UnsafeTarget(
            f"{ALLOWED_HOSTS_ENV} is not set. List the exact host(s) this run may hit, e.g. "
            f"{ALLOWED_HOSTS_ENV}=staging-api.example.com"
        )
    default_port = DEFAULT_PORTS[parts.scheme]
    if target in entries or (port == default_port and hostname in entries):
        return target
    raise UnsafeTarget(f"Refusing {target}: it is not listed in {ALLOWED_HOSTS_ENV}.")
