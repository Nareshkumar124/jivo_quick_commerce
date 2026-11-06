"""Phase 5 merged: real riders on the rider socket, the delivery hooks wired to P6, and the
rider-location purge on the real `RiderLocation`."""

from datetime import timedelta

import pytest
from django.contrib.gis.geos import Point
from django.utils import timezone

from apps.accounts.choices import RiderStatus
from apps.delivery import hooks
from apps.delivery.models import Rider, RiderLocation
from apps.delivery.tests.factories import RiderFactory, active_rider
from apps.realtime import consumers, contract, services
from apps.realtime.groups import rider_group, store_group
from apps.realtime.tests.conftest import (
    expect_close,
    group_send,
    open_socket,
    receive,
    run,
    token_for,
)

# --------------------------------------------------------------------------- rider socket


@pytest.mark.django_db(transaction=True)
def test_a_real_active_rider_gets_their_offers_and_is_cut_off_when_suspended(settings):
    settings.WS_RIDER_RECHECK_SECONDS = 1.0
    rider = active_rider()
    token = token_for(rider.user, "rider")

    async def scenario():
        from channels.db import database_sync_to_async

        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        assert (await receive(socket))["type"] == "auth.ok"
        offer = {"type": "offer.new", "data": contract.OFFER_DATA, "sent_at": "x"}
        await group_send(rider_group(rider.pk), offer)
        assert await receive(socket) == offer
        await database_sync_to_async(
            lambda: Rider.objects.filter(pk=rider.pk).update(status=RiderStatus.SUSPENDED)
        )()
        output = await socket.receive_output(timeout=20)
        assert output == {"type": "websocket.close", "code": contract.CLOSE_FORBIDDEN}

    run(scenario)


@pytest.mark.django_db(transaction=True)
def test_a_rider_profile_that_is_not_active_is_refused():
    rider = RiderFactory()  # PENDING_KYC
    token = token_for(rider.user, "rider")

    async def scenario():
        socket, _, _ = await open_socket("/ws/v1/rider/")
        await socket.send_json_to({"type": "auth", "token": token})
        await expect_close(socket, contract.CLOSE_FORBIDDEN)

    run(scenario)


@pytest.mark.django_db
def test_active_rider_id_needs_an_active_user():
    rider = active_rider()
    assert consumers.active_rider_id(rider.user) == rider.pk
    rider.user.is_active = False
    rider.user.save(update_fields=["is_active"])
    assert consumers.active_rider_id(rider.user) is None


# --------------------------------------------------------------------------- delivery hooks

SENT: list = []


@pytest.fixture
def recorded(monkeypatch):
    SENT.clear()
    monkeypatch.setattr(services, "send_now", lambda groups, body: SENT.append((groups, body)))
    return SENT


@pytest.mark.django_db
def test_location_hook_reaches_the_home_store_map_and_no_customer_without_a_task(
    recorded, django_capture_on_commit_callbacks
):
    rider = active_rider()
    with django_capture_on_commit_callbacks(execute=True):
        hooks.publish_rider_location(rider.pk, 28.47, 77.04, timezone.now(), heading=12.0)
    [(groups, body)] = recorded
    assert groups == [store_group(rider.home_store_id)]
    assert body["data"]["rider_id"] == rider.pk
    assert body["data"]["order_id"] is None  # no active task: no customer socket


@pytest.mark.django_db
def test_location_hook_passes_the_order_only_for_an_active_task(monkeypatch):
    calls = []
    monkeypatch.setattr(hooks, "active_task_order_id", lambda rider_id: 1203)
    import apps.realtime as realtime

    monkeypatch.setattr(
        realtime, "publish_rider_location", lambda *args, **kwargs: calls.append(kwargs)
    )
    hooks.publish_rider_location(41, 28.47, 77.04, timezone.now())
    assert calls == [{"order_id": 1203, "heading": None}]


@pytest.mark.django_db
def test_active_task_order_id_is_none_until_the_task_model_exists():
    """Slice 5.3 adds `DeliveryTask`; until then no order is ever tracked from a ping."""
    assert hooks.active_task_order_id(41) is None
    assert hooks.CUSTOMER_TRACKING_TASK_STATUSES == {
        "ASSIGNED",
        "AT_STORE",
        "PICKED_UP",
        "AT_CUSTOMER",
    }


@pytest.mark.django_db
def test_offer_and_push_hooks_call_p6(recorded, django_capture_on_commit_callbacks):
    rider = active_rider()
    with django_capture_on_commit_callbacks(execute=True):
        hooks.publish_offer(rider.pk, contract.OFFER_DATA)
        hooks.send_push(rider.user, "rider.offer_new", {"offer_id": 9001, "task_id": 7001})
    [(groups, body)] = recorded
    assert groups == [rider_group(rider.pk)]
    assert body["type"] == "offer.new"
    assert rider.user.notifications.get().event == "rider.offer_new"


@pytest.mark.django_db
def test_hooks_never_raise(monkeypatch, caplog):
    import apps.notifications as notifications
    import apps.realtime as realtime

    def boom(*args, **kwargs):
        raise ConnectionError("down")

    monkeypatch.setattr(realtime, "publish_offer", boom)
    monkeypatch.setattr(realtime, "publish_rider_location", boom)
    monkeypatch.setattr(notifications, "send_push", boom)
    hooks.publish_offer(1, {})
    hooks.publish_rider_location(1, 28.4, 77.0, timezone.now())
    hooks.send_push(None, "rider.offer_new", {})
    assert caplog.text.count("failed") == 3


# --------------------------------------------------------------------------- retention


@pytest.mark.django_db
def test_purge_old_locations_deletes_only_old_points_in_batches(settings):
    from apps.realtime.tasks import purge_old_locations

    settings.RIDER_LOCATION_RETENTION_DAYS = 30
    rider = active_rider()
    now = timezone.now()
    for days in (31, 40, 45, 1):
        RiderLocation.objects.create(
            rider=rider,
            point=Point(77.04, 28.47, srid=4326),
            accuracy_m=5,
            recorded_at=now - timedelta(days=days),
        )
    assert services.purge_old_locations(batch_size=2) == 3
    assert RiderLocation.objects.count() == 1
    assert purge_old_locations() == 0
