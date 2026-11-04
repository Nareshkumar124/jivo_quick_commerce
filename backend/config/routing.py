"""WebSocket routes (02 §7, 06 §4), from the `realtime` app (Phase 6):
/ws/v1/orders/{order_id}/, /ws/v1/rider/ and /ws/ops/live/.
"""

from apps.realtime.routing import websocket_urlpatterns

__all__ = ["websocket_urlpatterns"]
