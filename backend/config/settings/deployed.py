"""Shared hardening for deployed environments (staging and production). Every secret is required
from the environment; nothing falls back to a default.

Checked in CI with `manage.py check --deploy --fail-level WARNING`.
"""

from django.core.exceptions import ImproperlyConfigured

from config.sentry import init_sentry

from .base import *

DEBUG = False

SECRET_KEY = env_str("DJANGO_SECRET_KEY")
if len(SECRET_KEY) < 50:
    raise ImproperlyConfigured("DJANGO_SECRET_KEY must be at least 50 characters long.")
SIMPLE_JWT = {**SIMPLE_JWT, "SIGNING_KEY": env_str("JWT_SIGNING_KEY", default=SECRET_KEY)}

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
if not ALLOWED_HOSTS:
    raise ImproperlyConfigured("DJANGO_ALLOWED_HOSTS must list at least one host.")

# Deployed behind nginx / a load balancer (02 §8): the number of trusted proxies must be set
# explicitly, otherwise every client would share the proxy's IP for OTP limits and the lockout.
NUM_PROXIES = env_int("NUM_PROXIES")
REST_FRAMEWORK = {**REST_FRAMEWORK, "NUM_PROXIES": NUM_PROXIES or None}

# TLS is terminated by nginx / the load balancer (02 §8).
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", default=True)
SECURE_REDIRECT_EXEMPT = [r"^health/"]  # load-balancer probes may use plain HTTP
SECURE_HSTS_SECONDS = env_int("DJANGO_SECURE_HSTS_SECONDS", default=60 * 60 * 24 * 365)
SECURE_HSTS_INCLUDE_SUBDOMAINS = env_bool("DJANGO_SECURE_HSTS_INCLUDE_SUBDOMAINS", default=True)
SECURE_HSTS_PRELOAD = env_bool("DJANGO_SECURE_HSTS_PRELOAD", default=True)
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

API_DOCS_PUBLIC = False

init_sentry()
