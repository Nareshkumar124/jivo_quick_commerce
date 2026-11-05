"""Project-wide pytest fixtures.

Tests use real PostgreSQL (`test_jivo_quick_commerce`, managed by pytest-django) and the compose
Redis on port 6380 (DB 15). Parallel runs pick their own with `POSTGRES_TEST_DB` (must start with
`test_jivo_quick_commerce`) and `TEST_REDIS_DB` (3-15). See config/settings/test.py.

pytest-xdist (`-n 4`) workers share that Redis DB; each keeps its keys under its own namespace
(`settings.TEST_REDIS_NAMESPACE`, config/testing.py), and `cache.clear()` clears only that.
"""

from urllib.parse import urlparse

import pytest
from django.conf import settings
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory


@pytest.fixture
def api_client() -> APIClient:
    return APIClient()


@pytest.fixture
def user(db):
    return UserFactory()


@pytest.fixture
def staff_user(db):
    return StaffUserFactory()


@pytest.fixture
def superuser(db):
    return SuperUserFactory()


@pytest.fixture(autouse=True, scope="session")
def _rate_limit_keys_in_the_worker_namespace():
    """apps.core.ratelimit writes raw Redis keys (`jqc:rl:...`) outside the cache. Prefix them
    with this worker's namespace so parallel workers never share counters, and so the per-test
    `cache.clear()` (which deletes `<namespace>:*`) resets them as FLUSHDB used to."""
    from apps.core import ratelimit

    original = ratelimit._key

    def namespaced_key(limit, ident):
        return f"{settings.TEST_REDIS_NAMESPACE}:{original(limit, ident)}"

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(ratelimit, "_key", namespaced_key)
        yield


@pytest.fixture(autouse=True)
def _isolated_redis_and_outbox(_rate_limit_keys_in_the_worker_namespace):
    """Each test starts with an empty Redis namespace (cached app config, catalog pages,
    rate-limit counters, channel groups) and empty SMS and push outboxes. Only ever this worker's
    keys in the dedicated test DB (config/settings/test.py); never FLUSHDB."""
    from apps.notifications import push, sms

    expected = f"/{settings.TEST_REDIS_DB}"
    assert urlparse(settings.REDIS_URL).path == expected, "tests must use the test Redis DB"
    cache.clear()
    sms.outbox.clear()
    push.outbox.clear()
    push.invalid_tokens.clear()
    yield
    sms.outbox.clear()
    push.outbox.clear()
    push.invalid_tokens.clear()


@pytest.fixture
def make_auth_client():
    """APIClient signed in as `user` with a real access token for `app`."""
    from apps.accounts.services.auth import issue_tokens

    def make(user, app: str = "customer") -> APIClient:
        client = APIClient()
        access, _ = issue_tokens(user, app)
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        return client

    return make


@pytest.fixture
def auth_client(user, make_auth_client) -> APIClient:
    return make_auth_client(user)
