"""The rider sessions (P5 contract: shift start, GPS batches, offer polling, heartbeat) against
the in-memory fake API."""

import random
from datetime import UTC, datetime, timedelta

from jivo_loadtest.config import API, RIDER_PHONES, RunConfig
from jivo_loadtest.flows import Recorder, RiderSession
from tests.fake_api import FakeApi


class Clocks:
    def __init__(self) -> None:
        self.mono = 1000.0
        self.wall = datetime(2026, 11, 5, 6, 0, tzinfo=UTC)

    def advance(self, seconds: float) -> None:
        self.mono += seconds
        self.wall += timedelta(seconds=seconds)


def rider(api, clocks=None, **cfg) -> RiderSession:
    clocks = clocks or Clocks()
    return RiderSession(
        api,
        RunConfig(**cfg),
        phone=RIDER_PHONES[0],
        rng=random.Random(4),
        clock=lambda: clocks.mono,
        wallclock=lambda: clocks.wall,
        recorder=Recorder(),
    )


def test_rider_phone_range_is_dedicated():
    assert RIDER_PHONES[0] == "+919000000300"
    assert RIDER_PHONES[-1] == "+919000000399"
    assert len(set(RIDER_PHONES)) == 100


def test_shift_start_upload_poll_and_heartbeat():
    api = FakeApi()
    clocks = Clocks()
    r = rider(api, clocks)
    assert r.rider_journey() == "online"
    assert api.failures == []
    assert api.journey_failures == []
    names = api.names()
    assert names[:4] == [
        f"GET {API}/config/app/",
        f"POST {API}/auth/otp/request/",
        f"POST {API}/auth/otp/verify/",
        f"GET {API}/rider/me/",
    ]
    for expected in (
        f"POST {API}/rider/shift/start/",
        f"POST {API}/rider/locations/",
        f"GET {API}/rider/offers/current/",
        f"POST {API}/rider/heartbeat/",
    ):
        assert expected in names
    assert f"PATCH {API}/me/" not in names  # the customer profile step is not for riders
    login = next(c for c in api.calls if c[2] == f"{API}/auth/otp/request/")
    assert login[3]["X-App-Name"] == "rider"
    assert all(h["X-App-Name"] == "rider" for *_, h in api.calls)
    assert len(api.points) == 3  # 30 s interval / 10 s sampling
    assert r.next_wait() == 30


def test_points_are_unique_and_stay_near_the_store():
    api = FakeApi()
    clocks = Clocks()
    r = rider(api, clocks)
    for _ in range(20):
        r.rider_journey()
        clocks.advance(r.next_wait())
    stamps = [x["recorded_at"] for x in api.points]
    assert len(stamps) == len(set(stamps)) == 60
    assert stamps == sorted(stamps)
    cfg = RunConfig()
    for x in api.points:
        assert abs(x["lat"] - float(cfg.lat)) <= 0.005 + 1e-9
        assert abs(x["lng"] - float(cfg.lng)) <= 0.005 + 1e-9
    assert api.shift_starts == 1
    assert api.tokens == 1


def test_heartbeat_about_once_a_minute():
    api = FakeApi()
    clocks = Clocks()
    r = rider(api, clocks)
    for _ in range(10):  # 10 ticks x 30 s = 5 minutes
        r.rider_journey()
        clocks.advance(30)
    assert api.heartbeats == 5
    assert api.offer_polls == 10


def test_server_settings_change_the_cadence():
    api = FakeApi()
    api.location_settings.update(idle_interval_seconds=60, idle_sample_seconds=5, max_batch=8)
    r = rider(api)
    r.rider_journey()
    assert r.next_wait() == 60
    assert len(api.points) == 8  # capped by max_batch


def test_set_offline_by_the_server_goes_online_again():
    api = FakeApi()
    clocks = Clocks()
    r = rider(api, clocks)
    r.rider_journey()
    api.rider_offline_once = True
    clocks.advance(30)
    assert r.rider_journey() == "set offline"
    clocks.advance(30)
    assert r.rider_journey() == "online"
    assert api.shift_starts == 2


def test_inactive_rider_is_a_recorded_failure():
    api = FakeApi(rider_status="PENDING_KYC")
    r = rider(api)
    assert r.rider_journey() == "aborted"
    assert api.journey_failures[0][0] == "rider shift"
    assert "PENDING_KYC" in api.journey_failures[0][1]
    assert f"POST {API}/rider/shift/start/" not in api.names()


def test_end_shift():
    api = FakeApi()
    r = rider(api)
    r.end_shift()  # offline: nothing to end
    assert f"POST {API}/rider/shift/end/" not in api.names()
    r.rider_journey()
    r.end_shift()
    assert api.names()[-1] == f"POST {API}/rider/shift/end/"
    assert not api.rider_online


def test_profiles_carry_riders_and_can_override():
    from jivo_loadtest import profiles

    assert profiles.get("target").riders == 40
    assert profiles.get("smoke").riders == 2
    assert profiles.get("target", riders=0).riders == 0
    import pytest

    with pytest.raises(ValueError, match="riders must be"):
        profiles.get("target", riders=101)
    with pytest.raises(ValueError, match="cannot exceed"):
        profiles.get("smoke", riders=8)  # 3 buyers + 8 riders > 10 sessions


def test_cli_riders_option_and_otp_env(monkeypatch, capsys):
    from jivo_loadtest import cli

    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", "127.0.0.1:8005")
    seen = {}
    monkeypatch.setattr(cli.subprocess, "call", lambda argv, env: seen.update(env) or 0)
    assert cli.main(["run", "--host", "http://127.0.0.1:8005", "--riders", "0"]) == 0
    assert seen["LOADTEST_RIDERS"] == "0"
    assert cli.main(["run", "--host", "http://127.0.0.1:8005", "--riders", "500"]) == cli.REFUSED
    assert cli.main(["otp-env", "--count", "2", "--riders", "2"]) == 0
    last = capsys.readouterr().out.strip().splitlines()[-1]
    assert last == (
        "+919000000200:123456,+919000000201:123456,+919000000300:123456,+919000000301:123456"
    )
