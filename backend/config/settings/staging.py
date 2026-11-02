"""Staging: production-like (02 §4) with test keys. Phase gates run seed_demo here."""

from .deployed import *

APP_ENVIRONMENT = "staging"
SEED_DEMO_ALLOWED = env_bool("SEED_DEMO_ALLOWED", default=True)

# D-15: fixed-OTP test numbers are allowed on staging, configured explicitly per deployment.
OTP_TEST_NUMBERS = env_dict("OTP_TEST_NUMBERS", default={})
