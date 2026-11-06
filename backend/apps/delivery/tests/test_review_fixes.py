"""Code review of 48c2291 (Phase 5): DPDP erasure and KYC retention, the track phone rule,
rate limits on the registration endpoints, decryption errors, audit IPs, cross-store IDOR on the
staff services, `/rider/me/` query count, key rotation."""

from datetime import date, timedelta
from io import StringIO

import pytest
from cryptography.fernet import Fernet
from django.contrib.auth.models import Group
from django.core.exceptions import ValidationError
from django.core.files.storage import default_storage
from django.core.management import CommandError, call_command
from django.test import override_settings
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.services.auth import anonymise_user
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core import crypto
from apps.core.models import AuditLog
from apps.delivery.models import Rider, RiderDocument, RiderLocation
from apps.delivery.services import kyc, privacy, tracking
from apps.delivery.tasks import purge_offboarded_kyc
from apps.delivery.tests.factories import RiderFactory, active_rider, add_documents
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles():
    roles.sync_roles()


def staff(*role_names, stores=()):
    user = StaffUserFactory()
    for name in role_names:
        user.groups.add(Group.objects.get(name=name))
    for store in stores:
        grant_store_access(user, store)
    return user


# --------------------------------------------------------------------------- DPDP erasure


def _location(rider):
    from django.contrib.gis.geos import Point

    return RiderLocation.objects.create(
        rider=rider,
        point=Point(77.05, 28.45, srid=4326),
        accuracy_m=5,
        recorded_at=timezone.now(),
    )


def test_anonymising_a_user_erases_the_rider_profile():
    rider = active_rider()
    _location(rider)
    user = rider.user
    user.deleted_at = timezone.now() - timedelta(days=31)
    user.save()
    assert rider.history.exists()
    assert anonymise_user(user.pk) is True
    rider.refresh_from_db()
    assert rider.full_name == ""
    assert rider.dob is None
    assert rider.emergency_contact_name == ""
    assert rider.emergency_contact_phone == ""
    assert rider.bank_account_name == ""
    assert rider.bank_account_number_encrypted == ""
    assert rider.ifsc == ""
    assert rider.upi_id == ""
    assert rider.bank_account_last4 == ""
    assert rider.vehicle_number == ""
    assert rider.is_online is False
    assert rider.anonymised_at is not None
    assert rider.kyc_purge_after == timezone.now().date() + timedelta(days=365)
    assert not RiderLocation.objects.filter(rider=rider).exists()
    assert not rider.history.exists()
    # KYC documents stay until the D-14 retention date.
    assert RiderDocument.objects.filter(rider=rider).count() == 6
    assert privacy.scrub_rider(user) is False  # idempotent


def test_scrub_without_rider_profile():
    assert privacy.scrub_rider(UserFactory()) is False


def test_kyc_purge_after_retention(django_capture_on_commit_callbacks):
    rider = active_rider()
    names = list(rider.documents.values_list("file", flat=True))
    Rider.objects.filter(pk=rider.pk).update(kyc_purge_after=date.today() + timedelta(days=1))
    assert purge_offboarded_kyc() == 0
    Rider.objects.filter(pk=rider.pk).update(kyc_purge_after=date.today())
    assert purge_offboarded_kyc() == 6
    assert not RiderDocument.objects.filter(rider=rider).exists()
    assert not any(default_storage.exists(name) for name in names)
    assert purge_offboarded_kyc() == 0


def test_kyc_purge_keeps_the_row_when_the_bucket_refuses(monkeypatch):
    rider = active_rider()
    Rider.objects.filter(pk=rider.pk).update(kyc_purge_after=date.today())

    def refuse(name):
        raise OSError("bucket unavailable")

    monkeypatch.setattr(privacy.default_storage, "delete", refuse)
    assert privacy.purge_offboarded_kyc() == 0
    assert RiderDocument.objects.filter(rider=rider).count() == 6


# --------------------------------------------------------------------------- track phone rule


@pytest.mark.parametrize(
    ("status", "visible"),
    [
        (OrderStatus.ACCEPTED, False),
        (OrderStatus.PACKED, False),
        (OrderStatus.OUT_FOR_DELIVERY, True),
        (OrderStatus.DELIVERED, False),
        (OrderStatus.DELIVERY_FAILED, False),
    ],
)
def test_rider_phone_only_while_out_for_delivery(status, visible):
    rider = active_rider(full_name="Ravi Kumar Singh")
    order = OrderFactory(status=status)
    body = tracking.rider_body(order, rider, None, None)
    assert body["phone"] == (rider.user.phone if visible else None)
    assert body["name"] == "Ravi S."
    assert body["lat"] is None


def test_track_is_owner_only(make_auth_client):
    order = OrderFactory(status=OrderStatus.OUT_FOR_DELIVERY)
    assert (
        make_auth_client(UserFactory()).get(f"/api/v1/orders/{order.pk}/track/").status_code == 404
    )
    body = make_auth_client(order.user).get(f"/api/v1/orders/{order.pk}/track/").json()
    assert body["rider"] is None  # no task until slice 5.3


def test_short_name_single_word():
    assert tracking._short_name("Ravi") == "Ravi"


# --------------------------------------------------------------------------- rate limits


@pytest.mark.parametrize(
    ("throttle", "scope", "path", "method"),
    [
        ("RiderProfileWriteThrottle", "rider_profile_write", "/api/v1/rider/register/", "post"),
        ("RiderProfileWriteThrottle", "rider_profile_write", "/api/v1/rider/bank-account/", "put"),
        ("RiderDocumentsThrottle", "rider_documents", "/api/v1/rider/documents/", "post"),
    ],
)
def test_registration_rate_limits(make_auth_client, monkeypatch, throttle, scope, path, method):
    from apps.delivery import throttling

    monkeypatch.setattr(getattr(throttling, throttle), "THROTTLE_RATES", {scope: "1/hour"})
    client = make_auth_client(RiderFactory().user, "rider")
    getattr(client, method)(path, {}, format="json")
    response = getattr(client, method)(path, {}, format="json")
    assert response.status_code == 429


# --------------------------------------------------------------------------- decryption, IP


def test_undecryptable_numbers_give_a_readable_error():
    rider = active_rider()
    pan = rider.documents.get(doc_type="PAN")
    other_key = Fernet(Fernet.generate_key())
    pan.number_encrypted = other_key.encrypt(b"ABCDE1234F").decode()
    pan.save()
    Rider.objects.filter(pk=rider.pk).update(
        bank_account_number_encrypted=other_key.encrypt(b"123456789").decode()
    )
    rider.refresh_from_db()
    ops = staff(roles.OPS)
    with pytest.raises(ValidationError, match="cannot be decrypted"):
        kyc.document_number(pan.pk, by=ops)
    with pytest.raises(ValidationError, match="cannot be decrypted"):
        rider.bank_account_number()


def test_staff_actions_record_the_request_ip():
    rider = RiderFactory()
    document = add_documents(rider, "PENDING")[0]
    kyc.approve_document(document.pk, by=staff(roles.OPS), ip="203.0.113.7")
    assert AuditLog.objects.get(action="rider.document_approve").ip == "203.0.113.7"


# --------------------------------------------------------------------------- cross-store IDOR


def test_scoped_reviewer_cannot_reach_another_stores_rider():
    """A reviewer limited to store A (Ops + Store Manager: the stricter scope wins) gets "not
    found" for a rider of store B, for every document action."""
    store_a, store_b = DarkStoreFactory(), DarkStoreFactory()
    rider = active_rider(preferred_store=store_b)
    document = rider.documents.get(doc_type="PAN")
    reviewer = staff(roles.OPS, roles.STORE_MANAGER, stores=[store_a])
    for action in (kyc.document_file_url, kyc.document_number, kyc.approve_document):
        with pytest.raises(ValidationError, match="not found"):
            action(document.pk, by=reviewer)
    with pytest.raises(ValidationError, match="not found"):
        kyc.reject_document(document.pk, by=reviewer, note="x")
    # Same reviewer, own store: allowed.
    grant_store_access(reviewer, store_b)
    assert kyc.approve_document(document.pk, by=reviewer).status == "APPROVED"


# --------------------------------------------------------------------------- query count


def test_rider_me_query_count_does_not_grow_with_documents(make_auth_client):
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    bare = RiderFactory()
    full = active_rider()
    counts = []
    for rider in (bare, full):
        client = make_auth_client(rider.user, "rider")
        client.get("/api/v1/rider/me/")  # warm the app-config cache
        with CaptureQueriesContext(connection) as ctx:
            assert client.get("/api/v1/rider/me/").status_code == 200
        counts.append(len(ctx.captured_queries))
    assert counts[0] == counts[1]
    assert counts[1] <= 8


# --------------------------------------------------------------------------- key rotation


def test_rotate_field_keys():
    old_key, new_key = Fernet.generate_key().decode(), Fernet.generate_key().decode()
    crypto._fernet.cache_clear()
    with override_settings(FIELD_ENCRYPTION_KEYS=[old_key]):
        rider = active_rider()
        pan = rider.documents.get(doc_type="PAN")
        pan.number_encrypted = crypto.encrypt("ABCDE1234F")
        pan.save()
    with override_settings(FIELD_ENCRYPTION_KEYS=[new_key, old_key]):
        out = StringIO()
        call_command("rotate_field_keys", stdout=out)
        assert "done" in out.getvalue()
    with override_settings(FIELD_ENCRYPTION_KEYS=[new_key]):
        rider.refresh_from_db()
        pan.refresh_from_db()
        assert rider.bank_account_number() == "50100123456789"
        assert pan.number() == "ABCDE1234F"
        # A value no configured key can read: reported, the command fails.
        Rider.objects.filter(pk=rider.pk).update(
            bank_account_number_encrypted=Fernet(Fernet.generate_key()).encrypt(b"1").decode()
        )
        with pytest.raises(CommandError):
            call_command("rotate_field_keys", stdout=StringIO())
