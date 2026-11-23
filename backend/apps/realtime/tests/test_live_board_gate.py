"""BUG-0026 (P8-TC-32): the live map's data on `/ws/ops/live/` (`rider.location`,
`delivery.progress`) reaches only staff who may see the live order board (05 §3 "Live order
board": `live_ops.can_view`, `orders.view_order` + `orders.cancel_order`) for their stores.
Finance and Store Staff keep the ops feed (order events, alerts, task and rider status) but get
no rider positions or delivery progress; Catalog has no ops feed at all.
"""

import pytest
from asgiref.sync import sync_to_async
from django.contrib.auth.models import Group
from django.test import Client
from django.utils import timezone

from apps.accounts import roles
from apps.delivery.services import live_ops
from apps.realtime import consumers, contract, services
from apps.realtime.groups import live_board_group, store_group
from apps.realtime.tests.conftest import (
    expect_close,
    expect_silence,
    group_send,
    open_socket,
    receive,
    run,
    session_headers,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db(transaction=True)

LIVE_MAP_TYPES = (contract.RIDER_LOCATION, contract.DELIVERY_PROGRESS)


def _progress(store_id: int) -> dict:
    return {"type": contract.DELIVERY_PROGRESS, "data": {"store_id": store_id}, "sent_at": "x"}


async def _send_location(store_id: int) -> None:
    """The real publish path of an ops `rider.location` (no order: ops map only)."""
    await sync_to_async(services.send_rider_location)(
        7, 28.47, 77.04, timezone.now().isoformat(), store_id=store_id, order_id=None, heading=None
    )


async def _received_types(socket) -> list[str]:
    types = []
    while not await socket.receive_nothing(timeout=0.3):
        types.append((await receive(socket))["type"])
    return types


# --------------------------------------------------------------------------- unit: access


@pytest.mark.parametrize(
    ("role", "live_board"),
    [
        (roles.OPS, True),
        (roles.STORE_MANAGER, True),
        (roles.SUPPORT, True),
        (roles.FINANCE, False),
        (roles.STORE_STAFF, False),
    ],
)
def test_ops_access_carries_the_live_board_flag_of_live_ops_can_view(make_staff, role, live_board):
    """P8-TC-32: the socket uses the same check as the HTTP live map (single source of truth)."""
    store = DarkStoreFactory()
    staff = make_staff(role, store)
    client = Client()
    session_headers(client, staff)  # a real staff login session (stamped at login)
    access = consumers.ops_store_ids(staff.pk, client.session.session_key)
    assert isinstance(access, consumers.OpsAccess), access
    assert store.pk in access.store_ids
    assert access.live_board is live_board
    assert live_ops.can_view(staff) is live_board


# --------------------------------------------------------------------------- sockets


@pytest.mark.parametrize("role", [roles.FINANCE, roles.STORE_STAFF])
def test_roles_without_the_live_board_get_no_live_map_data(make_staff, role):
    """P8-TC-32 / BUG-0026: Finance and Store Staff (on a store they can see) get no
    `rider.location` or `delivery.progress`, but still get the order events and alerts."""
    store = DarkStoreFactory()
    staff = make_staff(role, store)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, connected, _ = await open_socket("/ws/ops/live/", headers=headers)
        assert connected
        await _send_location(store.pk)
        await group_send(live_board_group(store.pk), _progress(store.pk))
        await expect_silence(socket)
        created = {"type": "order.created", "data": {"store_id": store.pk}, "sent_at": "x"}
        await group_send(store_group(store.pk), created)
        assert await receive(socket) == created
        alert = {"type": "alert", "data": {"store_id": store.pk}, "sent_at": "x"}
        await group_send(store_group(store.pk), alert)
        assert await receive(socket) == alert
        await socket.disconnect()

    run(scenario)


@pytest.mark.parametrize("role", [roles.OPS, roles.SUPPORT])
def test_live_board_roles_get_the_live_map_data(make_staff, role):
    """P8-TC-32: Ops and Support (05 §3 "Live order board" view) get both live-map messages."""
    store = DarkStoreFactory()
    staff = make_staff(role)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await _send_location(store.pk)
        location = await receive(socket)
        assert location["type"] == contract.RIDER_LOCATION
        assert location["data"]["store_id"] == store.pk
        await group_send(live_board_group(store.pk), _progress(store.pk))
        assert await receive(socket) == _progress(store.pk)
        await socket.disconnect()

    run(scenario)


def test_store_manager_gets_live_map_data_of_own_store_only(make_staff):
    """P8-TC-32: Store Manager (own stores) gets its store's live map data, never another's."""
    mine, other = DarkStoreFactory(), DarkStoreFactory()
    staff = make_staff(roles.STORE_MANAGER, mine)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await _send_location(other.pk)
        await group_send(live_board_group(other.pk), _progress(other.pk))
        await expect_silence(socket)
        await _send_location(mine.pk)
        await group_send(live_board_group(mine.pk), _progress(mine.pk))
        assert await _received_types(socket) == list(LIVE_MAP_TYPES)
        await socket.disconnect()

    run(scenario)


def test_catalog_manager_has_no_ops_feed(make_staff):
    """P8-TC-32: Catalog (no `orders.view_order`) is refused the socket outright."""
    store = DarkStoreFactory()
    staff = make_staff(roles.CATALOG_MANAGER, store)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


def test_losing_the_live_board_on_recheck_stops_the_live_map_data(make_staff, settings):
    """BUG-0026: the live-board groups follow the periodic re-check like the store groups; the
    order feed stays open for a user who keeps `orders.view_order`."""
    settings.WS_OPS_RECHECK_SECONDS = 0.3
    store = DarkStoreFactory()
    staff = make_staff(roles.STORE_MANAGER, store)
    headers = session_headers(Client(), staff)

    async def scenario():
        socket, _, _ = await open_socket("/ws/ops/live/", headers=headers)
        await group_send(live_board_group(store.pk), _progress(store.pk))
        assert await receive(socket) == _progress(store.pk)

        def demote():
            staff.groups.clear()
            staff.groups.add(Group.objects.get(name=roles.STORE_STAFF))

        await sync_to_async(demote)()
        await socket.receive_nothing(timeout=0.8)  # let the re-check run
        await group_send(live_board_group(store.pk), _progress(store.pk))
        await expect_silence(socket)
        created = {"type": "order.created", "data": {"store_id": store.pk}, "sent_at": "x"}
        await group_send(store_group(store.pk), created)
        assert await receive(socket) == created
        await socket.disconnect()

    run(scenario)
