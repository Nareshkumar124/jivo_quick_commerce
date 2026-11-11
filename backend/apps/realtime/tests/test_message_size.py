"""BUG-0020, P6-TC-50 (06 §4.1): an inbound message over WS_MAX_MESSAGE_BYTES (4096) closes the
socket with 1009, is never processed, and logs a WARNING line, never an ERROR traceback. On every
consumer that enforces the limit (customer order socket, rider socket, ops socket), before and
after auth.

WebsocketCommunicator accepts any close code, so these tests alone could not catch the daphne
refusal of 1009: `test_daphne_compat.py` and `test_real_servers.py` cover the servers.
"""

import json
import logging

import pytest
from django.test import Client

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.orders.tests.factories import OrderFactory
from apps.realtime import consumers, contract
from apps.realtime.tests.conftest import (
    expect_close,
    open_socket,
    receive,
    run,
    session_headers,
    token_for,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db(transaction=True)

LIMIT = 4096  # the 06 §4.1 default, not lowered: the test sends what QA sent (about 5,000 bytes)


def message_of(size: int, *, type_: str = contract.PING, char: str = "x", **fields) -> str:
    """A JSON text message of exactly `size` UTF-8 bytes."""
    base = json.dumps({"type": type_, **fields, "pad": ""}, ensure_ascii=False)
    room = size - len(base.encode())
    assert room >= 0
    assert room % len(char.encode()) == 0
    pad = char * (room // len(char.encode()))
    return json.dumps({"type": type_, **fields, "pad": pad}, ensure_ascii=False)


@pytest.fixture
def spec(request, make_staff, monkeypatch):
    """(path, headers, token, after-auth messages to read) for the socket `request.param`."""
    kind = request.param
    if kind == "order":
        order = OrderFactory()
        return f"/ws/v1/orders/{order.pk}/", [], token_for(order.user), 2  # auth.ok + snapshot
    if kind == "rider":
        rider_user = UserFactory()
        monkeypatch.setattr(
            consumers, "active_rider_id", lambda u: 41 if u.pk == rider_user.pk else None
        )
        return "/ws/v1/rider/", [], token_for(rider_user, "rider"), 1
    DarkStoreFactory()
    staff = make_staff(roles.OPS)
    return "/ws/ops/live/", session_headers(Client(), staff), None, 0  # session: no auth message


async def ready_socket(spec, *, authenticated: bool):
    path, headers, token, replies = spec
    socket, connected, _ = await open_socket(path, headers=headers)
    assert connected
    if authenticated and token is not None:
        await socket.send_json_to({"type": "auth", "token": token})
        for _ in range(replies):
            await receive(socket)
    return socket


class LogRecords(logging.Handler):
    """Collects every record that reaches the root logger. Not `caplog`: the first socket in a
    process imports `config.asgi`, whose Django setup re-applies LOGGING and so removes caplog's
    handler from the root logger. This one is attached after the socket is open."""

    def __init__(self):
        super().__init__(logging.DEBUG)
        self.records: list[logging.LogRecord] = []

    def emit(self, record):
        self.records.append(record)

    def __enter__(self):
        logging.getLogger().addHandler(self)
        return self

    def __exit__(self, *exc):
        logging.getLogger().removeHandler(self)


def assert_warning_only(logs: LogRecords) -> None:
    errors = [r for r in logs.records if r.levelno >= logging.ERROR]
    assert not errors, [r.getMessage() for r in errors]
    warnings = [
        r
        for r in logs.records
        if r.name == "apps.realtime.consumers" and r.levelno == logging.WARNING
    ]
    assert len(warnings) == 1, [r.getMessage() for r in logs.records]
    assert "over WS_MAX_MESSAGE_BYTES (4096); closing with 1009" in warnings[0].getMessage()


@pytest.mark.parametrize(
    ("spec", "authenticated"),
    [
        ("order", False),
        ("order", True),
        ("rider", False),
        ("rider", True),
        ("ops", True),  # the staff session authenticates the socket at connect
    ],
    indirect=["spec"],
    ids=["order-before-auth", "order-after-auth", "rider-before-auth", "rider-after-auth", "ops"],
)
def test_oversized_message_closes_with_1009_and_logs_no_error(spec, authenticated, settings):
    """BUG-0020, P6-TC-50: about 5,000 bytes, before and after auth, on every socket. Before
    auth the oversized message is a valid auth message: it is not processed (no `auth.ok`)."""
    settings.WS_MAX_MESSAGE_BYTES = LIMIT
    _, _, token, _ = spec

    async def scenario():
        socket = await ready_socket(spec, authenticated=authenticated)
        if authenticated or token is None:
            oversized = message_of(5000)  # a ping: no pong comes back
        else:
            oversized = message_of(5000, type_=contract.AUTH, token=token)
        with LogRecords() as logs:
            await socket.send_to(text_data=oversized)
            await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)
            await socket.disconnect()
        assert_warning_only(logs)

    run(scenario)


@pytest.mark.parametrize("spec", ["order", "rider", "ops"], indirect=True)
def test_a_message_of_exactly_the_limit_is_processed(spec, settings):
    """The limit is inclusive: WS_MAX_MESSAGE_BYTES bytes is fine, one more closes 1009."""
    settings.WS_MAX_MESSAGE_BYTES = LIMIT

    async def scenario():
        socket = await ready_socket(spec, authenticated=True)
        await socket.send_to(text_data=message_of(LIMIT))
        assert (await receive(socket))["type"] == contract.PONG
        await socket.send_to(text_data=message_of(LIMIT + 1))
        await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)

    run(scenario)


@pytest.mark.parametrize("spec", ["order"], indirect=True)
def test_the_limit_counts_utf8_bytes_not_characters(spec, settings):
    settings.WS_MAX_MESSAGE_BYTES = 400  # the auth message (a JWT, about 300 bytes) fits

    async def scenario():
        socket = await ready_socket(spec, authenticated=True)
        text = message_of(403, char="é")  # 2 bytes each: 215 characters, 403 bytes
        assert len(text) <= 400 < len(text.encode())
        await socket.send_to(text_data=text)
        await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)

    run(scenario)


@pytest.mark.parametrize("spec", ["order"], indirect=True)
def test_binary_messages_count_too(spec, settings):
    settings.WS_MAX_MESSAGE_BYTES = LIMIT

    async def scenario():
        socket = await ready_socket(spec, authenticated=True)
        await socket.send_to(bytes_data=b"x" * (LIMIT + 1))
        await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)

    run(scenario)


@pytest.mark.parametrize("spec", ["order"], indirect=True)
def test_a_socket_closed_for_size_frees_its_slot(spec, settings):
    """The 1009 close goes through `close_with`: the per-user socket slot (L5) is released."""
    settings.WS_MAX_MESSAGE_BYTES = LIMIT
    settings.WS_MAX_SOCKETS_PER_USER = 1

    async def scenario():
        socket = await ready_socket(spec, authenticated=True)
        await socket.send_to(text_data=message_of(5000))
        await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)
        again = await ready_socket(spec, authenticated=False)
        await again.send_json_to({"type": "auth", "token": spec[2]})
        assert (await receive(again))["type"] == contract.AUTH_OK
        await again.disconnect()

    run(scenario)
