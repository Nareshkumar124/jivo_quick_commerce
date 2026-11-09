"""Publishing (06 §4.4) and the WebSocket contract: every example and every payload the server
really sends validates against its `Ws...` component (the apps build against them)."""

from decimal import Decimal

import jsonschema
import pytest
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.gis.geos import Point
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.realtime import contract, services
from apps.realtime.groups import order_group, rider_group, store_group
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db


@pytest.fixture(scope="module")
def components() -> dict:
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


def validate(components, name: str, value: dict) -> None:
    jsonschema.validate(value, to_json_schema({"$ref": f"#/components/schemas/{name}"}, components))


SENT: list[tuple[list[str], dict]] = []


@pytest.fixture(autouse=True)
def _record_sends(monkeypatch):
    """Record what reaches the channel layer (`services.send_now`). Delivery from the layer to a
    socket is covered by test_consumers.py and `test_send_now_reaches_the_channel_layer`."""
    SENT.clear()
    monkeypatch.setattr(
        services, "send_now", lambda groups, body: SENT.append((list(groups), body))
    )
    yield
    SENT.clear()


class Listener:
    """The messages sent to any of `groups`, in order."""

    def __init__(self, *groups):
        self.groups = set(groups)

    def messages(self, timeout: float = 0) -> list[dict]:
        return [body for groups, body in SENT if self.groups & set(groups)]


# --------------------------------------------------------------------------- contract


def test_every_ws_component_is_published_with_a_valid_example(components):
    names = {name for name, *_ in contract.MESSAGES}
    for name in [*names, "WsAuthRequest", "WsPingRequest"]:
        assert name in components, name
        validate(components, name, components[name]["example"])
    assert set(contract.examples()) == names
    for message_type in [
        "order.status",
        "rider.location",
        "order.eta",
        "offer.new",
        "offer.withdrawn",
        "task.updated",
        "order.created",
        "rider.status",
        "alert",
    ]:
        assert any(type_ == message_type for _, type_, *_ in contract.MESSAGES), message_type


def test_ws_examples_reject_unknown_keys(components):
    bad = {**contract.examples()["WsOrderStatusMessage"]}
    bad["data"] = {**bad["data"], "delivery_otp": "1234"}
    with pytest.raises(jsonschema.ValidationError):
        validate(components, "WsOrderStatusMessage", bad)


# --------------------------------------------------------------------------- order events


def test_status_event_goes_to_the_order_and_its_store(components):
    order = OrderFactory(status=OrderStatus.ACCEPTED, eta_at=timezone.now())
    listener = Listener(order_group(order.pk))
    ops = Listener(store_group(order.store_id))
    assert services.publish_order_event("order.accepted", order.pk) == [
        "order.status",
        "order.eta",
    ]
    message, eta = listener.messages()
    assert message["type"] == "order.status"
    assert message["data"]["status"] == "ACCEPTED"
    validate(components, "WsOrderStatusMessage", message)
    # T-612: the recomputed ETA follows every status change (08 §8), to the customer only.
    assert eta["type"] == "order.eta"
    validate(components, "WsOrderEtaMessage", eta)
    assert ops.messages() == [message]


def test_placed_also_sends_order_created_to_the_store(components):
    order = OrderFactory()  # no lines: item_count 0
    ops = Listener(store_group(order.store_id))
    assert services.publish_order_event("order.placed", order.pk) == [
        "order.status",
        "order.eta",
        "order.created",
    ]
    status, created = ops.messages()
    assert created["type"] == "order.created"
    assert created["data"] == {
        "order_id": order.pk,
        "order_number": order.order_number,
        "store_id": order.store_id,
        "status": "PLACED",
        "payment_method": "COD",
        "item_count": 0,
        "grand_total": "300.00",
        "placed_at": services.iso(order.placed_at),
        "eta_at": None,
    }
    validate(components, "WsOrderCreatedMessage", created)
    validate(components, "WsOrderStatusMessage", status)


@pytest.mark.parametrize(
    ("event", "code"),
    [
        ("order.acceptance_sla_breached", "ACCEPTANCE_SLA_BREACHED"),
        ("payment.late_capture", "LATE_CAPTURE"),
        ("payment.refund_failed", "REFUND_FAILED"),
    ],
)
def test_ops_alert_events(components, event, code):
    order = OrderFactory()
    customer = Listener(order_group(order.pk))
    ops = Listener(store_group(order.store_id))
    assert services.publish_order_event(event, order.pk) == ["alert"]
    [alert] = ops.messages()
    assert alert["data"]["code"] == code
    assert order.order_number in alert["data"]["message"]
    validate(components, "WsAlertMessage", alert)
    assert customer.messages(timeout=0.2) == []  # alerts never reach the customer


def test_unknown_order_publishes_nothing():
    assert services.publish_order_event("order.accepted", 999_999) == []


def test_order_event_task_fans_out(django_capture_on_commit_callbacks):
    """apps.orders.events.emit -> order_event -> socket + notification tasks (eager)."""
    from apps.orders import events

    order = OrderFactory(status=OrderStatus.ACCEPTED)
    listener = Listener(order_group(order.pk))
    with django_capture_on_commit_callbacks(execute=True):
        events.emit(events.ACCEPTED, order.pk)
    # T-612: `order.eta` follows the status (08 §8); `notification.new` goes to the user group.
    types = [m["type"] for m in listener.messages()]
    assert types[0] == "order.status"
    assert set(types[1:]) == {"order.eta"}  # also after dispatch creates the task
    assert order.user.notifications.filter(event="order.accepted").count() == 1


def test_a_failing_socket_publish_does_not_stop_the_notification(monkeypatch):
    from apps.orders.tasks import order_event

    def boom(*args, **kwargs):
        raise ConnectionError("redis down")

    monkeypatch.setattr(services, "send_now", boom)  # Redis down
    order = OrderFactory(status=OrderStatus.ACCEPTED)
    order_event("order.accepted", order.pk)
    assert order.user.notifications.filter(event="order.accepted").exists()


# --------------------------------------------------------------------------- Phase 5 calls


def test_publish_offer_and_withdrawal_and_task_update(
    components, django_capture_on_commit_callbacks
):
    listener = Listener(rider_group(41))
    with django_capture_on_commit_callbacks(execute=True):
        services.publish_offer(41, contract.OFFER_DATA)
        services.publish_offer_withdrawn(41, offer_id=9001, task_id=7001, reason="TAKEN")
        services.publish_task_updated(
            41,
            task_id=7001,
            order_id=1203,
            status="ASSIGNED",
            order_status="PACKED",
            change="ORDER_PACKED",
        )
    offer, withdrawn, task = listener.messages()
    validate(components, "WsOfferNewMessage", offer)
    validate(components, "WsOfferWithdrawnMessage", withdrawn)
    validate(components, "WsTaskUpdatedMessage", task)


def test_nothing_is_published_when_the_transaction_rolls_back(django_capture_on_commit_callbacks):
    from django.db import transaction

    listener = Listener(rider_group(41))

    def publish_then_fail():
        with transaction.atomic():
            services.publish_offer(41, contract.OFFER_DATA)
            raise RuntimeError

    with (
        django_capture_on_commit_callbacks(execute=True) as callbacks,
        pytest.raises(RuntimeError),
    ):
        publish_then_fail()
    assert callbacks == []
    assert listener.messages(timeout=0.2) == []


def test_publish_rejects_unknown_reasons():
    with pytest.raises(ValueError, match="reason"):
        services.publish_offer_withdrawn(1, offer_id=1, task_id=1, reason="BORED")
    with pytest.raises(ValueError, match="change"):
        services.publish_task_updated(
            1, task_id=1, order_id=1, status="X", order_status="PACKED", change="NOPE"
        )


def test_rider_status_and_ops_alert(components, django_capture_on_commit_callbacks):
    ops = Listener(store_group(3))
    with django_capture_on_commit_callbacks(execute=True):
        services.publish_rider_status(41, store_id=3, is_online=True, on_task=False)
        services.publish_ops_alert(
            store_id=3, code="DISPATCH_UNASSIGNED", message_text="No rider", order_id=5
        )
    status, alert = ops.messages()
    validate(components, "WsRiderStatusMessage", status)
    validate(components, "WsAlertMessage", alert)


def test_rider_location_goes_to_the_store_and_the_order(
    components, django_capture_on_commit_callbacks
):
    order = OrderFactory(status=OrderStatus.ACCEPTED)
    customer = Listener(order_group(order.pk))
    ops = Listener(store_group(order.store_id))
    with django_capture_on_commit_callbacks(execute=True):
        services.publish_rider_location(
            41, 28.47, 77.04, timezone.now(), store_id=order.store_id, order_id=order.pk, heading=90
        )
    [mine] = customer.messages()
    assert set(mine["data"]) == {"order_id", "lat", "lng", "heading", "recorded_at"}  # no rider id
    validate(components, "WsRiderLocationMessage", mine)
    [theirs] = ops.messages()
    validate(components, "WsOpsRiderLocationMessage", theirs)
    assert theirs["data"]["rider_id"] == 41


def test_rider_location_without_a_store_or_order_reaches_nobody():
    """No `store_id` and no rider 41 to find a home store from: nothing is sent."""
    assert (
        services.send_rider_location(
            41, 28.47, 77.04, "2026-11-10T09:47:12Z", store_id=None, order_id=None, heading=None
        )
        == []
    )


def test_eta_is_sent_while_out_for_delivery_and_throttled(components):
    order = OrderFactory(
        status=OrderStatus.OUT_FOR_DELIVERY, delivery_location=Point(77.05, 28.45, srid=4326)
    )
    customer = Listener(order_group(order.pk))
    sent = services.send_rider_location(
        41, 28.47, 77.04, "2026-11-10T09:47:12Z", store_id=None, order_id=order.pk, heading=None
    )
    assert sent == ["rider.location", "order.eta"]
    _location, eta = customer.messages()
    validate(components, "WsOrderEtaMessage", eta)
    expected = services.eta_minutes_from(28.47, 77.04, 28.45, 77.05)
    assert eta["data"]["eta_minutes"] == expected >= 3
    # Within WS_ETA_MIN_INTERVAL_SECONDS: location only.
    assert services.send_rider_location(
        41, 28.46, 77.045, "2026-11-10T09:47:22Z", store_id=None, order_id=order.pk, heading=None
    ) == ["rider.location"]


def test_no_eta_before_pickup():
    order = OrderFactory(status=OrderStatus.PACKED)
    assert not services.publish_eta_from_location(order.pk, 28.47, 77.04)


def test_eta_formula_08_8(settings):
    settings.ETA_ROAD_FACTOR = 1.3
    settings.ETA_AVG_SPEED_KMPH = 20
    settings.ETA_BUFFER_MINUTES = 2
    assert services.eta_minutes_from(28.45, 77.05, 28.45, 77.05) == 2  # buffer only
    # ~2.22 km x 1.3 = 2.89 km at 20 km/h = 8.7 min + 2 = 10.7 -> 11
    assert services.eta_minutes_from(28.45, 77.05, 28.47, 77.05) == 11


def test_iso_is_utc_with_z():
    from datetime import UTC, datetime

    assert services.iso(datetime(2026, 11, 10, 9, 30, tzinfo=UTC)) == "2026-11-10T09:30:00Z"
    assert services.iso(datetime(2026, 11, 10, 9, 30)) == "2026-11-10T09:30:00Z"
    assert services.iso(None) is None


def test_rider_location_of_an_unknown_rider_reaches_nobody():
    assert services.rider_home_store_id(999_999) is None


def test_money_in_order_created_is_a_string():
    order = OrderFactory(grand_total=Decimal("300.00"))
    assert services.order_created_data(order)["grand_total"] == "300.00"


def test_send_now_reaches_the_channel_layer(monkeypatch):
    """The real `send_now` (unpatched): a group member receives `ws.message` events."""
    import asyncio

    monkeypatch.undo()
    from apps.realtime import services as real

    async def scenario():
        layer = get_channel_layer()
        channel = await layer.new_channel()
        await layer.group_add("order.424242", channel)
        from asgiref.sync import sync_to_async

        await sync_to_async(real.send_now)(["order.424242"], {"type": "pong"})
        async with asyncio.timeout(5):
            return await layer.receive(channel)

    assert async_to_sync(scenario)() == {"type": "ws.message", "message": {"type": "pong"}}
