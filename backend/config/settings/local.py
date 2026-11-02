"""Local development: `uv run python manage.py runserver 8001` or the compose `backend` service."""

from .base import *

APP_ENVIRONMENT = "local"
DEBUG = True

# Development-only fallback. Never used outside local (production requires DJANGO_SECRET_KEY).
SECRET_KEY = SECRET_KEY or "django-insecure-local-development-only-do-not-use-anywhere-else"

# 10.0.2.2 is the host as seen from the Android emulator (http://10.0.2.2:8001).
# `backend` is the compose service name (container-to-container calls, healthchecks).
ALLOWED_HOSTS = env_list(
    "DJANGO_ALLOWED_HOSTS",
    default=["localhost", "127.0.0.1", "[::1]", "10.0.2.2", "backend"],
)

API_DOCS_PUBLIC = env_bool("API_DOCS_PUBLIC", default=True)

REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
}

# D-15 fixed-OTP test numbers (no SMS, no send limits). Override with OTP_TEST_NUMBERS.
OTP_TEST_NUMBERS = env_dict(
    "OTP_TEST_NUMBERS",
    default={
        "+919000000001": "123456",  # test customer (seed_demo)
        "+919000000002": "123456",  # second customer (IDOR checks)
        "+919000000003": "123456",  # rider app login (no rider profile until Phase 5)
    },
)
