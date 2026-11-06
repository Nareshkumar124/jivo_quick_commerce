"""The journeys against the in-memory fake API (no server, no Locust)."""

import random

import pytest

from jivo_loadtest.config import API, PHONES, RunConfig
from jivo_loadtest.flows import ACCESS_REFRESH_AFTER_S, Recorder, Session
from tests.fake_api import STORE_ID, FakeApi


class Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


def session(api, *, phone=PHONES[0], seed=1, clock=None, **cfg) -> Session:
    return Session(
        api,
        RunConfig(**cfg),
        phone=phone,
        rng=random.Random(seed),
        clock=clock or Clock(),
        recorder=Recorder(),
    )


@pytest.mark.parametrize("seed", range(8))
def test_cod_journey_places_and_polls(seed):
    api = FakeApi()
    s = session(api, seed=seed, online_share=0.0, cancel_share=0.0)
    assert s.buyer_journey() == "placed"
    assert api.failures == []
    assert api.journey_failures == []
    order = api.orders[1]
    assert order["status"] == "PLACED"
    names = api.names()
    for expected in (
        f"GET {API}/config/app/",
        f"POST {API}/auth/otp/request/",
        f"POST {API}/auth/otp/verify/",
        f"PATCH {API}/me/",
        f"POST {API}/addresses/",
        f"GET {API}/serviceability/",
        f"GET {API}/home/",
        f"GET {API}/categories/",
        f"GET {API}/products/",
        f"GET {API}/products/{{id_or_slug}}/",
        f"GET {API}/search/suggest/",
        f"GET {API}/search/",
        f"DELETE {API}/cart/",
        f"POST {API}/cart/items/",
        f"PATCH {API}/cart/",
        f"POST {API}/orders/",
        f"GET {API}/orders/",
        f"GET {API}/orders/{{id}}/",
    ):
        assert expected in names, expected
    assert names.count(f"GET {API}/orders/{{id}}/") == 3  # cfg.polls
    assert s.recorder.outcomes == {"order placed": 1}
    assert len(s.recorder.placed) == 1


def test_every_request_has_app_headers_and_catalog_calls_the_store():
    api = FakeApi()
    session(api, online_share=0.0).buyer_journey()
    for _method, _path, name, headers in api.calls:
        assert headers["X-App-Name"] == "customer"
        assert headers["X-App-Version"]
        assert headers["X-Platform"] == "android"
        if name.startswith((f"{API}/cart/", f"{API}/products/", f"{API}/home/", f"{API}/search")):
            assert headers["X-Store-Id"] == str(STORE_ID)


def test_order_uses_the_cart_total_and_a_fresh_idempotency_key():
    api = FakeApi()
    s = session(api, online_share=0.0, cancel_share=0.0)
    s.buyer_journey()
    s.buyer_journey()
    places = [c for c in api.calls if c[0] == "POST" and c[2] == f"{API}/orders/"]
    assert len(places) == 2
    keys = {headers["Idempotency-Key"] for *_, headers in places}
    assert len(keys) == 2
    assert api.tokens == 1  # logged in once, the second journey reuses the session


def test_online_with_the_fake_gateway_verifies_the_signature():
    api = FakeApi()
    s = session(api, online_share=1.0, cancel_share=0.0)
    assert s.buyer_journey() == "placed"
    assert api.failures == []
    assert api.orders[1]["status"] == "PLACED"
    assert f"POST {API}/payments/razorpay/verify/" in api.names()
    assert s.recorder.outcomes["online: paid (fake gateway)"] == 1


def test_online_with_a_real_gateway_is_abandoned_and_cancelled():
    """Staging uses Razorpay test mode (the fake gateway is refused there): no verify is sent,
    the unpaid order is cancelled (T5) and not counted as placed."""
    api = FakeApi(key_id="rzp_test_ABCDEFG")
    s = session(api, online_share=1.0)
    assert s.buyer_journey() == "abandoned"
    assert f"POST {API}/payments/razorpay/verify/" not in api.names()
    assert api.orders[1]["status"] == "CANCELLED"
    assert s.recorder.placed == []
    assert api.failures == []


def test_cancel_share_cancels_after_polling():
    api = FakeApi()
    s = session(api, online_share=0.0, cancel_share=1.0)
    assert s.buyer_journey() == "cancelled"
    assert api.orders[1]["status"] == "CANCELLED"


def test_minimum_order_blocker_is_fixed_by_adding_items():
    api = FakeApi(min_order=__import__("decimal").Decimal("500.00"))
    s = session(api, online_share=0.0, cancel_share=0.0, seed=3)
    assert s.buyer_journey() == "placed"
    assert api.journey_failures == []


def test_a_pending_order_is_cancelled_then_placement_retried():
    api = FakeApi(pending_order_once=True)
    s = session(api, online_share=0.0, cancel_share=0.0)
    assert s.buyer_journey() == "placed"
    assert api.orders[900]["status"] == "CANCELLED"
    assert api.failures == [(f"POST {API}/orders/", 409)]  # visible in the stats, then handled


def test_unserviceable_location_aborts_and_is_recorded():
    api = FakeApi(serviceable=False)
    s = session(api)
    assert s.buyer_journey() == "aborted"
    assert api.journey_failures[0][0] == "serviceability"
    assert f"POST {API}/orders/" not in api.names()


def test_access_token_is_refreshed_before_it_expires():
    api = FakeApi()
    clock = Clock()
    s = session(api, clock=clock, online_share=0.0, cancel_share=0.0)
    s.buyer_journey()
    clock.now += ACCESS_REFRESH_AFTER_S + 1
    s.buyer_journey()
    assert api.refreshes == 1
    assert api.failures == []


def test_browser_is_anonymous():
    api = FakeApi()
    s = Session(api, RunConfig(), rng=random.Random(2), recorder=Recorder())
    assert s.browser_journey() == "browsed"
    assert api.failures == []
    assert all("Authorization" not in headers for *_, headers in api.calls)
    assert f"GET {API}/home/" in api.names()
    with pytest.raises(ValueError, match="anonymous"):
        s.login()


def test_recorder_rate():
    r = Recorder()
    r.placed.extend([(5.0, "COD"), (70.0, "COD"), (80.0, "ONLINE"), (130.0, "COD")])
    assert r.orders_per_min(60, 120) == pytest.approx(2.0)
    assert r.orders_per_min(10, 10) == 0.0
