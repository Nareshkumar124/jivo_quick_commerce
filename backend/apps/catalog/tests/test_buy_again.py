"""Home "Previously bought" rail (`buy_again`, 03 §2.5, 06 §2.4; T-817).

The signed-in customer's variants from DELIVERED orders that the store sells now: one card per
product, most recent first, out-of-stock last, at most 10. Per user, never in the shared cache.
"""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from apps.accounts.tests.factories import UserFactory
from apps.catalog import services
from apps.catalog.tests.factories import ProductFactory, VariantFactory
from apps.inventory.tests.factories import stock
from apps.orders.choices import OrderStatus
from apps.orders.models import OrderItem
from apps.orders.tests.factories import OrderFactory

pytestmark = pytest.mark.django_db

HOME = "/api/v1/home/"


def deliver(user, *variants, store=None, days_ago=1, status=OrderStatus.DELIVERED, unavailable=0):
    """An order of `user` with one line per variant, delivered `days_ago` days ago."""
    when = timezone.now() - timedelta(days=days_ago)
    order = OrderFactory(
        user=user,
        status=status,
        delivered_at=when if status == OrderStatus.DELIVERED else None,
        **({"store": store} if store else {}),
    )
    for variant in variants:
        OrderItem.objects.create(
            order=order,
            variant=variant,
            product=variant.product,
            product_name=variant.product.name,
            variant_name=variant.name,
            sku=variant.sku,
            mrp=variant.mrp,
            selling_price=variant.selling_price,
            quantity=2,
            quantity_unavailable=unavailable,
            line_total=variant.selling_price * 2,
        )
    return order


def home(client, world, store=None):
    store = store or world.store
    response = client.get(HOME, headers={"X-Store-Id": str(store.pk)})
    assert response.status_code == 200
    return response.json()


def names(rail) -> list[str]:
    return [card["name"] for card in rail]


class TestBuyAgain:
    def test_delivered_variants_most_recent_first(self, make_auth_client, user, world, conforms):
        """P2-TC-24: signed-in home fills `buy_again` from delivered orders."""
        deliver(user, world.olive_1l, days_ago=5)
        deliver(user, world.juice_500, world.canola_5l, days_ago=1)
        body = home(make_auth_client(user), world)
        conforms(body, "HomeFeed")
        rail = body["buy_again"]
        # Newest order first (lines of one order: newest variant id first), older order last.
        assert names(rail) == [
            "Jivo Wheatgrass Juice",
            "Jivo Cold Pressed Canola Oil",
            "Jivo Pomace Olive Oil",
        ]
        canola = next(c for c in rail if c["name"] == "Jivo Cold Pressed Canola Oil")
        assert canola["default_variant_id"] == world.canola_5l.pk  # the variant bought
        assert [v["name"] for v in canola["variants"]] == ["1 L", "5 L"]  # full tile

    def test_one_card_per_product_with_latest_variant(self, make_auth_client, user, world):
        deliver(user, world.canola_5l, days_ago=10)
        deliver(user, world.canola_1l, days_ago=2)
        rail = home(make_auth_client(user), world)["buy_again"]
        assert names(rail) == ["Jivo Cold Pressed Canola Oil"]
        assert rail[0]["default_variant_id"] == world.canola_1l.pk

    def test_only_delivered_orders_count(self, make_auth_client, user, world):
        for status in (
            OrderStatus.PLACED,
            OrderStatus.OUT_FOR_DELIVERY,
            OrderStatus.CANCELLED,
        ):
            deliver(user, world.olive_1l, status=status)
        # A line the store marked fully unavailable was never delivered.
        deliver(user, world.juice_500, unavailable=2)
        assert home(make_auth_client(user), world)["buy_again"] == []

    def test_partly_unavailable_line_counts(self, make_auth_client, user, world):
        deliver(user, world.juice_500, unavailable=1)
        assert names(home(make_auth_client(user), world)["buy_again"]) == ["Jivo Wheatgrass Juice"]

    def test_filtered_to_what_the_store_sells(self, make_auth_client, user, world):
        """Bought at any store; shown only where the variant is sold, active and visible."""
        deliver(user, world.canola_1l, world.olive_1l, store=world.other_store)
        client = make_auth_client(user)
        assert names(home(client, world)["buy_again"]) == [
            "Jivo Pomace Olive Oil",
            "Jivo Cold Pressed Canola Oil",
        ]
        # The other store sells only the olive oil.
        assert names(home(client, world, world.other_store)["buy_again"]) == [
            "Jivo Pomace Olive Oil"
        ]

    def test_inactive_and_unsold_are_dropped(self, make_auth_client, user, world):
        retired = VariantFactory(product=world.olive, sku="JV-OLV-OLD", is_active=False)
        stock(world.store, retired, 5)
        hidden_product = ProductFactory(name="Jivo Gone", category=world.oils, is_active=False)
        hidden = VariantFactory(product=hidden_product, sku="JV-GONE")
        stock(world.store, hidden, 5)
        unsold = VariantFactory(product=ProductFactory(name="Jivo Elsewhere", category=world.oils))
        deliver(user, retired, hidden, unsold)
        assert home(make_auth_client(user), world)["buy_again"] == []

    def test_out_of_stock_last(self, make_auth_client, user, world):
        deliver(user, world.olive_1l, days_ago=3)
        deliver(user, world.mustard_1l, days_ago=1)  # newer, but out of stock here
        rail = home(make_auth_client(user), world)["buy_again"]
        assert names(rail) == ["Jivo Pomace Olive Oil", "Jivo Mustard Oil"]
        assert rail[1]["variants"][0]["stock_status"] == "OUT_OF_STOCK"

    def test_at_most_ten(self, make_auth_client, user, world):
        variants = []
        for n in range(12):
            product = ProductFactory(name=f"Jivo Item {n:02d}", category=world.oils)
            variant = VariantFactory(product=product, sku=f"JV-ITEM-{n:02d}")
            stock(world.store, variant, 5)
            variants.append(variant)
        for n, variant in enumerate(variants):
            deliver(user, variant, days_ago=20 - n)  # Item 11 is the most recent
        rail = home(make_auth_client(user), world)["buy_again"]
        assert len(rail) == services.RAIL_SIZE == 10
        assert names(rail)[0] == "Jivo Item 11"
        assert names(rail)[-1] == "Jivo Item 02"

    def test_anonymous_is_empty(self, api_client, user, world):
        deliver(user, world.olive_1l)
        assert home(api_client, world)["buy_again"] == []
        assert services.buy_again(world.store, None) == []

    def test_only_the_requesters_orders(self, make_auth_client, user, world):
        """IDOR: another customer's history never shows up, and the shared cache holds no
        personal rail (the anonymous and other-user bodies stay empty after a warm cache)."""
        deliver(user, world.olive_1l)
        other = UserFactory()
        deliver(other, world.juice_500)
        assert names(home(make_auth_client(user), world)["buy_again"]) == ["Jivo Pomace Olive Oil"]
        assert names(home(make_auth_client(other), world)["buy_again"]) == ["Jivo Wheatgrass Juice"]
        assert home(make_auth_client(UserFactory()), world)["buy_again"] == []

    def test_constant_number_of_queries(self, user, world):
        """No N+1: the history query, then the cards (products + prefetches)."""
        deliver(user, world.olive_1l, world.canola_1l, days_ago=4)
        with CaptureQueriesContext(connection) as small:
            assert len(services.buy_again(world.store, user)) == 2
        for n in range(6):
            product = ProductFactory(name=f"Jivo More {n}", category=world.oils)
            variant = VariantFactory(
                product=product, sku=f"JV-MORE-{n}", selling_price=Decimal("10.00")
            )
            stock(world.store, variant, 5)
            deliver(user, variant, days_ago=1)
        with CaptureQueriesContext(connection) as large:
            assert len(services.buy_again(world.store, user)) == 8
        assert len(large) == len(small) <= 6
        # A long history (more lines than BUY_AGAIN_CANDIDATES) costs the same queries.
        many = []
        for n in range(services.BUY_AGAIN_CANDIDATES + 5):
            product = ProductFactory(name=f"Jivo Bulk {n:02d}", category=world.oils)
            variant = VariantFactory(product=product, sku=f"JV-BULK-{n:02d}")
            stock(world.store, variant, 5)
            many.append(variant)
        deliver(user, *many, days_ago=0)
        with CaptureQueriesContext(connection) as long_history:
            rail = services.buy_again(world.store, user)
        assert len(rail) == services.RAIL_SIZE
        assert len(long_history) == len(small)
        history_sql = long_history.captured_queries[0]["sql"]
        assert f"LIMIT {services.BUY_AGAIN_CANDIDATES}" in history_sql  # bounded read
        newcomer = UserFactory()
        with CaptureQueriesContext(connection) as none:
            assert services.buy_again(world.store, newcomer) == []
        assert len(none) == 1  # no history: no card queries
