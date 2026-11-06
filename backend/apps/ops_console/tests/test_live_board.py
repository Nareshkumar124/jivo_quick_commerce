"""Live order board (05 §1.2; T-413): role matrix (05 §3 "Live order board", "Cancel order"),
store scoping, columns and exceptions lane, SLA timers, filters, query counts, no customer PII on
cards, and the cancel button (through `order_actions` only).
"""

import json
from datetime import UTC, timedelta
from urllib.parse import unquote

import pytest
from django.db import connection
from django.test import Client
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.ops_console import board, sla
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    CANCEL_ORDER_ROLES,
    LIVE_BOARD_ROLES,
    NON_STAFF,
    PRINCIPALS,
    STORE_SCOPED,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import (  # noqa: F401 - fixture
    fake_services,
    invalid_transition,
    make_order,
)
from apps.orders.choices import OrderStatus, PaymentMethod, PaymentStatus
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
PAGE = "ops:live-board"
COLUMNS = "ops:live-board-columns"
PHONE = "+919811122233"


@pytest.fixture
def shop():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    customer = UserFactory(name="Asha Verma", phone=PHONE)
    return {
        "own": own,
        "other": other,
        "placed": make_order(own, user=customer, order_number="JV-BOARD-0001"),
        "other_order": make_order(other, order_number="JV-BOARD-0002"),
    }


def board_numbers(response) -> set[str]:
    data = response.context["board"]
    return {
        card.order.order_number
        for column in (*data.columns, *data.exceptions)
        for card in column.cards
    }


# --------------------------------------------------------------------------- access


@pytest.mark.parametrize("url_name", [PAGE, COLUMNS])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_board_role_matrix(client, shop, principal, url_name):
    """05 §3 "Live order board": Super Admin, Ops, Store Manager (own), Support (view)."""
    login_with_stores(client, principal, shop["own"])
    response = client.get(reverse(url_name))
    assert response.status_code == expected_status(principal, LIVE_BOARD_ROLES), principal


def test_store_staff_and_finance_are_refused(client, shop):
    for role in (roles.STORE_STAFF, roles.FINANCE, roles.CATALOG_MANAGER):
        client.force_login(staff_in_role(role))
        response = client.get(reverse(PAGE))
        assert response.status_code == 403, role
        assert response["X-Ops-Refused"] == "1"


def test_htmx_partial_is_a_fragment(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse(COLUMNS), **HX)
    assert response.status_code == 200
    html = response.content.decode()
    assert "<html" not in html
    assert 'id="board-columns"' in html
    assert "ops:refresh from:body" in html


def test_sidebar_link_follows_the_capability(client, shop):
    client.force_login(staff_in_role(roles.SUPPORT))
    assert reverse(PAGE) in client.get(reverse("ops:dashboard")).content.decode()
    client.force_login(staff_in_role(roles.FINANCE))
    assert reverse(PAGE) not in client.get(reverse("ops:dashboard")).content.decode()


# --------------------------------------------------------------------------- scoping


@pytest.mark.parametrize("role", sorted(STORE_SCOPED & LIVE_BOARD_ROLES))
def test_store_manager_sees_only_own_store(client, shop, role):
    login_with_stores(client, role, shop["own"])
    response = client.get(reverse(PAGE))
    assert board_numbers(response) == {"JV-BOARD-0001"}
    assert "JV-BOARD-0002" not in response.content.decode()
    assert "Your assigned stores only." in response.content.decode()


def test_store_filter_cannot_widen_scope(client, shop):
    login_with_stores(client, roles.STORE_MANAGER, shop["own"])
    response = client.get(reverse(COLUMNS), {"store": shop["other"].pk})
    assert board_numbers(response) == {"JV-BOARD-0001"}  # invalid choice ignored, still scoped


def test_store_manager_without_stores_sees_nothing(client, shop):
    client.force_login(staff_in_role(roles.STORE_MANAGER))
    response = client.get(reverse(PAGE))
    assert response.status_code == 200
    assert board_numbers(response) == set()


def test_ops_sees_every_store_and_can_filter(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse(PAGE))
    assert board_numbers(response) == {"JV-BOARD-0001", "JV-BOARD-0002"}
    response = client.get(reverse(COLUMNS), {"store": shop["other"].pk})
    assert board_numbers(response) == {"JV-BOARD-0002"}


# --------------------------------------------------------------------------- columns


def test_columns_exceptions_and_terminal_orders(client, shop):
    own = shop["own"]
    make_order(own, OrderStatus.ACCEPTED, order_number="JV-BOARD-ACC")
    make_order(own, OrderStatus.PACKING, order_number="JV-BOARD-PKG")
    make_order(own, OrderStatus.PACKED, order_number="JV-BOARD-PKD", pickup_code="K7Q2")
    make_order(own, OrderStatus.OUT_FOR_DELIVERY, order_number="JV-BOARD-OFD")
    make_order(
        own,
        OrderStatus.PAYMENT_PENDING,
        order_number="JV-BOARD-PAY",
        placed_at=None,
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PENDING,
        payment_expires_at=timezone.now() + timedelta(minutes=10),
    )
    make_order(own, OrderStatus.DELIVERY_FAILED, order_number="JV-BOARD-DF")
    for terminal in (OrderStatus.DELIVERED, OrderStatus.CANCELLED, OrderStatus.RETURNED):
        make_order(own, terminal, order_number=f"JV-BOARD-{terminal[:6]}")
    login_with_stores(client, roles.STORE_MANAGER, own)
    data = client.get(reverse(PAGE)).context["board"]
    columns = {column.code: [c.order.order_number for c in column.cards] for column in data.columns}
    assert columns == {
        "PLACED": ["JV-BOARD-0001"],
        "ACCEPTED": ["JV-BOARD-ACC"],
        "PACKING": ["JV-BOARD-PKG"],
        "PACKED": ["JV-BOARD-PKD"],
        "OUT_FOR_DELIVERY": ["JV-BOARD-OFD"],
    }
    lane = {column.code: [c.order.order_number for c in column.cards] for column in data.exceptions}
    assert lane == {"PAYMENT_PENDING": ["JV-BOARD-PAY"], "DELIVERY_FAILED": ["JV-BOARD-DF"]}
    assert data.total == 7


def test_card_content_and_no_customer_pii(client, shop):
    client.force_login(staff_in_role(roles.SUPPORT))  # a full-PII role: cards still carry none
    html = client.get(reverse(PAGE)).content.decode()
    assert "JV-BOARD-0001" in html
    assert "GGN-01" in html
    assert "2 items" in html  # one line of 2 units
    assert "COD" in html
    assert PHONE not in html
    assert "Asha Verma" not in html
    assert "Flat 402" not in html


def test_units_exclude_unavailable(shop):
    order = shop["placed"]
    order.items.update(quantity_unavailable=1)
    staff = staff_in_role(roles.OPS)
    data = board.build(staff, board.base_queryset(staff))
    card = next(c for c in data.columns[0].cards if c.order.pk == order.pk)
    assert card.units == 1


def test_column_limit_shows_the_oldest_and_counts_the_rest(shop):
    for age in (5, 9, 7):
        make_order(shop["own"], age_minutes=age, order_number=f"JV-BOARD-AGE{age}")
    staff = staff_in_role(roles.OPS)
    data = board.build(staff, board.base_queryset(staff).filter(store=shop["own"]), limit=2)
    placed = data.columns[0]
    assert placed.count == 4
    assert [c.order.order_number for c in placed.cards] == ["JV-BOARD-AGE9", "JV-BOARD-AGE7"]
    assert placed.hidden == 2


def test_query_count_does_not_grow_with_orders(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse(COLUMNS)
    client.get(url)  # warm caches (content types, sessions)
    with CaptureQueriesContext(connection) as few:
        client.get(url)
    for index in range(12):
        status = (OrderStatus.PLACED, OrderStatus.PACKING, OrderStatus.PACKED)[index % 3]
        make_order(shop["own"], status, lines=2, pickup_code=f"Q{index:03d}")
    with CaptureQueriesContext(connection) as many:
        response = client.get(url)
    assert response.context["board"].total == 14
    assert len(many) == len(few), [q["sql"] for q in many.captured_queries]


# --------------------------------------------------------------------------- SLA


@pytest.mark.parametrize(
    ("age_minutes", "tone"),
    [(0.5, sla.OK), (1.75, sla.WARNING), (3, sla.BREACHED)],
)
def test_acceptance_sla_tone(settings, shop, age_minutes, tone):
    """PLACED counts against the acceptance SLA (setting; 05 §1.1 default 2 min); amber in the
    last quarter, red once past."""
    settings.STORE_ACCEPTANCE_SLA_SECONDS = 120
    settings.OPS_SLA_WARNING_FRACTION = 0.25
    order = make_order(shop["own"], age_minutes=age_minutes)
    timer = sla.timer_for(order)
    assert timer.tone == tone
    assert timer.deadline == order.placed_at + timedelta(seconds=120)


def test_sla_setting_is_read(settings, shop):
    settings.STORE_ACCEPTANCE_SLA_SECONDS = 600
    order = make_order(shop["own"], age_minutes=3)
    assert sla.timer_for(order).tone == sla.OK


def test_eta_deadline_after_acceptance(shop):
    order = make_order(shop["own"], OrderStatus.PACKING, age_minutes=40)  # eta = placed + 30
    timer = sla.timer_for(order)
    assert timer.deadline == order.eta_at
    assert timer.tone == sla.BREACHED


def test_breached_filter(client, settings, shop):
    settings.STORE_ACCEPTANCE_SLA_SECONDS = 120
    make_order(shop["own"], age_minutes=10, order_number="JV-BOARD-LATE")
    make_order(shop["own"], OrderStatus.PACKING, age_minutes=40, order_number="JV-BOARD-ETA")
    make_order(shop["own"], OrderStatus.PACKING, age_minutes=5, order_number="JV-BOARD-FINE")
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse(COLUMNS), {"breached": "on"})
    assert board_numbers(response) == {"JV-BOARD-LATE", "JV-BOARD-ETA"}
    assert "past the SLA" in response.content.decode()


def test_payment_filter(client, shop):
    make_order(
        shop["own"],
        order_number="JV-BOARD-ONL",
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PAID,
    )
    client.force_login(staff_in_role(roles.OPS))
    response = client.get(reverse(COLUMNS), {"payment": PaymentMethod.ONLINE})
    assert board_numbers(response) == {"JV-BOARD-ONL"}


def test_card_carries_timer_data_for_the_script(client, shop):
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(reverse(PAGE)).content.decode()
    order = shop["placed"]
    start = order.placed_at.astimezone(UTC).isoformat(timespec="seconds")
    assert f'data-sla-start="{start.replace("+00:00", "Z")}"' in html
    assert "data-sla-deadline=" in html
    assert "ops/js/orders.js" in html


# --------------------------------------------------------------------------- cancel


def cancel_url(order) -> str:
    return reverse("ops:board-cancel", args=[order.pk])


@pytest.fixture
def no_cancel_service(monkeypatch):
    """A branch without the cancel service: the adapter cannot find it."""
    from apps.ops_console import order_actions

    monkeypatch.setitem(
        order_actions.SERVICES, order_actions.CANCEL, ("apps.orders.store_ops", "no_such_service")
    )


def test_cancel_button_hidden_until_the_service_exists(client, shop, no_cancel_service):
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(reverse(PAGE)).content.decode()
    assert "cancel-JV-BOARD-0001" not in html
    assert 'data-testid="cancel-dialog"' not in html


def test_cancel_unavailable_is_501(client, shop, no_cancel_service):
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(cancel_url(shop["placed"]), {"reason": "OTHER_STAFF"}, **HX)
    assert response.status_code == 501
    assert "not available yet" in unquote(response["X-Ops-Message"])


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_cancel_role_matrix(client, shop, fake_services, principal):  # noqa: F811
    """05 §3 "Cancel order": Super Admin, Ops, Store Manager (own), Support."""
    login_with_stores(client, principal, shop["own"])
    response = client.post(cancel_url(shop["placed"]), {"reason": "OTHER_STAFF"}, **HX)
    if principal in CANCEL_ORDER_ROLES:
        expected = 204
    elif principal in (NON_STAFF, ANONYMOUS):
        expected = 401  # HTMX: 401 + HX-Redirect to the login
    else:
        expected = 403
    assert response.status_code == expected, principal


def test_cancel_goes_through_the_service(client, shop, fake_services):  # noqa: F811
    staff = staff_in_role(roles.SUPPORT)
    client.force_login(staff)
    html = client.get(reverse(PAGE)).content.decode()
    assert "cancel-JV-BOARD-0001" in html
    assert 'data-testid="cancel-dialog"' in html
    response = client.post(
        cancel_url(shop["placed"]), {"reason": "STORE_CLOSING", "note": "Power cut"}, **HX
    )
    assert response.status_code == 204
    trigger = json.loads(response["HX-Trigger"])
    assert trigger["ops:refresh"] is True
    assert "JV-BOARD-0001" in trigger["ops:toast"]["message"]
    assert fake_services.calls == [
        (
            "cancel_by_staff",
            shop["placed"].pk,
            (),
            {"by": staff, "reason": "STORE_CLOSING", "note": "Power cut"},
        )
    ]


def test_cancel_needs_a_valid_reason(client, shop, fake_services):  # noqa: F811
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(cancel_url(shop["placed"]), {"reason": "BORED"}, **HX)
    assert response.status_code == 400
    assert fake_services.calls == []


def test_cancel_refused_by_the_service_is_409_with_its_message(client, shop, fake_services):  # noqa: F811
    fake_services.refuse_with = invalid_transition()
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(cancel_url(shop["placed"]), {"reason": "OTHER_STAFF"}, **HX)
    assert response.status_code == 409
    assert unquote(response["X-Ops-Message"]) == "This order is already packed."


def test_cancel_other_store_order_is_404(client, shop, fake_services):  # noqa: F811
    login_with_stores(client, roles.STORE_MANAGER, shop["own"])
    response = client.post(cancel_url(shop["other_order"]), {"reason": "OTHER_STAFF"}, **HX)
    assert response.status_code == 404
    assert fake_services.calls == []


def test_cancel_is_post_only_and_needs_csrf(shop, fake_services):  # noqa: F811
    staff = staff_in_role(roles.OPS)
    strict = Client(enforce_csrf_checks=True)
    strict.force_login(staff)
    assert strict.get(cancel_url(shop["placed"])).status_code == 405
    response = strict.post(cancel_url(shop["placed"]), {"reason": "OTHER_STAFF"}, **HX)
    assert response.status_code == 403
    assert fake_services.calls == []


def test_plain_post_redirects_back_with_a_message(client, shop, fake_services):  # noqa: F811
    client.force_login(staff_in_role(roles.OPS))
    response = client.post(cancel_url(shop["placed"]), {"reason": "OTHER_STAFF"})
    assert response.status_code == 302
    assert response["Location"] == reverse(PAGE)


def test_store_manager_of_two_stores(client, shop):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, shop["own"])
    grant_store_access(manager, shop["other"])
    client.force_login(manager)
    assert board_numbers(client.get(reverse(PAGE))) == {"JV-BOARD-0001", "JV-BOARD-0002"}
