"""Staff roles (05 §3), Customers admin (05 §2), staff login throttling (09 §3.1), seed_demo."""

import importlib
import sys

import pytest
from django.contrib.auth.models import Group
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from django.core.management import CommandError, call_command
from django.urls import reverse
from rest_framework.test import APIClient

from apps.accounts import roles
from apps.accounts.models import Address, Customer, User
from apps.accounts.services.auth import issue_tokens
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory

pytestmark = pytest.mark.django_db


def staff_with_role(role):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


class TestRoles:
    def test_groups_exist_with_their_permissions(self):
        roles.sync_roles()
        names = set(Group.objects.values_list("name", flat=True))
        assert set(roles.ROLE_PERMISSIONS) <= names
        support = {p.codename for p in Group.objects.get(name=roles.SUPPORT).permissions.all()}
        assert {"view_customer", "change_customer", "view_product"} <= support
        # P7 PM default: Support edits FAQs (05 §2 Support module); nothing else.
        assert not any(
            code.startswith(("add_", "delete_")) and code not in {"add_faq", "delete_faq"}
            for code in support
        )
        admin_perms = Group.objects.get(name=roles.SUPER_ADMIN).permissions
        assert admin_perms.filter(codename="change_user").exists()
        assert admin_perms.filter(codename="change_appconfig").exists()
        assert admin_perms.filter(codename="adjust_stock").exists()  # custom permission (P2)
        finance = {p.codename for p in Group.objects.get(name=roles.FINANCE).permissions.all()}
        assert finance == {
            "view_storeinventory",
            "view_stockmovement",
            "view_pricingconfig",
            # Phase 3: coupons, orders and payments, view only
            "view_coupon",
            "view_couponredemption",
            "view_order",
            "view_orderitem",
            "view_orderstatushistory",
            "view_payment",
            "view_refund",
            "view_paymentwebhookevent",
            # Phase 4: invoices, refunds (05 §3 Refund ✔), the audit log (view)
            "view_invoice",
            "issue_refund",
            "view_auditlog",
            # Phase 5 slice 5.4 (05 §3 Payouts ✔; DL-61 a: Finance records cash deposits)
            "record_cash_deposit",
            "view_ridercashledger",
            "manage_payouts",
            "view_payout",
            "view_riderearning",
            "view_earningrule",
            # Phase 7 (05 §3 Reports row, ⚠ PM default): all three report families
            "view_reports",
            "view_catalog_reports",
            "view_finance_reports",
        }

    @pytest.mark.parametrize(
        ("role", "allowed", "denied"),
        [
            (roles.STORE_MANAGER, {"adjust_stock", "view_darkstore"}, {"change_productvariant"}),
            (roles.STORE_STAFF, {"view_storeinventory"}, {"adjust_stock"}),
            (roles.CATALOG_MANAGER, {"change_productvariant", "add_banner"}, {"adjust_stock"}),
            (roles.OPS, {"view_serviceabilityrequest"}, {"adjust_stock", "change_storeinventory"}),
        ],
    )
    def test_phase_2_matrix(self, role, allowed, denied):
        """05 §3: catalog, inventory and stores rows. Price changes stay with catalog/admin."""
        roles.sync_roles()
        codes = {p.codename for p in Group.objects.get(name=role).permissions.all()}
        assert allowed <= codes
        assert not denied & codes

    @pytest.mark.parametrize(
        ("role", "allowed", "denied"),
        [
            (roles.CATALOG_MANAGER, {"add_coupon", "change_coupon"}, {"view_payment"}),
            (roles.SUPPORT, {"view_coupon", "view_order", "view_refund"}, {"change_coupon"}),
            (roles.OPS, {"view_order"}, {"change_order", "view_coupon", "view_payment"}),
            (roles.STORE_MANAGER, {"view_order"}, {"change_order", "view_payment"}),
            (roles.STORE_STAFF, {"view_order"}, {"view_coupon", "view_payment"}),
            (roles.FINANCE, {"view_payment", "view_refund"}, {"change_coupon", "change_order"}),
        ],
    )
    def test_phase_3_matrix(self, role, allowed, denied):
        """05 §3 Coupons, Refund, order board and packing console rows (PM default)."""
        roles.sync_roles()
        codes = {p.codename for p in Group.objects.get(name=role).permissions.all()}
        assert allowed <= codes
        assert not denied & codes
        admin = Group.objects.get(name=roles.SUPER_ADMIN).permissions
        assert (
            admin.filter(codename__in=["change_coupon", "view_cart", "view_payment"]).count() == 3
        )

    def test_sync_is_idempotent(self):
        roles.sync_roles()
        count = Group.objects.count()
        support = Group.objects.get(name=roles.SUPPORT)
        support.permissions.clear()
        roles.sync_roles()
        assert Group.objects.count() == count
        assert support.permissions.count() == len(roles.ROLE_PERMISSIONS[roles.SUPPORT])


class TestCustomersAdmin:
    @pytest.fixture
    def customer(self):
        customer = UserFactory(phone="+919811122233", name="Ravi Customer")
        Address.objects.create(
            user=customer,
            label="home",
            receiver_name="Ravi",
            receiver_phone=customer.phone,
            house="12",
            building_street="MG Road",
            city="Gurugram",
            state="Haryana",
            pincode="122001",
            lat=1,
            lng=1,
            is_default=True,
        )
        return customer

    def test_superuser_list_search_detail(self, client, customer):
        StaffUserFactory()  # staff are not customers
        client.force_login(SuperUserFactory())
        changelist = reverse("admin:accounts_customer_changelist")
        response = client.get(changelist, {"q": "9811122233"})
        assert response.status_code == 200
        assert b"Ravi Customer" in response.content
        assert Customer.objects.count() == 1
        detail = client.get(reverse("admin:accounts_customer_change", args=[customer.pk]))
        assert detail.status_code == 200
        assert b"MG Road" in detail.content
        assert client.get(reverse("admin:accounts_customer_add")).status_code == 403

    def test_support_can_block_and_unblock(self, client, customer):
        _, refresh = issue_tokens(customer, "customer")
        client.force_login(staff_with_role(roles.SUPPORT))
        changelist = reverse("admin:accounts_customer_changelist")
        response = client.post(changelist, {"action": "block", "_selected_action": [customer.pk]})
        assert response.status_code == 302
        customer.refresh_from_db()
        assert not customer.is_active
        assert (
            APIClient().post("/api/v1/auth/token/refresh/", {"refresh": refresh}).status_code == 401
        )
        client.post(changelist, {"action": "unblock", "_selected_action": [customer.pk]})
        customer.refresh_from_db()
        assert customer.is_active

    def test_support_cannot_manage_staff_users(self, client):
        client.force_login(staff_with_role(roles.SUPPORT))
        assert client.get(reverse("admin:accounts_user_changelist")).status_code == 403

    def test_store_staff_cannot_see_customers(self, client):
        client.force_login(staff_with_role(roles.STORE_STAFF))
        assert client.get(reverse("admin:accounts_customer_changelist")).status_code == 403

    def test_anonymise_now_only_touches_deletion_requests(self, client, customer):
        from django.utils import timezone

        other = UserFactory()
        customer.deleted_at = timezone.now()
        customer.save()
        client.force_login(SuperUserFactory())
        client.post(
            reverse("admin:accounts_customer_changelist"),
            # confirm=yes: the action asks first (see test_admin_roles.TestAnonymiseConfirmation)
            {
                "action": "anonymise_now",
                "_selected_action": [customer.pk, other.pk],
                "confirm": "yes",
            },
        )
        customer.refresh_from_db()
        other.refresh_from_db()
        assert customer.anonymised_at is not None
        assert customer.phone is None
        assert other.anonymised_at is None


class TestStaffLoginThrottling:
    def test_locks_out_after_five_failures(self, client):
        StaffUserFactory(email="ops@jivo.test", password="a-strong-pass-1")
        url = reverse("admin:login")
        for spelling in ("ops@jivo.test", "OPS@jivo.test", "Ops@Jivo.Test", "ops@JIVO.test"):
            response = client.post(url, {"username": spelling, "password": "wrong"})
            assert response.status_code == 200  # form error
        fifth = client.post(url, {"username": "ops@jivo.test", "password": "wrong"})
        assert fifth.status_code == 429  # AXES_FAILURE_LIMIT reached: locked out
        locked = client.post(url, {"username": "ops@jivo.test", "password": "a-strong-pass-1"})
        assert locked.status_code == 429  # even the right password, until the cool-off
        other_ip = client.post(
            url,
            {"username": "ops@jivo.test", "password": "a-strong-pass-1"},
            REMOTE_ADDR="203.0.113.9",
        )
        # T-814 (H2, DL-59): the lockout is also per username, whatever the IP, so rotating
        # IPs cannot brute-force one staff account (cool-off AXES_COOLOFF_MINUTES).
        assert other_ip.status_code == 429

    def test_success_logs_in(self, client):
        StaffUserFactory(email="ops@jivo.test", password="a-strong-pass-1")
        response = client.post(
            reverse("admin:login"),
            {"username": "OPS@jivo.test", "password": "a-strong-pass-1", "next": "/admin/"},
        )
        assert response.status_code == 302


class TestSeedDemo:
    PASSWORD = "seed-test-only-password-1"  # set per test through the env, never committed

    @pytest.fixture
    def staff_password(self, monkeypatch):
        monkeypatch.setenv("SEED_DEMO_STAFF_PASSWORD", self.PASSWORD)

    def test_creates_staff_per_role_customer_and_config(self, staff_password, capsys):
        from apps.accounts.seed import STAFF
        from apps.cms.models import AppVersionPolicy

        call_command("seed_demo")
        call_command("seed_demo")  # idempotent
        out = capsys.readouterr().out
        assert User.objects.filter(is_staff=True).count() == len(STAFF) == 7
        for email, _name, role, is_superuser in STAFF:
            user = User.objects.get(email=email)
            assert list(user.groups.values_list("name", flat=True)) == [role]
            assert user.is_superuser is is_superuser
            assert user.check_password(self.PASSWORD)
        customer = User.objects.get(phone="+919000000001")
        assert customer.name == "Test Customer"
        assert Address.objects.filter(user=customer, is_default=True).count() == 1
        assert "+919000000001 (OTP 123456)" in out
        assert self.PASSWORD not in out
        assert AppVersionPolicy.objects.count() == 3

    def test_without_the_env_var_passwords_are_unusable(self, monkeypatch, capsys):
        monkeypatch.delenv("SEED_DEMO_STAFF_PASSWORD", raising=False)
        call_command("seed_demo")
        assert not User.objects.filter(is_staff=True, password__startswith="md5").exists()
        assert not User.objects.get(email="superadmin@jivo.test").has_usable_password()
        assert "passwords are unusable" in capsys.readouterr().out

    def test_existing_passwords_change_only_with_the_reset_flag(self, monkeypatch):
        monkeypatch.setenv("SEED_DEMO_STAFF_PASSWORD", "first-password-123")
        call_command("seed_demo")
        monkeypatch.setenv("SEED_DEMO_STAFF_PASSWORD", self.PASSWORD)
        call_command("seed_demo")
        ops = User.objects.get(email="ops@jivo.test")
        assert ops.check_password("first-password-123")  # untouched without the flag

        call_command("seed_demo", "--reset-staff-passwords")
        for user in User.objects.filter(is_staff=True):
            assert user.check_password(self.PASSWORD)
            assert not user.check_password("first-password-123")

    def test_reset_flag_requires_the_env_var(self, monkeypatch):
        monkeypatch.delenv("SEED_DEMO_STAFF_PASSWORD", raising=False)
        with pytest.raises(CommandError, match="SEED_DEMO_STAFF_PASSWORD"):
            call_command("seed_demo", "--reset-staff-passwords")


class TestOtpTestNumberSafety:
    """D-15: fixed-OTP numbers never in production."""

    def test_checks_reject_bad_entries_and_production(self, settings):
        settings.OTP_TEST_NUMBERS = {"+919000000001": "12345", "12345": "123456"}
        ids = {error.id for error in run_checks() if error.id.startswith("accounts.")}
        assert ids == {"accounts.E002"}
        settings.OTP_TEST_NUMBERS = {"+919000000001": "123456"}
        settings.APP_ENVIRONMENT = "production"
        # Production's SMS default (the test settings' locmem backend is E003, BUG-0005).
        settings.SMS_BACKEND = "apps.notifications.sms.UnconfiguredSmsBackend"
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": "j" * 64}  # T-814 (L3)
        ids = {error.id for error in run_checks() if error.id.startswith("accounts.")}
        assert ids == {"accounts.E001"}

    @pytest.fixture
    def deploy_env(self, monkeypatch):
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.com")
        monkeypatch.setenv("NUM_PROXIES", "1")
        monkeypatch.setenv("OTP_TEST_NUMBERS", "+919000000001:123456")
        monkeypatch.delenv("SENTRY_DSN", raising=False)
        yield
        for name in ("production", "staging", "deployed"):
            sys.modules.pop(f"config.settings.{name}", None)

    def _load(self, name):
        sys.modules.pop(f"config.settings.{name}", None)
        return importlib.import_module(f"config.settings.{name}")

    def test_production_refuses_to_start_with_test_numbers(self, deploy_env):
        with pytest.raises(ImproperlyConfigured, match="OTP_TEST_NUMBERS"):
            self._load("production")

    def test_staging_allows_them(self, deploy_env):
        assert self._load("staging").OTP_TEST_NUMBERS == {"+919000000001": "123456"}
