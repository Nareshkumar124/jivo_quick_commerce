"""WebSocket consumers (06 §4): auth (first message, subprotocol, never the URL), timeouts, the
owner-only order socket (IDOR), the rider socket and the store-scoped ops socket.

P6-TC: socket auth, IDOR and store scoping (Phase 6 backend tests).
"""

from datetime import timedelta

import pytest
from django.test import Client
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.orders.tests.factories import OrderFactory
from apps.realtime import consumers, contract
from apps.realtime.groups import order_group, rider_group, store_group
from apps.realtime.tests.conftest import (
    expect_close,
    expect_silence,
    group_send,
    open_socket,
    receive,
    run,
    session_headers,
    token_for,
)
from apps.stores.models import StaffStoreAccess
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db(transaction=True)


@pytest.fixture
def order():
    return OrderFactory()


def order_path(order) -> str:
    return f"/ws/v1/orders/{order.pk}/"


# --------------------------------------------------------------------------- order socket


def test_owner_authenticates_with_the_first_message_and_gets_a_snapshot(order):
    token = token_for(order.user)

    async def scenario():
        socket, connected, subprotocol = await open_socket(order_path(order))
        assert connected
        assert subprotocol is None
        await socket.send_json_to({"type": "auth", "token": token})
        ok = await receive(socket)
        assert ok["type"] == "auth.ok"
        assert ok["data"]["user_id"] == order.user.pk
        assert ok["data"]["expires_at"].endswith("Z")
        snapshot = await receive(socket)
        assert snapshot["type"] == "order.status"
        assert snapshot["data"]["order_id"] == order.pk
        assert snapshot["data"]["status"] == "PLACED"
        # Group messages now reach the socket.
        body = {"type": "order.status", "data": {"order_id": order.pk}, "sent_at": "x"}
        await group_send(order_group(order.pk), body)
        assert await receive(socket) == body
        await socket.send_json_to({"type": "ping"})
        assert (await receive(socket))["type"] == "pong"
        await socket.send_json_to({"type": "subscribe"})
        error = await receive(socket)
        assert error["type"] == "error"
        assert error["data"]["code"] == "VALIDATION_ERROR"
        await socket.send_to(text_data="not json")
        assert (await receive(socket))["type"] == "error"
        await socket.disconnect()

    run(scenario)


def test_owner_authenticates_with_the_subprotocol(order):
    token = token_for(order.user)

    async def scenario():
        socket, connected, subprotocol = await open_socket(
            order_path(order), subprotocols=["jivo.v1", f"jivo.auth.{token}"]
        )
        assert connected
        assert subprotocol == "jivo.v1"  # never the token
        assert (await receive(socket))["type"] == "auth.ok"
        assert (await receive(socket))["type"] == "order.status"
        await socket.disconnect()

    run(scenario)


def test_another_users_order_closes_with_4404(order):
    """IDOR: another customer's order id is "not found", like the REST API."""
    token = token_for(UserFactory())

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_NOT_FOUND)

    run(scenario)


def test_unknown_order_closes_with_4404(order):
    token = token_for(order.user)

    async def scenario():
        socket, _, _ = await open_socket(f"/ws/v1/orders/{order.pk + 1000}/")
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_NOT_FOUND)

    run(scenario)


def test_another_users_socket_never_receives_the_order_messages(order):
    other = OrderFactory()  # another customer, another order
    token = token_for(other.user)

    async def scenario():
        socket, _, _ = await open_socket(order_path(other))
        await socket.send_json_to({"type": "auth", "token": token})
        await receive(socket)  # auth.ok
        await receive(socket)  # snapshot of their own order
        await group_send(order_group(order.pk), {"type": "order.status", "data": {}})
        await expect_silence(socket)
        await socket.disconnect()

    run(scenario)


@pytest.mark.parametrize(
    "first_message",
    [{"type": "ping"}, {"type": "auth"}, {"token": "x"}],
)
def test_bad_first_message(order, first_message):
    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to(first_message)
        code = (
            contract.CLOSE_UNAUTHENTICATED
            if first_message.get("type") == "auth"
            else contract.CLOSE_BAD_MESSAGE
        )
        await expect_close(socket, code)

    run(scenario)


def test_non_json_first_message_closes_with_4400(order):
    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_to(text_data="hello")
        await expect_close(socket, contract.CLOSE_BAD_MESSAGE)

    run(scenario)


def test_invalid_and_refresh_tokens_close_with_4401(order):
    from apps.accounts.services.auth import issue_tokens

    _, refresh = issue_tokens(order.user, "customer")

    async def scenario():
        for token in ["not-a-jwt", refresh]:
            socket, _, _ = await open_socket(order_path(order))
            await socket.send_json_to({"type": "auth", "token": token})
            await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_bad_subprotocol_token_closes_with_4401(order):
    async def scenario():
        socket, connected, _ = await open_socket(
            order_path(order), subprotocols=["jivo.v1", "jivo.auth.garbage"]
        )
        assert connected
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_expired_token_closes_with_4401(order):
    token = AccessToken.for_user(order.user)
    token.set_exp(lifetime=timedelta(seconds=-5))

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": str(token)})
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_inactive_user_closes_with_4401(order):
    token = token_for(order.user)
    order.user.is_active = False
    order.user.save(update_fields=["is_active"])

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_no_auth_message_times_out_with_4408(order, settings):
    settings.WS_AUTH_TIMEOUT_SECONDS = 0.2

    async def scenario():
        socket, connected, _ = await open_socket(order_path(order))
        assert connected
        await expect_close(socket, contract.CLOSE_AUTH_TIMEOUT)

    run(scenario)


def test_a_token_in_the_url_is_ignored(order, settings):
    """06 §4: never in the URL. A query token authenticates nothing."""
    settings.WS_AUTH_TIMEOUT_SECONDS = 0.2
    token = token_for(order.user)

    async def scenario():
        socket, _, _ = await open_socket(f"{order_path(order)}?token={token}")
        await expect_close(socket, contract.CLOSE_AUTH_TIMEOUT)

    run(scenario)


def test_the_socket_closes_when_the_token_expires(order):
    token = AccessToken.for_user(order.user)
    token.set_exp(lifetime=timedelta(seconds=3))

    async def scenario():
        import json

        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": str(token)})
        seen = []
        while (output := await socket.receive_output(timeout=10))["type"] == "websocket.send":
            seen.append(json.loads(output["text"])["type"])
        assert seen[0] == "auth.ok"
        assert output == {"type": "websocket.close", "code": contract.CLOSE_UNAUTHENTICATED}

    run(scenario)


def test_reauth_extends_and_another_users_token_closes(order):
    first = token_for(order.user)
    fresh = token_for(order.user)
    stranger = token_for(UserFactory())

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": first})
        await receive(socket)
        await receive(socket)
        await socket.send_json_to({"type": "auth", "token": fresh})
        assert (await receive(socket))["type"] == "auth.ok"  # no second snapshot
        await expect_silence(socket)
        await socket.send_json_to({"type": "auth", "token": stranger})
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_app_sockets_need_no_origin_but_any_origin_is_fine(order):
    """Native apps send no Origin header; the JWT is not ambient, so no Origin check."""
    token = token_for(order.user)

    async def scenario():
        socket, connected, _ = await open_socket(
            order_path(order), headers=[(b"origin", b"https://evil.example")]
        )
        assert connected
        await socket.send_json_to({"type": "auth", "token": token})
        assert (await receive(socket))["type"] == "auth.ok"
        await socket.disconnect()

    run(scenario)


# --------------------------------------------------------------------------- rider socket


def test_rider_socket_refuses_a_customer_app_token(user):
    token = token_for(user, "customer")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_rider_socket_refuses_a_user_without_an_active_rider_profile(user):
    """Until the Phase 5 `delivery.Rider` model exists, nobody is a rider (fail closed)."""
    token = token_for(user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_active_rider_gets_only_their_own_offers(user, monkeypatch):
    monkeypatch.setattr(consumers, "active_rider_id", lambda u: 41 if u.pk == user.pk else None)
    token = token_for(user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        assert (await receive(socket))["type"] == "auth.ok"
        offer = {"type": "offer.new", "data": contract.OFFER_DATA, "sent_at": "x"}
        await group_send(rider_group(41), offer)
        assert await receive(socket) == offer
        await group_send(rider_group(42), offer)  # another rider's offer
        await expect_silence(socket)
        await socket.disconnect()

    run(scenario)


# --------------------------------------------------------------------------- ops socket


def test_ops_socket_needs_a_staff_session():
    async def scenario():
        socket, connected, _ = await open_socket(
            "/ws/ops/live/", headers=[(b"origin", b"http://testserver")]
        )
        assert connected
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)


def test_ops_socket_refuses_a_cross_site_origin(make_staff):
    staff = make_staff(superuser=True)
    headers = [h for h in session_headers(Client(), staff) if h[0] != b"origin"]

    async def scenario():
        _, connected, _ = await open_socket(
            "/ws/ops/live/", headers=[*headers, (b"origin", b"https://evil.example")]
        )
        assert not connected

    run(scenario)


def test_ops_socket_refuses_staff_without_the_board_permission(make_staff):
    store = DarkStoreFactory()
    staff = make_staff(roles.CATALOG_MANAGER, store)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_store_staff_without_a_store_is_refused(make_staff):
    staff = make_staff(roles.STORE_STAFF)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_store_staff_see_only_their_stores(make_staff):
    """05 §3: store roles are scoped to their StaffStoreAccess stores."""
    mine, other = DarkStoreFactory(), DarkStoreFactory()
    staff = make_staff(roles.STORE_MANAGER, mine)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await group_send(store_group(other.pk), {"type": "order.created", "data": {}})
        await expect_silence(socket)
        body = {"type": "order.created", "data": {"store_id": mine.pk}, "sent_at": "x"}
        await group_send(store_group(mine.pk), body)
        assert await receive(socket) == body
        await socket.send_json_to({"type": "ping"})
        assert (await receive(socket))["type"] == "pong"
        await socket.send_json_to({"type": "nope"})
        assert (await receive(socket))["type"] == "error"
        await socket.disconnect()

    run(scenario)


def test_ops_role_sees_every_store(make_staff):
    first, second = DarkStoreFactory(), DarkStoreFactory()
    staff = make_staff(roles.OPS)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        for store in (first, second):
            body = {"type": "alert", "data": {"store_id": store.pk}, "sent_at": "x"}
            await group_send(store_group(store.pk), body)
            assert await receive(socket) == body
        await socket.disconnect()

    run(scenario)


def test_revoked_store_access_closes_the_socket_on_recheck(make_staff, settings):
    settings.WS_OPS_RECHECK_SECONDS = 0.3
    store = DarkStoreFactory()
    staff = make_staff(roles.STORE_STAFF, store)
    headers = session_headers(Client(), staff)

    async def scenario():
        from channels.db import database_sync_to_async

        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await database_sync_to_async(lambda: StaffStoreAccess.objects.filter(user=staff).delete())()
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_logout_closes_the_ops_socket_on_recheck(make_staff, settings):
    settings.WS_OPS_RECHECK_SECONDS = 0.3
    staff = make_staff(superuser=True)
    DarkStoreFactory()
    client = Client()
    headers = session_headers(client, staff)

    async def scenario():
        from channels.db import database_sync_to_async

        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await database_sync_to_async(client.logout)()
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)

    run(scenario)
