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
"""

from urllib.parse import urlsplit

from config.env import env_test_redis_db

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
            **DATABASES["default"]["OPTIONS"],
            "options": (
                f"-c idle_in_transaction_session_timeout={TEST_DB_IDLE_IN_TRANSACTION_TIMEOUT_MS}"
            ),
        },
    }
}

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
CACHES = {
    "default": {
        **CACHES["default"],
        "LOCATION": REDIS_TEST_URL,
        "KEY_PREFIX": "jqc-test",
    }
}
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [REDIS_TEST_URL], "prefix": "jqc-test-asgi"},
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
# Same numbers as local.py, so the documented test numbers are exercised by the suite.
OTP_TEST_NUMBERS = {
    "+919000000001": "123456",
    "+919000000002": "123456",
    "+919000000003": "123456",
}
