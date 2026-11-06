"""Packing console pre-UAT fixes (UX audit design/audits/2026-11-04-packing-console.md
PC-01..06; design/screens/ops/cant-supply-dialog.md;
design/system/components/ops-alert-banner-and-sla-badges.md):
units to pack, "Can't supply" data and its total-only contract, SLA badges and LATE-first order,
stored amounts on tickets (UAT-P4-06), alert data attributes and the acceptance SLA setting.
The browser-side behaviour (polling guard, sound cadence, banners) lives in ops/js/orders.js and
is checked in the manual smoke / UAT; these tests pin what the server renders for it."""

from datetime import timedelta
from decimal import Decimal
from types import SimpleNamespace
from urllib.parse import unquote

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.ops_console import packing, sla
from apps.ops_console.tests.helpers import login_with_stores, staff_in_role
from apps.ops_console.tests.orders_support import (  # noqa: F401 - fixture
    fake_services,
    make_order,
)
from apps.orders.choices import OrderStatus, PaymentMethod, PaymentStatus
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")


def page(store) -> str:
    return reverse("ops:packing", args=[store.code])


def html_for(client, store, role=roles.STORE_STAFF) -> str:
    login_with_stores(client, role, store)
    return client.get(page(store)).content.decode()


# --------------------------------------------------------------------------- PC-04 units to pack


def test_pick_list_shows_units_to_pack(client, store):
    order = make_order(store, OrderStatus.PACKING, lines=2, pickup_code="K7Q2")
    first, second = order.items.order_by("id")
    first.quantity_unavailable = 1
    first.save(update_fields=["quantity_unavailable"])
    second.quantity_unavailable = 2  # fully unavailable
    second.save(update_fields=["quantity_unavailable"])
    html = html_for(client, store)
    assert f'data-testid="pack-{first.sku}">× 1</span>' in html  # noqa: RUF001
    assert '<del aria-label="ordered 2">2</del> 1 can\'t supply' in html
    assert "Not in this order" in html
    assert f'data-testid="pack-{second.sku}"' not in html
    # Fully unavailable lines go last.
    assert html.index(f"line-{first.sku}") < html.index(f"line-{second.sku}")


def test_slip_has_a_pack_column(client, store):
    order = make_order(store, OrderStatus.PACKING, lines=2, pickup_code="K7Q2")
    first, second = order.items.order_by("id")
    first.quantity_unavailable = 1
    first.save(update_fields=["quantity_unavailable"])
    second.quantity_unavailable = 2
    second.save(update_fields=["quantity_unavailable"])
    login_with_stores(client, roles.STORE_STAFF, store)
    html = client.get(reverse("ops:packing-slip", args=[store.code, order.pk])).content.decode()
    assert f'data-testid="slip-pack-{first.sku}">Pack 1</td>' in html
    assert "(2 ordered, 1 unavailable)" in html
    assert f"slip-pack-{second.sku}" not in html
    assert "1 line not in this order" in html
    assert "1 item" in html  # units still to pack


def test_would_empty_marks_the_last_line_left(store):
    order = make_order(store, OrderStatus.PACKING, lines=2)
    first, second = order.items.order_by("id")
    second.quantity_unavailable = 2
    second.save(update_fields=["quantity_unavailable"])
    ticket = packing.build(store).queues[2].tickets[0]
    lines = {line.pk: line for line in ticket.lines}
    assert lines[first.pk].would_empty is True
    assert lines[first.pk].to_pack == 2
    assert lines[second.pk].not_in_order is True
    other = make_order(store, OrderStatus.PACKING, lines=2)
    ticket = next(t for t in packing.build(store).queues[2].tickets if t.order.pk == other.pk)
    assert [line.would_empty for line in ticket.lines] == [False, False]


# --------------------------------------------------------------------------- PC-03 can't supply


def test_cant_supply_button_carries_the_dialog_data(client, store, fake_services):  # noqa: F811
    order = make_order(store, OrderStatus.ACCEPTED, payment_method=PaymentMethod.COD)
    line = order.items.get()
    html = html_for(client, store)
    assert 'name="quantity_unavailable"' not in html  # no inline number field any more
    assert 'data-testid="cant-supply-dialog"' in html
    end = html.index(f'data-testid="cant-supply-{line.sku}"')
    button = html[html.rindex("<button", 0, end) : end]
    for attribute in (
        f'data-item="{line.pk}"',
        'data-quantity="2"',
        'data-already="0"',
        'data-to-pack="2"',
        'data-would-empty="1"',
        'data-payment="COD"',
        f'aria-label="Can\'t supply {line.product_name} {line.variant_name}"',
    ):
        assert attribute in button, attribute


def test_no_cant_supply_once_packed(client, store, fake_services):  # noqa: F811
    order = make_order(store, OrderStatus.PACKED, pickup_code="K7Q3")
    line = order.items.get()
    assert f"cant-supply-{line.sku}" not in html_for(client, store)


def unavailable(client, store, order, line, total):
    url = reverse("ops:packing-unavailable", args=[store.code, order.pk])
    return client.post(url, {"item": line.pk, "quantity_unavailable": total}, **HX)


def test_posting_the_total_names_item_and_count(client, store, fake_services):  # noqa: F811
    order = make_order(store, OrderStatus.PACKING)
    line = order.items.get()
    line.quantity_unavailable = 1
    line.save(update_fields=["quantity_unavailable"])
    staff = login_with_stores(client, roles.STORE_STAFF, store)
    response = unavailable(client, store, order, line, 2)
    assert response.status_code == 204
    assert fake_services.calls == [
        ("mark_item_unavailable", order.pk, (line.pk,), {"unavailable": 2, "by": staff})
    ]
    assert f"{line.product_name} {line.variant_name}: 1 unit removed." in response["HX-Trigger"]


def test_a_decrease_is_refused_before_the_service(client, store, fake_services):  # noqa: F811
    order = make_order(store, OrderStatus.PACKING)
    line = order.items.get()
    line.quantity_unavailable = 1
    line.save(update_fields=["quantity_unavailable"])
    login_with_stores(client, roles.STORE_STAFF, store)
    response = unavailable(client, store, order, line, 0)
    assert response.status_code == 400
    assert "can't be undone" in unquote(response["X-Ops-Message"])
    assert fake_services.calls == []


def test_resending_the_same_total_is_passed_on(client, store, fake_services):  # noqa: F811
    """The service treats the same total as a no-op, so a retry after a lost response is safe."""
    order = make_order(store, OrderStatus.PACKING)
    line = order.items.get()
    line.quantity_unavailable = 1
    line.save(update_fields=["quantity_unavailable"])
    login_with_stores(client, roles.STORE_STAFF, store)
    response = unavailable(client, store, order, line, 1)
    assert response.status_code == 204
    assert "already marked" in response["HX-Trigger"]


def test_toast_when_the_order_is_cancelled(client, store, monkeypatch):
    from apps.orders import store_ops

    monkeypatch.setattr(
        store_ops,
        "mark_item_unavailable",
        lambda *args, **kwargs: SimpleNamespace(status=OrderStatus.CANCELLED),
    )
    order = make_order(store, OrderStatus.PACKING)
    line = order.items.get()
    login_with_stores(client, roles.STORE_STAFF, store)
    response = unavailable(client, store, order, line, 2)
    assert f"Order {order.order_number} cancelled: nothing left to pack." in response["HX-Trigger"]


def test_danger_confirmations_focus_the_safe_button(client, store):
    html = html_for(client, store, roles.SUPER_ADMIN)
    assert "$store.confirm.tone === 'danger' ? $refs.cancel : $refs.accept" in html
    assert 'x-ref="back"' in html  # the "Can't supply" dialog's Go back


# --------------------------------------------------------------------------- amounts (UAT-P4-06)


def test_ticket_shows_stored_amounts(client, store):
    cod = make_order(
        store,
        OrderStatus.PACKING,
        payment_method=PaymentMethod.COD,
        payment_status=PaymentStatus.COD_PENDING,
        mrp_total=Decimal("200.00"),
        item_total=Decimal("150.00"),
        product_discount=Decimal("50.00"),
        grand_total=Decimal("150.00"),
    )
    online = make_order(
        store,
        OrderStatus.ACCEPTED,
        payment_method=PaymentMethod.ONLINE,
        payment_status=PaymentStatus.PARTIALLY_REFUNDED,
        mrp_total=Decimal("200.00"),
        item_total=Decimal("150.00"),
        product_discount=Decimal("50.00"),
        grand_total=Decimal("150.00"),
        amount_paid=Decimal("300.00"),
        amount_refunded=Decimal("150.00"),
    )
    html = html_for(client, store)
    cod_row = html[html.index(f"amounts-{cod.order_number}") :][:600]
    assert "Cash on delivery: rider collects <strong>₹150.00</strong>" in cod_row
    online_row = html[html.index(f"amounts-{online.order_number}") :][:600]
    assert "Paid online: bill <strong>₹150.00</strong>" in online_row
    assert "Refunded <strong>₹150.00</strong>" in online_row


# --------------------------------------------------------------------------- PC-06 badges, order


def test_late_tickets_first_with_badge_and_divider(client, settings, store):
    settings.OPS_SLA_WARNING_FRACTION = 0.25
    on_time = make_order(store, OrderStatus.PACKING, age_minutes=40, eta_at=None)
    on_time.eta_at = timezone.now() + timedelta(minutes=20)
    on_time.save(update_fields=["eta_at"])
    late = make_order(store, OrderStatus.PACKING, age_minutes=35)  # eta = placed + 30: late
    soon = make_order(store, OrderStatus.PACKING, age_minutes=25)  # 5 of 30 min left: due soon
    html = html_for(client, store)
    assert html.index(f"ticket-{late.order_number}") < html.index(f"ticket-{on_time.order_number}")
    assert 'data-testid="late-divider-PACKING">LATE (1)</p>' in html
    late_row = html[html.index(f'badge-{late.order_number}"') :][:1200]
    assert 'data-tone-badge="danger"' in late_row
    assert "LATE</span>" in late_row
    assert "late</span>" in late_row  # "5m late"
    soon_row = html[html.index(f'badge-{soon.order_number}"') :][:1200]
    assert "DUE SOON</span>" in soon_row
    assert "left</span>" in soon_row
    assert "1 late" in html  # queue pill


@pytest.mark.parametrize(
    ("seconds", "text"),
    [
        (3900, "1h 05m left"),
        (720, "12m left"),
        (100, "1m 40s left"),
        (40, "40s left"),
        (-180, "3m late"),
        (-40, "40s late"),
        (-4200, "1h 10m late"),
    ],
)
def test_time_text_rules(seconds, text):
    now = timezone.now()
    timer = sla.Timer(now, now + timedelta(seconds=seconds), None, sla.OK, "Promised delivery time")
    assert sla.time_text(timer, now) == text


def test_no_deadline_shows_waiting():
    now = timezone.now()
    timer = sla.Timer(now - timedelta(minutes=14), None, None, sla.BREACHED, "")
    assert sla.time_text(timer, now) == "Waiting 14m"


# --------------------------------------------------------------------------- PC-02 alert data, SLA


def test_acceptance_sla_is_the_backend_setting(settings, store):
    settings.STORE_ACCEPTANCE_SLA_SECONDS = 60
    order = make_order(store, age_minutes=0.5)
    assert sla.timer_for(order).deadline == order.placed_at + timedelta(seconds=60)
    assert sla.timer_for(make_order(store, age_minutes=2)).tone == sla.BREACHED


def test_queues_carry_the_alert_data(client, settings, store):
    settings.STORE_ACCEPTANCE_SLA_SECONDS = 60
    older = make_order(store, age_minutes=0.5)
    make_order(store, age_minutes=0.2)
    login_with_stores(client, roles.STORE_STAFF, store)
    html = client.get(reverse("ops:packing-queues", args=[store.code]), **HX).content.decode()
    assert 'data-new-count="2"' in html
    assert "data-oldest-deadline=" in html
    assert f'data-oldest-number="{older.order_number}"' in html
    assert 'id="ops-alerts"' not in html  # alerts live outside the polled region
    page_html = client.get(page(store)).content.decode()
    assert 'id="ops-alerts"' in page_html
    assert page_html.index('id="ops-alerts"') < page_html.index('id="packing-queues"')
    assert 'id="ops-announcer"' in page_html
    assert 'data-testid="start-taking-orders"' in page_html


def test_board_carries_breach_count_and_late_first(client, store):
    late = make_order(store, OrderStatus.PACKING, age_minutes=35)
    fine = make_order(store, OrderStatus.PACKING, age_minutes=40)
    fine.eta_at = timezone.now() + timedelta(minutes=20)
    fine.save(update_fields=["eta_at"])
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(reverse("ops:live-board")).content.decode()
    assert 'data-breached="1"' in html
    assert html.index(f"card-{late.order_number}") < html.index(f"card-{fine.order_number}")
    assert 'data-testid="late-PACKING"' in html
    assert 'id="ops-alerts"' in html
