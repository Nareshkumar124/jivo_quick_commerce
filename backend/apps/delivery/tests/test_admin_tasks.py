"""Read-only DeliveryTask / DeliveryOffer admins (slice 5.3, T-517b): role matrix, store scoping
(another store's task or offer is a 404), no add / change / delete, codes never shown."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.core.crypto import encrypt
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import DeliveryOffer, DeliveryTask
from apps.delivery.tests.factories import active_rider
from apps.ops_console.tests.helpers import (
    _SA,
    PRINCIPALS,
    expected_status,
    login_with_stores,
    staff_in_role,
)
from apps.ops_console.tests.orders_support import make_order
from apps.orders.choices import OrderStatus
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

VIEW_ROLES = frozenset({*_SA, roles.OPS, roles.STORE_MANAGER})
PICKUP_CODE = "Z9P4"
OTP = "771204"


@pytest.fixture(autouse=True)
def _roles(db):
    roles.sync_roles()


def _task(store, number, rider) -> DeliveryTask:
    code = PICKUP_CODE if not DeliveryTask.objects.filter(store=store).exists() else ""
    order = make_order(store, OrderStatus.PACKED, order_number=number, pickup_code=code)
    now = timezone.now()
    task = DeliveryTask.objects.create(
        order=order,
        store=store,
        status=TS.ASSIGNED,
        rider=rider,
        assignment_mode="AUTO",
        search_started_at=now,
        assigned_at=now,
        distance_km=Decimal("1.20"),
        payout_amount=Decimal("30.00"),
        delivery_otp_encrypted=encrypt(OTP),
        otp_locked_at=now,
    )
    DeliveryOffer.objects.create(
        task=task,
        rider=rider,
        status=OfferStatus.ACCEPTED,
        offered_at=now,
        expires_at=now + timedelta(seconds=30),
        responded_at=now,
    )
    return task


@pytest.fixture
def world():
    own = DarkStoreFactory(code="GGN-01")
    other = DarkStoreFactory(code="NOI-18")
    return {
        "own": own,
        "other": other,
        "task": _task(own, "JV-ADM-0001", active_rider(preferred_store=own)),
        "other_task": _task(other, "JV-ADM-0009", active_rider(preferred_store=other)),
    }


@pytest.mark.parametrize("model", ["deliverytask", "deliveryoffer"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_changelist_role_matrix(client, world, principal, model):
    login_with_stores(client, principal, world["own"])
    response = client.get(reverse(f"admin:delivery_{model}_changelist"))
    assert response.status_code == expected_status(principal, VIEW_ROLES), principal


def test_store_manager_scoped_and_other_store_is_404(client, world):
    login_with_stores(client, roles.STORE_MANAGER, world["own"])
    content = client.get(reverse("admin:delivery_deliverytask_changelist")).content.decode()
    assert "JV-ADM-0001" in content
    assert "JV-ADM-0009" not in content
    other = world["other_task"]
    assert (
        client.get(reverse("admin:delivery_deliverytask_change", args=[other.pk])).status_code
        == 404
    )
    other_offer = other.offers.get()
    url = reverse("admin:delivery_deliveryoffer_change", args=[other_offer.pk])
    assert client.get(url).status_code == 404
    offers = client.get(reverse("admin:delivery_deliveryoffer_changelist")).content.decode()
    assert "JV-ADM-0001" in offers
    assert "JV-ADM-0009" not in offers


def test_detail_is_read_only_and_hides_codes(client, world):
    client.force_login(staff_in_role(roles.OPS))
    task = world["task"]
    response = client.get(reverse("admin:delivery_deliverytask_change", args=[task.pk]))
    assert response.status_code == 200
    content = response.content.decode()
    assert PICKUP_CODE not in content
    assert OTP not in content
    assert "Locked" in content
    assert reverse("ops:dispatch-task", args=[task.pk]) in content
    assert 'name="_save"' not in content
    assert client.get(reverse("admin:delivery_deliverytask_add")).status_code == 403
    delete = reverse("admin:delivery_deliverytask_delete", args=[task.pk])
    assert client.post(delete, {"post": "yes"}).status_code == 403
    assert DeliveryTask.objects.filter(pk=task.pk).exists()
    change = reverse("admin:delivery_deliverytask_change", args=[task.pk])
    client.post(change, {"status": TS.CANCELLED})
    assert DeliveryTask.objects.get(pk=task.pk).status == TS.ASSIGNED


def test_changelist_query_count_is_flat(client, world, django_assert_max_num_queries):
    client.force_login(staff_in_role(roles.OPS))
    url = reverse("admin:delivery_deliverytask_changelist")
    for index in range(10):
        _task(world["own"], f"JV-ADM-1{index:03}", active_rider(preferred_store=world["own"]))
    client.get(url)
    with django_assert_max_num_queries(20):
        client.get(url)
