"""Production (02 §4)."""

from django.core.exceptions import ImproperlyConfigured

from .deployed import *

APP_ENVIRONMENT = "production"
SEED_DEMO_ALLOWED = env_bool("SEED_DEMO_ALLOWED", default=False)

# D-15: fixed-OTP test numbers never exist in production. Refuse to start if configured.
if env_str("OTP_TEST_NUMBERS", default="").strip():
    raise ImproperlyConfigured("OTP_TEST_NUMBERS must not be set in production (D-15).")
OTP_TEST_NUMBERS: dict[str, str] = {}
