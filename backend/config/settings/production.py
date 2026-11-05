"""Production (02 §4)."""

from django.core.exceptions import ImproperlyConfigured

from .deployed import *

APP_ENVIRONMENT = "production"
SEED_DEMO_ALLOWED = env_bool("SEED_DEMO_ALLOWED", default=False)

# D-15: fixed-OTP test numbers never exist in production. Refuse to start if configured.
if env_str("OTP_TEST_NUMBERS", default="").strip():
    raise ImproperlyConfigured("OTP_TEST_NUMBERS must not be set in production (D-15).")
OTP_TEST_NUMBERS: dict[str, str] = {}

# T-812: load-test data commands never run in production (also the system check loadtest.E001).
if env_bool("LOADTEST_DATA_ALLOWED", default=False):
    raise ImproperlyConfigured("LOADTEST_DATA_ALLOWED must not be set in production (T-812).")
LOADTEST_DATA_ALLOWED = False
