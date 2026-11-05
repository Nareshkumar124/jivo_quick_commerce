"""Riders admin (05 §2 "Riders", 05 §3 "Rider approval / suspend"; Phase 5): role matrix, store
scoping (another store's rider or document is a 404), PII per role, review actions only through
`apps.delivery.services.kyc` (audited, with the request IP), KYC file and number only on
request, shifts and locations read-only."""

import pytest
from django.contrib.gis.geos import Point
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.choices import RiderStatus
from apps.core.models import AuditLog
from apps.delivery.choices import DocumentStatus
from apps.delivery.models import RiderLocation, RiderShift
from apps.delivery.tests.factories import RiderDocumentFactory, RiderFactory, complete_rider
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    NON_STAFF,
    PRINCIPALS,
    login_with_stores,
    staff_in_role,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

_SA = {roles.SUPER_ADMIN, "superuser flag"}
VIEW_ROLES = frozenset({*_SA, roles.OPS, roles.STORE_MANAGER})
REVIEW_ROLES = frozenset({*_SA, roles.OPS})
PHONE = "+919822200011"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def world():
    own = DarkStoreFactory(code="GGN-01")
    other = DarkStoreFactory(code="NOI-18")
    rider = complete_rider(preferred_store=own, user__phone=PHONE)
    foreign = RiderFactory(preferred_store=other)
    return {
        "own": own,
        "other": other,
        "rider": rider,
        "doc": rider.documents.order_by("pk").first(),
        "foreign": foreign,
        "foreign_doc": RiderDocumentFactory(rider=foreign),
    }


def expected(principal, allowed) -> int:
    if principal in allowed:
        return 200
    if principal in (NON_STAFF, ANONYMOUS):
        return 302
    return 403


@pytest.mark.parametrize(
    "url_name", ["admin:delivery_rider_changelist", "admin:delivery_riderdocument_changelist"]
)
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_list_matrix(client, world, principal, url_name):
    login_with_stores(client, principal, world["own"])
    assert client.get(reverse(url_name)).status_code == expected(principal, VIEW_ROLES), principal


def test_store_manager_sees_only_own_store_riders(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    html = client.get(reverse("admin:delivery_rider_changelist")).content.decode()
    assert world["rider"].full_name in html
    assert world["foreign"].full_name not in html
    for url in (
        reverse("admin:delivery_rider_change", args=[world["foreign"].pk]),
        reverse("admin:delivery_riderdocument_change", args=[world["foreign_doc"].pk]),
    ):
        assert client.get(url).status_code == 404


def test_pii_per_role(client, world):
    rider_url = reverse("admin:delivery_rider_change", args=[world["rider"].pk])
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    html = client.get(rider_url).content.decode()
    assert PHONE not in html
    assert "+91 XXXXXX0011" in html
    assert "12 Apr 1998" not in html
    assert "50100123456789" not in html
    client.force_login(staff_in_role(roles.OPS))
    html = client.get(rider_url).content.decode()
    assert PHONE in html
    assert "12 Apr 1998" in html
    assert "•••• 6789" in html
    assert "50100123456789" not in html  # never the full account number


@pytest.mark.parametrize("principal", sorted(VIEW_ROLES - {"superuser flag"}))
def test_review_actions_offered_only_to_reviewers(client, world, principal):
    login_with_stores(client, principal, world["own"])
    url = reverse("admin:delivery_rider_approve", args=[world["rider"].pk])
    response = client.get(url)
    assert response.status_code == (200 if principal in REVIEW_ROLES else 403), principal


def test_approve_goes_through_the_service_and_is_audited(client, world):
    staff = staff_in_role(roles.OPS)
    client.force_login(staff)
    url = reverse("admin:delivery_rider_approve", args=[world["rider"].pk])
    response = client.post(url, {"home_store": str(world["own"].pk), "cash_limit": ""})
    assert response.status_code == 302
    world["rider"].refresh_from_db()
    assert world["rider"].status == RiderStatus.ACTIVE
    entry = AuditLog.objects.filter(actor=staff, object_id=str(world["rider"].pk)).latest("id")
    assert entry.ip == "127.0.0.1"


def test_reject_needs_a_reason(client, world):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse("admin:delivery_rider_reject", args=[world["rider"].pk])
    assert client.post(url, {"reason": ""}).status_code == 200  # form error, nothing changed
    world["rider"].refresh_from_db()
    assert world["rider"].status == RiderStatus.PENDING_KYC
    assert client.post(url, {"reason": "Blurred photo"}).status_code == 302
    world["rider"].refresh_from_db()
    assert world["rider"].status == RiderStatus.REJECTED


def test_service_refusal_is_a_message(client, world):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse("admin:delivery_rider_reinstate", args=[world["rider"].pk])
    response = client.post(url, follow=True)
    assert "Only a suspended rider can be reinstated." in response.content.decode()


def test_document_review_and_file_access(client, world):
    staff = staff_in_role(roles.OPS)
    client.force_login(staff)
    fresh = RiderFactory(preferred_store=world["own"])
    doc = RiderDocumentFactory(rider=fresh, doc_type="PAN")
    approve = reverse("admin:delivery_riderdocument_approve_document", args=[doc.pk])
    assert client.post(approve).status_code == 302
    doc.refresh_from_db()
    assert doc.status == DocumentStatus.APPROVED
    url = reverse("admin:delivery_riderdocument_open_file", args=[doc.pk])
    before = AuditLog.objects.filter(actor=staff, object_id=str(doc.pk)).count()
    page = client.get(url)  # a confirm page: a prefetch makes no audited view
    assert page.status_code == 200
    assert AuditLog.objects.filter(actor=staff, object_id=str(doc.pk)).count() == before
    response = client.post(url)
    assert response.status_code == 302  # to the short-lived signed URL
    assert AuditLog.objects.filter(actor=staff, object_id=str(doc.pk)).count() == before + 1


def test_store_manager_cannot_open_kyc_files(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    for name in ("open_file", "show_number"):
        url = reverse(f"admin:delivery_riderdocument_{name}", args=[world["doc"].pk])
        assert client.get(url).status_code == 403, name


def test_document_number_is_not_cached(client, world):
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    url = reverse("admin:delivery_riderdocument_show_number", args=[world["doc"].pk])
    assert 'data-testid="document-number"' not in client.get(url).content.decode()  # confirm
    response = client.post(url)
    assert response.status_code in (200, 302)
    if response.status_code == 200:
        assert "no-store" in response["Cache-Control"]


def test_shifts_and_locations_are_read_only_and_scoped(client, world):
    shift = RiderShift.objects.create(
        rider=world["rider"],
        started_at=timezone.now(),
        start_location=Point(77.05, 28.45, srid=4326),
    )
    location = RiderLocation.objects.create(
        rider=world["rider"],
        point=Point(77.051234, 28.451234, srid=4326),
        accuracy_m=5,
        recorded_at=timezone.now(),
    )
    client.force_login(staff_in_role(roles.SUPER_ADMIN))
    html = client.get(reverse("admin:delivery_riderlocation_changelist")).content.decode()
    assert "28.4512, 77.0512" in html
    assert "28.451234" not in html
    assert client.get(reverse("admin:delivery_ridershift_add")).status_code == 403
    change = reverse("admin:delivery_ridershift_change", args=[shift.pk])
    assert 'name="_save"' not in client.get(change).content.decode()
    client.force_login(staff_in_role(roles.OPS))  # no location permission
    url = reverse("admin:delivery_riderlocation_change", args=[location.pk])
    assert client.get(url).status_code == 403
