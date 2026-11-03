"""Inventory services (07 §2.4, 08 §6.1): every on_hand change is locked, ledgered and
validated; availability as published by the catalog (DL-26); store-scoped adjust permission."""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.db.models import Sum

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.catalog.cache import STORE_VERSION_KEY
from apps.catalog.choices import StockStatus
from apps.catalog.tests.factories import VariantFactory
from apps.inventory import services
from apps.inventory.models import MovementType, StockMovement, StoreInventory, stock_write
from apps.inventory.services import InwardRow
from apps.inventory.tasks import low_stock_alert
from apps.inventory.tests.factories import stock
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

INWARD, DAMAGE, AUDIT = MovementType.INWARD, MovementType.DAMAGE, MovementType.AUDIT_ADJUSTMENT


@pytest.fixture
def store():
    return DarkStoreFactory()


@pytest.fixture
def variant():
    return VariantFactory()


def ledger_matches(store, variant) -> bool:
    inventory = StoreInventory.objects.get(store=store, variant=variant)
    total = StockMovement.objects.filter(store=store, variant=variant).aggregate(s=Sum("delta"))
    return (total["s"] or 0) == inventory.on_hand


class TestEnsureInventory:
    def test_creates_at_zero_once(self, store, variant):
        first = services.ensure_inventory(store, variant)
        second = services.ensure_inventory(store, variant)
        assert first.pk == second.pk
        assert (first.on_hand, first.reserved) == (0, 0)
        assert not StockMovement.objects.exists()


class TestAdjustStock:
    def test_inward_writes_a_movement(self, store, variant):
        actor = StaffUserFactory()
        movement = services.adjust_stock(
            store=store,
            variant=variant,
            delta=12,
            movement_type=INWARD,
            reason=" GRN 4411 ",
            actor=actor,
        )
        assert (movement.delta, movement.on_hand_after, movement.type) == (12, 12, INWARD)
        assert movement.reason == "GRN 4411"
        assert movement.created_by == actor
        assert StoreInventory.objects.get(store=store, variant=variant).on_hand == 12

    def test_anonymous_actor_is_not_recorded(self, store, variant):
        from django.contrib.auth.models import AnonymousUser

        movement = services.adjust_stock(
            store=store,
            variant=variant,
            delta=3,
            movement_type=INWARD,
            reason="x",
            actor=AnonymousUser(),
        )
        assert movement.created_by is None

    def test_damage_and_audit(self, store, variant):
        stock(store, variant, 10)
        services.adjust_stock(
            store=store, variant=variant, delta=-2, movement_type=DAMAGE, reason="broken"
        )
        services.adjust_stock(
            store=store, variant=variant, delta=-1, movement_type=AUDIT, reason="recount"
        )
        services.adjust_stock(
            store=store, variant=variant, delta=4, movement_type=AUDIT, reason="found"
        )
        assert StoreInventory.objects.get(store=store, variant=variant).on_hand == 11
        assert ledger_matches(store, variant)

    @pytest.mark.parametrize(
        ("delta", "movement_type", "reason", "field"),
        [
            (0, INWARD, "x", "delta"),
            (-1, INWARD, "x", "delta"),
            (2, DAMAGE, "x", "delta"),
            (2, INWARD, "   ", "reason"),
            (2, INWARD, "r" * 256, "reason"),
            (2, MovementType.SALE, "x", "type"),
            (2, "BOGUS", "x", "type"),
        ],
    )
    def test_rejects_invalid_adjustments(self, store, variant, delta, movement_type, reason, field):
        with pytest.raises(ValidationError) as exc:
            services.adjust_stock(
                store=store,
                variant=variant,
                delta=delta,
                movement_type=movement_type,
                reason=reason,
            )
        assert field in exc.value.message_dict
        assert not StockMovement.objects.exists()

    def test_cannot_go_below_reserved(self, store, variant):
        """08 §6.1: reserved stock belongs to placed orders."""
        stock(store, variant, 5, reserved=3)
        with pytest.raises(ValidationError) as exc:
            services.adjust_stock(
                store=store, variant=variant, delta=-3, movement_type=DAMAGE, reason="x"
            )
        assert "2 units are free (3 are held" in exc.value.message_dict["delta"][0]
        assert StoreInventory.objects.get(store=store, variant=variant).on_hand == 5

    def test_cannot_go_negative(self, store, variant):
        stock(store, variant, 1)
        with pytest.raises(ValidationError):
            services.adjust_stock(
                store=store, variant=variant, delta=-2, movement_type=AUDIT, reason="x"
            )

    def test_low_stock_alert_is_queued_after_commit(
        self, store, variant, django_capture_on_commit_callbacks
    ):
        from unittest import mock

        services.ensure_inventory(store, variant)
        with (
            mock.patch("apps.inventory.tasks.low_stock_alert.delay") as delay,
            django_capture_on_commit_callbacks(execute=True),
        ):
            services.adjust_stock(
                store=store, variant=variant, delta=2, movement_type=INWARD, reason="x"
            )
            delay.assert_not_called()  # not before commit
        delay.assert_called_once_with(store.pk, variant.pk)  # 2 available < threshold 5

    def test_store_cache_version_is_bumped_after_commit(
        self, store, variant, django_capture_on_commit_callbacks
    ):
        from django.core.cache import cache

        key = STORE_VERSION_KEY.format(store_id=store.pk)
        cache.set(key, 7, timeout=None)
        with django_capture_on_commit_callbacks(execute=True):
            services.adjust_stock(
                store=store, variant=variant, delta=20, movement_type=INWARD, reason="x"
            )
        assert cache.get(key) >= 8


class TestCountedStock:
    def test_sets_the_count(self, store, variant):
        stock(store, variant, 10)
        movement = services.set_counted_stock(
            store=store, variant=variant, counted=7, reason="cycle count"
        )
        assert (movement.delta, movement.type, movement.on_hand_after) == (-3, AUDIT, 7)
        assert ledger_matches(store, variant)

    def test_unchanged_count_writes_nothing(self, store, variant):
        stock(store, variant, 4)
        assert (
            services.set_counted_stock(store=store, variant=variant, counted=4, reason="x") is None
        )
        assert StockMovement.objects.count() == 1

    @pytest.mark.parametrize(
        ("counted", "reason", "field"), [(-1, "x", "counted"), (3, "", "reason")]
    )
    def test_invalid(self, store, variant, counted, reason, field):
        with pytest.raises(ValidationError) as exc:
            services.set_counted_stock(store=store, variant=variant, counted=counted, reason=reason)
        assert field in exc.value.message_dict


class TestInwardBatch:
    def test_applies_all_rows_by_sku_or_sap_code(self, store):
        oil = VariantFactory(sku="JV-CAN-1L")
        juice = VariantFactory(sku="JV-WG-500", sap_item_code="SAP-1002")
        movements = services.apply_inward_batch(
            store=store,
            rows=[InwardRow("SAP-1002", 6), InwardRow(" JV-CAN-1L ", 24)],
            reason="GRN 77",
        )
        assert [m.variant_id for m in movements] == sorted([oil.pk, juice.pk])
        assert StoreInventory.objects.get(store=store, variant=oil).on_hand == 24
        assert StoreInventory.objects.get(store=store, variant=juice).on_hand == 6

    def test_all_or_nothing_with_line_errors(self, store):
        VariantFactory(sku="JV-OK")
        with pytest.raises(ValidationError) as exc:
            services.apply_inward_batch(
                store=store,
                rows=[InwardRow("JV-OK", 5), InwardRow("NOPE", 1), InwardRow("JV-OK", 0)],
                reason="GRN",
            )
        assert exc.value.message_dict["rows"] == [
            "line 2: unknown SKU 'NOPE'.",
            "line 3: the quantity must be a whole number above 0.",
        ]
        assert not StockMovement.objects.exists()

    @pytest.mark.parametrize(
        ("rows", "reason", "field"), [([], "x", "rows"), (None, " ", "reason")]
    )
    def test_empty_or_no_reason(self, store, rows, reason, field):
        rows = [InwardRow("X", 1)] if rows is None else rows
        with pytest.raises(ValidationError) as exc:
            services.apply_inward_batch(store=store, rows=rows, reason=reason)
        assert field in exc.value.message_dict


class TestSettingsAvailabilityPrice:
    def test_settings(self, store, variant):
        inventory = stock(store, variant, 3)
        services.update_inventory_settings(
            inventory, low_stock_threshold=2, rack_location="  A-12-03 "
        )
        inventory.refresh_from_db()
        assert (inventory.low_stock_threshold, inventory.rack_location) == (2, "A-12-03")
        assert services.update_inventory_settings(inventory) is inventory  # no-op
        with pytest.raises(ValidationError):
            services.update_inventory_settings(inventory, low_stock_threshold=-1)

    def test_availability_switch(self, store, variant):
        inventory = stock(store, variant, 3)
        services.set_availability(inventory, is_available=False)
        inventory.refresh_from_db()
        assert inventory.is_available is False
        services.set_availability(inventory, is_available=False)  # unchanged: no save
        assert not StockMovement.objects.filter(delta__lt=0).exists()

    def test_price_override(self, store, variant):
        inventory = stock(store, variant, 3)
        services.set_price_override(inventory, Decimal("249.5"))
        inventory.refresh_from_db()
        assert inventory.price_override == Decimal("249.50")
        assert services.effective_price(inventory, variant) == Decimal("249.50")
        services.set_price_override(inventory, None)
        assert services.effective_price(inventory, variant) == variant.selling_price
        assert services.effective_price(None, variant) == variant.selling_price

    @pytest.mark.parametrize("price", [Decimal("0"), Decimal("-5"), Decimal("349.01")])
    def test_price_override_must_be_within_mrp(self, store, variant, price):
        """Above the MRP would publish a negative discount."""
        inventory = stock(store, variant, 3)
        with pytest.raises(ValidationError):
            services.set_price_override(inventory, price)


class TestAvailability:
    """DL-26: orderable = min(available, max per order); LOW_STOCK when 1..3 left."""

    @pytest.mark.parametrize(
        ("on_hand", "reserved", "is_available", "expected"),
        [
            (0, 0, True, (StockStatus.OUT_OF_STOCK, 0, None)),
            (4, 4, True, (StockStatus.OUT_OF_STOCK, 0, None)),
            (50, 0, False, (StockStatus.OUT_OF_STOCK, 0, None)),
            (3, 0, True, (StockStatus.LOW_STOCK, 3, 3)),
            (5, 3, True, (StockStatus.LOW_STOCK, 2, 2)),
            (4, 0, True, (StockStatus.IN_STOCK, 4, None)),
            (50, 0, True, (StockStatus.IN_STOCK, 5, None)),
        ],
    )
    def test_rules(self, on_hand, reserved, is_available, expected):
        result = services.availability(
            on_hand=on_hand, reserved=reserved, is_available=is_available, max_qty_per_order=5
        )
        assert (result.stock_status, result.orderable_quantity, result.units_left) == expected

    def test_low_stock_capped_by_max_per_order(self):
        result = services.availability(
            on_hand=2, reserved=0, is_available=True, max_qty_per_order=1
        )
        assert (result.orderable_quantity, result.units_left) == (1, 2)

    def test_not_sellable(self):
        result = services.availability(
            on_hand=9, reserved=0, is_available=True, max_qty_per_order=5, sellable=False
        )
        assert result.stock_status == StockStatus.OUT_OF_STOCK


class TestCanAdjust:
    def test_superuser(self, store):
        assert services.can_adjust_stock(SuperUserFactory(), store)

    def test_store_manager_only_for_own_store(self, store):
        roles.sync_roles()
        manager = StaffUserFactory()
        manager.groups.add(Group.objects.get(name=roles.STORE_MANAGER))
        other = DarkStoreFactory()
        grant_store_access(manager, store)
        assert services.can_adjust_stock(manager, store)
        assert not services.can_adjust_stock(manager, other)

    def test_roles_without_the_permission(self, store):
        roles.sync_roles()
        staff = StaffUserFactory()
        staff.groups.add(Group.objects.get(name=roles.STORE_STAFF))
        grant_store_access(staff, store)
        assert not services.can_adjust_stock(staff, store)
        assert not services.can_adjust_stock(None, store)


class TestLowStockTask:
    def test_alerts_and_skips(self, store, variant):
        inventory = stock(store, variant, 2)
        assert low_stock_alert(store.pk, variant.pk) == "alerted"
        inventory.on_hand = 40
        with stock_write():
            inventory.save()
        assert low_stock_alert(store.pk, variant.pk) == "skipped"
        assert low_stock_alert(store.pk, 999_999) == "skipped"


class TestDatabaseGuarantees:
    def test_check_constraints(self, store, variant):
        inventory = stock(store, variant, 2)
        for field, value in [("reserved", 3), ("on_hand", -1), ("reserved", -1)]:
            setattr(inventory, field, value)
            with pytest.raises(IntegrityError), transaction.atomic(), stock_write():
                inventory.save()
            inventory.refresh_from_db()

    def test_one_row_per_store_and_variant(self, store, variant):
        stock(store, variant, 1)
        with pytest.raises(IntegrityError), transaction.atomic():
            StoreInventory.objects.create(store=store, variant=variant)

    def test_movements_are_append_only(self, store, variant):
        stock(store, variant, 2)
        movement = StockMovement.objects.get()
        movement.reason = "edited"
        with pytest.raises(ValidationError):
            movement.save()
        with pytest.raises(ValidationError):
            movement.delete()
        assert "+2" in str(movement)
        assert StoreInventory.objects.get().available == 2
        assert "on hand" in str(StoreInventory.objects.get())

    def test_ledger_always_sums_to_on_hand(self, store):
        oil, juice = VariantFactory(), VariantFactory()
        stock(store, oil, 30)
        stock(store, juice, 8)
        services.adjust_stock(store=store, variant=oil, delta=-4, movement_type=DAMAGE, reason="x")
        services.set_counted_stock(store=store, variant=juice, counted=11, reason="count")
        services.apply_inward_batch(
            store=store, rows=[InwardRow(oil.sku, 5), InwardRow(juice.sku, 1)], reason="GRN"
        )
        assert ledger_matches(store, oil)
        assert ledger_matches(store, juice)
