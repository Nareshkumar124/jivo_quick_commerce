"""Project-wide pytest fixtures.

Tests use real PostgreSQL (`test_jivo_quick_commerce`, managed by pytest-django) and the compose
Redis on port 6380 (DB 15). See config/settings/test.py.
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


@pytest.fixture(autouse=True)
def _isolated_redis_and_outbox():
    """Each test starts with an empty test Redis DB (cached app config, rate-limit counters) and
    an empty SMS outbox. Only ever the dedicated test DB (config/settings/test.py)."""
    from apps.notifications import sms

    assert urlparse(settings.REDIS_URL).path == "/15", "tests must use the test Redis DB"
    cache.clear()
    sms.outbox.clear()
    yield
    sms.outbox.clear()


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
