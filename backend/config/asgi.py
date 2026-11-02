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
from channels.security.websocket import AllowedHostsOriginValidator  # noqa: E402

from config.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        # Phase 6 adds the consumers. Note for that phase: native mobile WebSocket clients send no
        # Origin header, which AllowedHostsOriginValidator rejects. JWT-authenticated app routes
        # (/ws/v1/) will need their own policy; the session-authenticated ops route keeps it.
        "websocket": AllowedHostsOriginValidator(URLRouter(websocket_urlpatterns)),
    }
)
