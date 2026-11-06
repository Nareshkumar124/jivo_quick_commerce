"""Ops dispatch screens and store returns (05 §1.4, §1.3 "Returns"; slice 5.3, T-517b).

Role matrix (05 §3 "Manual dispatch": Super Admin, Ops, Store Manager own; returns: the packing
roles), store scoping / IDOR (another store's task, order or store is a 404 and no service is
called), the real dispatch and T14 services behind the buttons, and that the pickup code and the
delivery OTP never reach the page.
"""

import json
from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.gis.geos import Point
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.core.crypto import encrypt
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import DeliveryOffer, DeliveryTask, Rider
from apps.delivery.tests.factories import active_rider
from apps.inventory.models import StockMovement
from apps.inventory.services import ensure_inventory
from apps.ops_console import order_actions
from apps.ops_console.tests.helpers import (
    DISPATCH_ROLES,
    PRINCIPALS,
    RECEIVE_RETURN_ROLES,
    STORE_SCOPED,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import make_order
from apps.orders.choices import OrderStatus
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
PICKUP_CODE = "Q7K2"
DELIVERY_OTP = "583920"


def make_task(order, status=TS.SEARCHING, rider=None, **kwargs) -> DeliveryTask:
    now = timezone.now()
    kwargs.setdefault("search_started_at", now - timedelta(minutes=3))
    if rider is not None:
        kwargs.setdefault("assigned_at", now - timedelta(minutes=2))
        kwargs.setdefault("assignment_mode", "AUTO")
    return DeliveryTask.objects.create(
        order=order,
        store=order.store,
        status=status,
        rider=rider,
        distance_km=Decimal("2.40"),
        payout_amount=Decimal("35.00"),
        **kwargs,
    )


def online(rider: Rider, lng=77.06, lat=28.45) -> Rider:
    now = timezone.now()
    Rider.objects.filter(pk=rider.pk).update(
        is_online=True,
        current_location=Point(lng, lat, srid=4326),
        last_location_at=now,
        last_location_received_at=now,
    )
    rider.refresh_from_db()
    return rider


@pytest.fixture
def world():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    rider = online(active_rider(preferred_store=own, full_name="Ravi Kumar"))
    busy_rider = online(active_rider(preferred_store=own, full_name="Mohit Singh"))
    other_rider = online(active_rider(preferred_store=other, full_name="Imran Khan"))
    searching = make_task(
        make_order(own, OrderStatus.ACCEPTED, order_number="JV-DSP-0001", pickup_code=PICKUP_CODE)
    )
    unassigned = make_task(
        make_order(own, OrderStatus.ACCEPTED, order_number="JV-DSP-0002"),
        TS.UNASSIGNED,
        unassigned_at=timezone.now(),
    )
    assigned = make_task(
        make_order(own, OrderStatus.PACKED, order_number="JV-DSP-0003", pickup_code="R2D4"),
        TS.ASSIGNED,
        rider=busy_rider,
    )
    other_task = make_task(
        make_order(other, OrderStatus.ACCEPTED, order_number="JV-DSP-0009"), TS.UNASSIGNED
    )
    other_offer = DeliveryOffer.objects.create(
        task=other_task,
        rider=other_rider,
        status=OfferStatus.PENDING,
        offered_at=timezone.now(),
        expires_at=timezone.now() + timedelta(seconds=30),
    )
    return {
        "own": own,
        "other": other,
        "rider": rider,
        "busy_rider": busy_rider,
        "other_rider": other_rider,
        "searching": searching,
        "unassigned": unassigned,
        "assigned": assigned,
        "other_task": other_task,
        "other_offer": other_offer,
    }


def task_url(task, name="ops:dispatch-task") -> str:
    return reverse(name, args=[task.pk])


# --------------------------------------------------------------------------- access matrix


@pytest.mark.parametrize("url_kind", ["board", "partial", "task", "panel"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_dispatch_role_matrix(client, world, principal, url_kind):
    """05 §3 "Manual dispatch": Super Admin, Ops, Store Manager (own stores). Everyone else 403;
    signed out or non-staff go to the login."""
    login_with_stores(client, principal, world["own"])
    url = {
        "board": reverse("ops:dispatch"),
        "partial": reverse("ops:dispatch-board"),
        "task": task_url(world["searching"]),
        "panel": task_url(world["searching"], "ops:dispatch-task-panel"),
    }[url_kind]
    response = client.get(url)
    assert response.status_code == expected_status(principal, DISPATCH_ROLES), principal


@pytest.mark.parametrize(
    "action", ["ops:dispatch-assign", "ops:dispatch-unassign", "ops:dispatch-retry"]
)
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_dispatch_buttons_refused_without_the_role(client, world, principal, action, monkeypatch):
    if principal in DISPATCH_ROLES:
        pytest.skip("allowed roles are covered by the service tests below")
    calls = []
    monkeypatch.setattr(order_actions, "_call", lambda *a, **k: calls.append(a))
    login_with_stores(client, principal, world["own"])
    response = client.post(task_url(world["unassigned"], action), {"rider": world["rider"].pk})
    assert response.status_code == expected_status(principal, DISPATCH_ROLES)
    assert calls == []


def test_dispatch_buttons_need_post(client, world):
    client.force_login(staff_in_role(roles.OPS))
    assert client.get(task_url(world["unassigned"], "ops:dispatch-retry")).status_code == 405


def test_nav_shows_dispatch_to_dispatch_roles_only(client, world):
    client.force_login(staff_in_role(roles.OPS))
    assert reverse("ops:dispatch").encode() in client.get(reverse("ops:dashboard")).content
    client.force_login(staff_in_role(roles.SUPPORT))
    assert reverse("ops:dispatch").encode() not in client.get(reverse("ops:dashboard")).content


# --------------------------------------------------------------------------- IDOR / scoping


def test_store_manager_sees_only_own_store_on_board(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    response = client.get(reverse("ops:dispatch"))
    board = response.context["board"]
    numbers = {task.order.order_number for task in board.waiting}
    assert numbers == {"JV-DSP-0001", "JV-DSP-0002"}
    assert board.offers == []  # the pending offer is another store's
    assert {row.rider.pk for row in board.riders} == {world["rider"].pk, world["busy_rider"].pk}
    assert b"JV-DSP-0009" not in response.content
    assert b"Imran Khan" not in response.content


def test_store_filter_cannot_widen_scope(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    response = client.get(reverse("ops:dispatch-board"), {"store": world["other"].pk}, **HX)
    assert response.status_code == 200
    assert b"JV-DSP-0009" not in response.content


def test_ops_sees_all_stores_and_filters(client, world):
    client.force_login(staff_in_role(roles.OPS))
    board = client.get(reverse("ops:dispatch")).context["board"]
    assert "JV-DSP-0009" in {task.order.order_number for task in board.waiting}
    assert [offer.pk for offer in board.offers] == [world["other_offer"].pk]
    filtered = client.get(reverse("ops:dispatch-board"), {"store": world["other"].pk}, **HX)
    assert {t.order.order_number for t in filtered.context["board"].waiting} == {"JV-DSP-0009"}


@pytest.mark.parametrize(
    "name",
    [
        "ops:dispatch-task",
        "ops:dispatch-task-panel",
        "ops:dispatch-assign",
        "ops:dispatch-unassign",
        "ops:dispatch-retry",
    ],
)
def test_other_store_task_is_404_for_store_manager(client, world, name, monkeypatch):
    calls = []
    monkeypatch.setattr(order_actions, "_call", lambda *a, **k: calls.append(a))
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    url = task_url(world["other_task"], name)
    is_post = name not in ("ops:dispatch-task", "ops:dispatch-task-panel")
    response = client.post(url, {"rider": world["other_rider"].pk}) if is_post else client.get(url)
    assert response.status_code == 404
    assert calls == []


def test_unknown_task_is_404(client, world):
    client.force_login(staff_in_role(roles.OPS))
    assert client.get(reverse("ops:dispatch-task", args=[999999])).status_code == 404


# --------------------------------------------------------------------------- board content


def test_board_lists_waiting_offers_and_riders_with_distance(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse("ops:dispatch"))
    content = response.content.decode()
    assert 'data-testid="waiting-JV-DSP-0002"' in content
    assert 'data-testid="road-JV-DSP-0003"' in content
    assert f'data-testid="offer-{world["other_offer"].pk}"' in content
    rows = {row.rider.pk: row for row in response.context["board"].riders}
    # Store at (28.45, 77.05), rider at (28.45, 77.06): about 0.98 km.
    assert rows[world["rider"].pk].km == pytest.approx(0.98, abs=0.02)
    assert rows[world["busy_rider"].pk].task == world["assigned"]
    assert rows[world["other_rider"].pk].pending_offer is True
    assert response.context["board"].unassigned == 2
    assert PICKUP_CODE not in content


def test_board_query_count_does_not_grow_with_rows(client, world):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse("ops:dispatch-board")
    client.get(url, **HX)  # warm caches (session, permissions)
    with CaptureQueriesContext(connection) as small:
        client.get(url, **HX)
    for index in range(8):
        order = make_order(world["own"], OrderStatus.ACCEPTED, order_number=f"JV-DSP-1{index:03}")
        task = make_task(order)
        rider = online(active_rider(preferred_store=world["own"]))
        DeliveryOffer.objects.create(
            task=task,
            rider=rider,
            status=OfferStatus.PENDING,
            offered_at=timezone.now(),
            expires_at=timezone.now() + timedelta(seconds=30),
        )
    with CaptureQueriesContext(connection) as big:
        client.get(url, **HX)
    assert len(big) == len(small)


def test_board_partial_polls_and_refreshes(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse("ops:dispatch-board"), **HX)
    content = response.content.decode()
    assert content.lstrip().startswith("<div") or 'id="dispatch-board"' in content
    assert "ops:refresh from:body" in content
    assert "<html" not in content


# --------------------------------------------------------------------------- task detail


def test_task_detail_shows_lock_state_never_codes(client, world):
    task = world["assigned"]
    DeliveryTask.objects.filter(pk=task.pk).update(
        pickup_locked_at=timezone.now(),
        pickup_attempts=5,
        delivery_otp_encrypted=encrypt(DELIVERY_OTP),
    )
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(task_url(task))
    content = response.content.decode()
    detail = response.context["detail"]
    assert detail.pickup_locked is True
    assert detail.otp_locked is False
    assert 'data-testid="pickup-lock"' in content
    assert "R2D4" not in content
    assert DELIVERY_OTP not in content
    assert "delivery_otp_encrypted" not in content
    assert [label for label, _ in detail.timeline] == [
        "Search started (current round)",
        "Rider assigned",
    ]


def test_task_detail_lists_candidates_of_the_store_only(client, world):
    client.force_login(staff_in_role(roles.OPS))
    detail = client.get(task_url(world["searching"])).context["detail"]
    assert detail.can_assign
    assert not detail.can_unassign
    assert not detail.can_retry
    # Free, online, active riders of the task's store; the busy one and the other store's are out.
    assert [row.rider.pk for row in detail.candidates] == [world["rider"].pk]


def test_cod_candidate_over_cash_limit_is_flagged(client, world):
    order = world["searching"].order
    rider = world["rider"]
    Rider.objects.filter(pk=rider.pk).update(cash_in_hand=rider.cash_limit)
    assert order.payment_method == "COD" or pytest.skip("factory order is not COD")
    client.force_login(staff_in_role(roles.OPS))
    detail = client.get(task_url(world["searching"])).context["detail"]
    assert detail.candidates[0].within_cash_limit is False


# --------------------------------------------------------------------------- actions (services)


def _toast(response) -> str:
    return json.loads(response["HX-Trigger"])["ops:toast"]["message"]


def test_manual_assign_through_the_service(client, world):
    """08 §5 step 7: the rider is assigned directly (MANUAL), audited."""
    from apps.core.models import AuditLog

    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    response = client.post(
        task_url(world["searching"], "ops:dispatch-assign"), {"rider": world["rider"].pk}, **HX
    )
    assert response.status_code == 204, response.content
    assert "Rider assigned" in _toast(response)
    task = DeliveryTask.objects.get(pk=world["searching"].pk)
    assert (task.status, task.rider_id, task.assignment_mode) == (
        TS.ASSIGNED,
        world["rider"].pk,
        "MANUAL",
    )
    assert AuditLog.objects.filter(action="delivery.manual_assign").exists()


def test_manual_assign_refusals_map_to_status(client, world):
    client.force_login(staff_in_role(roles.OPS))
    # Another store's rider: the service refuses (400), nothing changes.
    response = client.post(
        task_url(world["searching"], "ops:dispatch-assign"),
        {"rider": world["other_rider"].pk},
        **HX,
    )
    assert response.status_code == 400
    assert DeliveryTask.objects.get(pk=world["searching"].pk).rider_id is None
    # Task already has a rider: wrong state (409).
    response = client.post(
        task_url(world["assigned"], "ops:dispatch-assign"), {"rider": world["rider"].pk}, **HX
    )
    assert response.status_code == 409
    # No rider chosen: 400 before any service call.
    response = client.post(task_url(world["searching"], "ops:dispatch-assign"), {}, **HX)
    assert response.status_code == 400


def test_unassign_through_the_service(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(task_url(world["assigned"], "ops:dispatch-unassign"), **HX)
    assert response.status_code == 204, response.content
    task = DeliveryTask.objects.get(pk=world["assigned"].pk)
    assert (task.status, task.rider_id) == (TS.SEARCHING, None)


def test_retry_through_the_service_and_wrong_state(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(task_url(world["unassigned"], "ops:dispatch-retry"), **HX)
    assert response.status_code == 204, response.content
    assert DeliveryTask.objects.get(pk=world["unassigned"].pk).status == TS.SEARCHING
    response = client.post(task_url(world["assigned"], "ops:dispatch-retry"), **HX)
    assert response.status_code == 409
    assert "unassigned" in response["X-Ops-Message"]


def test_plain_post_redirects_back_with_message(client, world):
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(task_url(world["unassigned"], "ops:dispatch-retry"))
    assert response.status_code == 302
    assert response["Location"] == task_url(world["unassigned"])


def test_missing_service_disables_and_refuses(client, world, monkeypatch):
    monkeypatch.setitem(
        order_actions.SERVICES,
        order_actions.RETRY_DISPATCH,
        ("apps.delivery.services.dispatch", "no_such_service"),
    )
    client.force_login(staff_in_role(roles.OPS))
    page = client.get(task_url(world["unassigned"])).content.decode()
    assert 'data-testid="retry" disabled' in page
    response = client.post(task_url(world["unassigned"], "ops:dispatch-retry"), **HX)
    assert response.status_code == 501


# --------------------------------------------------------------------------- returns (T14)


@pytest.fixture
def failed(world):
    """A failed delivery of the own store, the rider bringing the items back (RETURNING)."""
    order = make_order(
        world["own"], OrderStatus.DELIVERY_FAILED, lines=2, order_number="JV-RET-0001"
    )
    for item in order.items.all():
        ensure_inventory(world["own"], item.variant)
    make_task(order, TS.RETURNING, rider=world["rider"], failed_at=timezone.now())
    other = make_order(world["other"], OrderStatus.DELIVERY_FAILED, order_number="JV-RET-0009")
    make_task(other, TS.RETURNING, rider=world["other_rider"])
    return {"order": order, "other": other}


def returns_url(store) -> str:
    return reverse("ops:store-returns", args=[store.code])


def receive_url(store, order) -> str:
    return reverse("ops:store-receive-return", args=[store.code, order.pk])


@pytest.mark.parametrize("partial", [False, True])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_returns_role_matrix(client, world, failed, principal, partial):
    """DL-61: Super Admin, Ops, Store Manager (own) receive returns; Store Staff and Support
    do not, although Store Staff holds orders.process_order."""
    login_with_stores(client, principal, world["own"])
    name = "ops:store-returns-list" if partial else "ops:store-returns"
    response = client.get(reverse(name, args=[world["own"].code]))
    assert response.status_code == expected_status(principal, RECEIVE_RETURN_ROLES), principal


def test_returns_other_store_is_404(client, world, failed, monkeypatch):
    calls = []
    monkeypatch.setattr(order_actions, "_call", lambda *a, **k: calls.append(a))
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    assert client.get(returns_url(world["other"])).status_code == 404
    # Another store's order through the own store's URL: not found either.
    assert client.post(receive_url(world["own"], failed["other"])).status_code == 404
    assert client.post(receive_url(world["other"], failed["other"])).status_code == 404
    assert calls == []


@pytest.mark.parametrize("principal", sorted(STORE_SCOPED | {roles.SUPPORT, roles.FINANCE}))
def test_receive_return_post_refused_without_the_role(client, world, failed, principal):
    """DL-61: no receive for Store Staff, Support or Finance; nothing changes."""
    if principal in RECEIVE_RETURN_ROLES:
        pytest.skip("allowed")
    login_with_stores(client, principal, world["own"])
    response = client.post(receive_url(world["own"], failed["order"]), **HX)
    assert response.status_code == 403
    failed["order"].refresh_from_db()
    assert failed["order"].status == OrderStatus.DELIVERY_FAILED


def test_store_staff_console_has_no_returns_link(client, world, failed):
    login_with_stores(client, roles.STORE_STAFF, world["own"])
    console = client.get(reverse("ops:packing", args=[world["own"].code])).content.decode()
    assert returns_url(world["own"]) not in console


def test_returns_page_lists_lines_and_link_from_console(client, world, failed):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    content = client.get(returns_url(world["own"])).content.decode()
    assert 'data-testid="return-JV-RET-0001"' in content
    assert "JV-RET-0009" not in content
    for item in failed["order"].items.all():
        assert f'name="damaged_{item.pk}"' in content
    console = client.get(reverse("ops:packing", args=[world["own"].code])).content.decode()
    assert returns_url(world["own"]) in console


def test_receive_return_through_the_service(client, world, failed):
    """08 T14: good units back on the shelf, damaged recorded, order and task RETURNED."""
    order = failed["order"]
    first, second = list(order.items.order_by("pk"))
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    response = client.post(
        receive_url(world["own"], order),
        {f"damaged_{first.pk}": "1", f"damaged_{second.pk}": "0"},
        **HX,
    )
    assert response.status_code == 204, response.content
    assert "1 damaged unit recorded" in _toast(response)
    order.refresh_from_db()
    assert order.status == OrderStatus.RETURNED
    assert DeliveryTask.objects.get(order=order).status == TS.RETURNED
    damage = StockMovement.objects.filter(order=order, type="DAMAGE")
    assert [(m.variant_id, m.delta) for m in damage] == [(first.variant_id, -1)]


def test_receive_return_rejects_bad_counts_and_wrong_state(client, world, failed):
    order = failed["order"]
    first = order.items.order_by("pk").first()
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    response = client.post(receive_url(world["own"], order), {f"damaged_{first.pk}": "9"}, **HX)
    assert response.status_code == 400
    DeliveryTask.objects.filter(order=order).update(status=TS.FAILED)
    response = client.post(receive_url(world["own"], order), **HX)
    assert response.status_code == 409
    order.refresh_from_db()
    assert order.status == OrderStatus.DELIVERY_FAILED


def test_not_ready_return_has_no_form(client, world, failed):
    DeliveryTask.objects.filter(order=failed["order"]).update(status=TS.FAILED)
    client.force_login(staff_in_role(roles.OPS))
    content = client.get(returns_url(world["own"])).content.decode()
    assert 'data-testid="not-ready-JV-RET-0001"' in content
    assert 'data-testid="receive-JV-RET-0001"' not in content
