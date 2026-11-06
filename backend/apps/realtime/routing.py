"""WebSocket routes (06 §4).

App sockets (`/ws/v1/`) authenticate with the JWT and have no Origin check: native apps send no
Origin header and the token is not ambient, so another site cannot ride on it. The staff socket
uses the session cookie, so it keeps the Origin check (cross-site WebSocket hijacking).
"""

from channels.auth import AuthMiddlewareStack
from channels.security.websocket import AllowedHostsOriginValidator
from django.urls import path

from apps.realtime.consumers import OpsLiveConsumer, OrderConsumer, RiderConsumer

websocket_urlpatterns = [
    path("ws/v1/orders/<int:order_id>/", OrderConsumer.as_asgi()),
    path("ws/v1/rider/", RiderConsumer.as_asgi()),
    path(
        "ws/ops/live/",
        AllowedHostsOriginValidator(AuthMiddlewareStack(OpsLiveConsumer.as_asgi())),
    ),
]
