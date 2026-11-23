"""Live delivery monitoring (05 §1.4 rider map, T-821): `/ops/riders/map/` and its JSON.

Role matrix (05 §3 "Live order board": Super Admin, Ops, Store Manager own, Support view;
Finance, Store Staff, Catalog Manager none), store scoping / IDOR (another store's order is
absent from the snapshot and a 404 on the route endpoint), the JSON shape from
`live_ops.snapshot`, the service's PermissionDenied as a 403, customer names only where the
service gives them, and that the drawer's actions point at the existing endpoints.
"""

import json
import re
from pathlib import Path

import pytest
from django.conf import settings
from django.contrib.auth.models import Permission
from django.core.exceptions import PermissionDenied
from django.urls import resolve, reverse

from apps.accounts import roles
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.services import live_ops
from apps.delivery.tests.factories import active_rider
from apps.ops_console import dispatch_views, live_map, order_actions, order_views
from apps.ops_console.tests.helpers import (
    DISPATCH_ROLES,
    LIVE_BOARD_ROLES,
    PRINCIPALS,
    STORE_SCOPED,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import make_order
from apps.ops_console.tests.test_dispatch import make_task, online
from apps.orders.choices import OrderStatus
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

PAGE = "ops:live-map"
DATA = "ops:live-map-data"
HX = {"HTTP_HX_REQUEST": "true"}
CUSTOMER = "Asha Verma"
PICKUP_CODE = "Q7K2"


@pytest.fixture
def world():
    own = DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")
    other = DarkStoreFactory(code="NOI-18", name="Jivo Noida 18")
    rider = online(active_rider(preferred_store=own, full_name="Ravi Kumar"))
    other_rider = online(active_rider(preferred_store=other, full_name="Imran Khan"))
    waiting = make_task(make_order(own, OrderStatus.ACCEPTED, order_number="JV-LM-0001"))
    assigned_order = make_order(
        own, OrderStatus.PACKED, order_number="JV-LM-0002", pickup_code=PICKUP_CODE
    )
    assigned_order.user.name = CUSTOMER
    assigned_order.user.save(update_fields=["name"])
    assigned = make_task(assigned_order, TS.ASSIGNED, rider=rider)
    other_task = make_task(
        make_order(other, OrderStatus.PACKED, order_number="JV-LM-0009"),
        TS.ASSIGNED,
        rider=other_rider,
    )
    return {
        "own": own,
        "other": other,
        "rider": rider,
        "other_rider": other_rider,
        "waiting": waiting,
        "assigned": assigned,
        "other_task": other_task,
    }


def _numbers(response) -> set[str]:
    return {row["order_number"] for row in response.json()["deliveries"]}


# --------------------------------------------------------------------------- role matrix


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_page_role_matrix(client, world, principal):
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(PAGE))
    assert response.status_code == expected_status(principal, LIVE_BOARD_ROLES)
    if response.status_code == 200:
        body = response.content.decode()
        assert 'id="live-map-config"' in body
        assert "ops/js/live_map.js" in body
        assert "ops/vendor/ol-7.2.2.min.js" in body
        # No delivery data in the page itself: it comes from the JSON endpoint.
        assert "JV-LM-0002" not in body
        assert CUSTOMER not in body


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_data_role_matrix(client, world, principal):
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(DATA), **HX)
    allowed = expected_status(principal, LIVE_BOARD_ROLES)
    if allowed == 302:  # htmx-style request: 401 + HX-Redirect, never a login page
        assert response.status_code == 401
        assert response["HX-Redirect"].startswith(reverse("admin:login"))
        return
    assert response.status_code == allowed
    if allowed == 200:
        assert response["Content-Type"] == "application/json"
        assert "JV-LM-0002" in _numbers(response)
    else:
        assert b"JV-LM" not in response.content


def test_finance_sees_no_deliveries_or_customer_names(client, world):
    login_with_stores(client, roles.FINANCE)
    for name in (PAGE, DATA):
        response = client.get(reverse(name))
        assert response.status_code == 403
        assert CUSTOMER.encode() not in response.content
    route = reverse("ops:live-map-route", args=[world["assigned"].order_id])
    assert client.get(route).status_code == 403


def test_service_refusal_is_a_403(client, world, monkeypatch):
    login_with_stores(client, roles.OPS)

    def refuse(*args, **kwargs):
        raise PermissionDenied

    monkeypatch.setattr(live_ops, "snapshot", refuse)
    assert client.get(reverse(DATA)).status_code == 403
    monkeypatch.setattr(live_ops, "can_view", lambda user: False)
    assert client.get(reverse(PAGE)).status_code == 403
    route = reverse("ops:live-map-route", args=[world["assigned"].order_id])
    assert client.get(route).status_code == 403


# --------------------------------------------------------------------------- JSON shape


def test_json_shape_and_no_secrets(client, world):
    login_with_stores(client, roles.OPS)
    response = client.get(reverse(DATA))
    assert response.status_code == 200
    data = response.json()
    assert {"generated_at", "stale_after_seconds", "stores", "stats", "riders", "deliveries"} <= (
        set(data)
    )
    assert set(data["stats"]) >= {key for key, _ in live_map.STATS}
    [row] = [d for d in data["deliveries"] if d["order_number"] == "JV-LM-0002"]
    assert row["task_status"] == "ASSIGNED"
    assert row["rider_id"] == world["rider"].pk
    assert row["rider_name"]
    assert row["customer_name"] == CUSTOMER  # Ops holds accounts.view_customer
    [rider] = [r for r in data["riders"] if r["rider_id"] == world["rider"].pk]
    assert rider["lat"] is not None
    assert rider["state"] == "TO_STORE"
    text = response.content.decode().lower()
    assert PICKUP_CODE.lower() not in text
    assert "phone" not in text
    assert "otp" not in text


def test_customer_name_only_where_the_service_gives_it(client, world):
    """A staff member with the live-board permissions but none of the customer-name ones
    (Finance plus a direct `orders.cancel_order`) gets the deliveries without names; `drop` /
    `area` are optional for the page."""
    user = staff_in_role(roles.FINANCE)
    user.user_permissions.add(
        Permission.objects.get(content_type__app_label="orders", codename="cancel_order")
    )
    client.force_login(user)
    response = client.get(reverse(DATA))
    assert response.status_code == 200
    rows = response.json()["deliveries"]
    assert rows
    assert all(row.get("customer_name") is None for row in rows)
    assert CUSTOMER.encode() not in response.content
    # No drop point for this role -> no route either.
    route = client.get(reverse("ops:live-map-route", args=[world["assigned"].order_id]))
    assert route.status_code == 200
    assert route.json()["route"] is None


def _finance_with_cancel():
    user = staff_in_role(roles.FINANCE)
    user.user_permissions.add(
        Permission.objects.get(content_type__app_label="orders", codename="cancel_order")
    )
    return user


@pytest.mark.parametrize("principal", [*sorted(LIVE_BOARD_ROLES), "finance+cancel"])
def test_route_is_null_whenever_the_snapshot_omits_the_drop(client, world, principal):
    """Same rule on both endpoints (`live_ops.shows_customer_name`): no drop point (and no area
    or name) in the snapshot -> no route; a drop point -> the route ends there."""
    if principal == "finance+cancel":
        client.force_login(_finance_with_cancel())
    else:
        login_with_stores(client, principal, world["own"])
    [row] = [
        d
        for d in client.get(reverse(DATA)).json()["deliveries"]
        if d["order_id"] == world["assigned"].order_id
    ]
    route = client.get(reverse("ops:live-map-route", args=[world["assigned"].order_id]))
    assert route.status_code == 200
    if row["drop"] is None:
        assert route.json()["route"] is None
        assert row["area"] is None
        assert row["customer_name"] is None
    else:
        assert route.json()["route"] is not None
    assert (row["drop"] is None) == (not live_map.drop_visible(route.wsgi_request.user))


def test_live_board_capability_matches_the_backend_gate():
    """The page's capability is exactly the snapshot's permission set (Support included,
    Finance / Store Staff / Catalog Manager not)."""
    from apps.ops_console import capabilities

    assert capabilities.DEDICATED[capabilities.LIVE_BOARD] == (live_ops.LIVE_BOARD_PERMISSIONS,)
    for role in roles.ROLE_PERMISSIONS:
        user = staff_in_role(role)
        assert capabilities.allowed(user, capabilities.LIVE_BOARD) == live_ops.can_view(user), role
        assert live_ops.can_view(user) == (role in LIVE_BOARD_ROLES), role


# --------------------------------------------------------------------------- store scoping


@pytest.mark.parametrize("principal", sorted(STORE_SCOPED & LIVE_BOARD_ROLES))
def test_store_roles_see_only_their_stores(client, world, principal):
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(DATA))
    assert _numbers(response) == {"JV-LM-0001", "JV-LM-0002"}
    assert world["other_rider"].pk not in {r["rider_id"] for r in response.json()["riders"]}
    assert {s["id"] for s in response.json()["stores"]} == {world["own"].pk}
    # Asking for another store's id is ignored (own stores only), never widened.
    widened = client.get(reverse(DATA), {"store": world["other"].pk})
    assert _numbers(widened) == {"JV-LM-0001", "JV-LM-0002"}
    # Another store's order: 404 on the route endpoint.
    other = reverse("ops:live-map-route", args=[world["other_task"].order_id])
    assert client.get(other).status_code == 404


def test_store_filter_narrows_for_global_roles(client, world):
    login_with_stores(client, roles.OPS)
    everything = client.get(reverse(DATA))
    assert {"JV-LM-0002", "JV-LM-0009"} <= _numbers(everything)
    narrowed = client.get(reverse(DATA), {"store": world["other"].pk})
    assert _numbers(narrowed) == {"JV-LM-0009"}
    junk = client.get(reverse(DATA), {"store": "1;DROP"})
    assert junk.status_code == 200


def test_page_store_select_lists_only_own_stores(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    body = client.get(reverse(PAGE)).content.decode()
    assert "GGN-01" in body
    assert "NOI-18" not in body


# --------------------------------------------------------------------------- route


def test_route_for_an_assigned_delivery(client, world):
    login_with_stores(client, roles.OPS)
    response = client.get(reverse("ops:live-map-route", args=[world["assigned"].order_id]))
    assert response.status_code == 200
    route = response.json()["route"]
    assert route is not None
    assert route["leg"] == "TO_STORE"
    assert isinstance(route["polyline"], str)
    assert route["polyline"]
    # No rider yet: no route.
    waiting = client.get(reverse("ops:live-map-route", args=[world["waiting"].order_id]))
    assert waiting.json()["route"] is None
    assert client.get(reverse("ops:live-map-route", args=[999_999_999])).status_code == 404


# --------------------------------------------------------------------------- drawer actions


def _config(response) -> dict:
    match = re.search(
        r'<script id="live-map-config" type="application/json">(.*?)</script>',
        response.content.decode(),
        re.S,
    )
    assert match
    return json.loads(match.group(1))


@pytest.mark.parametrize("principal", sorted(LIVE_BOARD_ROLES - {"superuser flag"}))
def test_drawer_actions_reuse_existing_endpoints(client, world, principal):
    login_with_stores(client, principal, world["own"])
    config = _config(client.get(reverse(PAGE)))
    if principal in DISPATCH_ROLES:
        panel = config["taskPanelUrl"].replace("/0/", f"/{world['assigned'].pk}/")
        assert resolve(panel).func.__wrapped__ is dispatch_views.task_detail_partial.__wrapped__
        # The existing panel (assign / reassign / retry) renders for this task, in scope.
        assert client.get(panel, **HX).status_code == 200
    else:
        assert config["taskPanelUrl"] == ""
        assert config["taskUrl"] == ""
    if config["cancelUrl"]:
        assert order_actions.available(order_actions.CANCEL)
        cancel = config["cancelUrl"].replace("/0/", "/1/")
        assert resolve(cancel).func.__wrapped__ is order_views.board_cancel.__wrapped__
    order_url = config["orderUrl"].replace("/0/", "/1/")
    assert resolve(order_url).url_name == "orders_order_change"
    assert bool(config["riderUrl"]) == staff_in_role(principal).has_perm("delivery.view_rider")


def test_drawer_dispatch_panel_is_scoped(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    panel = reverse("ops:dispatch-task-panel", args=[world["other_task"].pk])
    assert client.get(panel, **HX).status_code == 404


def test_sidebar_link_follows_the_live_board_row(client, world):
    for principal, shown in ((roles.OPS, True), (roles.SUPPORT, True), (roles.FINANCE, False)):
        user = staff_in_role(principal)
        if principal in STORE_SCOPED:
            grant_store_access(user, world["own"])
        client.force_login(user)
        body = client.get(reverse("ops:dashboard")).content.decode()
        assert (reverse(PAGE) in body) is shown, principal


# --------------------------------------------------------------------------- static client


def _static(path: str) -> str:
    for base in settings.STATICFILES_DIRS:
        file = Path(base) / path
        if file.exists():
            return file.read_text(encoding="utf-8")
    raise AssertionError(path)


def test_client_never_renders_payloads_as_html():
    for path in (
        "ops/js/live_map.js",
        "ops/js/map_provider_ol.js",
        "ops/js/map_provider_google.js",
    ):
        source = _static(path)
        # (htmx's `swap: "innerHTML"` for the server-rendered dispatch panel is fine.)
        assert not re.search(r"\.(inner|outer)HTML\b", source)
        assert "insertAdjacentHTML" not in source
        assert "eval(" not in source
    source = _static("ops/js/live_map.js")
    # Automatic loads are background requests (idle timeout) and the socket stays primary.
    assert '"X-Ops-Background"' in source
    assert "ops:live-message" in source
    assert "delivery.progress" in source
    assert "rider.location" in source


def test_map_provider_setting_falls_back(settings):
    settings.GOOGLE_MAPS_WEB_KEY = ""
    settings.OPS_MAP_PROVIDER = "nope"
    assert live_map.map_provider()[0] == "openlayers"
    del settings.OPS_MAP_PROVIDER
    name, assets = live_map.map_provider()
    assert name == "openlayers"
    assert all("7.2.2" in path for path in assets["css"])
