"""pytest settings (pyproject.toml sets DJANGO_SETTINGS_MODULE=config.settings.test).

Tests run against real PostgreSQL (database `test_jivo_quick_commerce`, created and dropped by
pytest-django only) and the compose Redis on port 6380, never SQLite and never another project's
Redis.

Parallel runs against the same servers use separate state:
- `POSTGRES_TEST_DB` (default `test_jivo_quick_commerce`): must start with
  `test_jivo_quick_commerce`, checked in base.py.
- `TEST_REDIS_DB` (default 15): Redis DB index, 3-15.
Example (admin agent):
`POSTGRES_TEST_DB=test_jivo_quick_commerce_admin TEST_REDIS_DB=14 uv run pytest`.

pytest-xdist (`uv run pytest -n 4`, T-408c): pytest-django gives each worker its own database
(`<POSTGRES_TEST_DB>_gw0`, ...) and config/testing.py gives each worker its own Redis key
namespace inside TEST_REDIS_DB.
"""

from urllib.parse import urlsplit

from config.env import env_test_redis_db
from config.testing import worker_redis_namespace

from .base import *

APP_ENVIRONMENT = "test"
DEBUG = False
SECRET_KEY = "test-only-secret-key-not-used-anywhere-else-0123456789abcdefghij"  # noqa: S105
ALLOWED_HOSTS = ["testserver", "localhost"]

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

# The DB server is shared: a test run that is interrupted (Ctrl-C, killed agent) must not leave
# a session idle inside a transaction, holding row locks, for other test runs to wait on.
# PostgreSQL ends such a session after this long. Test databases only: in local, staging and
# production `select_for_update` transactions are legitimate and must not be cut off.
TEST_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS = 5 * 60 * 1000
DATABASES = {
    "default": {
        **DATABASES["default"],
        "OPTIONS": {
            **{k: v for k, v in DATABASES["default"]["OPTIONS"].items() if k != "pool"},
            "options": (
                f"-c idle_in_transaction_session_timeout={TEST_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS}"
            ),
        },
    }
}
# No connection pool in tests (T-218): test database creation and transactional tests manage
# connections themselves.
POSTGRES_POOL = False

# A dedicated Redis DB so tests (which may clear the cache) never touch dev data. REDIS_TEST_URL
# gives the server; TEST_REDIS_DB (default 15) picks the DB index and overrides the URL's path, so
# test runs in parallel (e.g. two agents) use separate DBs. DBs 0-2 are dev (cache, broker,
# channels) and are refused.
TEST_REDIS_DB = env_test_redis_db()
REDIS_TEST_URL = (
    urlsplit(env_str("REDIS_TEST_URL", default="redis://localhost:6380/15"))
    ._replace(path=f"/{TEST_REDIS_DB}")
    .geturl()
)
REDIS_URL = REDIS_TEST_URL
# T-408c: pytest-xdist workers share TEST_REDIS_DB, so each one keeps its keys under its own
# namespace (`jqc-test`, or `jqc-test-gw0`, ... under xdist): cache, channel layer and rate-limit
# counters (re-keyed in conftest.py). `cache.clear()` deletes only that namespace, never FLUSHDB.
TEST_REDIS_NAMESPACE = worker_redis_namespace()
CACHES = {
    "default": {
        **CACHES["default"],
        "BACKEND": "config.testing.NamespacedRedisCache",
        "LOCATION": REDIS_TEST_URL,
        "KEY_PREFIX": TEST_REDIS_NAMESPACE,
    }
}
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_TEST_URL], "prefix": f"{TEST_REDIS_NAMESPACE}:asgi"},
    }
}

# Celery runs tasks inline; nothing is sent to a broker.
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_BROKER_URL = "memory://"

EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
STORAGES = {
    **STORAGES,
    "default": {"BACKEND": "django.core.files.storage.InMemoryStorage"},
    "public": {
        "BACKEND": "django.core.files.storage.InMemoryStorage",
        "OPTIONS": {"base_url": "https://media.test/"},
    },
}

API_DOCS_PUBLIC = True
SEED_DEMO_ALLOWED = True

SMS_BACKEND = "apps.notifications.sms.LocmemSmsBackend"
SMS_OTP_DLT_TEMPLATE_ID = "1007000000000000001"
# Phase 6: push into a list, DLT ids for every notification event with SMS, fast auth timeout.
PUSH_BACKEND = "apps.notifications.push.LocmemPushBackend"
SMS_DLT_TEMPLATE_IDS = {
    "order.placed": "1007000000000000101",
    "order.items_adjusted": "1007000000000000102",
    "order.out_for_delivery": "1007000000000000103",
    "order.cancelled": "1007000000000000104",
    "refund.processed": "1007000000000000105",
}
# Same numbers as local.py, so the documented test numbers are exercised by the suite.
OTP_TEST_NUMBERS = {
    "+919000000001": "123456",
    "+919000000002": "123456",
    "+919000000003": "123456",
}

# Phase 3: tests never call a real payment gateway.
PAYMENT_GATEWAY = "apps.payments.gateways.FakeRazorpayGateway"
