"""P2 code review fixes in inventory: direct-write guards (#4), quantity bounds and SKU-first CSV
matching (#5), price override vs MRP (#3), narrower catalog cache invalidation (#6), and a
concurrent stock adjustment (missing test)."""

import threading
from decimal import Decimal

import pytest
from django.core.cache import cache
from django.core.exceptions import ValidationError
from django.db import connection
from django.db.models import Sum

from apps.catalog.cache import STORE_VERSION_KEY
from apps.catalog.tests.factories import VariantFactory
from apps.inventory import services
from apps.inventory.models import MovementType, StockMovement, StoreInventory, stock_write
from apps.inventory.services import MAX_QUANTITY, InwardRow
from apps.inventory.tests.factories import stock
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

INWARD, DAMAGE = MovementType.INWARD, MovementType.DAMAGE


@pytest.fixture
def store():
    return DarkStoreFactory()


@pytest.fixture
def variant():
    return VariantFactory(max_qty_per_order=5)


def _adjust(store, variant, delta, movement_type=INWARD):
    return services.adjust_stock(
        store=store, variant=variant, delta=delta, movement_type=movement_type, reason="test"
    )


# --------------------------------------------------------------------------- #4 guards


class TestDirectWriteGuards:
    def test_save_refuses_stock_changes_outside_the_services(self, store, variant):
        inventory = stock(store, variant, 5)
        inventory.on_hand = 50
        with pytest.raises(ValidationError, match=r"only through apps\.inventory\.services"):
            inventory.save()
        inventory.refresh_from_db()
        inventory.reserved = 1
        with pytest.raises(ValidationError):
            inventory.save(update_fields=["reserved"])

    def test_other_fields_save_normally(self, store, variant):
        inventory = stock(store, variant, 5)
        inventory.rack_location = "A-1"
        inventory.save()
        inventory.on_hand = 99  # not written: not in update_fields
        inventory.save(update_fields=["rack_location", "updated_at"])
        inventory.refresh_from_db()
        assert (inventory.on_hand, inventory.rack_location) == (5, "A-1")

    def test_new_rows_must_start_at_zero(self, store, variant):
        with pytest.raises(ValidationError):
            StoreInventory.objects.create(store=store, variant=variant, on_hand=10)

    def test_queryset_update_of_stock_is_refused(self, store, variant):
        stock(store, variant, 5)
        rows = StoreInventory.objects.filter(store=store)
        with pytest.raises(ValidationError):
            rows.update(on_hand=0)
        assert rows.update(rack_location="B-2") == 1
        with stock_write():
            assert rows.update(reserved=1) == 1

    def test_movements_cannot_be_bulk_updated_or_deleted(self, store, variant):
        stock(store, variant, 5)
        movements = StockMovement.objects.filter(store=store)
        with pytest.raises(ValidationError):
            movements.update(reason="edited")
        with pytest.raises(ValidationError):
            movements.delete()
        assert movements.count() == 1

    def test_deleting_the_actor_still_works(self, store, variant):
        from apps.accounts.tests.factories import StaffUserFactory

        actor = StaffUserFactory()
        services.adjust_stock(
            store=store, variant=variant, delta=3, movement_type=INWARD, reason="x", actor=actor
        )
        actor.delete()  # SET_NULL on created_by goes through a direct SQL update
        assert StockMovement.objects.get(store=store).created_by is None


# --------------------------------------------------------------------------- #5 bounds, SKU first


class TestBounds:
    def test_adjustment_is_bounded(self, store, variant):
        with pytest.raises(ValidationError, match="At most"):
            _adjust(store, variant, MAX_QUANTITY + 1)
        with pytest.raises(ValidationError, match="At most"):
            _adjust(store, variant, 10_000_000_000)  # would be a DataError (500) unbounded
        with pytest.raises(ValidationError, match="whole number"):
            _adjust(store, variant, True)
        assert _adjust(store, variant, MAX_QUANTITY).on_hand_after == MAX_QUANTITY

    def test_on_hand_has_a_ceiling(self, store, variant, monkeypatch):
        monkeypatch.setattr(services, "MAX_ON_HAND", 10)
        _adjust(store, variant, 10)
        with pytest.raises(ValidationError, match="cannot exceed"):
            _adjust(store, variant, 1)

    def test_counted_stock_is_bounded(self, store, variant):
        with pytest.raises(ValidationError, match="At most"):
            services.set_counted_stock(
                store=store, variant=variant, counted=MAX_QUANTITY + 1, reason="count"
            )
        with pytest.raises(ValidationError, match="whole number"):
            services.set_counted_stock(store=store, variant=variant, counted=2.5, reason="count")

    def test_csv_line_is_bounded(self, store, variant):
        with pytest.raises(ValidationError) as caught:
            services.apply_inward_batch(
                store=store, rows=[InwardRow(variant.sku, MAX_QUANTITY + 1)], reason="grn"
            )
        assert "line 1" in caught.value.message_dict["rows"][0]

    def test_csv_matches_sku_before_sap_code(self, store):
        """A SAP item code equal to another variant's SKU never takes that SKU's stock."""
        by_sku = VariantFactory(sku="JV-100", sap_item_code="SAP-1")
        by_sap = VariantFactory(sku="JV-200", sap_item_code="JV-100")
        services.apply_inward_batch(store=store, rows=[InwardRow("JV-100", 4)], reason="grn")
        assert StoreInventory.objects.get(store=store, variant=by_sku).on_hand == 4
        assert not StoreInventory.objects.filter(store=store, variant=by_sap).exists()
        services.apply_inward_batch(store=store, rows=[InwardRow("SAP-1", 1)], reason="grn")
        assert StoreInventory.objects.get(store=store, variant=by_sku).on_hand == 5


# --------------------------------------------------------------------------- #3 override vs MRP


class TestPriceOverrideAndMrp:
    def test_mrp_cut_below_an_override_is_refused(self, store):
        variant = VariantFactory(mrp=Decimal("349.00"), selling_price=Decimal("279.00"))
        services.set_price_override(stock(store, variant, 1), Decimal("300.00"))
        variant.mrp = Decimal("290.00")
        with pytest.raises(ValidationError) as caught:
            variant.full_clean()
        assert store.code in caught.value.message_dict["mrp"][0]
        variant.mrp = Decimal("300.00")  # equal to the override is fine
        variant.full_clean()

    def test_inventory_clean_checks_the_override(self, store, variant):
        inventory = stock(store, variant, 1)
        inventory.price_override = variant.mrp + 1
        with pytest.raises(ValidationError, match="above the MRP"):
            inventory.full_clean()
        inventory.price_override = Decimal("0.00")
        with pytest.raises(ValidationError, match="above 0"):
            inventory.full_clean()

    def test_override_left_above_mrp_is_ignored_in_python_and_sql(self, store):
        """The Python and SQL effective-price rules agree (compute_bill uses the former)."""
        from apps.catalog.services import sold_variants

        variant = VariantFactory(mrp=Decimal("349.00"), selling_price=Decimal("279.00"))
        inventory = services.set_price_override(stock(store, variant, 3), Decimal("300.00"))
        # A later MRP cut that bypassed the form validation (e.g. a bulk import).
        type(variant).objects.filter(pk=variant.pk).update(mrp=Decimal("289.00"))
        variant.refresh_from_db()
        inventory.refresh_from_db()
        sql_price = sold_variants(store).get(pk=variant.pk).inv_price
        assert services.effective_price(inventory, variant) == sql_price == Decimal("279.00")
        # And a valid override applies in both.
        type(variant).objects.filter(pk=variant.pk).update(mrp=Decimal("349.00"))
        variant.refresh_from_db()
        sql_price = sold_variants(store).get(pk=variant.pk).inv_price
        assert services.effective_price(inventory, variant) == sql_price == Decimal("300.00")

    @pytest.mark.parametrize(
        ("override", "mrp", "applies"),
        [
            (None, "100.00", False),
            ("0.00", "100.00", False),
            ("100.00", "100.00", True),
            ("100.01", "100.00", False),
            ("1.00", "100.00", True),
        ],
    )
    def test_override_applies(self, override, mrp, applies):
        value = Decimal(override) if override else None
        assert services.override_applies(value, Decimal(mrp)) is applies


# --------------------------------------------------------------------------- #6 cache


class TestCatalogCacheInvalidation:
    """Review #6: a stock row save bumps the store's catalog version only when the published
    availability (status, orderable quantity, units left), the switch or the price changes."""

    @pytest.fixture
    def version(self, store, django_capture_on_commit_callbacks):
        key = STORE_VERSION_KEY.format(store_id=store.pk)

        def run(action) -> bool:
            cache.set(key, 1, timeout=None)
            with django_capture_on_commit_callbacks(execute=True):
                action()
            return cache.get(key) > 1

        return run

    def test_change_above_the_per_order_cap_is_not_published(self, store, variant, version):
        stock(store, variant, 40)
        assert version(lambda: _adjust(store, variant, -1, DAMAGE)) is False  # 39: still 5

    def test_changes_that_are_published(self, store, variant, version, settings):
        settings.CATALOG_LOW_STOCK_UNITS = 3
        stock(store, variant, 6)
        assert version(lambda: _adjust(store, variant, -2, DAMAGE)) is True  # orderable 5 -> 4
        assert version(lambda: _adjust(store, variant, -1, DAMAGE)) is True  # LOW: 3 left
        assert version(lambda: _adjust(store, variant, -3, DAMAGE)) is True  # OUT
        inventory = StoreInventory.objects.get(store=store, variant=variant)
        assert version(lambda: services.set_availability(inventory, is_available=False)) is True
        assert version(lambda: services.set_price_override(inventory, Decimal("200.00"))) is True

    def test_non_catalog_fields_are_not_published(self, store, variant, version):
        inventory = stock(store, variant, 10)
        assert (
            version(lambda: services.update_inventory_settings(inventory, rack_location="C-3"))
            is False
        )

    def test_new_rows_are_published(self, store, variant, version):
        assert version(lambda: services.ensure_inventory(store, variant)) is True


# --------------------------------------------------------------------------- concurrency


@pytest.mark.django_db(transaction=True)
def test_concurrent_adjustments_never_lose_an_update():
    """Two connections adjust one row at the same time: the row lock serialises them, so both
    movements land and the ledger still sums to on_hand."""
    store, variant = DarkStoreFactory(), VariantFactory()
    stock(store, variant, 10)
    barrier = threading.Barrier(8)
    errors: list[Exception] = []

    def adjust():
        try:
            barrier.wait()
            _adjust(store, variant, 3)
        except Exception as exc:
            errors.append(exc)
        finally:
            connection.close()

    threads = [threading.Thread(target=adjust) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=30)
    assert errors == []
    inventory = StoreInventory.objects.get(store=store, variant=variant)
    total = StockMovement.objects.filter(store=store, variant=variant).aggregate(s=Sum("delta"))
    assert inventory.on_hand == 10 + 8 * 3 == total["s"]
