"""CGNAT-safe throttling (T-817): on public views a signed-in customer is throttled per user
(identity read from the bearer token), anonymous callers per IP. The request itself stays
anonymous: responses and the per-store cache do not depend on the caller, and a bad or expired
token never turns a public endpoint into a 401.
"""

from datetime import timedelta

import pytest
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.tests.factories import UserFactory
from apps.core import throttling

pytestmark = pytest.mark.django_db

SEARCH = "/api/v1/search/"
SUGGEST = "/api/v1/search/suggest/"
SERVICEABILITY = "/api/v1/serviceability/"
CATEGORIES = "/api/v1/categories/"
POINT = {"lat": "28.4646", "lng": "77.0864"}
CARRIER_IP = "100.64.0.10"  # one CGNAT address shared by everyone below


@pytest.fixture
def search_rate(monkeypatch):
    monkeypatch.setattr(throttling.SearchThrottle, "THROTTLE_RATES", {"search": "2/min"})


@pytest.fixture
def serviceability_rate(monkeypatch):
    monkeypatch.setattr(
        throttling.ServiceabilityThrottle, "THROTTLE_RATES", {"serviceability": "2/min"}
    )


def with_store(client: APIClient, world) -> APIClient:
    client.credentials(**client._credentials, HTTP_X_STORE_ID=str(world.store.pk))
    return client


def search(client, ip=CARRIER_IP):
    return client.get(SEARCH, {"q": "oil"}, REMOTE_ADDR=ip)


def expired_token(user) -> str:
    token = AccessToken.for_user(user)
    token.set_exp(lifetime=-timedelta(minutes=1))
    return str(token)


class TestSearchThrottleIdentity:
    def test_signed_in_customers_behind_one_ip_have_their_own_limit(
        self, make_auth_client, world, search_rate
    ):
        first = with_store(make_auth_client(UserFactory()), world)
        for _ in range(2):
            assert search(first).status_code == 200
        response = search(first)
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        # Another customer on the same carrier IP is not affected...
        assert search(with_store(make_auth_client(UserFactory()), world)).status_code == 200
        # ...nor an anonymous visitor on it, and the first user is limited on any IP.
        assert search(with_store(APIClient(), world)).status_code == 200
        assert search(first, ip="198.51.100.9").status_code == 429

    def test_anonymous_callers_stay_per_ip(self, store_client, search_rate):
        for _ in range(2):
            assert search(store_client).status_code == 200
        assert search(store_client).status_code == 429
        assert search(store_client, ip="198.51.100.9").status_code == 200

    def test_suggest_shares_the_search_limit_per_user(self, make_auth_client, world, search_rate):
        client = with_store(make_auth_client(UserFactory()), world)
        assert search(client).status_code == 200
        assert client.get(SUGGEST, {"q": "can"}, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert client.get(SUGGEST, {"q": "can"}, REMOTE_ADDR=CARRIER_IP).status_code == 429

    @pytest.mark.parametrize("token", ["not-a-jwt", "expired"])
    def test_bad_token_is_never_a_401_and_counts_per_ip(
        self, store_client, user, search_rate, token
    ):
        raw = expired_token(user) if token == "expired" else token
        store_client.credentials(**store_client._credentials, HTTP_AUTHORIZATION=f"Bearer {raw}")
        for _ in range(2):
            assert search(store_client).status_code == 200
        assert search(store_client).status_code == 429  # same IP bucket
        assert search(store_client, ip="198.51.100.9").status_code == 200

    def test_response_does_not_depend_on_the_caller(self, make_auth_client, store_client, world):
        signed_in = search(with_store(make_auth_client(UserFactory()), world)).json()
        assert search(store_client).json() == signed_in

    def test_forwarded_client_ip_behind_the_proxy(self, store_client, search_rate, settings):
        """NUM_PROXIES (T-814): anonymous callers are keyed by the forwarded client IP."""
        settings.REST_FRAMEWORK = {**settings.REST_FRAMEWORK, "NUM_PROXIES": 1}

        def via_proxy(client_ip):
            return store_client.get(
                SEARCH, {"q": "oil"}, REMOTE_ADDR="10.0.0.2", HTTP_X_FORWARDED_FOR=client_ip
            )

        for _ in range(2):
            assert via_proxy("203.0.113.5").status_code == 200
        assert via_proxy("203.0.113.5").status_code == 429
        assert via_proxy("203.0.113.6").status_code == 200


class TestServiceabilityThrottleIdentity:
    def test_signed_in_per_user(self, make_auth_client, world, serviceability_rate):
        client = make_auth_client(UserFactory())
        for _ in range(2):
            assert client.get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert client.get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 429
        other = make_auth_client(UserFactory())
        assert other.get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert APIClient().get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 200

    def test_anonymous_per_ip(self, api_client, world, serviceability_rate):
        for _ in range(2):
            assert api_client.get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert api_client.get(SERVICEABILITY, POINT, REMOTE_ADDR=CARRIER_IP).status_code == 429
        assert api_client.get(SERVICEABILITY, POINT, REMOTE_ADDR="198.51.100.9").status_code == 200

    def test_expired_token_is_not_a_401(self, api_client, user, world):
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {expired_token(user)}")
        assert api_client.get(SERVICEABILITY, POINT).status_code == 200


class TestBaselineOnPublicViews:
    """The default throttles on public views without their own scope (catalog, CMS, ...)."""

    def test_token_moves_the_caller_from_the_ip_bucket_to_the_user_bucket(
        self, make_auth_client, world, monkeypatch
    ):
        monkeypatch.setattr(throttling.BaselineAnonThrottle, "THROTTLE_RATES", {"anon": "1/min"})
        monkeypatch.setattr(throttling.BaselineUserThrottle, "THROTTLE_RATES", {"user": "2/min"})
        anonymous = with_store(APIClient(), world)
        assert anonymous.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert anonymous.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 429
        # The carrier IP is exhausted for anonymous callers, not for a signed-in customer.
        customer = with_store(make_auth_client(UserFactory()), world)
        for _ in range(2):
            assert customer.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert customer.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 429

    def test_tokened_requests_never_use_the_anonymous_ip_bucket(
        self, make_auth_client, world, monkeypatch
    ):
        """A signed-in caller on a public view is counted per user, not in the anon IP bucket."""
        monkeypatch.setattr(throttling.BaselineAnonThrottle, "THROTTLE_RATES", {"anon": "1/min"})
        monkeypatch.setattr(throttling.BaselineUserThrottle, "THROTTLE_RATES", {"user": "50/min"})
        customer = with_store(make_auth_client(UserFactory()), world)
        for _ in range(3):  # above the anon rate of 1/min
            assert customer.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 200
        # The anonymous bucket of that IP is still untouched: its first request passes.
        anonymous = with_store(APIClient(), world)
        assert anonymous.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert anonymous.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 429


class TestSignedInIpCeiling:
    """Many tokens from one IP stay bounded per IP (review of T-817), CGNAT-safe by default."""

    @pytest.fixture
    def ceiling(self, monkeypatch):
        monkeypatch.setattr(
            throttling.SignedInIpCeiling, "THROTTLE_RATES", {"signed_in_ip": "3/min"}
        )

    def test_rotating_accounts_on_one_ip_hit_the_ceiling(
        self, make_auth_client, world, search_rate, ceiling
    ):
        clients = [with_store(make_auth_client(UserFactory()), world) for _ in range(4)]
        for client in clients[:3]:
            assert search(client).status_code == 200  # each user well under 2/min
        response = search(clients[3])
        assert response.status_code == 429
        assert response.json()["error"]["details"]["retry_after_seconds"] > 0
        # Other IPs and anonymous callers on the same IP are not affected.
        assert search(clients[3], ip="198.51.100.9").status_code == 200
        assert search(with_store(APIClient(), world)).status_code == 200

    def test_applies_to_baseline_public_views_once_per_request(
        self, make_auth_client, world, ceiling
    ):
        client = with_store(make_auth_client(UserFactory()), world)
        for _ in range(3):
            assert client.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 200
        assert client.get(CATEGORIES, REMOTE_ADDR=CARRIER_IP).status_code == 429

    def test_views_that_authenticate_are_not_subject_to_it(self, make_auth_client, ceiling):
        client = make_auth_client(UserFactory())
        for _ in range(5):
            assert client.get("/api/v1/me/", REMOTE_ADDR=CARRIER_IP).status_code == 200

    def test_default_is_five_times_the_anonymous_baseline(self, settings):
        rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
        assert rates["signed_in_ip"] == "1500/min"
        assert rates["anon"] == "300/min"


class TestRefreshToken:
    def test_refresh_token_falls_back_to_per_ip_without_a_401(
        self, store_client, user, search_rate
    ):
        """Only access tokens identify a caller; a refresh token is anonymous (per IP)."""
        from rest_framework_simplejwt.tokens import RefreshToken

        refresh = str(RefreshToken.for_user(user))
        store_client.credentials(
            **store_client._credentials, HTTP_AUTHORIZATION=f"Bearer {refresh}"
        )
        for _ in range(2):
            assert search(store_client).status_code == 200
        assert search(store_client).status_code == 429  # the IP bucket
        assert search(store_client, ip="198.51.100.9").status_code == 200
        api = APIClient()
        api.credentials(HTTP_AUTHORIZATION=f"Bearer {refresh}")
        assert api.get(SERVICEABILITY, POINT).status_code == 200


def test_identity_helper(rf, user):
    from rest_framework.request import Request

    from apps.accounts.services.auth import issue_tokens

    access, _ = issue_tokens(user, "customer")
    request = Request(rf.get("/", HTTP_AUTHORIZATION=f"Bearer {access}"))  # no authenticators
    assert not request.user.is_authenticated
    assert throttling.throttle_user_id(request) == str(user.pk)
    assert throttling.throttle_user_id(Request(rf.get("/"))) is None
    basic = Request(rf.get("/", HTTP_AUTHORIZATION="Basic abc"))
    assert throttling.throttle_user_id(basic) is None
