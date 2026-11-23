# ruff: noqa: F811 - the `flow` fixture is imported from test_task_flow
"""T-821 live tracking (backend): location ingest hardening, the customer tracking payload
(route, distance left, staleness, 8-step progress, scoping), the rider's navigation leg, the
ops live dashboard snapshot (scope, role matrix, stats) and the new socket messages
(`order.route`, `delivery.progress`)."""

from datetime import timedelta
from types import SimpleNamespace

import jsonschema
import pytest
from django.contrib.auth.models import Group
from django.contrib.gis.geos import Point
from django.core.exceptions import PermissionDenied
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.accounts import roles
from apps.accounts.models import User
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import DeliveryTask, Rider, RiderLocation
from apps.delivery.services import live_ops, live_tracking, shifts
from apps.delivery.tests.conftest import STORE_POINT, put_online
from apps.delivery.tests.test_task_flow import flow  # noqa: F401
from apps.orders.choices import OrderStatus
from apps.orders.models import Order
from apps.realtime import services
from apps.realtime.groups import order_group, store_group
from apps.stores.services import grant_store_access
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db

LOCATIONS = "/api/v1/rider/locations/"
FAR = (28.95, 77.05)  # ~55 km north of the store


def fix(lat_lng=STORE_POINT, *, seconds_ago=0, accuracy=8.0, **extra) -> dict:
    lat, lng = lat_lng
    return {
        "lat": lat,
        "lng": lng,
        "accuracy": accuracy,
        "recorded_at": (timezone.now() - timedelta(seconds=seconds_ago)).isoformat(),
        **extra,
    }


@pytest.fixture(autouse=True)
def _roles():
    roles.sync_roles()


def staff(role, *stores):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    for store in stores:
        grant_store_access(user, store)
    return User.objects.get(pk=user.pk)  # fresh permission cache


@pytest.fixture(scope="module")
def components() -> dict:
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


def validate(components, name: str, body: dict) -> None:
    jsonschema.validate(body, to_json_schema({"$ref": f"#/components/schemas/{name}"}, components))


# --------------------------------------------------------------------------- ingest


@pytest.fixture
def online(make_rider, rider_client):
    def make(ago_seconds=0):
        rider = make_rider(online=False)
        rider = put_online(rider, ago_seconds=ago_seconds)
        return rider, rider_client(rider)

    return make


def post(client, *points, **extra):
    return client.post(LOCATIONS, {"points": list(points), **extra}, format="json")


def test_ingest_rejects_jumps_and_reports_reasons(online):
    """T-821: (0, 0), too old, future and implausible jumps are dropped with a reason; the live
    position moves only to the plausible fix."""
    rider, client = online(ago_seconds=30)
    response = post(
        client,
        fix((28.4505, 77.0505), seconds_ago=5),
        fix(FAR, seconds_ago=2),  # 55 km in 3 s
        fix((0.0, 0.0), seconds_ago=1),
        fix(seconds_ago=60 * 60 * 25),
        fix(seconds_ago=-600),
    )
    assert response.status_code == 200, response.json()
    body = response.json()
    assert body["accepted"] == 1
    assert body["rejected"] == 4
    assert body["rejected_reasons"] == {
        "too_old": 1,
        "future": 1,
        "invalid_point": 1,
        "implausible_jump": 1,
    }
    assert body["active_task_id"] is None
    rider.refresh_from_db()
    assert rider.current_location.y == pytest.approx(28.4505)
    assert RiderLocation.objects.filter(rider=rider).count() == 1


def test_a_jump_after_a_long_gap_is_accepted(online):
    rider, client = online(ago_seconds=20 * 60)  # last fix 20 minutes ago
    body = post(client, fix(FAR)).json()
    assert body["accepted"] == 1
    rider.refresh_from_db()
    assert rider.current_location.y == pytest.approx(FAR[0])


def test_jump_only_batch_still_counts_as_presence(online):
    rider, client = online()
    Rider.objects.filter(pk=rider.pk).update(last_location_received_at=None)
    body = post(client, fix(FAR)).json()
    assert body["rejected_reasons"]["implausible_jump"] == 1
    rider.refresh_from_db()
    assert rider.last_location_received_at is not None
    assert rider.current_location.y == pytest.approx(STORE_POINT[0])


def test_out_of_order_and_low_accuracy_are_history_only(online):
    rider, client = online()
    live_at = Rider.objects.get(pk=rider.pk).last_location_at
    body = post(
        client,
        fix((28.4502, 77.05), seconds_ago=120),  # older than the live position
        fix((28.4508, 77.05), seconds_ago=0, accuracy=900),  # too vague to move the marker
    ).json()
    assert body["accepted"] == 2
    assert body["out_of_order"] == 1
    assert body["low_accuracy"] == 1
    rider.refresh_from_db()
    assert rider.last_location_at == live_at
    assert rider.current_location.y == pytest.approx(STORE_POINT[0])
    assert RiderLocation.objects.filter(rider=rider).count() == 2


def test_heading_and_speed_reach_the_latest_location(online):
    rider, client = online()
    post(client, fix((28.4503, 77.05), heading=91.5, speed=6.2))
    location = shifts.latest_location(Rider.objects.get(pk=rider.pk))
    assert location["heading"] == 91.5
    assert location["speed"] == 6.2


@pytest.mark.parametrize(
    "bad",
    [{"lat": 91}, {"lng": -181}, {"heading": 361}, {"accuracy": -1}, {"speed": -2}],
)
def test_out_of_range_fields_are_a_400(online, bad):
    _, client = online()
    assert post(client, {**fix(), **bad}).status_code == 400


def test_task_id_is_only_compared(flow):
    """The rider's points always go to the rider and the server's active task."""
    f = flow()
    f.accept()
    body = post(f.client, fix((28.4503, 77.05)), task_id=999_999).json()
    assert body["accepted"] == 1
    assert body["active_task_id"] == f.task_id
    assert RiderLocation.objects.get(rider=f.rider).task_id == f.task_id


def test_unauthenticated_and_customer_tokens_are_refused(make_auth_client):
    from rest_framework.test import APIClient

    assert APIClient().post(LOCATIONS, {"points": [fix()]}, format="json").status_code == 401
    customer = make_auth_client(UserFactory())
    assert customer.post(LOCATIONS, {"points": [fix()]}, format="json").status_code == 403


# --------------------------------------------------------------------------- customer track


def test_track_payload_route_progress_and_scoping(flow, make_auth_client):
    f = flow()
    customer = make_auth_client(User.objects.get(pk=f.order.user_id))
    url = f"/api/v1/orders/{f.order.pk}/track/"
    before = customer.get(url).json()
    assert before["route"] is None
    assert before["distance_remaining_m"] is None
    assert before["progress"]["current"] == "PREPARING"
    assert [s["key"] for s in before["progress"]["steps"]] == list(live_tracking.STEPS)
    f.accept()
    body = customer.get(url).json()
    rider = body["rider"]
    assert rider["vehicle_type"] == f.rider.vehicle_type
    assert rider["is_stale"] is False
    assert "vehicle_number" not in rider
    assert body["route"]["leg"] == "TO_STORE"
    assert body["route"]["provider"] == "haversine"
    assert isinstance(body["distance_remaining_m"], int)
    steps = {s["key"]: s for s in body["progress"]["steps"]}
    assert body["progress"]["current"] == "RIDER_ASSIGNED"
    assert steps["RIDER_ASSIGNED"]["done"]
    assert not steps["PACKED"]["done"]  # assigned while the store is still packing
    # IDOR: another customer gets nothing.
    assert make_auth_client(UserFactory()).get(url).status_code == 404
    f.at_store()
    f.steps.pack(f.order)
    assert f.pickup().status_code == 200
    body = customer.get(url).json()
    assert body["route"]["leg"] == "TO_CUSTOMER"
    assert body["progress"]["steps"][4]["done"]  # PICKED_UP
    f.at_customer()
    assert customer.get(url).json()["progress"]["current"] == "ARRIVING"
    assert f.deliver().status_code == 200
    done = customer.get(url).json()
    assert done["route"] is None
    assert done["progress"]["current"] == "DELIVERED"
    assert done["progress"]["outcome"] == "DELIVERED"
    assert all(step["done"] for step in done["progress"]["steps"])


def test_track_is_404_for_another_user(flow, make_auth_client):
    """IDOR (T-821 payload): another customer gets 404 at every stage, never the route,
    position or progress; an unknown order is 404 too."""
    f = flow()
    url = f"/api/v1/orders/{f.order.pk}/track/"
    stranger = make_auth_client(UserFactory())
    response = stranger.get(url)
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"
    f.accept()
    response = stranger.get(url)
    assert response.status_code == 404
    assert "route" not in response.json()
    assert stranger.get("/api/v1/orders/999999999/track/").status_code == 404


def test_track_marks_a_stale_rider(flow, make_auth_client, settings):
    f = flow()
    f.accept()
    Rider.objects.filter(pk=f.rider.pk).update(
        last_location_at=timezone.now() - timedelta(minutes=5)
    )
    from django.core.cache import cache

    cache.delete(shifts.location_cache_key(f.rider.pk))
    customer = make_auth_client(User.objects.get(pk=f.order.user_id))
    rider = customer.get(f"/api/v1/orders/{f.order.pk}/track/").json()["rider"]
    assert rider["is_stale"] is True
    assert rider["heading"] is None


def _order_ns(status, **times):
    now = timezone.now()
    base = {
        "status": status,
        "placed_at": now - timedelta(minutes=10),
        "accepted_at": None,
        "packed_at": None,
        "picked_up_at": None,
        "delivered_at": None,
        "store": SimpleNamespace(location=Point(77.05, 28.45, srid=4326)),
        "delivery_location": Point(77.05, 28.48, srid=4326),  # ~3.3 km north
    }
    base.update(times)
    return SimpleNamespace(**base)


def test_progress_steps_from_real_states(settings):
    """On the way = outside the store geofence after pickup; arriving = within the radius."""
    settings.RIDER_STORE_GEOFENCE_M = 200
    settings.TRACKING_ARRIVING_RADIUS_M = 500
    now = timezone.now()
    picked = {"accepted_at": now, "packed_at": now, "picked_up_at": now}
    task = SimpleNamespace(status=TS.PICKED_UP, assigned_at=now, arrived_customer_at=None)
    order = _order_ns(OrderStatus.OUT_FOR_DELIVERY, **picked)
    at_store = live_tracking.progress(order, task, (28.45, 77.05))
    assert at_store["current"] == "PICKED_UP"
    riding = live_tracking.progress(order, task, (28.46, 77.05))
    assert riding["current"] == "ON_THE_WAY"
    close = live_tracking.progress(order, task, (28.477, 77.05))
    assert close["current"] == "ARRIVING"
    assert live_tracking.progress(order, task, None)["current"] == "PICKED_UP"
    # Not placed yet: nothing.
    pending = _order_ns(OrderStatus.PAYMENT_PENDING, placed_at=None)
    assert live_tracking.progress(pending, None, None)["current"] is None
    # Cancelled before pickup: the steps stay where they were.
    cancelled = _order_ns(OrderStatus.CANCELLED, accepted_at=now)
    body = live_tracking.progress(cancelled, None, None)
    assert (body["current"], body["outcome"]) == ("PREPARING", "CANCELLED")
    # A failed delivery after pickup was on the way.
    failed = _order_ns(OrderStatus.DELIVERY_FAILED, **picked)
    failed_task = SimpleNamespace(status=TS.RETURNING, assigned_at=now, arrived_customer_at=now)
    body = live_tracking.progress(failed, failed_task, None)
    assert body["current"] == "ARRIVING"
    assert body["outcome"] == "DELIVERY_FAILED"


def test_staleness_and_legs():
    now = timezone.now()
    assert live_tracking.is_stale(None, now)
    assert not live_tracking.is_stale(now - timedelta(seconds=30), now)
    assert live_tracking.is_stale(now - timedelta(seconds=61), now)
    assert live_tracking.leg_of(SimpleNamespace(status=TS.AT_STORE)) == "TO_STORE"
    assert live_tracking.leg_of(SimpleNamespace(status=TS.AT_CUSTOMER)) == "TO_CUSTOMER"
    assert live_tracking.leg_of(SimpleNamespace(status=TS.SEARCHING)) is None
    assert live_tracking.leg_of(None) is None
    assert live_tracking.route_body(None, None) is None
    assert live_tracking.distance_remaining_m(None, None, None) is None
    assert live_tracking.store_drop_route(SimpleNamespace(pk=None)) is None


# --------------------------------------------------------------------------- rider navigation


def test_rider_navigation_follows_the_leg(flow):
    f = flow()
    accepted = f.accept()
    assert accepted["navigation"]["leg"] == "TO_STORE"
    assert accepted["navigation"]["destination"] == {
        "lat": pytest.approx(STORE_POINT[0]),
        "lng": pytest.approx(STORE_POINT[1]),
    }
    # ~500 m away, a minute on (a plausible ride, not a GPS jump).
    assert post(f.client, fix((28.4545, 77.05), seconds_ago=-60)).json()["accepted"] == 1
    task = f.client.get("/api/v1/rider/tasks/current/").json()["task"]
    nav = task["navigation"]
    assert nav["route"]["leg"] == "TO_STORE"
    assert nav["distance_m"] > 0
    assert nav["eta_minutes"] >= 1
    assert nav["eta_at"]
    assert nav["position_at"]
    assert f.at_store().json()["navigation"]["eta_minutes"] == 0
    f.steps.pack(f.order)
    picked = f.pickup().json()
    assert picked["navigation"]["leg"] == "TO_CUSTOMER"
    f.at_customer()
    delivered = f.deliver().json()
    assert delivered["navigation"] is None


def test_navigation_without_a_position(flow):
    f = flow()
    f.accept()
    Rider.objects.filter(pk=f.rider.pk).update(current_location=None, last_location_at=None)
    from django.core.cache import cache

    cache.clear()
    nav = f.client.get("/api/v1/rider/tasks/current/").json()["task"]["navigation"]
    assert nav["route"] is None
    assert nav["distance_m"] is None
    assert nav["eta_minutes"] is None


# --------------------------------------------------------------------------- ops snapshot


def test_ops_snapshot_contents_and_stats(flow, admin):
    f = flow()
    f.accept()
    snap = live_ops.snapshot(admin)
    [row] = [d for d in snap["deliveries"] if d["order_id"] == f.order.pk]
    assert row["task_status"] == "ASSIGNED"
    assert row["rider_id"] == f.rider.pk
    assert row["customer_name"] == (f.order.user.name or None)
    assert isinstance(row["distance_remaining_m"], int)
    assert row["live_eta_minutes"] >= 1
    assert row["is_stale"] is False
    assert "phone" not in str(row).lower()
    stats = snap["stats"]
    assert stats["active_orders"] >= 1
    assert stats["to_store"] >= 1
    assert stats["riders_online"] >= 1
    assert stats["riders_delivering"] >= 1
    [rider] = [r for r in snap["riders"] if r["rider_id"] == f.rider.pk]
    assert rider["state"] == "TO_STORE"
    assert {s["id"] for s in snap["stores"]} >= {f.order.store_id}
    # Late: the promise is in the past.
    Order.objects.filter(pk=f.order.pk).update(eta_at=timezone.now() - timedelta(minutes=1))
    snap = live_ops.snapshot(admin, store_id=f.order.store_id)
    assert snap["stats"]["delayed"] == 1
    assert snap["deliveries"][0]["is_delayed"] is True
    # Picked up and delivered.
    f.at_store()
    f.steps.pack(f.order)
    f.pickup()
    stats = live_ops.snapshot(admin, store_id=f.order.store_id)["stats"]
    assert (stats["picked_up"], stats["in_transit"]) == (1, 1)
    f.at_customer()
    f.deliver()
    stats = live_ops.snapshot(admin, store_id=f.order.store_id)["stats"]
    assert stats["completed_today"] == 1
    assert stats["active_orders"] == 0


def test_ops_snapshot_scope_and_role_matrix(flow, shop):
    f = flow()
    f.accept()
    own = shop.store_model
    other = shop.other_store_model
    manager = staff(roles.STORE_MANAGER, own)
    assert [d["order_id"] for d in live_ops.snapshot(manager)["deliveries"]] == [f.order.pk]
    assert live_ops.snapshot(manager)["deliveries"][0]["customer_name"] == (
        f.order.user.name or None
    )
    # Another store's manager: nothing of it (and an out-of-scope store id is empty).
    stranger = staff(roles.STORE_MANAGER, other)
    snap = live_ops.snapshot(stranger)
    assert snap["deliveries"] == []
    assert f.rider.pk not in [r["rider_id"] for r in snap["riders"]]
    assert live_ops.snapshot(stranger, store_id=own.pk)["stores"] == []
    User.objects.filter(pk=f.order.user_id).update(name="Asha Verma")
    for role in (roles.OPS, roles.SUPPORT):
        [row] = live_ops.snapshot(staff(role))["deliveries"]
        assert row["customer_name"] == "Asha Verma"
        assert row["drop"] is not None
    # 05 §3 "Live order board": Finance, Store Staff and Catalog Manager have no board (review
    # fix 1): refused, like anyone without the order view.
    for role, stores in (
        (roles.FINANCE, ()),
        (roles.STORE_STAFF, (own,)),
        (roles.CATALOG_MANAGER, ()),
    ):
        with pytest.raises(PermissionDenied):
            live_ops.snapshot(staff(role, *stores))
    with pytest.raises(PermissionDenied):
        live_ops.snapshot(UserFactory())


def test_board_access_without_customer_permissions_hides_the_drop(flow):
    """The board pair alone (no customer, dispatch or packing permission): no name, no drop
    point, no area (review fix 1)."""
    from django.contrib.auth.models import Permission

    f = flow()
    f.accept()
    user = staff(roles.CATALOG_MANAGER)  # a global role (every store), no customer permission
    user.user_permissions.add(
        *Permission.objects.filter(
            content_type__app_label="orders", codename__in=["view_order", "cancel_order"]
        )
    )
    user = User.objects.get(pk=user.pk)
    assert not live_ops.shows_customer_name(user)
    [row] = live_ops.snapshot(user)["deliveries"]
    assert (row["customer_name"], row["drop"], row["area"]) == (None, None, None)
    assert row["order_number"] == f.order.order_number


def test_snapshot_query_count_does_not_grow_with_deliveries(flow, admin, monkeypatch):
    """Review fix 3: a constant number of queries, and no route provider call, for many
    deliveries."""
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    from apps.maps import services as maps_services
    from apps.orders.tests.factories import OrderFactory

    f = flow()
    f.accept()
    store = f.order.store
    live_ops.snapshot(admin, store_id=store.pk)  # warm caches (content types, routes)
    with CaptureQueriesContext(connection) as one:
        live_ops.snapshot(admin, store_id=store.pk)
    for _ in range(6):
        OrderFactory(store=store, status=OrderStatus.PACKING)
    calls = []
    real = maps_services.compute_route
    monkeypatch.setattr(
        maps_services, "compute_route", lambda *a, **k: calls.append(a) or real(*a, **k)
    )
    with CaptureQueriesContext(connection) as many:
        snap = live_ops.snapshot(admin, store_id=store.pk)
    assert len(snap["deliveries"]) == 7
    assert len(many) == len(one)
    assert calls == []


def test_offline_rider_on_a_task_is_flagged(flow, admin):
    f = flow()
    f.accept()
    Rider.objects.filter(pk=f.rider.pk).update(is_online=False)
    [rider] = [r for r in live_ops.snapshot(admin)["riders"] if r["rider_id"] == f.rider.pk]
    assert rider["state"] == "OFFLINE"


# --------------------------------------------------------------------------- sockets


@pytest.fixture
def sent(monkeypatch):
    items = []
    monkeypatch.setattr(services, "send_now", lambda groups, body: items.append((groups, body)))
    return items


def test_pings_send_route_and_throttled_progress(flow, sent, components, settings):
    f = flow()
    f.accept()
    from django.core.cache import cache

    cache.clear()  # the accept response computed the route: start fresh
    now = timezone.now().isoformat()
    task = DeliveryTask.objects.get(pk=f.task_id)
    args = (f.rider.pk, 28.4545, 77.05, now)
    services.send_rider_location(*args, store_id=task.store_id, order_id=f.order.pk, heading=10.0)
    by_type = {body["type"]: (groups, body) for groups, body in sent}
    groups, route = by_type["order.route"]
    assert groups == [order_group(f.order.pk)]
    validate(components, "WsOrderRouteMessage", route)
    assert route["data"]["leg"] == "TO_STORE"
    groups, progress = by_type["delivery.progress"]
    assert groups == [store_group(f.order.store_id)]
    validate(components, "WsDeliveryProgressMessage", progress)
    assert "customer" not in str(progress["data"]).lower()
    location = next(b for g, b in sent if b["type"] == "rider.location" and "order" in g[0])
    validate(components, "WsRiderLocationMessage", location)
    assert location["data"]["distance_remaining_m"] > 0
    sent.clear()
    services.send_rider_location(*args, store_id=task.store_id, order_id=f.order.pk, heading=10.0)
    types = [body["type"] for _, body in sent]
    assert "order.route" not in types  # cached, not recomputed
    assert "delivery.progress" not in types  # throttled


def test_simulate_rider_bearing():
    from apps.delivery.management.commands.simulate_rider import bearing

    assert bearing((28.45, 77.05), (28.46, 77.05)) == 0.0
    assert bearing((28.45, 77.05), (28.45, 77.06)) == pytest.approx(90.0, abs=0.1)
    assert bearing((28.45, 77.05), (28.45, 77.05)) is None


def test_rider_assigned_step_drops_after_an_unassign():
    now = timezone.now()
    order = _order_ns(OrderStatus.PACKING, accepted_at=now)
    searching = SimpleNamespace(status=TS.SEARCHING, assigned_at=now, arrived_customer_at=None)
    assert live_tracking.progress(order, searching, None)["current"] == "PREPARING"
    assigned = SimpleNamespace(status=TS.ASSIGNED, assigned_at=now, arrived_customer_at=None)
    assert live_tracking.progress(order, assigned, None)["current"] == "RIDER_ASSIGNED"
