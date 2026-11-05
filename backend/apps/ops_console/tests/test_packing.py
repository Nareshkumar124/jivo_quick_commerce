"""Store packing console (05 §1.3, returns excepted; T-413): role matrix (05 §3 "Packing
console"), store and order scoping (404), queues and pick lists, buttons through `order_actions`
only (disabled while the Phase 4 services are missing), item unavailable, the store switch
(real `set_accepting_orders`), the printed slip, query counts and CSRF.
"""

import json
from urllib.parse import unquote

import pytest
from django.contrib.admin.models import LogEntry
from django.db import connection
from django.test import Client
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.inventory.models import StoreInventory
from apps.inventory.services import ensure_inventory
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    NON_STAFF,
    PACKING_ROLES,
    PRINCIPALS,
    STORE_SCOPED,
    TOGGLE_STORE_ROLES,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import (  # noqa: F401 - fixture
    fake_services,
    invalid_transition,
    make_order,
)
from apps.orders.choices import OrderStatus
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
PHONE = "+919811122233"


@pytest.fixture
def shop():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    customer = UserFactory(name="Asha Verma", phone=PHONE)
    placed = make_order(own, user=customer, order_number="JV-PACK-0001")
    packing = make_order(
        own, OrderStatus.PACKING, lines=2, order_number="JV-PACK-0002", pickup_code="K7Q2"
    )
    return {
        "own": own,
        "other": other,
        "placed": placed,
        "packing": packing,
        "other_order": make_order(other, order_number="JV-PACK-0009"),
    }


def page(store) -> str:
    return reverse("ops:packing", args=[store.code])


def step_url(store, order, step) -> str:
    return reverse("ops:packing-step", args=[store.code, order.pk, step])


def unavailable_url(store, order) -> str:
    return reverse("ops:packing-unavailable", args=[store.code, order.pk])


def ticket_numbers(response) -> set[str]:
    return {
        ticket.order.order_number
        for queue in response.context["console"].queues
        for ticket in queue.tickets
    }


# --------------------------------------------------------------------------- access


@pytest.mark.parametrize("url_kind", ["index", "page", "queues"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_packing_role_matrix(client, shop, principal, url_kind):
    """05 §3 "Packing console": Super Admin, Ops, Store Manager (own), Store Staff (own)."""
    login_with_stores(client, principal, shop["own"], shop["other"])
    url = {
        "index": reverse("ops:packing-index"),
        "page": page(shop["own"]),
        "queues": reverse("ops:packing-queues", args=[shop["own"].code]),
    }[url_kind]
    response = client.get(url)
    assert response.status_code == expected_status(principal, PACKING_ROLES), principal


@pytest.mark.parametrize("role", sorted(STORE_SCOPED))
def test_other_store_is_404_for_store_roles(client, shop, role):
    login_with_stores(client, role, shop["own"])
    assert client.get(page(shop["other"])).status_code == 404
    queues = reverse("ops:packing-queues", args=[shop["other"].code])
    assert client.get(queues, **HX).status_code == 404


def test_ops_opens_any_store(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    assert client.get(page(shop["other"])).status_code == 200


def test_index_redirects_to_the_only_store(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.get(reverse("ops:packing-index"))
    assert response.status_code == 302
    assert response["Location"] == page(shop["own"])


def test_index_lists_stores_or_explains_none(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(reverse("ops:packing-index")).content.decode()
    assert "GGN-01" in html
    assert "NOI-18" in html
    client.force_login(staff_in_role(roles.STORE_STAFF))
    assert "No store assigned" in client.get(reverse("ops:packing-index")).content.decode()


# --------------------------------------------------------------------------- queues


def test_queues_show_only_this_store(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.get(page(shop["own"]))
    assert ticket_numbers(response) == {"JV-PACK-0001", "JV-PACK-0002"}
    html = response.content.decode()
    assert "JV-PACK-0009" not in html
    assert PHONE not in html
    assert "Asha Verma" not in html
    assert "Flat 402" not in html


def test_pick_list_with_rack_location(client, shop):
    order = shop["packing"]
    first = order.items.order_by("id").first()
    ensure_inventory(shop["own"], first.variant)
    StoreInventory.objects.filter(store=shop["own"], variant=first.variant).update(
        rack_location="A-03"
    )
    first.quantity_unavailable = 2  # fully unavailable: needs no tick
    first.save(update_fields=["quantity_unavailable"])
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.get(page(shop["own"]))
    ticket = next(
        t for q in response.context["console"].queues for t in q.tickets if t.order.pk == order.pk
    )
    assert [line.rack for line in ticket.lines if line.pk == first.pk] == ["A-03"]
    assert ticket.units == 2
    assert first.pk not in [int(pk) for pk in ticket.pick_ids]
    html = response.content.decode()
    assert "A-03" in html
    assert "K7Q2" in html  # pickup code
    assert f'x-data="pickList({order.pk})"' in html


def test_new_order_ids_feed_the_alert(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    html = client.get(page(shop["own"])).content.decode()
    assert f'data-new-orders="[{shop["placed"].pk}]"' in html
    assert "ops/js/orders.js" in html


def test_queue_partial_is_a_fragment(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.get(reverse("ops:packing-queues", args=[shop["own"].code]), **HX)
    html = response.content.decode()
    assert response.status_code == 200
    assert "<html" not in html
    assert 'id="packing-queues"' in html


def test_query_count_does_not_grow_with_orders(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    url = reverse("ops:packing-queues", args=[shop["own"].code])
    client.get(url, **HX)
    with CaptureQueriesContext(connection) as few:
        client.get(url, **HX)
    for index in range(9):
        status = (OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PACKING)[index % 3]
        make_order(shop["own"], status, lines=3, pickup_code=f"P{index:03d}")
    with CaptureQueriesContext(connection) as many:
        client.get(url, **HX)
    assert len(many) == len(few), [q["sql"] for q in many.captured_queries]


# --------------------------------------------------------------------------- buttons


def test_buttons_disabled_while_services_are_missing(client, shop, monkeypatch):
    from apps.ops_console import order_actions

    for action in (order_actions.ACCEPT, order_actions.MARK_UNAVAILABLE):
        monkeypatch.setitem(
            order_actions.SERVICES, action, ("apps.orders.store_ops", "no_such_service")
        )
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    html = client.get(page(shop["own"])).content.decode()
    assert step_url(shop["own"], shop["placed"], "accept") not in html
    assert "Waiting for the order service" in html
    assert unavailable_url(shop["own"], shop["packing"]) not in html
    response = client.post(step_url(shop["own"], shop["placed"], "accept"), **HX)
    assert response.status_code == 501
    assert "not available yet" in unquote(response["X-Ops-Message"])


def test_buttons_live_with_services(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    html = client.get(page(shop["own"])).content.decode()
    assert step_url(shop["own"], shop["placed"], "accept") in html
    assert step_url(shop["own"], shop["packing"], "mark-packed") in html
    assert unavailable_url(shop["own"], shop["packing"]) in html
    assert "cancel-JV-PACK" not in html  # Store Staff may not cancel (05 §3)


@pytest.mark.parametrize(
    ("step", "service"),
    [
        ("accept", "accept_order"),
        ("start-packing", "start_packing"),
        ("mark-packed", "mark_packed"),
    ],
)
def test_steps_call_the_service(client, shop, fake_services, step, service):  # noqa: F811
    staff = login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.post(step_url(shop["own"], shop["placed"], step), **HX)
    assert response.status_code == 204
    assert json.loads(response["HX-Trigger"])["ops:refresh"] is True
    assert fake_services.calls == [(service, shop["placed"].pk, (), {"by": staff})]


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_step_role_matrix(client, shop, fake_services, principal):  # noqa: F811
    login_with_stores(client, principal, shop["own"])
    response = client.post(step_url(shop["own"], shop["placed"], "accept"), **HX)
    if principal in PACKING_ROLES:
        expected = 204
    elif principal in (NON_STAFF, ANONYMOUS):
        expected = 401
    else:
        expected = 403
    assert response.status_code == expected, principal


def test_step_refused_is_409(client, shop, fake_services):  # noqa: F811
    fake_services.refuse_with = invalid_transition()
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.post(step_url(shop["own"], shop["placed"], "accept"), **HX)
    assert response.status_code == 409
    assert unquote(response["X-Ops-Message"]) == "This order is already packed."


def test_other_store_order_through_own_store_is_404(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_MANAGER, shop["own"])
    response = client.post(step_url(shop["own"], shop["other_order"], "accept"), **HX)
    assert response.status_code == 404
    response = client.post(step_url(shop["other"], shop["other_order"], "accept"), **HX)
    assert response.status_code == 404
    assert fake_services.calls == []


def test_unknown_step_is_404(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    response = client.post(step_url(shop["own"], shop["placed"], "deliver"), **HX)
    assert response.status_code == 404
    assert fake_services.calls == []


def test_steps_need_post_and_csrf(shop, fake_services):  # noqa: F811
    strict = Client(enforce_csrf_checks=True)
    login_with_stores(strict, roles.STORE_STAFF, shop["own"])
    url = step_url(shop["own"], shop["placed"], "accept")
    assert strict.get(url).status_code == 405
    assert strict.post(url, **HX).status_code == 403
    assert fake_services.calls == []


# --------------------------------------------------------------------------- unavailable


def test_mark_unavailable_calls_the_service(client, shop, fake_services):  # noqa: F811
    staff = login_with_stores(client, roles.STORE_STAFF, shop["own"])
    line = shop["packing"].items.order_by("id").first()
    url = unavailable_url(shop["own"], shop["packing"])
    response = client.post(url, {"item": line.pk, "quantity_unavailable": 1}, **HX)
    assert response.status_code == 204
    assert fake_services.calls == [
        ("mark_item_unavailable", shop["packing"].pk, (line.pk,), {"unavailable": 1, "by": staff})
    ]


def test_unavailable_more_than_ordered_is_400(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    line = shop["packing"].items.first()
    url = unavailable_url(shop["own"], shop["packing"])
    response = client.post(url, {"item": line.pk, "quantity_unavailable": 3}, **HX)
    assert response.status_code == 400
    assert "At most 2" in unquote(response["X-Ops-Message"])
    assert fake_services.calls == []


def test_unavailable_line_of_another_order_is_404(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    foreign = shop["other_order"].items.first()
    url = unavailable_url(shop["own"], shop["packing"])
    response = client.post(url, {"item": foreign.pk, "quantity_unavailable": 1}, **HX)
    assert response.status_code == 404
    assert fake_services.calls == []


# --------------------------------------------------------------------------- cancel


def test_store_staff_cannot_cancel_manager_can(client, shop, fake_services):  # noqa: F811
    url = reverse("ops:packing-cancel", args=[shop["own"].code, shop["placed"].pk])
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    assert client.post(url, {"reason": "OTHER_STAFF"}, **HX).status_code == 403
    manager = login_with_stores(client, roles.STORE_MANAGER, shop["own"])
    assert "cancel-JV-PACK-0001" in client.get(page(shop["own"])).content.decode()
    assert client.post(url, {"reason": "ITEMS_UNAVAILABLE"}, **HX).status_code == 204
    assert fake_services.calls == [
        (
            "cancel_by_staff",
            shop["placed"].pk,
            (),
            {"by": manager, "reason": "ITEMS_UNAVAILABLE", "note": ""},
        )
    ]


# --------------------------------------------------------------------------- store switch


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_accepting_switch_matrix(client, shop, principal):
    login_with_stores(client, principal, shop["own"])
    url = reverse("ops:packing-accepting", args=[shop["own"].code])
    response = client.post(url, {"accepting": "0"}, **HX)
    if principal in TOGGLE_STORE_ROLES:
        expected = 200  # the store bar, swapped in place (PC-21)
    elif principal in (NON_STAFF, ANONYMOUS):
        expected = 401
    else:
        expected = 403
    assert response.status_code == expected, principal
    shop["own"].refresh_from_db()
    assert shop["own"].is_accepting_orders is (principal not in TOGGLE_STORE_ROLES)


def test_accepting_switch_goes_through_the_service(client, shop):
    staff = staff_in_role(roles.SUPER_ADMIN)
    client.force_login(staff)
    assert "accepting-toggle" in client.get(page(shop["own"])).content.decode()
    url = reverse("ops:packing-accepting", args=[shop["own"].code])
    response = client.post(url, {"accepting": "0"}, **HX)
    assert response.status_code == 200
    html = response.content.decode()
    assert 'id="store-bar"' in html
    assert 'data-testid="alert-paused"' in html  # the paused banner (component spec A1)
    assert "Resume orders" in html
    assert "Store paused" in response["HX-Trigger"]
    shop["own"].refresh_from_db()
    assert shop["own"].is_accepting_orders is False
    assert LogEntry.objects.filter(user=staff, object_id=str(shop["own"].pk)).exists()
    assert client.post(url, {"accepting": "maybe"}, **HX).status_code == 400


def test_store_manager_switches_own_store_only(client, shop):
    """05 §1.3 "Store Manager can toggle Accepting orders"; another store is a 404."""
    manager = login_with_stores(client, roles.STORE_MANAGER, shop["own"])
    assert "accepting-toggle" in client.get(page(shop["own"])).content.decode()
    url = reverse("ops:packing-accepting", args=[shop["own"].code])
    assert client.post(url, {"accepting": "0"}, **HX).status_code == 200
    assert LogEntry.objects.filter(user=manager, object_id=str(shop["own"].pk)).exists()
    other = reverse("ops:packing-accepting", args=[shop["other"].code])
    assert client.post(other, {"accepting": "0"}, **HX).status_code == 404
    shop["other"].refresh_from_db()
    assert shop["other"].is_accepting_orders is True


def test_store_staff_and_ops_see_no_switch(client, shop):
    for role in (roles.STORE_STAFF, roles.OPS):
        login_with_stores(client, role, shop["own"])
        html = client.get(page(shop["own"])).content.decode()
        assert "accepting-toggle" not in html, role
        assert "Taking orders" in html


# --------------------------------------------------------------------------- slip


def test_slip_for_packing_order(client, shop):
    login_with_stores(client, roles.STORE_STAFF, shop["own"])
    url = reverse("ops:packing-slip", args=[shop["own"].code, shop["packing"].pk])
    response = client.get(url)
    html = response.content.decode()
    assert response.status_code == 200
    assert 'data-qr="K7Q2"' in html
    assert "JV-PACK-0002" in html
    assert "4 items" in html
    assert "qrcode-generator-1.4.4.js" in html
    assert PHONE not in html
    assert "Flat 402" not in html


def test_slip_only_for_packing_or_packed_and_own_store(client, shop):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, shop["own"])
    client.force_login(manager)
    placed = reverse("ops:packing-slip", args=[shop["own"].code, shop["placed"].pk])
    assert client.get(placed).status_code == 404
    foreign = reverse("ops:packing-slip", args=[shop["own"].code, shop["other_order"].pk])
    assert client.get(foreign).status_code == 404
