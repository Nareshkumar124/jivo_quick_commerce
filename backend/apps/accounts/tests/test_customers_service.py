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
