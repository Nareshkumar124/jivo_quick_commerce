"""Socket test helpers: drive `config.asgi.application` with Channels' WebsocketCommunicator.

Tests are sync functions that run one coroutine with `async_to_sync` (no pytest-asyncio). The
consumers' `database_sync_to_async` calls run back on the test thread (asgiref thread-sensitive
mode), so they see the test's transaction; `transactional_db` is used because the consumers'
`close_old_connections` would otherwise end the test transaction.
"""

import pytest
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from channels.testing import WebsocketCommunicator
from django.contrib.auth.models import Group

from apps.accounts.services.auth import issue_tokens
from apps.accounts.tests.factories import StaffUserFactory
from apps.stores.services import grant_store_access

TIMEOUT = 10


def run(coroutine_function):
    return async_to_sync(coroutine_function)()


def token_for(user, app: str = "customer") -> str:
    return issue_tokens(user, app)[0]


async def open_socket(path: str, *, subprotocols=None, headers=None):
    from config.asgi import application

    communicator = WebsocketCommunicator(
        application, path, subprotocols=subprotocols, headers=headers or []
    )
    connected, subprotocol = await communicator.connect(timeout=TIMEOUT)
    return communicator, connected, subprotocol


async def receive(communicator) -> dict:
    return await communicator.receive_json_from(timeout=TIMEOUT)


async def expect_close(communicator, code: int) -> None:
    output = await communicator.receive_output(timeout=TIMEOUT)
    assert output == {"type": "websocket.close", "code": code}, output


async def expect_silence(communicator) -> None:
    assert await communicator.receive_nothing(timeout=0.3)


async def group_send(group: str, body: dict) -> None:
    await get_channel_layer().group_send(group, {"type": "ws.message", "message": body})


@pytest.fixture
def make_staff(transactional_db):
    def make(role=None, *stores, superuser=False):
        user = StaffUserFactory(is_superuser=superuser)
        if role:
            user.groups.add(Group.objects.get(name=role))
        for store in stores:
            grant_store_access(user, store)
        return user

    return make


def session_headers(client, user) -> list[tuple[bytes, bytes]]:
    """Cookie + same-site Origin for the staff socket, from a real Django session login."""
    client.force_login(user)
    cookie = client.cookies["sessionid"].value
    return [(b"cookie", f"sessionid={cookie}".encode()), (b"origin", b"http://testserver")]
