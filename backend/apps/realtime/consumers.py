"""Channels consumers (06 §4). Contract, messages and close codes: `apps.realtime.contract`.

- `/ws/v1/orders/{order_id}/` (`OrderConsumer`): the order's owner only.
- `/ws/v1/rider/` (`RiderConsumer`): an active rider, with a token issued to the rider app.
- `/ws/ops/live/` (`OpsLiveConsumer`): staff session, `orders.view_order`, permitted stores.

App sockets are accepted first (so the close code reaches the app), then must authenticate
within WS_AUTH_TIMEOUT_SECONDS. Nothing is sent to a socket before it is authorised.
"""

import asyncio
import json
import logging

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.conf import settings
from django.utils import timezone

from apps.realtime import contract
from apps.realtime.auth import SocketIdentity, authenticate_token, token_from_subprotocols
from apps.realtime.groups import order_group, rider_group, store_group

logger = logging.getLogger(__name__)


class BaseSocketConsumer(AsyncJsonWebsocketConsumer):
    """Group bookkeeping, control messages and the forwarder of group messages."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.joined: set[str] = set()
        self.tasks: list[asyncio.Task] = []
        self.authorised = False
        self.closing = False

    async def join(self, groups) -> None:
        for group in groups:
            if group not in self.joined:
                await self.channel_layer.group_add(group, self.channel_name)
                self.joined.add(group)

    async def leave(self, groups) -> None:
        for group in list(groups):
            if group in self.joined:
                await self.channel_layer.group_discard(group, self.channel_name)
                self.joined.discard(group)

    async def close_with(self, code: int) -> None:
        if self.closing:
            return
        self.closing = True
        self.authorised = False
        await self.leave(self.joined)
        await self.close(code=code)

    async def disconnect(self, code) -> None:
        for task in self.tasks:
            task.cancel()
        await self.leave(self.joined)

    def later(self, delay: float, coro_fn) -> asyncio.Task:
        async def run():
            await asyncio.sleep(max(0.0, delay))
            await coro_fn()

        task = asyncio.ensure_future(run())
        self.tasks.append(task)
        return task

    async def send_message(self, type_: str, data: dict | None = None) -> None:
        from apps.realtime.services import message

        await self.send_json(message(type_, data))

    async def receive(self, text_data=None, bytes_data=None, **kwargs) -> None:
        try:
            content = json.loads(text_data if text_data is not None else bytes_data)
        except (TypeError, ValueError):
            content = None
        if not isinstance(content, dict):
            await self.on_bad_message()
            return
        await self.receive_json(content)

    async def on_bad_message(self) -> None:
        await self.send_error("Messages must be JSON objects.")

    async def send_error(self, text: str) -> None:
        await self.send_message(contract.ERROR, {"code": "VALIDATION_ERROR", "message": text})

    async def ws_message(self, event) -> None:
        """A group message (`apps.realtime.services.send_now`): forward it if authorised."""
        if self.authorised and not self.closing:
            await self.send_json(event["message"])


class JwtSocketConsumer(BaseSocketConsumer):
    """App sockets: JWT from the subprotocol or the first message, then `authorize()`."""

    identity: SocketIdentity | None = None

    async def connect(self) -> None:
        token, offered = token_from_subprotocols(self.scope.get("subprotocols"))
        await self.accept(subprotocol=contract.SUBPROTOCOL if offered else None)
        if token is not None:
            await self.authenticate(token)
        else:
            self.auth_deadline = self.later(settings.WS_AUTH_TIMEOUT_SECONDS, self._auth_timeout)

    async def _auth_timeout(self) -> None:
        if self.identity is None:
            await self.close_with(contract.CLOSE_AUTH_TIMEOUT)

    async def on_bad_message(self) -> None:
        if self.identity is None:
            await self.close_with(contract.CLOSE_BAD_MESSAGE)
        else:
            await super().on_bad_message()

    async def receive_json(self, content, **kwargs) -> None:
        if self.closing:
            return
        type_ = content.get("type")
        if type_ == contract.AUTH:
            await self.authenticate(content.get("token"))
        elif self.identity is None:
            await self.close_with(contract.CLOSE_BAD_MESSAGE)
        elif type_ == contract.PING:
            await self.send_message(contract.PONG)
        else:
            await self.send_error("Unknown message type.")

    async def authenticate(self, raw) -> None:
        identity = await database_sync_to_async(authenticate_token)(raw)
        if identity is None or (
            self.identity is not None and identity.user.pk != self.identity.user.pk
        ):
            await self.close_with(contract.CLOSE_UNAUTHENTICATED)
            return
        first = self.identity is None
        if first:
            code = await self.authorize(identity)
            if code is not None:
                await self.close_with(code)
                return
        self.identity = identity
        self.authorised = True
        if hasattr(self, "auth_deadline"):
            self.auth_deadline.cancel()
        if getattr(self, "expiry", None) is not None:
            self.expiry.cancel()
        if identity.expires_at is not None:
            remaining = (identity.expires_at - timezone.now()).total_seconds()
            self.expiry = self.later(remaining, self._expired)
        await self.send_message(
            contract.AUTH_OK,
            {
                "user_id": identity.user.pk,
                "expires_at": identity.expires_at.isoformat().replace("+00:00", "Z")
                if identity.expires_at
                else None,
            },
        )
        if first:
            await self.after_auth()

    async def _expired(self) -> None:
        await self.close_with(contract.CLOSE_UNAUTHENTICATED)

    async def authorize(self, identity: SocketIdentity) -> int | None:
        """Join this socket's groups; return a close code to refuse."""
        raise NotImplementedError

    async def after_auth(self) -> None:
        """Send the initial snapshot, if any."""


# --------------------------------------------------------------------------- customer


def own_order_status(user, order_id: int) -> dict | None:
    """The order's `order.status` data, only if it is the user's own (IDOR: None otherwise)."""
    from apps.orders.models import Order
    from apps.realtime.services import order_status_data

    order = Order.objects.filter(pk=order_id, user=user).first()
    return order_status_data(order) if order is not None else None


class OrderConsumer(JwtSocketConsumer):
    async def authorize(self, identity: SocketIdentity) -> int | None:
        self.order_id = int(self.scope["url_route"]["kwargs"]["order_id"])
        if await database_sync_to_async(own_order_status)(identity.user, self.order_id) is None:
            return contract.CLOSE_NOT_FOUND
        # Join before the snapshot, so nothing that changes in between is missed.
        await self.join([order_group(self.order_id)])
        return None

    async def after_auth(self) -> None:
        data = await database_sync_to_async(own_order_status)(self.identity.user, self.order_id)
        if data is not None:
            await self.send_message(contract.ORDER_STATUS, data)


# --------------------------------------------------------------------------- rider


def active_rider_id(user) -> int | None:
    """The user's ACTIVE `delivery.Rider` pk (Phase 5); None without one or before Phase 5."""
    from django.apps import apps

    from apps.accounts.choices import RiderStatus

    try:
        Rider = apps.get_model("delivery", "Rider")
    except LookupError:
        return None
    return (
        Rider.objects.filter(user=user, status=RiderStatus.ACTIVE)
        .values_list("pk", flat=True)
        .first()
    )


class RiderConsumer(JwtSocketConsumer):
    async def authorize(self, identity: SocketIdentity) -> int | None:
        from apps.accounts.choices import AppName

        if identity.app != AppName.RIDER:
            return contract.CLOSE_FORBIDDEN
        rider_id = await database_sync_to_async(active_rider_id)(identity.user)
        if rider_id is None:
            return contract.CLOSE_FORBIDDEN
        await self.join([rider_group(rider_id)])
        return None


# --------------------------------------------------------------------------- ops

LIVE_BOARD_PERMISSION = "orders.view_order"


def ops_store_ids(user_id, session_key: str | None) -> list[int] | int:
    """The store ids the staff user may watch, or the close code that refuses them (05 §3):
    no valid session / not active staff -> 4401; no permission or no store -> 4403."""
    from django.contrib.auth import get_user_model
    from django.contrib.sessions.backends.base import SessionBase
    from django.utils.module_loading import import_string

    from apps.stores.services import stores_for

    if user_id is None or not session_key:
        return contract.CLOSE_UNAUTHENTICATED
    store_class: type[SessionBase] = import_string(f"{settings.SESSION_ENGINE}.SessionStore")
    if not store_class().exists(session_key):
        return contract.CLOSE_UNAUTHENTICATED
    user = get_user_model().objects.filter(pk=user_id).first()
    if user is None or not (user.is_active and user.is_staff):
        return contract.CLOSE_UNAUTHENTICATED
    if not user.has_perm(LIVE_BOARD_PERMISSION):
        return contract.CLOSE_FORBIDDEN
    store_ids = sorted(stores_for(user).values_list("pk", flat=True))
    return store_ids or contract.CLOSE_FORBIDDEN


class OpsLiveConsumer(BaseSocketConsumer):
    """Staff session (AuthMiddlewareStack). Joins one group per permitted store at connect and
    re-checks access every WS_OPS_RECHECK_SECONDS."""

    async def connect(self) -> None:
        await self.accept()
        if await self.check_access():
            self.authorised = True
            self.schedule_recheck()

    def _session_key(self) -> str | None:
        session = self.scope.get("session")
        return getattr(session, "session_key", None)

    async def check_access(self) -> bool:
        user = self.scope.get("user")
        user_id = user.pk if user is not None and user.is_authenticated else None
        result = await database_sync_to_async(ops_store_ids)(user_id, self._session_key())
        if isinstance(result, int):
            await self.close_with(result)
            return False
        wanted = {store_group(pk) for pk in result}
        await self.leave(self.joined - wanted)
        await self.join(sorted(wanted))
        return True

    def schedule_recheck(self) -> None:
        async def recheck():
            if await self.check_access():
                self.schedule_recheck()

        self.later(settings.WS_OPS_RECHECK_SECONDS, recheck)

    async def receive_json(self, content, **kwargs) -> None:
        if self.closing:
            return
        if content.get("type") == contract.PING:
            await self.send_message(contract.PONG)
        else:
            await self.send_error("Unknown message type.")
