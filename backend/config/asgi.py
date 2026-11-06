"""ASGI entry point for the `web` process: HTTP (Django/DRF) and WebSockets (Channels).

Production: `gunicorn config.asgi:application -k uvicorn_worker.UvicornWorker`.
Local: `manage.py runserver` (daphne) serves the same application.
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.production")

# Initialise Django before importing anything that touches models.
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402

from config.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        # Phase 6: the Origin check and session auth are per route (apps.realtime.routing): the
        # session-authenticated ops socket keeps AllowedHostsOriginValidator; the JWT app
        # sockets (/ws/v1/) have none, because native mobile clients send no Origin header.
        "websocket": URLRouter(websocket_urlpatterns),
    }
)
