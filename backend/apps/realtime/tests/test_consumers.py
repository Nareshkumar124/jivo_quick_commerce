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


# --------------------------------------------------------------------------- fail closed (review)


def test_ops_recheck_that_raises_closes_the_socket(make_staff, settings, monkeypatch):
    """Code review of f08c329 (Major): a re-check that cannot run never leaves access open."""
    settings.WS_OPS_RECHECK_SECONDS = 0.3
    store = DarkStoreFactory()
    staff = make_staff(roles.OPS)
    headers = session_headers(Client(), staff)
    real = consumers.ops_store_ids
    calls = []

    def flaky(*args):
        calls.append(args)
        if len(calls) > 1:
            raise ConnectionError("database unreachable")
        return real(*args)

    monkeypatch.setattr(consumers, "ops_store_ids", flaky)

    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await expect_close(socket, contract.CLOSE_UNAUTHENTICATED)
        # Closed for good: a store message after the failure is not delivered.
        await group_send(store_group(store.pk), {"type": "alert", "data": {}})
        assert await socket.receive_nothing(timeout=0.3)

    run(scenario)


def test_rider_suspended_mid_session_is_cut_off(user, settings, monkeypatch):
    settings.WS_RIDER_RECHECK_SECONDS = 0.3
    status = {"active": True}
    monkeypatch.setattr(consumers, "active_rider_id", lambda u: 41 if status["active"] else None)
    token = token_for(user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        assert (await receive(socket))["type"] == "auth.ok"
        status["active"] = False  # ops suspend the rider
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_rider_recheck_that_raises_closes_with_4403(user, settings, monkeypatch):
    settings.WS_RIDER_RECHECK_SECONDS = 0.3
    calls = []

    def flaky(u):
        calls.append(u)
        if len(calls) > 1:
            raise ConnectionError("database unreachable")
        return 41

    monkeypatch.setattr(consumers, "active_rider_id", flaky)
    token = token_for(user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        assert (await receive(socket))["type"] == "auth.ok"
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_rider_reauth_with_a_customer_app_token_closes_with_4403(user, monkeypatch):
    monkeypatch.setattr(consumers, "active_rider_id", lambda u: 41)
    rider_token = token_for(user, "rider")
    customer_token = token_for(user, "customer")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": rider_token})
        assert (await receive(socket))["type"] == "auth.ok"
        await socket.send_json_to({"type": "auth", "token": customer_token})
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_rider_reauth_after_suspension_closes_with_4403(user, monkeypatch):
    status = {"active": True}
    monkeypatch.setattr(consumers, "active_rider_id", lambda u: 41 if status["active"] else None)
    first, fresh = token_for(user, "rider"), token_for(user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": first})
        assert (await receive(socket))["type"] == "auth.ok"
        status["active"] = False
        await socket.send_json_to({"type": "auth", "token": fresh})
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


# --------------------------------------------------------------------------- P8 OWASP review


def _staff_clocks(client, *, login_ago: float, seen_ago: float) -> None:
    """Move the staff session clocks (apps.accounts.middleware) back in time."""
    import time

    session = client.session
    now = time.time()
    session["_staff_login_at"] = now - login_ago
    session["_staff_last_seen"] = now - seen_ago
    session.save()


def _ops_socket_closes(headers, code):
    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await expect_close(socket, code)

    run(scenario)


def test_ops_socket_refuses_a_session_past_the_8_hour_limit(make_staff, settings):
    """M1: the absolute staff limit applies to the socket too (store-only staff, no idle)."""
    staff = make_staff(roles.STORE_STAFF, DarkStoreFactory())
    client = Client()
    headers = session_headers(client, staff)
    _staff_clocks(client, login_ago=settings.STAFF_SESSION_MAX_AGE_SECONDS + 5, seen_ago=1)
    _ops_socket_closes(headers, contract.CLOSE_UNAUTHENTICATED)


def test_ops_socket_closes_when_the_session_reaches_its_limit(make_staff, settings):
    """M1: closed at the deadline itself, not at the next 300 s re-check."""
    staff = make_staff(roles.STORE_STAFF, DarkStoreFactory())
    client = Client()
    headers = session_headers(client, staff)
    _staff_clocks(client, login_ago=settings.STAFF_SESSION_MAX_AGE_SECONDS - 8, seen_ago=1)

    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await socket.send_json_to({"type": "ping"})
        assert (await receive(socket))["type"] == "pong"  # open before the deadline
        output = await socket.receive_output(timeout=20)
        assert output == {"type": "websocket.close", "code": contract.CLOSE_UNAUTHENTICATED}

    run(scenario)


def test_ops_socket_refuses_an_idle_admin_session(make_staff, settings):
    """M1: admin roles end after 2 h without a request; the socket follows."""
    DarkStoreFactory()
    staff = make_staff(roles.OPS)
    client = Client()
    headers = session_headers(client, staff)
    _staff_clocks(client, login_ago=3 * 3600, seen_ago=settings.STAFF_SESSION_IDLE_SECONDS + 5)
    _ops_socket_closes(headers, contract.CLOSE_UNAUTHENTICATED)


def test_store_only_staff_have_no_idle_limit_on_the_socket(make_staff, settings):
    staff = make_staff(roles.STORE_STAFF, DarkStoreFactory())
    client = Client()
    headers = session_headers(client, staff)
    _staff_clocks(client, login_ago=3 * 3600, seen_ago=settings.STAFF_SESSION_IDLE_SECONDS + 5)

    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await socket.send_json_to({"type": "ping"})
        assert (await receive(socket))["type"] == "pong"
        await socket.disconnect()

    run(scenario)


def test_ops_socket_refuses_an_expired_or_deleted_session(make_staff):
    """M1: `exists()` ignored `expire_date`; the session is now loaded."""
    from django.contrib.sessions.models import Session
    from django.utils import timezone as tz

    DarkStoreFactory()
    staff = make_staff(superuser=True)
    client = Client()
    headers = session_headers(client, staff)
    Session.objects.filter(session_key=client.session.session_key).update(
        expire_date=tz.now() - timedelta(seconds=1)
    )
    _ops_socket_closes(headers, contract.CLOSE_UNAUTHENTICATED)

    other = Client()
    headers = session_headers(other, staff)
    other.logout()  # deletes the session row
    _ops_socket_closes(headers, contract.CLOSE_UNAUTHENTICATED)


def test_ops_socket_refuses_a_session_without_the_login_stamp(make_staff):
    DarkStoreFactory()
    staff = make_staff(superuser=True)
    client = Client()
    headers = session_headers(client, staff)
    session = client.session
    del session["_staff_login_at"]
    session.save()
    _ops_socket_closes(headers, contract.CLOSE_UNAUTHENTICATED)


def test_too_many_sockets_per_user_closes_with_4429(order, settings):
    """L5: at most WS_MAX_SOCKETS_PER_USER sockets per user; a closed one frees its slot."""
    settings.WS_MAX_SOCKETS_PER_USER = 2
    token = token_for(order.user)

    async def scenario():
        sockets = []
        for _ in range(2):
            socket, _, _ = await open_socket(order_path(order))
            await socket.send_json_to({"type": "auth", "token": token})
            assert (await receive(socket))["type"] == "auth.ok"
            await receive(socket)  # snapshot
            sockets.append(socket)
        third, _, _ = await open_socket(order_path(order))
        await third.send_json_to({"type": "auth", "token": token})
        await expect_close(third, contract.CLOSE_TOO_MANY_SOCKETS)
        await sockets[0].disconnect()
        again, _, _ = await open_socket(order_path(order))
        await again.send_json_to({"type": "auth", "token": token})
        assert (await receive(again))["type"] == "auth.ok"
        for socket in (sockets[1], again):
            await socket.disconnect()

    run(scenario)


def test_too_many_bad_messages_close_with_4400(order, settings):
    """L5: after WS_MAX_BAD_MESSAGES malformed or unknown messages the socket closes."""
    settings.WS_MAX_BAD_MESSAGES = 2
    token = token_for(order.user)

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": token})
        await receive(socket)
        await receive(socket)
        await socket.send_json_to({"type": "nope"})
        assert (await receive(socket))["type"] == "error"
        await socket.send_to(text_data="[1, 2]")
        assert (await receive(socket))["type"] == "error"
        await socket.send_json_to({"type": "nope"})
        await expect_close(socket, contract.CLOSE_BAD_MESSAGE)

    run(scenario)


def test_oversized_message_closes_with_1009(order, settings):
    settings.WS_MAX_MESSAGE_BYTES = 100

    async def scenario():
        socket, _, _ = await open_socket(order_path(order))
        await socket.send_json_to({"type": "auth", "token": "x" * 200})
        await expect_close(socket, contract.CLOSE_MESSAGE_TOO_BIG)

    run(scenario)
