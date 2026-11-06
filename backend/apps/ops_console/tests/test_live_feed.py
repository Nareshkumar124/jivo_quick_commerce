"""Live Ops Console (Phase 6): the live client is served only to users the ops socket accepts
(05 §3 "Live order board": `orders.view_order`), the board, packing and dispatch partials refresh
on `ops:live` and keep polling as the fallback, and the client never renders event payloads as
HTML (textContent / x-text only) and tolerates unknown events."""

import re
from pathlib import Path

import pytest
from django.conf import settings
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.ops_console.tests.helpers import (
    LIVE_BOARD_ROLES,
    ORDER_VIEW_ROLES,
    PACKING_ROLES,
    ROLES,
    SUPERUSER,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.views import live_feed_url
from apps.realtime import contract
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
STATIC = Path(settings.BASE_DIR) / "static" / "ops" / "js"
TEMPLATES = Path(settings.BASE_DIR) / "templates" / "ops"
LIVE_JS = (STATIC / "live.js").read_text(encoding="utf-8")


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01", name="Jivo Sector 14")


def _page(principal, store, client, url):
    login_with_stores(client, principal, store)
    return client.get(url)


@pytest.mark.parametrize("principal", sorted({*ROLES, SUPERUSER}))
def test_dashboard_serves_the_live_client_only_to_order_viewers(client, store, principal):
    response = _page(principal, store, client, reverse("ops:dashboard"))
    assert response.status_code == 200
    html = response.content.decode()
    if principal in ORDER_VIEW_ROLES:
        assert f'data-ops-live-url="{contract.OPS_SOCKET}"' in html
        assert "ops/js/live.js" in html
        assert 'data-testid="ops-live-status"' in html
        assert 'data-testid="ops-alerts-toggle"' in html
        assert 'data-ops-order-url="/admin/orders/order/0/change/"' in html
    else:
        assert "data-ops-live-url" not in html
        assert "ops/js/live.js" not in html
        assert "ops-live-status" not in html


@pytest.mark.parametrize("principal", sorted(LIVE_BOARD_ROLES))
def test_live_board_page_is_live(client, store, principal):
    response = _page(principal, store, client, reverse("ops:live-board"))
    assert response.status_code == 200
    html = response.content.decode()
    assert "ops/js/live.js" in html
    assert "ops:live from:body[opsLiveAllowed('board-columns')]" in html


def test_live_feed_url_rules():
    assert live_feed_url(UserFactory()) == ""  # not staff
    inactive = staff_in_role(roles.OPS, is_active=False)
    assert live_feed_url(inactive) == ""
    assert live_feed_url(StaffUserFactory()) == ""  # staff without a role
    assert live_feed_url(staff_in_role(roles.CATALOG_MANAGER)) == ""
    assert live_feed_url(staff_in_role(roles.OPS)) == contract.OPS_SOCKET


@pytest.mark.parametrize(
    ("principal", "name", "region"),
    [
        (roles.OPS, "ops:live-board-columns", "board-columns"),
        (roles.STORE_MANAGER, "ops:live-board-columns", "board-columns"),
        (roles.OPS, "ops:dispatch-board", "dispatch-board"),
        (roles.STORE_MANAGER, "ops:dispatch-board", "dispatch-board"),
    ],
)
def test_partials_refresh_on_live_events_and_keep_polling(client, store, principal, name, region):
    login_with_stores(client, principal, store)
    response = client.get(reverse(name), **HX)
    assert response.status_code == 200
    html = response.content.decode()
    assert "<html" not in html
    assert f"every 5s[opsPollAllowed('{region}')]" in html or "[opsPollAllowed(" in html
    assert f"ops:live from:body[opsLiveAllowed('{region}')]" in html
    assert "ops:refresh from:body" in html


@pytest.mark.parametrize("principal", sorted(PACKING_ROLES - {SUPERUSER}))
def test_packing_queues_refresh_on_live_events(client, store, principal):
    login_with_stores(client, principal, store)
    response = client.get(reverse("ops:packing-queues", args=[store.code]), **HX)
    assert response.status_code == 200
    html = response.content.decode()
    assert "[opsPollAllowed('packing-queues')]" in html
    assert "ops:live from:body[opsLiveAllowed('packing-queues')]" in html


def test_packing_queues_of_another_store_are_refused(client, store):
    other = DarkStoreFactory(code="NOI-18")
    login_with_stores(client, roles.STORE_STAFF, store)
    response = client.get(reverse("ops:packing-queues", args=[other.code]), **HX)
    assert response.status_code in (403, 404)


# --------------------------------------------------------------------------- client checks


def _js_list(name: str) -> list[str]:
    match = re.search(rf"const {name} = \[([^\]]*)\]", LIVE_JS)
    assert match, name
    return re.findall(r'"([^"]+)"', match.group(1))


def _js_keys(name: str) -> set[str]:
    match = re.search(rf"const {name} = \{{([^}}]*)\}}", LIVE_JS)
    assert match, name
    return set(re.findall(r'"?([\w.]+)"?\s*:', match.group(1)))


def refreshes(type_: str) -> bool:
    return type_ in _js_keys("REFRESH_TYPES") or any(
        type_.startswith(prefix) for prefix in _js_list("REFRESH_PREFIXES")
    )


@pytest.mark.parametrize(
    "type_",
    [contract.ORDER_STATUS, contract.ORDER_CREATED, contract.RIDER_STATUS, contract.ALERT],
)
def test_every_store_feed_event_refreshes_the_boards(type_):
    assert refreshes(type_)


@pytest.mark.parametrize(
    "type_", ["dispatch.unassigned", "dispatch.assigned", "task.updated", "order.anything_new"]
)
def test_future_dispatch_task_and_order_events_refresh(type_):
    assert refreshes(type_)


@pytest.mark.parametrize(
    "type_", [contract.RIDER_LOCATION, contract.PONG, contract.ERROR, "something.unknown"]
)
def test_other_events_do_not_refresh(type_):
    assert not refreshes(type_)


def test_alert_types_cover_the_contract():
    assert {contract.ALERT, "ops_alert"} <= _js_keys("ALERT_TYPES")


def test_close_codes_match_the_contract():
    assert {str(contract.CLOSE_UNAUTHENTICATED), str(contract.CLOSE_FORBIDDEN)} <= _js_keys(
        "STOP_CODES"
    )
    assert str(contract.CLOSE_TOO_MANY_SOCKETS) in LIVE_JS


@pytest.mark.parametrize("sink", ["innerHTML", "outerHTML", "insertAdjacentHTML", "document.write"])
def test_live_client_never_writes_html(sink):
    code = "\n".join(
        line for line in LIVE_JS.splitlines() if not line.strip().startswith(("*", "/*", "//"))
    )
    assert sink not in code
    assert "eval(" not in code


def test_live_status_component_renders_text_only():
    component = (TEMPLATES / "components" / "live_status.html").read_text(encoding="utf-8")
    assert "x-html" not in component
    assert "|safe" not in component
    assert 'x-text="item.message"' in component


def test_token_never_in_the_socket_url():
    assert "token" not in LIVE_JS.lower().split("function socketurl")[1].split("}")[0]


def test_live_refreshes_are_rate_limited():
    match = re.search(r"const DEBOUNCE_MS = (\d+);", LIVE_JS)
    assert match
    assert int(match.group(1)) >= 1500


def test_stored_alerts_are_rebuilt_from_whitelisted_keys():
    body = LIVE_JS.split("function loadAlerts")[1].split("function saveAlerts")[0]
    assert "Object.assign" not in body  # no stored key is copied through
    assert "orderUrl: orderUrl(orderId)" in body
