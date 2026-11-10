"""Socket slots per user (P8 OWASP review L5): Redis leases, expiry and fail-open."""

import time

import pytest

from apps.realtime import limits


def test_slots_are_counted_and_released(settings):
    settings.WS_MAX_SOCKETS_PER_USER = 2
    assert limits.acquire(7, "a")
    assert limits.acquire(7, "b")
    assert not limits.acquire(7, "c")
    assert limits.count(7) == 2
    assert limits.acquire(8, "c")  # another user
    limits.release(7, "a")
    assert limits.acquire(7, "c")


def test_a_lost_socket_stops_counting_when_its_lease_ends(settings):
    settings.WS_MAX_SOCKETS_PER_USER = 1
    settings.WS_SOCKET_LEASE_SECONDS = 0.2
    assert limits.acquire(9, "crashed-server-socket")
    assert not limits.acquire(9, "new")
    time.sleep(0.3)
    assert limits.acquire(9, "new")


def test_renew_extends_only_existing_slots(settings):
    settings.WS_SOCKET_LEASE_SECONDS = 0.2
    assert limits.acquire(10, "a")
    settings.WS_SOCKET_LEASE_SECONDS = 60
    limits.renew(10, "a")
    limits.renew(10, "never-acquired")
    time.sleep(0.3)
    assert limits.count(10) == 1


def test_redis_errors_fail_open(monkeypatch, caplog):
    def down():
        raise ConnectionError("redis down")

    monkeypatch.setattr(limits, "_client", down)
    assert limits.acquire(11, "a")
    limits.renew(11, "a")
    limits.release(11, "a")
    assert "allowing" in caplog.text
    with pytest.raises(ConnectionError):
        limits.count(11)
