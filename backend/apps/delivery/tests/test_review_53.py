# ruff: noqa: RUF001 - the look-alike characters are the point of these tests
"""Code review of slice 5.3: pickup code input (non-ASCII), pickup brute force (lock + throttle),
manual assignment racing a pending offer, a pickup with nothing reserved, and real-thread
races (two connections, committed data)."""

import pytest

from apps.core.exceptions import ApiError
from apps.delivery import hooks
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import DeliveryOffer, DeliveryTask
from apps.delivery.services import dispatch
from apps.delivery.services import tasks as task_actions
from apps.inventory.models import ReservationStatus, StockMovement, StockReservation
from apps.orders.choices import OrderStatus
from apps.orders.models import Order

AT_STORE = {"lat": 28.4501, "lng": 77.0501, "accuracy": 8}


def take(order, rider, client):
    dispatch.dispatch_order(order.pk)
    offer = DeliveryOffer.objects.get(task__order=order, status="PENDING")
    assert offer.rider == rider
    return client.post(f"/api/v1/rider/offers/{offer.pk}/accept/").json()["id"]


@pytest.fixture
def at_store(place, store_steps, make_rider, rider_client):
    """A packed order whose rider is at the store: (order, rider, client, pickup_url)."""
    order = place()
    store_steps.accept(order)
    rider = make_rider()
    client = rider_client(rider)
    task_id = take(order, rider, client)
    client.post(f"/api/v1/rider/tasks/{task_id}/arrived-store/", AT_STORE, format="json")
    store_steps.pack(order)
    order.refresh_from_db()
    return order, rider, client, f"/api/v1/rider/tasks/{task_id}/pickup/"


# --------------------------------------------------------------------------- non-ASCII codes


@pytest.mark.django_db
@pytest.mark.parametrize(
    "code",
    [
        "ABCé",
        "AB\U0001f600",
        "ıııı",  # dotless i: upper() would give "IIII"
        "ſſſſ",  # long s: upper() would give "SSSS"
        "JQC1:JV-261110-001203:K7Qé",
        "JQC1:JV-261110-ı:K7QX",
        "AB",
        "",
    ],
)
def test_non_ascii_or_malformed_codes_are_refused_cleanly(at_store, code):
    order, _rider, client, url = at_store
    response = client.post(url, {"order_code": code}, format="json")
    assert response.status_code == 400, response.content
    assert response.json()["error"]["code"] in ("PICKUP_CODE_INVALID", "VALIDATION_ERROR")
    if code:
        assert response.json()["error"]["code"] == "PICKUP_CODE_INVALID"
    task = DeliveryTask.objects.get(order=order)
    assert task.pickup_attempts == 0  # not a code: no attempt used
    assert task.status == TS.AT_STORE


@pytest.mark.django_db
def test_code_format_and_compare_are_ascii_only():
    assert task_actions.code_format_ok("k7qx")
    assert task_actions.code_format_ok("JQC1:JV-261110-001203:K7QX")
    assert not task_actions.code_format_ok("ıııı")
    assert task_actions.code_format_ok(" K7QX ")  # surrounding spaces are stripped
    order = Order(order_number="JV-261110-001203", pickup_code="SSSS")
    assert not task_actions._code_matches(order, "ſſſſ")
    assert task_actions._code_matches(order, "ssss")


# --------------------------------------------------------------------------- brute force


@pytest.mark.django_db
def test_wrong_codes_lock_the_pickup(at_store, monkeypatch):
    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    order, _rider, client, url = at_store
    wrong = "ZZZZ" if order.pickup_code != "ZZZZ" else "YYYY"
    for remaining in (4, 3, 2, 1):
        response = client.post(url, {"order_code": wrong}, format="json")
        assert response.json()["error"] == {
            "code": "PICKUP_CODE_INVALID",
            "message": response.json()["error"]["message"],
            "details": {"attempts_remaining": remaining},
        }
    locked = client.post(url, {"order_code": wrong}, format="json")
    assert locked.status_code == 423
    assert locked.json()["error"]["code"] == "PICKUP_CODE_LOCKED"
    assert alerts == ["PICKUP_CODE_LOCKED"]
    right = client.post(url, {"order_code": order.pickup_code}, format="json")
    assert right.status_code == 423  # the rider cannot get past it
    assert not StockMovement.objects.filter(order=order).exists()


@pytest.mark.django_db
def test_reassignment_resets_the_pickup_lock(at_store, admin, make_rider):
    order, _rider, _client, _url = at_store
    DeliveryTask.objects.filter(order=order).update(
        pickup_attempts=5, pickup_locked_at="2026-11-05T10:00Z"
    )
    dispatch.unassign(order.pk, by=admin)
    other = make_rider((28.4510, 77.05))
    task = dispatch.manual_assign(order.pk, other.pk, by=admin)
    assert (task.pickup_attempts, task.pickup_locked_at) == (0, None)


@pytest.mark.django_db
def test_pickup_is_throttled_per_rider(at_store, monkeypatch):
    from apps.delivery import throttling

    monkeypatch.setattr(throttling.RiderPickupThrottle, "THROTTLE_RATES", {"rider_pickup": "1/min"})
    _order, _rider, client, url = at_store
    client.post(url, {"order_code": "ZZZZ"}, format="json")
    assert client.post(url, {"order_code": "ZZZZ"}, format="json").status_code == 429


# --------------------------------------------------------------------------- manual assign vs offer


@pytest.mark.django_db
def test_manual_assign_while_the_rider_holds_another_offer(
    place, store_steps, make_rider, rider_client, admin, django_capture_on_commit_callbacks
):
    rider = make_rider()
    offered, assigned = place(), place()
    store_steps.accept(offered)
    store_steps.accept(assigned)
    dispatch.dispatch_order(offered.pk)
    offer = DeliveryOffer.objects.get(task__order=offered, status="PENDING")
    assert offer.rider == rider
    # Ops give the rider the other order; before the after-commit withdrawal runs, the rider
    # taps accept on the first offer: a clean OFFER_TAKEN, never a 500.
    dispatch.manual_assign(assigned.pk, rider.pk, by=admin)
    response = rider_client(rider).post(f"/api/v1/rider/offers/{offer.pk}/accept/")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "OFFER_TAKEN"
    offer.refresh_from_db()
    assert offer.status == OfferStatus.WITHDRAWN
    assert DeliveryTask.objects.get(order=offered).status == TS.SEARCHING


@pytest.mark.django_db
def test_manual_assign_withdraws_the_riders_pending_offer_after_commit(
    place, store_steps, make_rider, admin, django_capture_on_commit_callbacks
):
    rider = make_rider()
    offered, assigned = place(), place()
    store_steps.accept(offered)
    store_steps.accept(assigned)
    dispatch.dispatch_order(offered.pk)
    with django_capture_on_commit_callbacks(execute=True):
        dispatch.manual_assign(assigned.pk, rider.pk, by=admin)
    assert DeliveryOffer.objects.get(task__order=offered).status == OfferStatus.WITHDRAWN


# --------------------------------------------------------------------------- nothing reserved


@pytest.mark.django_db
def test_pickup_with_nothing_reserved_alerts_ops(
    at_store, monkeypatch, django_capture_on_commit_callbacks
):
    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    order, _rider, client, url = at_store
    StockReservation.objects.filter(order=order).update(status=ReservationStatus.RELEASED)
    with django_capture_on_commit_callbacks(execute=True):
        response = client.post(url, {"order_code": order.pickup_code}, format="json")
    assert response.status_code == 200
    assert "STOCK_NOT_COMMITTED" in alerts


# --------------------------------------------------------------------------- real threads


def _race(*jobs):
    from apps.orders.tests.test_concurrency import race

    return race(*jobs)


@pytest.mark.django_db(transaction=True)
def test_race_accept_vs_manual_assign(place, store_steps, make_rider, admin):
    """Two connections: the rider accepts while ops assign someone else. Exactly one wins."""
    a = make_rider()
    order = place()
    store_steps.accept(order)
    dispatch.dispatch_order(order.pk)
    offer = DeliveryOffer.objects.get(task__order=order, status="PENDING")
    b = make_rider((28.4510, 77.05))
    results = _race(
        lambda: dispatch.accept_offer(a.user, offer.pk),
        lambda: dispatch.manual_assign(order.pk, b.pk, by=admin),
    )
    wins = [r for r in results if not isinstance(r, Exception)]
    losses = [r for r in results if isinstance(r, Exception)]
    assert len(wins) == 1, results
    assert len(losses) == 1, results
    assert isinstance(losses[0], ApiError), results
    task = DeliveryTask.objects.get(order=order)
    assert task.status == TS.ASSIGNED
    assert task.rider_id in (a.pk, b.pk)


@pytest.mark.django_db(transaction=True)
def test_race_double_accept(place, store_steps, make_rider):
    """The same offer accepted twice at once (double tap): one assignment, both answers OK."""
    rider = make_rider()
    order = place()
    store_steps.accept(order)
    dispatch.dispatch_order(order.pk)
    offer = DeliveryOffer.objects.get(task__order=order, status="PENDING")
    results = _race(
        lambda: dispatch.accept_offer(rider.user, offer.pk),
        lambda: dispatch.accept_offer(rider.user, offer.pk),
    )
    assert all(not isinstance(r, Exception) for r in results), results
    assert DeliveryTask.objects.filter(rider=rider, status=TS.ASSIGNED).count() == 1


@pytest.mark.django_db(transaction=True)
def test_race_pickup_vs_cancel(place, store_steps, make_rider, rider_client, admin):
    """Pickup and a staff cancellation at once: exactly one wins and the stock is consistent."""
    from apps.orders import store_ops

    rider = make_rider()
    order = place()
    store_steps.accept(order)
    client = rider_client(rider)
    task_id = take(order, rider, client)
    client.post(f"/api/v1/rider/tasks/{task_id}/arrived-store/", AT_STORE, format="json")
    store_steps.pack(order)
    order.refresh_from_db()
    results = _race(
        lambda: task_actions.pickup(rider.user, task_id, order_code=order.pickup_code),
        lambda: store_ops.cancel_by_staff(order.pk, by=admin, reason="CUSTOMER_REQUEST"),
    )
    assert sum(not isinstance(r, Exception) for r in results) == 1, results
    order.refresh_from_db()
    reservation = StockReservation.objects.get(order=order)
    sales = StockMovement.objects.filter(order=order, type="SALE").count()
    if order.status == OrderStatus.OUT_FOR_DELIVERY:
        assert reservation.status == ReservationStatus.COMMITTED
        assert sales == 1
    else:
        assert order.status == OrderStatus.CANCELLED
        assert reservation.status == ReservationStatus.RELEASED
        assert sales == 0
        assert DeliveryTask.objects.get(order=order).status == TS.CANCELLED
