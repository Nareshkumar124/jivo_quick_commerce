"""Customer moderation services for the panel: block / unblock (actor recorded), the anonymise
permission (DL-35) and admin-log scrubbing on anonymisation."""

from datetime import timedelta

import pytest
from django.contrib.admin.models import LogEntry
from django.contrib.auth.models import Group
from django.core.exceptions import ValidationError
from django.utils import timezone
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts import roles
from apps.accounts.models import Device
from apps.accounts.services import auth, customers
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def ops(db):
    return StaffUserFactory()


def _device(user):
    return Device.objects.create(
        user=user,
        app="customer",
        platform="android",
        fcm_token=f"fcm-{user.pk}",
        app_version="1.0.0",
        last_seen_at=timezone.now(),
    )


def _in_role(role):
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


def _log(user):
    return LogEntry.objects.filter(object_id=str(user.pk)).order_by("pk")


class TestBlock:
    def test_blocks_revokes_tokens_deactivates_devices_and_records_the_actor(self, ops):
        customer = UserFactory()
        refresh = RefreshToken.for_user(customer)
        _device(customer)
        assert customers.block_customer(customer.pk, by=ops) is True
        customer.refresh_from_db()
        assert customer.is_active is False
        assert not Device.objects.filter(user=customer, is_active=True).exists()
        outstanding = OutstandingToken.objects.get(jti=refresh["jti"])
        assert hasattr(outstanding, "blacklistedtoken")
        entry = _log(customer).get()
        assert entry.user == ops
        assert entry.object_repr == f"Customer {customer.pk}"  # no phone in the log
        assert customer.phone not in entry.change_message

    def test_blocked_customer_cannot_use_the_api(self, ops, make_auth_client, api_client):
        customer = UserFactory()
        client = make_auth_client(customer)
        refresh = str(RefreshToken.for_user(customer))
        customers.block_customer(customer.pk, by=ops)
        assert client.get("/api/v1/me/").status_code == 401
        refreshed = api_client.post(
            "/api/v1/auth/token/refresh/", {"refresh": refresh}, format="json"
        )
        assert refreshed.status_code == 401

    def test_is_idempotent(self, ops):
        customer = UserFactory()
        assert customers.block_customer(customer.pk, by=ops) is True
        assert customers.block_customer(customer.pk, by=ops) is False
        assert _log(customer).count() == 1

    @pytest.mark.parametrize("make", [StaffUserFactory, SuperUserFactory])
    def test_refuses_staff(self, ops, make):
        staff = make()
        with pytest.raises(ValidationError, match="Staff accounts"):
            customers.block_customer(staff.pk, by=ops)
        staff.refresh_from_db()
        assert staff.is_active

    def test_refuses_anonymised_and_unknown(self, ops):
        customer = UserFactory(deleted_at=timezone.now() - timedelta(days=31))
        auth.anonymise_user(customer.pk)
        with pytest.raises(ValidationError, match="anonymised"):
            customers.block_customer(customer.pk, by=ops)
        with pytest.raises(ValidationError, match="does not exist"):
            customers.block_customer(999_999_999, by=ops)

    def test_requires_an_actor(self):
        customer = UserFactory()
        with pytest.raises(ValueError, match="acting staff user"):
            customers.block_customer(customer.pk, by=None)
        customer.refresh_from_db()
        assert customer.is_active  # rolled back


class TestUnblock:
    def test_unblocks_and_records_the_actor(self, ops):
        customer = UserFactory()
        customers.block_customer(customer.pk, by=ops)
        other = StaffUserFactory()
        assert customers.unblock_customer(customer.pk, by=other) is True
        customer.refresh_from_db()
        assert customer.is_active
        assert [e.user_id for e in _log(customer)] == [ops.pk, other.pk]
        assert customers.unblock_customer(customer.pk, by=other) is False

    def test_refuses_staff_and_anonymised(self, ops):
        with pytest.raises(ValidationError):
            customers.unblock_customer(StaffUserFactory(is_active=False).pk, by=ops)
        customer = UserFactory(deleted_at=timezone.now() - timedelta(days=31))
        auth.anonymise_user(customer.pk)
        with pytest.raises(ValidationError):
            customers.unblock_customer(customer.pk, by=ops)


class TestCodBlock:
    """T-405c: `set_cod_blocked`, the service the admin's COD actions call. Lifting a block
    needs `delivery.lift_cod_block` (DL-61 d, 05 §3: Super Admin, Ops; code review)."""

    @pytest.fixture
    def lifter(self):
        return _in_role(roles.OPS)

    def test_block_and_allow_are_audited_without_personal_data(self, lifter):
        from apps.core.models import AuditLog

        customer = UserFactory()
        assert customers.set_cod_blocked(customer.pk, True, by=lifter) is True
        assert customers.set_cod_blocked(customer.pk, True, by=lifter) is False  # no entries
        assert customers.set_cod_blocked(customer.pk, False, by=lifter) is True
        entries = AuditLog.objects.filter(object_id=str(customer.pk)).order_by("pk")
        assert [(e.action, e.actor_id, e.object_type, e.changes) for e in entries] == [
            ("accounts.cod_blocked", lifter.pk, "accounts.user", {}),
            ("accounts.cod_block_lifted", lifter.pk, "accounts.user", {}),
        ]
        assert list(_log(customer).values_list("change_message", flat=True)) == [
            customers.LOG_COD_BLOCKED,
            customers.LOG_COD_ALLOWED,
        ]
        assert set(_log(customer).values_list("object_repr", flat=True)) == {
            f"Customer {customer.pk}"
        }

    def test_allowing_cod_again_restarts_the_refusal_count(self, lifter):
        """DL-61 (d): ops lifting the block (here, from the admin) sets `cod_block_lifted_at`,
        so only refusals after it count towards the next automatic block. Blocking does not."""
        customer = UserFactory(cod_blocked=True)
        customers.set_cod_blocked(customer.pk, False, by=lifter)
        customer.refresh_from_db()
        lifted_at = customer.cod_block_lifted_at
        assert (customer.cod_blocked, lifted_at is not None) == (False, True)
        customers.set_cod_blocked(customer.pk, True, by=lifter)
        customer.refresh_from_db()
        assert (customer.cod_blocked, customer.cod_block_lifted_at) == (True, lifted_at)

    @pytest.mark.parametrize("role", [roles.OPS, roles.SUPER_ADMIN])
    def test_ops_and_super_admin_lift_a_block(self, role):
        customer = UserFactory(cod_blocked=True)
        assert customers.set_cod_blocked(customer.pk, False, by=_in_role(role)) is True
        customer.refresh_from_db()
        assert customer.cod_blocked is False
        assert customer.cod_block_lifted_at is not None

    def test_superuser_lifts_a_block(self):
        customer = UserFactory(cod_blocked=True)
        assert customers.set_cod_blocked(customer.pk, False, by=SuperUserFactory()) is True

    @pytest.mark.parametrize(
        "role", [roles.SUPPORT, roles.STORE_MANAGER, roles.FINANCE, roles.CATALOG_MANAGER, None]
    )
    def test_others_cannot_lift_a_block_and_nothing_changes(self, role):
        """Support may block COD (Customer `change`) but not lift a block: refused before
        anything is read or written (no `cod_block_lifted_at`, no LogEntry, no AuditLog)."""
        from django.core.exceptions import PermissionDenied

        from apps.core.models import AuditLog

        customer = UserFactory(cod_blocked=True)
        staff = _in_role(role) if role else StaffUserFactory()
        with pytest.raises(PermissionDenied, match="Super Admin and Ops"):
            customers.set_cod_blocked(customer.pk, False, by=staff)
        customer.refresh_from_db()
        assert (customer.cod_blocked, customer.cod_block_lifted_at) == (True, None)
        assert not AuditLog.objects.exists()
        assert not _log(customer).exists()

    def test_support_still_blocks_cod(self):
        customer = UserFactory()
        assert customers.set_cod_blocked(customer.pk, True, by=_in_role(roles.SUPPORT)) is True
        customer.refresh_from_db()
        assert customer.cod_blocked is True

    def test_inactive_lifter_is_refused(self):
        from django.core.exceptions import PermissionDenied

        ops = _in_role(roles.OPS)
        ops.is_active = False
        with pytest.raises(PermissionDenied):
            customers.set_cod_blocked(UserFactory(cod_blocked=True).pk, False, by=ops)

    def test_refused_change_writes_nothing(self, lifter):
        from apps.core.models import AuditLog

        with pytest.raises(ValidationError):
            customers.set_cod_blocked(StaffUserFactory().pk, True, by=lifter)
        assert not AuditLog.objects.exists()


class TestAnonymisation:
    def test_scrubs_personal_data_from_the_admin_log(self, ops):
        customer = UserFactory(deleted_at=timezone.now() - timedelta(days=31))
        customers.block_customer(customer.pk, by=ops)
        # A log entry Django's admin would write itself (object_repr = str(user) = the phone).
        LogEntry.objects.create(
            user=ops,
            content_type_id=_log(customer).get().content_type_id,
            object_id=str(customer.pk),
            object_repr=customer.phone,
            action_flag=2,
        )
        assert auth.anonymise_user(customer.pk)
        assert set(_log(customer).values_list("object_repr", flat=True)) == {
            f"Customer {customer.pk}"
        }

    def test_anonymise_permission_is_super_admin_only(self):
        """DL-35: `accounts.anonymise_customer` belongs to Super Admin and no other role."""
        roles.sync_roles()
        for role in roles.ROLE_PERMISSIONS:
            user = StaffUserFactory()
            user.groups.add(Group.objects.get(name=role))
            expected = role == roles.SUPER_ADMIN
            assert user.has_perm("accounts.anonymise_customer") is expected, role
