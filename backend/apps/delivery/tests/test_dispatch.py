"""Slice 5.3 (T-514a): dispatch, offers, expiry, re-offer, give-up, ops actions (08 §5, §3)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.core.exceptions import PermissionDenied, ValidationError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.choices import RiderStatus
from apps.core.exceptions import ApiError
from apps.delivery import hooks
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import DeliveryOffer, DeliveryTask, Rider
from apps.delivery.services import dispatch
from apps.orders.choices import OrderStatus

pytestmark = pytest.mark.django_db

CURRENT = "/api/v1/rider/offers/current/"


def accept_url(offer):
    return f"/api/v1/rider/offers/{offer.pk}/accept/"


def reject_url(offer):
    return f"/api/v1/rider/offers/{offer.pk}/reject/"


@pytest.fixture
def accepted(place, store_steps):
    order = place()
    store_steps.accept(order)
    order.refresh_from_db()
    return order


def offer_of(order) -> DeliveryOffer:
    return DeliveryOffer.objects.get(task__order=order, status=OfferStatus.PENDING)


# --------------------------------------------------------------------------- trigger


def test_accepting_an_order_starts_dispatch(
    place, store_steps, make_rider, django_capture_on_commit_callbacks
):
    rider = make_rider()
    order = place()
    with django_capture_on_commit_callbacks(execute=True):
        store_steps.accept(order)
    task = DeliveryTask.objects.get(order=order)
    assert task.status == TS.OFFERED
    assert offer_of(order).rider == rider


def test_dispatch_trigger_placed(place, make_rider, settings, django_capture_on_commit_callbacks):
    settings.DISPATCH_TRIGGER = "PLACED"
    make_rider()
    with django_capture_on_commit_callbacks(execute=True):
        order = place()
    assert DeliveryTask.objects.get(order=order).status == TS.OFFERED


def test_dispatch_skips_orders_not_dispatchable(place):
    order = place()
    order.status = OrderStatus.PAYMENT_PENDING
    order.save(update_fields=["status"])
    assert dispatch.dispatch_order(order.pk) == "skipped"
    assert dispatch.dispatch_order(999999) == "skipped"


# --------------------------------------------------------------------------- candidates


def test_candidates_rules(accepted, make_rider, shop):
    order = accepted
    good = make_rider()
    make_rider(online=False)  # offline
    stale = make_rider()
    Rider.objects.filter(pk=stale.pk).update(
        last_location_received_at=timezone.now() - timedelta(minutes=5)
    )
    other_store = make_rider()
    Rider.objects.filter(pk=other_store.pk).update(home_store=shop.other_store_model)
    suspended = make_rider()
    Rider.objects.filter(pk=suspended.pk).update(status=RiderStatus.SUSPENDED, is_online=False)
    over_cash = make_rider()
    Rider.objects.filter(pk=over_cash.pk).update(cash_in_hand=Decimal("4900.00"))
    task = dispatch.ensure_task(order, timezone.now())
    found = dispatch.candidates(task, order, timezone.now())
    assert found == [good]


def test_cash_limit_only_applies_to_cod(place, store_steps, make_rider):
    rider = make_rider()
    Rider.objects.filter(pk=rider.pk).update(cash_in_hand=Decimal("4999.00"))
    order = place("ONLINE")
    store_steps.accept(order)
    assert dispatch.dispatch_order(order.pk) == "offered"
    assert offer_of(order).rider_id == rider.pk


def test_ranking_at_store_by_idle_then_nearest(accepted, make_rider):
    far = make_rider((28.47, 77.05))  # about 2.2 km
    near = make_rider((28.455, 77.05))  # about 560 m
    at_store_busy_recently = make_rider((28.4505, 77.05))
    at_store_idle_longest = make_rider((28.4502, 77.0501))
    now = timezone.now()
    Rider.objects.filter(pk=at_store_busy_recently.pk).update(approved_at=now)
    Rider.objects.filter(pk=at_store_idle_longest.pk).update(approved_at=now - timedelta(hours=3))
    task = dispatch.ensure_task(accepted, now)
    ranked = dispatch.candidates(task, accepted, now)
    assert ranked == [at_store_idle_longest, at_store_busy_recently, near, far]


def test_busy_rider_and_rider_with_pending_offer_are_skipped(place, store_steps, make_rider):
    rider = make_rider()
    first, second = place(), place()
    store_steps.accept(first)
    store_steps.accept(second)
    assert dispatch.dispatch_order(first.pk) == "offered"
    assert dispatch.dispatch_order(second.pk) == "no_candidate"  # one offer at a time
    task = DeliveryTask.objects.get(order=second)
    assert task.status == TS.SEARCHING
    assert task.next_dispatch_at is not None
    assert dispatch.dispatch_order(second.pk) == "waiting"  # not before the retry time
    assert offer_of(first).rider == rider


# --------------------------------------------------------------------------- offers API


def test_current_offer_and_accept(accepted, make_rider, rider_client):
    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    client = rider_client(rider)
    body = client.get(CURRENT).json()
    offer = body["offer"]
    assert offer["store_name"] == accepted.store.name
    assert offer["payment_type"] == "COD"
    assert offer["cod_amount"] == str(accepted.grand_total)
    assert offer["estimated_payout"] == "30.00"  # base pay, drop at the store's pin
    assert offer["item_count"] == 2
    assert "Flat 402" not in str(body)  # no full address before accepting
    response = client.post(accept_url(offer_of(accepted)))
    assert response.status_code == 200, response.json()
    task = response.json()
    assert task["status"] == "ASSIGNED"
    assert task["customer_address"]["house"] == "Flat 402"
    assert task["cod_amount_due"] == str(accepted.grand_total)
    assert task["cod_amount_previous"] is None
    assert client.get(CURRENT).json()["offer"] is None


def test_accept_is_idempotent(accepted, make_rider, rider_client):
    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    client = rider_client(rider)
    first = client.post(accept_url(offer)).json()
    again = client.post(accept_url(offer))
    assert again.status_code == 200
    assert again.json()["id"] == first["id"]


def test_late_accept_is_offer_expired_and_redispatches(accepted, make_rider, rider_client):
    first = make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    second = make_rider()
    DeliveryOffer.objects.filter(pk=offer.pk).update(
        expires_at=timezone.now() - timedelta(seconds=1)
    )
    response = rider_client(first).post(accept_url(offer))
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "OFFER_EXPIRED"
    offer.refresh_from_db()
    assert offer.status == OfferStatus.EXPIRED  # kept although the request failed
    assert DeliveryTask.objects.get(order=accepted).status == TS.SEARCHING
    assert dispatch.dispatch_order(accepted.pk) == "offered"
    assert offer_of(accepted).rider == second


def test_accept_after_cancellation_is_offer_taken(accepted, make_rider, rider_client, admin):
    from apps.orders import store_ops

    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    store_ops.cancel_by_staff(accepted.pk, by=admin, reason="CUSTOMER_REQUEST")
    offer.refresh_from_db()
    assert offer.status == OfferStatus.WITHDRAWN
    assert DeliveryTask.objects.get(order=accepted).status == TS.CANCELLED
    response = rider_client(rider).post(accept_url(offer))
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "OFFER_TAKEN"


def test_two_riders_one_order(accepted, make_rider, rider_client):
    """Race: the first offer expired and went to rider B; A's late accept loses, B wins."""
    a, b = make_rider(), make_rider((28.4510, 77.05))
    dispatch.dispatch_order(accepted.pk)
    offer_a = offer_of(accepted)
    assert offer_a.rider == a
    DeliveryOffer.objects.filter(pk=offer_a.pk).update(expires_at=timezone.now())
    assert dispatch.expire_offer(offer_a.pk) == "expired"
    dispatch.dispatch_order(accepted.pk)
    offer_b = offer_of(accepted)
    assert offer_b.rider == b
    assert rider_client(a).post(accept_url(offer_a)).json()["error"]["code"] == "OFFER_EXPIRED"
    assert rider_client(b).post(accept_url(offer_b)).status_code == 200
    task = DeliveryTask.objects.get(order=accepted)
    assert (task.status, task.rider) == (TS.ASSIGNED, b)


def test_accept_while_offline_is_refused(accepted, make_rider, rider_client):
    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    Rider.objects.filter(pk=rider.pk).update(is_online=False)
    response = rider_client(rider).post(accept_url(offer_of(accepted)))
    assert response.json()["error"]["code"] == "RIDER_OFFLINE"


def test_offer_idor(accepted, make_rider, rider_client):
    owner, other = make_rider(), make_rider((28.46, 77.05))
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    assert offer.rider == owner
    assert rider_client(other).post(accept_url(offer)).status_code == 404
    assert rider_client(other).post(reject_url(offer), {}, format="json").status_code == 404
    assert rider_client(other).get(CURRENT).json()["offer"] is None


def test_reject_offers_the_next_rider(accepted, make_rider, rider_client):
    first = make_rider()
    second = make_rider((28.4510, 77.05))
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    client = rider_client(first)
    response = client.post(reject_url(offer), {"reason": "TOO_FAR"}, format="json")
    assert response.status_code == 204
    offer.refresh_from_db()
    assert (offer.status, offer.reject_reason) == (OfferStatus.REJECTED, "TOO_FAR")
    assert client.post(reject_url(offer), {}, format="json").status_code == 204  # no-op
    dispatch.dispatch_order(accepted.pk)
    assert offer_of(accepted).rider == second


def test_reject_after_accept_is_409(accepted, make_rider, rider_client):
    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    client = rider_client(rider)
    client.post(accept_url(offer))
    assert client.post(reject_url(offer), {}, format="json").status_code == 409


# --------------------------------------------------------------------------- expiry & give-up


def test_expire_offer_is_idempotent_and_waits_for_expiry(accepted, make_rider):
    make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    assert dispatch.expire_offer(offer.pk) == "not_due"
    later = offer.expires_at + timedelta(seconds=1)
    assert dispatch.expire_offer(offer.pk, now=later) == "expired"
    assert dispatch.expire_offer(offer.pk, now=later) == "skipped"
    assert dispatch.expire_offer(999999) == "skipped"


def test_give_up_after_max_attempts_then_resume(accepted, make_rider, settings, monkeypatch):
    settings.MAX_OFFER_ATTEMPTS = 2
    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append(kind))
    riders = [make_rider((28.4501 + i / 10000, 77.05)) for i in range(3)]
    now = timezone.now()
    for _ in range(2):
        assert dispatch.dispatch_order(accepted.pk, now=now) == "offered"
        offer = offer_of(accepted)
        now = offer.expires_at + timedelta(seconds=1)
        dispatch.expire_offer(offer.pk, now=now)
    assert dispatch.dispatch_order(accepted.pk, now=now) == "unassigned"
    task = DeliveryTask.objects.get(order=accepted)
    assert task.status == TS.UNASSIGNED
    assert task.unassigned_at is not None
    # The alert runs after commit; call the dispatch result's alert check directly.
    assert dispatch.dispatch_order(accepted.pk, now=now) == "paused"
    resume = now + timedelta(seconds=61)
    for rider in riders:
        Rider.objects.filter(pk=rider.pk).update(last_location_received_at=resume)
    assert dispatch.dispatch_order(accepted.pk, now=resume) == "offered"  # a new round
    assert DeliveryTask.objects.get(order=accepted).attempt_count == 1


def test_give_up_after_timeout(accepted):
    now = timezone.now()
    dispatch.dispatch_order(accepted.pk, now=now)  # no rider: searching
    later = now + timedelta(seconds=181)
    assert dispatch.dispatch_order(accepted.pk, now=later) == "unassigned"


def test_unassigned_alert_is_sent(accepted, monkeypatch, django_capture_on_commit_callbacks):
    alerts = []
    monkeypatch.setattr(hooks, "ops_alert", lambda kind, data: alerts.append((kind, data)))
    now = timezone.now()
    dispatch.dispatch_order(accepted.pk, now=now)
    with django_capture_on_commit_callbacks(execute=True):
        dispatch.dispatch_order(accepted.pk, now=now + timedelta(minutes=4))
    assert alerts[0][0] == "DISPATCH_UNASSIGNED"
    assert alerts[0][1]["order_number"] == accepted.order_number


def test_sweep_expires_and_redispatches(accepted, make_rider):
    first = make_rider()
    dispatch.dispatch_order(accepted.pk)
    offer = offer_of(accepted)
    second = make_rider((28.4510, 77.05))
    later = offer.expires_at + timedelta(seconds=1)
    Rider.objects.filter(pk__in=[first.pk, second.pk]).update(last_location_received_at=later)
    result = dispatch.dispatch_sweep(now=later)
    assert result == {"expired": 1, "dispatched": 1}
    assert offer_of(accepted).rider == second


def test_offer_push_and_websocket_through_hooks(
    accepted, make_rider, monkeypatch, django_capture_on_commit_callbacks
):
    calls = []
    monkeypatch.setattr(hooks, "send_push", lambda user, event, data: calls.append(event))
    monkeypatch.setattr(hooks, "publish_offer", lambda rider_id, body: calls.append("ws"))
    make_rider()
    with django_capture_on_commit_callbacks(execute=True):
        dispatch.dispatch_order(accepted.pk)
    assert calls == ["rider.offer_new", "ws"]


def test_going_offline_withdraws_the_pending_offer(
    accepted, make_rider, rider_client, django_capture_on_commit_callbacks
):
    rider = make_rider()
    dispatch.dispatch_order(accepted.pk)
    with django_capture_on_commit_callbacks(execute=True):
        assert rider_client(rider).post("/api/v1/rider/shift/end/").status_code == 200
    assert DeliveryOffer.objects.get(task__order=accepted).status == OfferStatus.WITHDRAWN
    assert DeliveryTask.objects.get(order=accepted).status in (TS.SEARCHING, TS.OFFERED)


def test_packed_order_with_no_rider_raises_priority(
    place, store_steps, make_rider, django_capture_on_commit_callbacks
):
    order = place()
    store_steps.accept(order)
    dispatch.dispatch_order(order.pk)  # nobody online: retry later
    make_rider()
    with django_capture_on_commit_callbacks(execute=True):
        store_steps.pack(order)
    assert DeliveryTask.objects.get(order=order).status == TS.OFFERED


def test_packed_order_tells_the_assigned_rider(
    place, store_steps, make_rider, rider_client, monkeypatch, django_capture_on_commit_callbacks
):
    calls = []
    monkeypatch.setattr(hooks, "send_push", lambda user, event, data: calls.append(event))
    rider = make_rider()
    order = place()
    store_steps.accept(order)
    dispatch.dispatch_order(order.pk)
    rider_client(rider).post(accept_url(offer_of(order)))
    with django_capture_on_commit_callbacks(execute=True):
        store_steps.pack(order)
    assert "rider.order_ready" in calls


def test_cod_amount_change_reaches_the_task(place, store_steps, make_rider, rider_client, admin):
    from apps.orders import store_ops

    rider = make_rider()
    order = place()
    store_steps.accept(order)
    dispatch.dispatch_order(order.pk)
    client = rider_client(rider)
    client.post(accept_url(offer_of(order)))
    before = order.grand_total
    item = order.items.get()
    store_ops.mark_item_unavailable(order.pk, item.pk, unavailable=1, by=admin)
    body = client.get("/api/v1/rider/tasks/current/").json()["task"]
    assert body["cod_amount_previous"] == str(before)
    assert Decimal(body["cod_amount_due"]) < before
    assert body["item_count"] == 1


# --------------------------------------------------------------------------- ops


def _ops(*role_names, stores=()):
    from django.contrib.auth.models import Group

    from apps.accounts.tests.factories import StaffUserFactory
    from apps.stores.services import grant_store_access

    roles.sync_roles()
    user = StaffUserFactory()
    for name in role_names:
        user.groups.add(Group.objects.get(name=name))
    for store in stores:
        grant_store_access(user, store)
    return user


def test_manual_assign_bypasses_the_offer(accepted, make_rider, monkeypatch):
    first = make_rider()
    dispatch.dispatch_order(accepted.pk)
    chosen = make_rider((28.4510, 77.05))
    ops = _ops(roles.OPS)
    task = dispatch.manual_assign(accepted.pk, chosen.pk, by=ops, ip="203.0.113.9")
    assert (task.status, task.rider, task.assignment_mode) == (TS.ASSIGNED, chosen, "MANUAL")
    assert DeliveryOffer.objects.get(rider=first).status == OfferStatus.WITHDRAWN
    with pytest.raises(ApiError):
        dispatch.manual_assign(accepted.pk, first.pk, by=ops)  # already has a rider


def test_manual_assign_guards(accepted, make_rider, shop):
    ops = _ops(roles.OPS)
    offline = make_rider(online=False)
    with pytest.raises(ValidationError, match="offline"):
        dispatch.manual_assign(accepted.pk, offline.pk, by=ops)
    rich = make_rider()
    Rider.objects.filter(pk=rich.pk).update(cash_in_hand=Decimal("4990.00"))
    with pytest.raises(ApiError) as exc:
        dispatch.manual_assign(accepted.pk, rich.pk, by=ops)
    assert exc.value.error_code == "CASH_LIMIT_EXCEEDED"
    elsewhere = make_rider()
    Rider.objects.filter(pk=elsewhere.pk).update(home_store=shop.other_store_model)
    with pytest.raises(ValidationError):
        dispatch.manual_assign(accepted.pk, elsewhere.pk, by=ops)


def test_dispatch_permissions_and_scope(accepted, make_rider, shop):
    rider = make_rider()
    with pytest.raises(PermissionDenied):
        dispatch.manual_assign(
            accepted.pk, rider.pk, by=_ops(roles.STORE_STAFF, stores=[shop.store_model])
        )
    with pytest.raises(PermissionDenied):
        dispatch.manual_assign(accepted.pk, rider.pk, by=_ops(roles.SUPPORT))
    other_manager = _ops(roles.STORE_MANAGER, stores=[shop.other_store_model])
    with pytest.raises(ValidationError, match="Order not found"):
        dispatch.manual_assign(accepted.pk, rider.pk, by=other_manager)
    manager = _ops(roles.STORE_MANAGER, stores=[shop.store_model])
    assert dispatch.manual_assign(accepted.pk, rider.pk, by=manager).rider == rider


def test_unassign_and_retry(accepted, make_rider):
    ops = _ops(roles.OPS)
    rider = make_rider()
    dispatch.manual_assign(accepted.pk, rider.pk, by=ops)
    task = dispatch.unassign(accepted.pk, by=ops)
    assert (task.status, task.rider) == (TS.SEARCHING, None)
    with pytest.raises(ApiError):
        dispatch.unassign(accepted.pk, by=ops)
    with pytest.raises(ApiError):
        dispatch.retry_dispatch(accepted.pk, by=ops)
    DeliveryTask.objects.filter(pk=task.pk).update(status=TS.UNASSIGNED)
    task = dispatch.retry_dispatch(accepted.pk, by=ops)
    assert task.status == TS.SEARCHING
    assert task.attempt_count == 0
    from apps.core.models import AuditLog

    assert set(AuditLog.objects.values_list("action", flat=True)) >= {
        "delivery.manual_assign",
        "delivery.unassign",
        "delivery.retry_dispatch",
    }


def test_redispatch_round_can_reoffer_riders_from_earlier_rounds(accepted, make_rider, settings):
    """Review M2: the "already offered" exclusion covers only the current round (offers since
    `search_started_at`), so after a give-up and resume the same rider can be offered again."""
    settings.MAX_OFFER_ATTEMPTS = 1
    rider = make_rider()
    now = timezone.now()
    assert dispatch.dispatch_order(accepted.pk, now=now) == "offered"
    offer = offer_of(accepted)
    now = offer.expires_at + timedelta(seconds=1)
    Rider.objects.filter(pk=rider.pk).update(last_location_received_at=now)
    dispatch.expire_offer(offer.pk, now=now)
    # Same round: the rider who let the offer expire is not offered again.
    task = DeliveryTask.objects.get(order=accepted)
    assert dispatch.candidates(task, accepted, now) == []
    assert dispatch.dispatch_order(accepted.pk, now=now) == "unassigned"
    resume = now + timedelta(seconds=settings.DISPATCH_UNASSIGNED_PAUSE_SECONDS + 1)
    Rider.objects.filter(pk=rider.pk).update(last_location_received_at=resume)
    assert dispatch.dispatch_order(accepted.pk, now=resume) == "offered"  # a new round
    assert offer_of(accepted).rider == rider
    assert DeliveryOffer.objects.filter(task__order=accepted, rider=rider).count() == 2
