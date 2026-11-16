"""Production (02 §4)."""

from django.core.exceptions import ImproperlyConfigured

from .deployed import *

APP_ENVIRONMENT = "production"

# Security audit m8: demo data never reaches production. seed_demo creates demo staff and
# fixed-OTP customers, and simulate_rider fakes rider pings; both obey this flag. Refuse to start
# if it is set (staging keeps it).
if env_bool("SEED_DEMO_ALLOWED", default=False):
    raise ImproperlyConfigured("SEED_DEMO_ALLOWED must not be set in production (m8).")
SEED_DEMO_ALLOWED = False

# D-15: fixed-OTP test numbers never exist in production. Refuse to start if configured.
if env_str("OTP_TEST_NUMBERS", default="").strip():
    raise ImproperlyConfigured("OTP_TEST_NUMBERS must not be set in production (D-15).")
OTP_TEST_NUMBERS: dict[str, str] = {}

# T-812: load-test data commands never run in production (also the system check loadtest.E001).
if env_bool("LOADTEST_DATA_ALLOWED", default=False):
    raise ImproperlyConfigured("LOADTEST_DATA_ALLOWED must not be set in production (T-812).")
LOADTEST_DATA_ALLOWED = False
