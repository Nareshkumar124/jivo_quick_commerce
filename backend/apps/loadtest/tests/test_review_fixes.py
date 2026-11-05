"""T-812 review of f8271e4: cleanup never touches accounts in the ranges that are not tagged
load-test accounts, the stock reversal survives a lost race, and load-test riders are seeded
(through the delivery services) and removed."""

import uuid
from io import StringIO

import pytest
from django.contrib.auth.models import Group
from django.core.management import CommandError, call_command
from django.db import IntegrityError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.choices import RiderStatus
from apps.accounts.models import Address, OTPRequest, User
from apps.accounts.services.auth import issue_tokens
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.cart.tests.conftest import INSIDE, make_address, shop  # noqa: F401 - shared fixture
from apps.core.models import AuditLog
from apps.delivery.choices import DocumentStatus
from apps.delivery.models import Rider, RiderDocument, RiderShift
from apps.delivery.services import shifts
from apps.delivery.tests.factories import RiderFactory
from apps.inventory.models import StockMovement
from apps.loadtest import services
from apps.orders.models import Order

CART = "/api/v1/cart/"
ORDERS = "/api/v1/orders/"


@pytest.fixture(autouse=True)
def _roles(db):
    roles.sync_roles()


@pytest.fixture
def allowed(settings):
    settings.LOADTEST_DATA_ALLOWED = True
    settings.OTP_TEST_NUMBERS = {}
    return settings


@pytest.fixture
def reviewer(db):
    user = StaffUserFactory(email="ops.loadtest@jivo.test")
    user.groups.add(Group.objects.get(name=roles.OPS))
    return user


def run(command: str, *args) -> str:
    out = StringIO()
    call_command(command, *args, stdout=out)
    return out.getvalue()


def place_cod(shop, user):  # noqa: F811
    from rest_framework.test import APIClient

    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user, 'customer')[0]}")
    headers = shop.headers()
    address = make_address(user)
    client.post(f"{CART}items/", {"variant_id": shop.canola_1l.pk, "quantity": 2}, headers=headers)
    client.patch(CART, {"address_id": address.pk}, headers=headers)
    total = client.get(CART, headers=headers).json()["bill"]["grand_total"]
    response = client.post(
        ORDERS,
        {"address_id": address.pk, "payment_method": "COD", "expected_grand_total": total},
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
    )
    assert response.status_code == 201, response.content
    return Order.objects.get(pk=response.json()["order"]["id"])


# --------------------------------------------------------------------------- account guards


class TestAccountGuards:
    def test_tag_name(self):
        assert services.tag_name("+919000000207") == "Loadtest 207"
        assert services.tag_name("+919000000399") == "Loadtest 399"

    def test_staff_superusers_riders_and_untagged_accounts_survive_cleanup(
        self,
        allowed,
        shop,  # noqa: F811
    ):
        """Major review finding: only tagged load-test accounts are removed. Staff, superusers,
        a customer-range account with a rider profile and an account not named `Loadtest NNN`
        are kept and reported, and so are their orders (not even cancelled)."""
        p = services.PHONES
        staff = StaffUserFactory(phone=p[5], name=services.tag_name(p[5]))
        admin = SuperUserFactory(phone=p[6], name=services.tag_name(p[6]))
        rider_user = UserFactory(phone=p[7], name=services.tag_name(p[7]))
        RiderFactory(user=rider_user)
        person = UserFactory(phone=p[8], name="Real Person")
        their_order = place_cod(shop, person)
        rider_range_staff = StaffUserFactory(
            phone=services.RIDER_PHONES[0], name=services.tag_name(services.RIDER_PHONES[0])
        )
        tagged = UserFactory(phone=p[9], name=services.tag_name(p[9]))

        out = run("loadtest_cleanup", "--yes", "--keep-stock")

        for user in (staff, admin, rider_user, person, rider_range_staff):
            assert User.objects.filter(pk=user.pk).exists()
        assert not User.objects.filter(pk=tagged.pk).exists()
        their_order.refresh_from_db()
        assert their_order.status == "PLACED"
        assert "staff or superuser account" in out
        assert "has a rider profile" in out
        assert "not named 'Loadtest 208'" in out
        assert "customers 1 found, 1 deleted" in out
        assert Rider.objects.filter(user=rider_user).exists()

    def test_otp_requests_of_kept_accounts_stay(self, allowed, db):
        staff = StaffUserFactory(phone=services.PHONES[0], name="Loadtest 200")
        for phone in (staff.phone, services.PHONES[1]):
            OTPRequest.objects.create(
                phone=phone,
                app="customer",
                purpose="login",
                code_hash="x",
                expires_at=timezone.now(),
            )
        run("loadtest_cleanup", "--yes")
        assert list(OTPRequest.objects.values_list("phone", flat=True)) == [staff.phone]

    def test_seed_refuses_an_untagged_account_in_the_range(self, allowed, shop):  # noqa: F811
        UserFactory(phone=services.PHONES[0], name="Real Person")
        with pytest.raises(CommandError, match="not named 'Loadtest 200'"):
            run("loadtest_seed", "--store", shop.store_model.code, "--users", "1")

    def test_seed_refuses_a_customer_range_rider(self, allowed, shop):  # noqa: F811
        user = UserFactory(phone=services.PHONES[0], name="Loadtest 200")
        RiderFactory(user=user)
        with pytest.raises(CommandError, match="has a rider profile"):
            run("loadtest_seed", "--store", shop.store_model.code, "--users", "1")


# --------------------------------------------------------------------------- stock race


def test_reversal_race_keeps_the_row(allowed, shop, monkeypatch):  # noqa: F811
    """`available` is read without a lock; if an order takes the units first, the reversal's
    adjust_stock fails (IntegrityError or the service's ValidationError): reported, not a
    crash, and the other rows are still reversed."""
    run("loadtest_seed", "--store", shop.store_model.code, "--users", "1", "--stock-floor", "100")
    real = services.adjust_stock
    calls = []

    def racing(**kwargs):
        calls.append(kwargs["variant"].pk)
        if len(calls) == 1:
            raise IntegrityError("inventory_on_hand_gte_reserved")
        return real(**kwargs)

    monkeypatch.setattr(services, "adjust_stock", racing)
    out = run("loadtest_cleanup", "--yes")
    assert f"/{calls[0]} (store/variant): stock changed meanwhile" in out
    assert "reversed on 3 rows" in out
    assert StockMovement.objects.filter(reason=services.REASON_REVERSAL).count() == 3


# --------------------------------------------------------------------------- riders


class TestRiders:
    def test_seed_makes_active_riders_through_kyc(self, allowed, shop, reviewer):  # noqa: F811
        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "1",
            "--stock-floor",
            "0",
            "--riders",
            "2",
            "--approver",
            reviewer.email,
            "--print-otp-env",
        )
        riders = list(Rider.objects.filter(user__phone__in=services.RIDER_PHONES).order_by("pk"))
        assert [r.user.phone for r in riders] == list(services.RIDER_PHONES[:2])
        for rider in riders:
            assert rider.status == RiderStatus.ACTIVE
            assert rider.home_store_id == shop.store_model.pk
            assert rider.user.name == services.tag_name(rider.user.phone)
            assert rider.has_bank_account
            documents = RiderDocument.objects.filter(rider=rider)
            assert sorted(d.doc_type for d in documents) == sorted(rider.required_documents)
            assert all(d.status == DocumentStatus.APPROVED for d in documents)
            assert all(d.reviewed_by_id == reviewer.pk for d in documents)
        assert AuditLog.objects.filter(action="rider.approve", actor=reviewer).count() == 2
        assert "riders 2 approved now, 0 already ACTIVE" in out
        assert "+919000000300:123456,+919000000301:123456" in out

        out = run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "1",
            "--stock-floor",
            "0",
            "--riders",
            "2",
            "--approver",
            reviewer.email,
        )
        assert "riders 0 approved now, 2 already ACTIVE" in out

    def test_riders_need_a_kyc_reviewer(self, allowed, shop):  # noqa: F811
        code = shop.store_model.code
        with pytest.raises(CommandError, match="--approver"):
            run("loadtest_seed", "--store", code, "--riders", "1")
        plain = StaffUserFactory(email="nobody@jivo.test")
        with pytest.raises(CommandError, match="not an active staff user allowed"):
            run("loadtest_seed", "--store", code, "--riders", "1", "--approver", plain.email)
        with pytest.raises(CommandError, match="Between 0 and 100"):
            run("loadtest_seed", "--store", code, "--riders", "101", "--approver", "x@y.z")
        assert not Rider.objects.exists()

    def test_cleanup_removes_riders_with_an_open_shift(self, allowed, shop, reviewer):  # noqa: F811
        run(
            "loadtest_seed",
            "--store",
            shop.store_model.code,
            "--users",
            "1",
            "--stock-floor",
            "0",
            "--riders",
            "1",
            "--approver",
            reviewer.email,
        )
        user = User.objects.get(phone=services.RIDER_PHONES[0])
        store = shop.store_model
        shifts.start_shift(user, lat=store.location.y, lng=store.location.x, accuracy=5)
        assert RiderShift.objects.filter(rider__user=user, ended_at__isnull=True).exists()

        dry = run("loadtest_cleanup")
        assert "riders 1 found, 1 would be deleted" in dry
        assert Rider.objects.filter(user=user).exists()

        out = run("loadtest_cleanup", "--yes")
        assert "riders 1 found, 1 deleted" in out
        assert not User.objects.filter(phone__in=services.RIDER_PHONES).exists()
        assert not Rider.objects.exists()
        assert not RiderDocument.objects.exists()
        assert not Address.objects.filter(user__phone__in=services.PHONES).exists()
