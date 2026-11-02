"""WSGI entry point (management/fallback only; the web process is ASGI, see asgi.py)."""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

application = get_wsgi_application()
