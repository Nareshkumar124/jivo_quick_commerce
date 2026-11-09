# ruff: noqa: F811 - make_staff is a fixture imported from the realtime conftest
"""T-612 over real sockets (`WebsocketCommunicator`, Redis channel layer, eager Celery):
offer latency (< 3 s from dispatch to the rider socket), rider and store scoping, the customer
tracking socket (rider.location + order.eta), and `notification.new` (api-requests #47)."""

import time

import pytest
from channels.db import database_sync_to_async
from django.utils import timezone

from apps.delivery.models import DeliveryOffer, DeliveryTask
from apps.delivery.services import dispatch
from apps.realtime.tests.conftest import (  # noqa: F401 - make_staff is a fixture
    expect_silence,
    make_staff,
    open_socket,
    receive,
    run,
    session_headers,
    token_for,
)

OFFER_LATENCY_SECONDS = 3.0


async def _app_socket(path: str, token: str):
    socket, connected, _ = await open_socket(path)
    assert connected
    await socket.send_json_to({"type": "auth", "token": token})
    assert (await receive(socket))["type"] == "auth.ok"
    return socket


async def _next(socket, type_: str, limit: int = 10) -> dict:
    for _ in range(limit):
        message = await receive(socket)
        if message["type"] == type_:
            return message
    raise AssertionError(f"no {type_}")


@pytest.mark.django_db(transaction=True)
def test_offer_reaches_the_rider_socket_within_3_seconds(place, store_steps, make_rider):
    """P6-TC (T-612 acceptance): dispatch -> `offer.new` on `/ws/v1/rider/` in under 3 s.
    Another rider of the store gets nothing (scoping)."""
    order = place()
    store_steps.accept(order)  # no rider online yet: dispatch finds nobody
    rider = make_rider()
    bystander = make_rider((28.4700, 77.05))  # same store, ranked after `rider`
    DeliveryTask.objects.filter(order=order).update(next_dispatch_at=None)
    tokens = (token_for(rider.user, "rider"), token_for(bystander.user, "rider"))

    async def scenario():
        socket = await _app_socket("/ws/v1/rider/", tokens[0])
        other = await _app_socket("/ws/v1/rider/", tokens[1])
        started = time.monotonic()
        result = await database_sync_to_async(dispatch.dispatch_order)(order.pk)
        assert result == "offered"
        message = await receive(socket)
        elapsed = time.monotonic() - started
        assert message["type"] == "offer.new"
        offer = await database_sync_to_async(
            lambda: DeliveryOffer.objects.get(task__order=order, status="PENDING")
        )()
        assert message["data"]["id"] == offer.pk
        assert elapsed < OFFER_LATENCY_SECONDS, elapsed
        await expect_silence(other)
        await socket.disconnect()
        await other.disconnect()

    run(scenario)


@pytest.mark.django_db(transaction=True)
def test_ops_socket_gets_the_dispatch_board_of_its_stores_only(
    client, place, store_steps, make_rider, make_staff
):
    """`task.status` / `rider.status` are store-scoped: a manager of another store hears
    nothing."""
    from apps.stores.tests.factories import DarkStoreFactory

    order = place()
    manager = make_staff("Store Manager", order.store)
    stranger = make_staff("Store Manager", DarkStoreFactory())
    rider = make_rider()
    mine_headers = session_headers(client, manager)
    from django.test import Client

    theirs_headers = session_headers(Client(), stranger)

    async def scenario():
        mine, ok, _ = await open_socket("/ws/ops/live/", headers=mine_headers)
        assert ok
        theirs, ok, _ = await open_socket("/ws/ops/live/", headers=theirs_headers)
        assert ok
        await database_sync_to_async(store_steps.accept)(order)  # dispatch starts (T6)
        board = await _next(mine, "task.status")
        assert board["data"]["store_id"] == order.store_id
        assert board["data"]["order_id"] == order.pk
        assert board["data"]["status"] in ("SEARCHING", "OFFERED")
        await expect_silence(theirs)
        await mine.disconnect()
        await theirs.disconnect()

    assert rider.home_store_id == order.store_id
    run(scenario)


@pytest.mark.django_db(transaction=True)
def test_customer_socket_gets_rider_location_eta_and_new_inbox_entries(
    place, store_steps, make_rider, rider_client
):
    """While out for delivery a ping reaches the owner's order socket as `rider.location`
    (with `order_id`) followed by `order.eta`; a new inbox entry arrives as
    `notification.new` with the unread count."""
    from apps.delivery.tests.test_task_flow import Flow

    rider = make_rider()
    order = place()
    store_steps.accept(order)  # eager: dispatch offers to `rider`
    f = Flow(order, rider, rider_client(rider), store_steps)
    offer = DeliveryOffer.objects.get(task__order=order, status="PENDING")
    f.task_id = f.client.post(f"/api/v1/rider/offers/{offer.pk}/accept/").json()["id"]
    assert f.at_store().status_code == 200
    store_steps.pack(order)
    assert f.pickup().status_code == 200
    from django.core.cache import cache

    cache.delete(f"ws:eta:{order.pk}")
    customer = order.user
    token = token_for(customer)

    async def scenario():
        socket = await _app_socket(f"/ws/v1/orders/{order.pk}/", token)
        assert (await receive(socket))["type"] == "order.status"  # snapshot
        point = {
            "lat": 28.4510,
            "lng": 77.0503,
            "accuracy": 8.0,
            "recorded_at": timezone.now().isoformat(),
        }
        response = await database_sync_to_async(
            lambda: f.client.post("/api/v1/rider/locations/", {"points": [point]}, format="json")
        )()
        assert response.status_code in (200, 201)
        location = await _next(socket, "rider.location")
        assert location["data"]["order_id"] == order.pk
        assert location["data"]["lat"] == 28.4510
        eta = await _next(socket, "order.eta")
        assert eta["data"]["order_id"] == order.pk
        assert eta["data"]["eta_minutes"] >= 1

        from apps import notifications

        await database_sync_to_async(
            lambda: notifications.services.notify(
                customer, "order.accepted", {"order_id": order.pk, "ref": "t612"}
            )
        )()
        new = await _next(socket, "notification.new")
        assert new["data"]["title"] == "Order confirmed"
        assert new["data"]["unread_count"] >= 1
        await socket.disconnect()

    run(scenario)
