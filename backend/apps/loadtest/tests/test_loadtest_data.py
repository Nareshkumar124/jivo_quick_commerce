"""T-812 (Phase 8): the load-test data commands. Staging only, tagged by the +9190000002xx
phone range, and every stock or order change goes through the owning services."""

import importlib
import sys
import uuid
from io import StringIO

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from django.core.management import CommandError, call_command

from apps.accounts.models import Address, OTPRequest, User
from apps.accounts.services.auth import issue_tokens
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.cart.tests.conftest import INSIDE, make_address, shop  # noqa: F401 - shared fixture
from apps.inventory.models import MovementType, StockMovement, StoreInventory
from apps.loadtest import services
from apps.orders.models import Order
from apps.payments.models import Payment

CART = "/api/v1/cart/"
ORDERS = "/api/v1/orders/"


@pytest.fixture
def allowed(settings):
    settings.LOADTEST_DATA_ALLOWED = True
    settings.OTP_TEST_NUMBERS = {"+919000000001": "123456"}
    return settings


def run(command: str, *args) -> str:
    out = StringIO()
    call_command(command, *args, stdout=out)
    return out.getvalue()


def place(client, shop, user, *, method="COD", variant=None, quantity=2):  # noqa: F811
    """Place an order through the real API as `user` (the load-test client's path)."""
    headers = shop.headers()
    address = Address.objects.filter(user=user, is_deleted=False).first() or make_address(user)
    response = client.post(
        f"{CART}items/",
        {"variant_id": (variant or shop.canola_1l).pk, "quantity": quantity},
        headers=headers,
    )
    assert response.status_code == 200, response.content
    client.patch(CART, {"address_id": address.pk}, headers=headers)
    total = client.get(CART, headers=headers).json()["bill"]["grand_total"]
    response = client.post(
        ORDERS,
        {"address_id": address.pk, "payment_method": method, "expected_grand_total": total},
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
    )
    assert response.status_code == 201, response.content
    return Order.objects.get(pk=response.json()["order"]["id"])


def client_for(user):
    from rest_framework.test import APIClient

    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user, 'customer')[0]}")
    return client


# --------------------------------------------------------------------------- guard


class TestGuard:
    @pytest.mark.parametrize("command", ["loadtest_seed", "loadtest_cleanup"])
    def test_refused_unless_allowed(self, db, settings, command):
        settings.LOADTEST_DATA_ALLOWED = False
        args = ["--store", "X"] if command == "loadtest_seed" else []
        with pytest.raises(CommandError, match="LOADTEST_DATA_ALLOWED"):
            run(command, *args)

    @pytest.mark.parametrize("command", ["loadtest_seed", "loadtest_cleanup"])
    def test_refused_in_production_even_when_allowed(self, db, settings, command):
        settings.LOADTEST_DATA_ALLOWED = True
        settings.APP_ENVIRONMENT = "production"
        args = ["--store", "X"] if command == "loadtest_seed" else ["--yes"]
        with pytest.raises(CommandError, match="never allowed in production"):
            run(command, *args)

    def test_system_check_refuses_the_flag_in_production(self, settings):
        settings.LOADTEST_DATA_ALLOWED = True
        settings.APP_ENVIRONMENT = "production"
        assert "loadtest.E001" in {e.id for e in run_checks()}

    @pytest.mark.parametrize("environment", ["staging", "local", "test"])
    def test_system_check_allows_the_flag_elsewhere(self, settings, environment):
        settings.LOADTEST_DATA_ALLOWED = True
        settings.APP_ENVIRONMENT = environment
        assert "loadtest.E001" not in {e.id for e in run_checks()}

    def test_production_settings_refuse_the_flag_at_startup(self, monkeypatch):
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
        monkeypatch.setenv("NUM_PROXIES", "1")
        monkeypatch.setenv("LOADTEST_DATA_ALLOWED", "true")
        for name in ("OTP_TEST_NUMBERS", "SENTRY_DSN"):
            monkeypatch.delenv(name, raising=False)
        modules = ("config.settings.production", "config.settings.deployed")
        try:
            for module in modules:
                sys.modules.pop(module, None)
            with pytest.raises(ImproperlyConfigured, match="LOADTEST_DATA_ALLOWED"):
                importlib.import_module("config.settings.production")
            monkeypatch.delenv("LOADTEST_DATA_ALLOWED")
            for module in modules:
                sys.modules.pop(module, None)
            assert importlib.import_module("config.settings.production").LOADTEST_DATA_ALLOWED is (
                False
            )
        finally:
            for module in modules:
                sys.modules.pop(module, None)

    def test_default_is_off(self):
        from config.settings import base

        assert base.LOADTEST_DATA_ALLOWED is False


# --------------------------------------------------------------------------- seed


class TestSeed:
    def test_phone_range_is_dedicated(self):
        assert services.PHONES[0] == "+919000000200"
        assert services.PHONES[-1] == "+919000000299"
        assert len(set(services.PHONES)) == 100
        assert all(p.startswith("+9190000002") for p in services.PHONES)

    def test_creates_customers_addresses_and_stock_idempotently(self, allowed, shop):  # noqa: F811
        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "3",
            "--lat",
            str(INSIDE[0]),
            "--lng",
            str(INSIDE[1]),
            "--stock-floor",
            "100",
        )
        users = list(services.loadtest_users().order_by("phone"))
        assert [u.phone for u in users] == list(services.PHONES[:3])
        assert all(u.name.startswith("Loadtest") and not u.has_usable_password() for u in users)
        for user in users:
            address = Address.objects.get(user=user, is_deleted=False)
            assert address.is_default
            assert address.custom_label == "loadtest"
        canola = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_1l)
        assert canola.available == 100
        topups = StockMovement.objects.filter(reason=services.REASON_TOPUP)
        assert topups.count() == 4  # every sellable row of the store
        assert all(m.type == MovementType.INWARD for m in topups)
        assert "3 created" in out
        assert "3 load-test numbers are not in OTP_TEST_NUMBERS" in out

        # Idempotent: nothing more is created or added.
        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "3",
            "--stock-floor",
            "100",
        )
        assert services.loadtest_users().count() == 3
        assert Address.objects.filter(user__in=users).count() == 3
        assert topups.count() == 4
        assert "0 created, 3 existing" in out

    def test_print_otp_env_keeps_configured_numbers(self, allowed, shop):  # noqa: F811
        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "2",
            "--stock-floor",
            "0",
            "--print-otp-env",
        )
        line = next(x for x in out.splitlines() if x.startswith("OTP_TEST_NUMBERS="))
        assert line == (
            "OTP_TEST_NUMBERS=+919000000001:123456,+919000000200:123456,+919000000201:123456"
        )

    def test_no_otp_warning_when_configured(self, allowed, shop):  # noqa: F811
        allowed.OTP_TEST_NUMBERS = dict.fromkeys(services.PHONES, "123456")
        out = run(
            "loadtest_seed", "--store", shop.store_model.code, "--users", "1", "--stock-floor", "0"
        )
        assert "not in OTP_TEST_NUMBERS" not in out

    def test_warns_when_point_outside_store(self, allowed, shop):  # noqa: F811
        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "1",
            "--lat",
            "28.70",
            "--lng",
            "77.40",
            "--stock-floor",
            "0",
        )
        assert "outside this store's service area" in out

    def test_bad_arguments(self, allowed, shop):  # noqa: F811
        code = shop.store_model.code
        with pytest.raises(CommandError, match="No store"):
            run("loadtest_seed", "--store", "NOPE")
        with pytest.raises(CommandError, match="Between 1 and 100"):
            run("loadtest_seed", "--store", code, "--users", "101")
        with pytest.raises(CommandError, match="both --lat and --lng"):
            run("loadtest_seed", "--store", code, "--lat", "28.4")
        with pytest.raises(CommandError, match="stock_floor"):
            run("loadtest_seed", "--store", code, "--stock-floor", "-1")
        with pytest.raises(CommandError, match="Not a coordinate"):
            run("loadtest_seed", "--store", code, "--lat", "north", "--lng", "1")

    def test_never_touches_a_staff_user_in_the_range(self, allowed, shop):  # noqa: F811
        StaffUserFactory(phone=services.PHONES[0])
        with pytest.raises(CommandError, match="staff user"):
            run("loadtest_seed", "--store", shop.store_model.code, "--users", "1")


# --------------------------------------------------------------------------- cleanup


class TestCleanup:
    @pytest.fixture
    def seeded(self, allowed, shop):  # noqa: F811
        before = {
            row.variant_id: row.on_hand
            for row in StoreInventory.objects.filter(store=shop.store_model)
        }
        run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "3",
            "--lat",
            str(INSIDE[0]),
            "--lng",
            str(INSIDE[1]),
            "--stock-floor",
            "200",
        )
        return before

    def test_dry_run_changes_nothing(self, seeded, shop):  # noqa: F811
        user = User.objects.get(phone=services.PHONES[0])
        order = place(client_for(user), shop, user)
        out = run("loadtest_cleanup")
        assert "DRY RUN" in out
        assert "1 would be cancelled, 1 would be deleted" in out
        assert "3 would be deleted" in out
        order.refresh_from_db()
        assert order.status == "PLACED"
        assert services.loadtest_users().count() == 3
        assert StockMovement.objects.filter(reason=services.REASON_REVERSAL).count() == 0

    def test_removes_orders_customers_otp_and_reverses_stock(self, seeded, shop):  # noqa: F811
        """COD PLACED (T11) and an ONLINE order still awaiting payment (T5) are cancelled through
        the order service, their reservations released, then deleted with their payments."""
        first, second = (User.objects.get(phone=p) for p in services.PHONES[:2])
        cod = place(client_for(first), shop, first)
        online = place(client_for(second), shop, second, method="ONLINE", variant=shop.chia)
        assert Payment.objects.filter(order=online).exists()
        OTPRequest.objects.create(
            phone=services.PHONES[0],
            app="customer",
            purpose="login",
            code_hash="x",
            expires_at=cod.created_at,
        )
        stranger = UserFactory()
        stranger_order = place(client_for(stranger), shop, stranger, variant=shop.flax)

        out = run("loadtest_cleanup", "--yes")

        assert "2 cancelled, 2 deleted, 0 kept" in out
        assert not Order.objects.filter(pk__in=[cod.pk, online.pk]).exists()
        assert not Payment.objects.filter(order_id=online.pk).exists()
        assert services.loadtest_users().count() == 0
        assert not OTPRequest.objects.filter(phone__in=services.PHONES).exists()
        # The other customer's order and its reservation are untouched.
        stranger_order.refresh_from_db()
        assert stranger_order.status == "PLACED"
        flax = StoreInventory.objects.get(store=shop.store_model, variant=shop.flax)
        assert flax.reserved == 2
        # Stock is back where it was before the seed, through ledger rows.
        for row in StoreInventory.objects.filter(store=shop.store_model):
            assert row.on_hand == seeded[row.variant_id]
        canola = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_1l)
        assert canola.reserved == 0
        reversals = StockMovement.objects.filter(reason=services.REASON_REVERSAL)
        assert reversals.count() == 4
        assert all(m.type == MovementType.AUDIT_ADJUSTMENT and m.delta < 0 for m in reversals)

        # Re-running finds nothing left to do.
        out = run("loadtest_cleanup", "--yes")
        assert "orders 0 found" in out
        assert "reversed on 0 rows" in out

    def test_keeps_orders_whose_stock_was_committed(self, seeded, shop):  # noqa: F811
        """A load-test order that left the store (SALE ledger rows) is never deleted, nor its
        customer: the ledger must keep summing to on_hand."""
        user = User.objects.get(phone=services.PHONES[0])
        order = place(client_for(user), shop, user)
        order.status = "CANCELLED"  # as if handled by staff; the ledger row is what matters
        order.save(update_fields=["status"])
        row = StoreInventory.objects.get(store=shop.store_model, variant=shop.flax)
        StockMovement.objects.create(  # ledgers are append-only: a SALE row naming the order
            store=shop.store_model,
            variant=shop.flax,
            delta=-1,
            type=MovementType.SALE,
            reason="test",
            on_hand_after=row.on_hand,
            order=order,
        )

        out = run("loadtest_cleanup", "--yes", "--keep-stock")

        assert f"kept order {order.order_number}: stock was committed" in out
        assert "has orders that were kept" in out
        assert Order.objects.filter(pk=order.pk).exists()
        assert User.objects.filter(pk=user.pk).exists()
        assert services.loadtest_users().count() == 1
        assert StockMovement.objects.filter(reason=services.REASON_REVERSAL).count() == 0

    def test_reversal_never_takes_reserved_units(self, seeded, shop):  # noqa: F811
        """Units held by someone else's order stay: the reversal is capped at free stock."""
        stranger = UserFactory()
        place(client_for(stranger), shop, stranger, variant=shop.canola_5l, quantity=1)
        row = StoreInventory.objects.get(store=shop.store_model, variant=shop.canola_5l)
        run("loadtest_cleanup", "--yes")
        row.refresh_from_db()
        assert row.reserved == 1
        assert row.on_hand >= row.reserved
