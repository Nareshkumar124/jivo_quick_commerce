"""Slice 5.1 staff services (T-512): what the Riders admin calls, with the 05 §3 role matrix."""

from decimal import Decimal

import pytest
from django.core.exceptions import PermissionDenied, ValidationError

from apps.accounts import roles
from apps.accounts.choices import RiderStatus
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.core.exceptions import ApiError
from apps.core.models import AuditLog
from apps.delivery.choices import DocumentStatus, ShiftEndReason
from apps.delivery.models import Rider, RiderDocument, RiderShift
from apps.delivery.services import kyc
from apps.delivery.tests.factories import (
    RiderFactory,
    active_rider,
    add_documents,
    complete_rider,
)
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _roles():
    roles.sync_roles()


def staff(role, *stores):
    from django.contrib.auth.models import Group

    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    for store in stores:
        grant_store_access(user, store)
    return user


@pytest.fixture
def ops():
    return staff(roles.OPS)


# --------------------------------------------------------------------------- role matrix


@pytest.mark.parametrize(
    ("role", "can_review"),
    [
        (roles.SUPER_ADMIN, True),
        (roles.OPS, True),
        (roles.STORE_MANAGER, False),
        (roles.STORE_STAFF, False),
        (roles.CATALOG_MANAGER, False),
        (roles.SUPPORT, False),
        (roles.FINANCE, False),
    ],
)
def test_rider_approval_matrix(role, can_review):
    """05 §3 "Rider approval / suspend": Super Admin and Ops only."""
    rider = complete_rider()
    user = staff(role, rider.preferred_store)
    assert kyc.can_review(user) is can_review
    if can_review:
        assert kyc.approve_rider(rider.pk, by=user).status == RiderStatus.ACTIVE
    else:
        with pytest.raises(PermissionDenied):
            kyc.approve_rider(rider.pk, by=user)


def test_store_manager_views_own_store_riders_only():
    mine, other = RiderFactory(), RiderFactory()
    manager = staff(roles.STORE_MANAGER, mine.preferred_store)
    assert list(kyc.staff_riders(manager)) == [mine]
    assert other not in kyc.staff_riders(manager)
    assert kyc.staff_riders(staff(roles.FINANCE)).count() == 0  # no view permission


def test_superuser_sees_and_reviews_every_rider():
    rider = complete_rider()
    admin = SuperUserFactory()
    assert rider in kyc.staff_riders(admin)
    kyc.approve_rider(rider.pk, by=admin)


# --------------------------------------------------------------------------- approve / reject


def test_approve_sets_home_store_cash_limit_and_audits(ops):
    rider = complete_rider()
    other = DarkStoreFactory()
    rider = kyc.approve_rider(rider.pk, by=ops, home_store_id=other.pk, cash_limit="3000.00")
    rider.refresh_from_db()
    assert rider.status == RiderStatus.ACTIVE
    assert rider.home_store_id == other.pk
    assert rider.cash_limit == Decimal("3000.00")
    assert rider.approved_by == ops
    assert rider.approved_at
    entry = AuditLog.objects.get(action="rider.approve")
    assert entry.changes == {"home_store": other.pk, "cash_limit": "3000.00"}


def test_approve_needs_every_document_approved_and_bank(ops):
    rider = RiderFactory()
    add_documents(rider, DocumentStatus.PENDING)
    with pytest.raises(ValidationError, match="Approve every required document"):
        kyc.approve_rider(rider.pk, by=ops)
    RiderDocument.objects.filter(rider=rider).update(status=DocumentStatus.APPROVED)
    with pytest.raises(ValidationError, match="bank details"):
        kyc.approve_rider(rider.pk, by=ops)


def test_approve_only_pending(ops):
    rider = active_rider()
    with pytest.raises(ApiError) as exc:
        kyc.approve_rider(rider.pk, by=ops)
    assert exc.value.error_code == "INVALID_STATE_TRANSITION"


def test_out_of_scope_rider_is_not_found():
    rider = complete_rider()
    manager_elsewhere = staff(roles.STORE_MANAGER, DarkStoreFactory())
    assert kyc.staff_riders(manager_elsewhere).count() == 0
    # Ops with a store role is scoped like a store role (stricter wins).
    scoped_ops = staff(roles.OPS, DarkStoreFactory())
    from django.contrib.auth.models import Group

    scoped_ops.groups.add(Group.objects.get(name=roles.STORE_MANAGER))
    with pytest.raises(ValidationError, match="Rider not found"):
        kyc.approve_rider(rider.pk, by=scoped_ops)


def test_reject_needs_a_reason_and_lets_the_rider_resubmit(ops):
    rider = RiderFactory()
    with pytest.raises(ValidationError):
        kyc.reject_rider(rider.pk, by=ops, reason="  ")
    rider = kyc.reject_rider(rider.pk, by=ops, reason="PAN unreadable")
    assert rider.status == RiderStatus.REJECTED
    assert rider.rejection_reason == "PAN unreadable"
    assert AuditLog.objects.get(action="rider.reject").changes == {"reason_length": 14}
    with pytest.raises(ApiError):
        kyc.reject_rider(rider.pk, by=ops, reason="again")


def test_reject_reason_length(ops):
    rider = RiderFactory()
    with pytest.raises(ValidationError):
        kyc.reject_rider(rider.pk, by=ops, reason="x" * 301)


# --------------------------------------------------------------------------- documents


def test_document_review(ops):
    rider = RiderFactory()
    document = add_documents(rider, DocumentStatus.PENDING)[0]
    kyc.approve_document(document.pk, by=ops)
    document.refresh_from_db()
    assert document.status == DocumentStatus.APPROVED
    assert document.reviewed_by == ops
    assert kyc.approve_document(document.pk, by=ops).status == DocumentStatus.APPROVED
    kyc.reject_document(document.pk, by=ops, note="Expired")
    document.refresh_from_db()
    assert document.status == DocumentStatus.REJECTED
    assert document.review_note == "Expired"
    actions = list(AuditLog.objects.values_list("action", flat=True).order_by("id"))
    assert actions == ["rider.document_approve", "rider.document_reject"]


def test_rejecting_an_active_riders_document_keeps_the_rider_active(ops):
    """api-requests #25."""
    rider = active_rider()
    document = rider.documents.get(doc_type="DL")
    kyc.reject_document(document.pk, by=ops, note="Licence expired")
    rider.refresh_from_db()
    assert rider.status == RiderStatus.ACTIVE
    assert kyc.online_blockers(rider) == ["DOCUMENTS_NOT_APPROVED"]


def test_document_review_permission_and_scope():
    rider = RiderFactory()
    document = add_documents(rider, DocumentStatus.PENDING)[0]
    with pytest.raises(PermissionDenied):
        kyc.approve_document(document.pk, by=staff(roles.STORE_MANAGER, rider.preferred_store))
    with pytest.raises(ValidationError):
        kyc.approve_document(999999, by=staff(roles.OPS))


def test_document_file_url_and_number_are_audited(ops):
    rider = active_rider()
    pan = rider.documents.get(doc_type="PAN")
    pan.number_encrypted = __import__("apps.core.crypto", fromlist=["encrypt"]).encrypt(
        "ABCDE1234F"
    )
    pan.save()
    url, expires_at = kyc.document_file_url(pan.pk, by=ops)
    assert url
    assert expires_at
    assert kyc.document_number(pan.pk, by=ops) == "ABCDE1234F"
    assert set(AuditLog.objects.values_list("action", flat=True)) == {
        "rider.document_view",
        "rider.document_number_view",
    }
    manager = staff(roles.STORE_MANAGER, rider.preferred_store)
    with pytest.raises(PermissionDenied):
        kyc.document_file_url(pan.pk, by=manager)
    with pytest.raises(PermissionDenied):
        kyc.document_number(pan.pk, by=manager)
    with pytest.raises(ValidationError):
        kyc.document_file_url(999999, by=ops)
    with pytest.raises(ValidationError):
        kyc.document_number(999999, by=ops)


# --------------------------------------------------------------------------- suspend etc.


def test_suspend_sets_offline_and_reinstate(ops):
    rider = active_rider()
    from django.contrib.gis.geos import Point
    from django.utils import timezone

    RiderShift.objects.create(
        rider=rider, started_at=timezone.now(), start_location=Point(77.05, 28.45, srid=4326)
    )
    Rider.objects.filter(pk=rider.pk).update(is_online=True)
    rider = kyc.suspend_rider(rider.pk, by=ops, reason="Repeated no-shows")
    rider.refresh_from_db()
    assert rider.status == RiderStatus.SUSPENDED
    assert not rider.is_online
    shift = RiderShift.objects.get(rider=rider)
    assert shift.end_reason == ShiftEndReason.ADMIN
    assert shift.ended_by == ops
    with pytest.raises(ApiError):
        kyc.suspend_rider(rider.pk, by=ops, reason="again")
    rider = kyc.reinstate_rider(rider.pk, by=ops)
    assert rider.status == RiderStatus.ACTIVE
    assert rider.suspension_reason == ""
    with pytest.raises(ApiError):
        kyc.reinstate_rider(rider.pk, by=ops)


def test_home_store_and_cash_limit(ops):
    rider = active_rider()
    store = DarkStoreFactory()
    assert kyc.set_home_store(rider.pk, store.pk, by=ops).home_store_id == store.pk
    with pytest.raises(ValidationError):
        kyc.set_home_store(rider.pk, DarkStoreFactory(is_active=False).pk, by=ops)
    Rider.objects.filter(pk=rider.pk).update(is_online=True)
    with pytest.raises(ApiError):
        kyc.set_home_store(rider.pk, store.pk, by=ops)
    assert kyc.set_cash_limit(rider.pk, "2500.50", by=ops).cash_limit == Decimal("2500.50")
    for bad in ["-1", "abc", "1.234", "NaN", "2000000"]:
        with pytest.raises(ValidationError):
            kyc.set_cash_limit(rider.pk, bad, by=ops)
