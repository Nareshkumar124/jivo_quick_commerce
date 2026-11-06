"""Tests never use real DNS: host names resolve through this table."""

import pytest

from jivo_loadtest import safety

FAKE_DNS = {
    "localtest.me": ["127.0.0.1"],
    "127.0.0.1.nip.io": ["127.0.0.1"],
    "mixed.example": ["203.0.113.5", "::1"],
    "anywhere.example": ["0.0.0.0"],
    "mapped.example": ["::ffff:127.0.0.1"],
}


def fake_resolve(hostname: str) -> list[str]:
    if hostname.endswith(".invalid"):
        raise OSError("[Errno 11001] getaddrinfo failed")
    if hostname == "empty.example":
        return []
    return FAKE_DNS.get(hostname, ["203.0.113.10"])


@pytest.fixture(autouse=True)
def _no_real_dns(monkeypatch):
    monkeypatch.setattr(safety, "resolve", fake_resolve)
