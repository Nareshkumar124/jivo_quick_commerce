"""pytest settings (pyproject.toml sets DJANGO_SETTINGS_MODULE=config.settings.test).

Tests run against real PostgreSQL (database `test_jivo_quick_commerce`, created and dropped by
pytest-django only) and the compose Redis on port 6380, never SQLite and never another project's
Redis.
"""

from .base import *

APP_ENVIRONMENT = "test"
DEBUG = False
SECRET_KEY = "test-only-secret-key-not-used-anywhere-else-0123456789abcdefghij"  # noqa: S105
ALLOWED_HOSTS = ["testserver", "localhost"]

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

# A dedicated Redis DB so tests (which may clear the cache) never touch dev data.
REDIS_TEST_URL = env_str("REDIS_TEST_URL", default="redis://localhost:6380/15")
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
