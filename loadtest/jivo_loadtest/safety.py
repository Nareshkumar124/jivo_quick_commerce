"""Where a load test may run. Checked by the CLI before Locust starts and again inside the
locustfile (so a plain `locust -f locustfile.py` is refused too).

Rules:
- A target host is required (`--host`); there is no default.
- The host name is normalised first: lower case, a trailing `.` removed (`localhost.`), and
  numeric IPv4 shorthand rewritten to dotted form through `socket.inet_aton` (`127.1`,
  `2130706433`, `0x7f000001` are all 127.0.0.1).
- The normalised host must match an entry of LOADTEST_ALLOWED_HOSTS exactly (`host` or
  `host:port`, comma-separated). Without that variable nothing is allowed.
- Loopback hosts on the shared dev and QA ports (8000, 8001, 8004) are always refused, even if
  listed: :8001 is the PM's develop server on the shared dev DB, :8004 is QA's instance.
- A host *name* (anything but an IP literal or `localhost`) must resolve, and none of its
  addresses may be loopback or unspecified: names like `localtest.me` or `127.0.0.1.nip.io`
  point at this machine and are refused, and so is a name that does not resolve.
"""

import ipaddress
import os
import socket
from collections.abc import Callable
from urllib.parse import urlsplit

ALLOWED_HOSTS_ENV = "LOADTEST_ALLOWED_HOSTS"
DENIED_LOOPBACK_PORTS = frozenset({8000, 8001, 8004})
DEFAULT_PORTS = {"http": 80, "https": 443}
LOOPBACK_NAMES = frozenset({"localhost", "localhost.localdomain"})

Resolver = Callable[[str], list[str]]


class UnsafeTarget(Exception):
    """The load test must not run against this host."""


def resolve(hostname: str) -> list[str]:
    """Every address `hostname` resolves to (raises OSError when it does not resolve)."""
    return sorted({info[4][0] for info in socket.getaddrinfo(hostname, None)})


def normalise_hostname(hostname: str) -> str:
    """Lower case, no trailing dot, numeric IPv4 shorthand in dotted form."""
    hostname = hostname.lower().rstrip(".")
    if hostname and all(c in "0123456789abcdefx." for c in hostname):
        try:
            return socket.inet_ntoa(socket.inet_aton(hostname))
        except OSError:
            pass
    return hostname


def _ip(value: str) -> ipaddress.IPv4Address | ipaddress.IPv6Address | None:
    try:
        return ipaddress.ip_address(value.split("%", 1)[0])
    except ValueError:
        return None


def _is_local(address: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    mapped = getattr(address, "ipv4_mapped", None)
    if mapped is not None:
        address = mapped
    return address.is_loopback or address.is_unspecified


def _entries(raw: str) -> set[str]:
    entries = set()
    for item in raw.split(","):
        item = item.strip().lower().rstrip("/")
        if "://" in item:
            item = item.split("://", 1)[1]
        if item:
            host, sep, port = item.rpartition(":") if not item.endswith("]") else (item, "", "")
            if sep and port.isdigit():
                entries.add(f"{normalise_hostname(host)}:{port}")
            else:
                entries.add(normalise_hostname(item))
    return entries


def check_target(
    host: str | None, allowed: str | None = None, *, resolver: Resolver | None = None
) -> str:
    """Return the normalised `hostname:port` of `host`, or raise UnsafeTarget.
    `allowed` defaults to the LOADTEST_ALLOWED_HOSTS environment variable; `resolver` to DNS."""
    if not host or not host.strip():
        raise UnsafeTarget("--host is required (for example --host https://staging-api.example).")
    parts = urlsplit(host.strip())
    if parts.scheme not in DEFAULT_PORTS or not parts.hostname:
        raise UnsafeTarget(f"--host must be an http(s) URL with a host name, not {host!r}.")
    if parts.path not in ("", "/") or parts.query or parts.fragment:
        raise UnsafeTarget("--host must be the server root (no path); the flows add /api/v1/.")
    hostname = normalise_hostname(parts.hostname)
    try:
        port = parts.port or DEFAULT_PORTS[parts.scheme]
    except ValueError as exc:
        raise UnsafeTarget(f"Invalid port in {host!r}.") from exc
    shown = f"[{hostname}]" if ":" in hostname else hostname
    target = f"{shown}:{port}"

    literal = _ip(hostname)
    if literal is None and hostname not in LOOPBACK_NAMES:
        try:
            addresses = (resolver or resolve)(hostname)
        except OSError as exc:
            raise UnsafeTarget(f"Refusing {target}: {hostname} does not resolve ({exc}).") from exc
        if not addresses:
            raise UnsafeTarget(f"Refusing {target}: {hostname} does not resolve.")
        local = [a for a in addresses if (ip := _ip(a)) is not None and _is_local(ip)]
        if local:
            raise UnsafeTarget(
                f"Refusing {target}: {hostname} resolves to this machine ({', '.join(local)}). "
                "Use the IP address itself for a throwaway local server."
            )
    is_local = hostname in LOOPBACK_NAMES or (literal is not None and _is_local(literal))
    if is_local and port in DENIED_LOOPBACK_PORTS:
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
    if target in entries or (port == default_port and shown in entries):
        return target
    raise UnsafeTarget(f"Refusing {target}: it is not listed in {ALLOWED_HOSTS_ENV}.")
