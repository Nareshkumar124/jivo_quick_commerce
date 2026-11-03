"""Dashboard cards with Phase 2 data (05 §1.1): stores, catalog and stock. Real data only, every
count limited to the user's stores, each group behind its own permission. Definitions:
docs/admin-panel-architecture.md §9 and `ops_console.selectors`."""

from datetime import time

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from freezegun import freeze_time

from apps.accounts import roles
from apps.catalog.tests.factories import ProductFactory, VariantFactory
from apps.inventory.models import StoreInventory
from apps.inventory.tests.factories import stock
from apps.ops_console import selectors
from apps.ops_console.tests.helpers import (
    NON_STAFF,
    PRINCIPALS,
    STAFF_PRINCIPALS,
    expected_status,
    login_as,
    staff_in_role,
)
from apps.stores.models import StoreTiming
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

# Tuesday 3 Nov 2026, 12:00 IST.
NOON_IST = "2026-11-03T06:30:00Z"
TUESDAY = 1


def store_with_hours(code, opens, closes, **kwargs):
    store = DarkStoreFactory(code=code, timings=False, **kwargs)
    StoreTiming.objects.create(store=store, weekday=TUESDAY, opens_at=opens, closes_at=closes)
    return store


@pytest.fixture
def network():
    """Three active stores (open, closed by hours, paused) and one inactive store."""
    open_store = store_with_hours("OPN-01", time(7), time(23))
    closed = store_with_hours("CLS-01", time(18), time(23))
    paused = store_with_hours("PAU-01", time(7), time(23), is_accepting_orders=False)
    store_with_hours("OFF-01", time(7), time(23), is_active=False)

    live = ProductFactory()
    hidden = ProductFactory(is_active=False)
    healthy = VariantFactory(product=live)
    running_low = VariantFactory(product=live)
    sold_out = VariantFactory(product=live)
    inactive_variant = VariantFactory(product=live, is_active=False)
    of_hidden_product = VariantFactory(product=hidden)

    stock(open_store, healthy, 50)  # threshold 5: fine
    stock(open_store, running_low, 3)  # low
    stock(open_store, sold_out, 0)  # low and out
    switched_off = stock(open_store, VariantFactory(product=live), 1)
    StoreInventory.objects.filter(pk=switched_off.pk).update(is_available=False)  # not on sale
    stock(open_store, inactive_variant, 0)  # not on sale
    stock(open_store, of_hidden_product, 0)  # not on sale
    stock(closed, running_low, 2, reserved=1)  # low (available 1)
    return {"open": open_store, "closed": closed, "paused": paused}


@freeze_time(NOON_IST)
def test_numbers_for_a_global_role(network):
    stats = selectors.operations_stats(staff_in_role(roles.OPS))
    assert stats.scoped is False
    assert stats.stores == selectors.StoreStats(active=3, open_now=1, paused=1)
    # 2 active products' worth: `live` only (hidden is inactive); its 5 variants minus 1 inactive.
    assert stats.catalog == selectors.CatalogStats(active_products=1, active_variants=4)
    assert stats.stock == selectors.StockStats(on_sale=4, low=3, out=1)


@freeze_time(NOON_IST)
def test_store_manager_counts_only_assigned_stores(network):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, network["closed"])
    stats = selectors.operations_stats(manager)
    assert stats.scoped is True
    assert stats.stores == selectors.StoreStats(active=1, open_now=0, paused=0)
    assert stats.stock == selectors.StockStats(on_sale=1, low=1, out=0)
    assert stats.catalog is not None  # the catalog is central


def test_store_role_without_stores_sees_zero_not_everything(network):
    stats = selectors.operations_stats(staff_in_role(roles.STORE_STAFF))
    assert stats.stores is None  # no stores.view_darkstore
    assert stats.stock == selectors.StockStats(on_sale=0, low=0, out=0)


@freeze_time(NOON_IST)
def test_cards_render_with_links_that_match_the_counts(client, network):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    html = client.get(reverse("ops:dashboard")).content.decode()
    assert "All stores." in html
    low_link = reverse("admin:inventory_storeinventory_changelist") + "?stock=low&amp;on_sale=1"
    assert low_link in html
    # The linked inventory list shows exactly the rows the card counts.
    response = client.get(
        reverse("admin:inventory_storeinventory_changelist"), {"stock": "low", "on_sale": "1"}
    )
    assert len(response.context["cl"].result_list) == 3
    out = client.get(
        reverse("admin:inventory_storeinventory_changelist"), {"stock": "out", "on_sale": "1"}
    )
    assert len(out.context["cl"].result_list) == 1


def test_scoped_user_is_told_the_numbers_are_theirs(client, network):
    manager = staff_in_role(roles.STORE_MANAGER)
    grant_store_access(manager, network["open"])
    client.force_login(manager)
    assert "Your assigned stores only." in client.get(reverse("ops:dashboard")).content.decode()


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_operations_partial_matrix(client, network, principal):
    login_as(client, principal)
    response = client.get(reverse("ops:dashboard-operations"))
    assert response.status_code == expected_status(principal, STAFF_PRINCIPALS)


def test_operations_partial_is_an_htmx_fragment(client, network):
    client.force_login(staff_in_role(roles.FINANCE))
    response = client.get(reverse("ops:dashboard-operations"), HTTP_HX_REQUEST="true")
    html = response.content.decode()
    assert response.status_code == 200
    assert "<html" not in html
    assert 'hx-trigger="every 60s"' in html
    assert 'data-testid="kpi-low-stock"' in html
    assert 'data-testid="kpi-stores-active"' not in html  # Finance has no store permission


def test_operations_partial_without_session_is_an_hx_redirect(client, network):
    login_as(client, NON_STAFF)
    response = client.get(reverse("ops:dashboard-operations"), HTTP_HX_REQUEST="true")
    assert response.status_code == 401
    assert response["HX-Redirect"].startswith(reverse("admin:login"))


def _count(client, url) -> int:
    with CaptureQueriesContext(connection) as queries:
        assert client.get(url).status_code == 200
    return len(queries)


def test_operations_queries_do_not_grow_with_stores_or_stock(client, network):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    url = reverse("ops:dashboard-operations")
    few = _count(client, url)
    for index in range(10):
        store = store_with_hours(f"MOR-{index:02d}", time(7), time(23))
        stock(store, VariantFactory(), 2)
    assert _count(client, url) == few


# Measured 2026-11-03 (Super Admin, every card: 11 queries); budget = measured + 2.
OPERATIONS_QUERY_BUDGET = 13


def test_operations_query_budget(client, network, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    with django_assert_max_num_queries(OPERATIONS_QUERY_BUDGET):
        client.get(reverse("ops:dashboard-operations"), HTTP_HX_REQUEST="true")
