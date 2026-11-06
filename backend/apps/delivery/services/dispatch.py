"""Dispatch (08 §5, §3; slice 5.3): delivery tasks, offers, expiry, re-offer, give-up, and the
ops actions (manual assign, unassign, retry).

Lock order on every path (no deadlocks): the Order row, then the DeliveryTask, then offers,
then the Rider. Rider-first callers (going offline, suspension) never lock tasks; they withdraw
the rider's offers after commit through `withdraw_rider_offers`, which takes the normal order.

Scheduling: `dispatch_sweep` (beat, every 15 s) is the backbone: it expires due offers,
re-runs searches whose retry time has come, and resumes UNASSIGNED tasks after the pause.
Countdown tasks (`expire_offer` at the offer's expiry, a retry when nobody was free) only make
it faster; they are skipped when Celery runs eagerly (tests drive time explicitly).

Ranking (08 §5 step 2): riders within `DISPATCH_AT_STORE_RADIUS_M` of the store first, longest
idle first (idle since the end of their last task, else their approval); then the others by
straight-line distance to the store (PostGIS), nearest first.
"""

import logging
from datetime import timedelta
from decimal import ROUND_HALF_UP, Decimal

from django.conf import settings
from django.contrib.gis.db.models.functions import Distance
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import IntegrityError, transaction
from django.db.models import Exists, F, OuterRef, Subquery
from django.db.models.functions import Coalesce
from django.utils import timezone

from apps.accounts.choices import RiderStatus
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.delivery import hooks
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.choices import OfferStatus
from apps.delivery.models import (
    RIDER_BUSY_STATUSES,
    AssignmentMode,
    DeliveryOffer,
    DeliveryTask,
    Rider,
)
from apps.delivery.services.riders import require_rider
from apps.orders.choices import OrderStatus, PaymentMethod
from apps.orders.models import Order
from apps.stores.services import haversine_km

logger = logging.getLogger(__name__)

DISPATCHABLE_ORDER_STATUSES = frozenset(
    {OrderStatus.PLACED, OrderStatus.ACCEPTED, OrderStatus.PACKING, OrderStatus.PACKED}
)
# Before pickup: a cancellation (T11/T12) or ops can still take the task from the rider.
CANCELLABLE_TASK_STATUSES = frozenset(
    {TS.SEARCHING, TS.OFFERED, TS.UNASSIGNED, TS.ASSIGNED, TS.AT_STORE}
)
MSG_OFFER_NOT_FOUND = "Offer not found."
MSG_ORDER_NOT_FOUND = "Order not found."
MSG_NO_PERMISSION = "You do not have permission to do this."
DISPATCH_PERMISSION = "delivery.dispatch_order"


# --------------------------------------------------------------------------- helpers


def _later(task, args: tuple, seconds: float) -> None:
    """A countdown task after commit; skipped under eager Celery (see the module doc)."""
    if getattr(settings, "CELERY_TASK_ALWAYS_EAGER", False):
        return
    transaction.on_commit(lambda: task.apply_async(args, countdown=max(seconds, 0)))


def _soon(order_id: int) -> None:
    """Run dispatch for the order right after commit."""
    from apps.delivery.tasks import dispatch_order

    transaction.on_commit(lambda: dispatch_order.delay(order_id))


def estimate(order: Order) -> tuple[Decimal, Decimal]:
    """`(distance_km, payout)`: store-to-drop straight line x the road factor (08 §8; the route
    distance used for distance pay, never the GPS trail) and the pay estimate (the earning rule
    in force, `earnings.estimate`)."""
    store = order.store
    km = haversine_km(
        store.location.y, store.location.x, order.delivery_location.y, order.delivery_location.x
    )
    distance = Decimal(str(km * settings.ETA_ROAD_FACTOR)).quantize(
        Decimal("0.01"), rounding=ROUND_HALF_UP
    )
    from apps.delivery.services.earnings import estimate as pay_estimate

    return distance, pay_estimate(distance)


def _locked_order(order_id: int) -> Order | None:
    return (
        Order.objects.select_for_update(of=("self",))
        .select_related("store")
        .filter(pk=order_id)
        .first()
    )


def _locked_task(order: Order) -> DeliveryTask | None:
    return DeliveryTask.objects.select_for_update(of=("self",)).filter(order=order).first()


def _pending_offer(task: DeliveryTask) -> DeliveryOffer | None:
    return (
        DeliveryOffer.objects.select_for_update()
        .filter(task=task, status=OfferStatus.PENDING)
        .first()
    )


def _new_round(task: DeliveryTask, now) -> None:
    task.status = TS.SEARCHING
    task.attempt_count = 0
    task.search_started_at = now
    task.next_dispatch_at = None


def ensure_task(order: Order, now) -> DeliveryTask:
    """The order's task, created SEARCHING if missing. The caller holds the order lock."""
    task = _locked_task(order)
    if task is None:
        distance, payout = estimate(order)
        task = DeliveryTask.objects.create(
            order=order,
            store=order.store,
            status=TS.SEARCHING,
            search_started_at=now,
            distance_km=distance,
            payout_amount=payout,
        )
    return task


# --------------------------------------------------------------------------- candidates


def candidates(task: DeliveryTask, order: Order, now) -> list[Rider]:
    """08 §5 step 1 and 2, ranked."""
    busy = DeliveryTask.objects.filter(rider=OuterRef("pk"), status__in=RIDER_BUSY_STATUSES)
    pending = DeliveryOffer.objects.filter(rider=OuterRef("pk"), status=OfferStatus.PENDING)
    # Only this dispatch round's offers (since `search_started_at`): a retry or re-dispatch
    # (`_new_round`) may offer the task again to a rider who timed out or rejected earlier.
    offered = DeliveryOffer.objects.filter(
        rider=OuterRef("pk"), task=task, offered_at__gte=task.search_started_at
    )
    last_end = (
        DeliveryTask.objects.filter(rider=OuterRef("pk"), ended_at__isnull=False)
        .order_by("-ended_at")
        .values("ended_at")[:1]
    )
    riders = (
        Rider.objects.filter(
            status=RiderStatus.ACTIVE,
            is_online=True,
            home_store_id=order.store_id,
            current_location__isnull=False,
            last_location_received_at__gte=now
            - timedelta(seconds=settings.DISPATCH_PING_MAX_AGE_SECONDS),
        )
        .exclude(Exists(busy))
        .exclude(Exists(pending))
        .exclude(Exists(offered))
        .annotate(
            distance=Distance("current_location", order.store.location),
            idle_since=Coalesce(Subquery(last_end), "approved_at", "created_at"),
        )
        .select_related("user")
    )
    if order.payment_method == PaymentMethod.COD:
        # cash_in_hand + this order's amount must stay within the limit (08 §5 step 1, DL-61 b;
        # no ops override). Riders left out only for cash get the "deposit cash" banner.
        over = F("cash_in_hand") + order.grand_total
        flagged = list(
            Rider.objects.filter(
                pk__in=riders.filter(cash_limit__lt=over).values("pk"),
                cash_skipped_at__isnull=True,
            ).values_list("pk", flat=True)
        )
        if flagged:
            Rider.objects.filter(pk__in=flagged, cash_skipped_at__isnull=True).update(
                cash_skipped_at=now
            )
            for skipped in Rider.objects.filter(pk__in=flagged).select_related("user"):
                # The "deposit cash" banner turns on (T-612 `cash.updated`, with a push).
                hooks.cash_updated(
                    skipped, "DEPOSIT_REQUIRED", push_ref=f"deposit:{now.isoformat()}"
                )
        riders = riders.filter(cash_limit__gte=over)
    at_store_m = settings.DISPATCH_AT_STORE_RADIUS_M

    def rank(rider):
        meters = rider.distance.m
        if meters <= at_store_m:
            return (0, rider.idle_since.timestamp(), rider.pk)
        return (1, meters, rider.pk)

    return sorted(riders, key=rank)


# --------------------------------------------------------------------------- dispatch


def dispatch_order(order_id: int, now=None) -> str:
    """06 §5 `dispatch_order`: offer the task to the best rider, or give up (UNASSIGNED) after
    `MAX_OFFER_ATTEMPTS` offers or `DISPATCH_TIMEOUT_SECONDS`. Idempotent: a task already
    offered, assigned or ended is left alone. Returns what happened."""
    now = now or timezone.now()
    with transaction.atomic():
        order = _locked_order(order_id)
        if order is None or order.status not in DISPATCHABLE_ORDER_STATUSES:
            return "skipped"
        task = ensure_task(order, now)
        if task.status == TS.UNASSIGNED:
            if task.next_dispatch_at and now < task.next_dispatch_at:
                return "paused"
            _new_round(task, now)  # 08 §5 step 6: the auto-retry resumes after the pause
        if task.status != TS.SEARCHING:
            return "skipped"
        if task.next_dispatch_at and now < task.next_dispatch_at:
            return "waiting"
        timed_out = now - task.search_started_at >= timedelta(
            seconds=settings.DISPATCH_TIMEOUT_SECONDS
        )
        if task.attempt_count >= settings.MAX_OFFER_ATTEMPTS or timed_out:
            task.status = TS.UNASSIGNED
            task.unassigned_at = now
            task.next_dispatch_at = now + timedelta(
                seconds=settings.DISPATCH_UNASSIGNED_PAUSE_SECONDS
            )
            task.save()
            data = {"order_id": order.pk, "order_number": order.order_number, "task_id": task.pk}
            transaction.on_commit(lambda: hooks.ops_alert("DISPATCH_UNASSIGNED", data))
            _schedule_dispatch(order.pk, settings.DISPATCH_UNASSIGNED_PAUSE_SECONDS)
            logger.warning("Dispatch gave up on order %s (task %s)", order.pk, task.pk)
            return "unassigned"
        for rider in candidates(task, order, now):
            offer = _try_offer(task, rider, now)
            if offer is not None:
                task.status = TS.OFFERED
                task.attempt_count += 1
                task.next_dispatch_at = None
                task.save()
                _announce_offer(offer, order, task)
                from apps.delivery.tasks import expire_offer

                _later(expire_offer, (offer.pk,), settings.OFFER_TIMEOUT_SECONDS)
                return "offered"
        task.next_dispatch_at = now + timedelta(seconds=settings.DISPATCH_RETRY_SECONDS)
        task.save()
        _schedule_dispatch(order.pk, settings.DISPATCH_RETRY_SECONDS)
        return "no_candidate"


def _schedule_dispatch(order_id: int, seconds: float) -> None:
    from apps.delivery.tasks import dispatch_order

    _later(dispatch_order, (order_id,), seconds)


def _try_offer(task: DeliveryTask, rider: Rider, now) -> DeliveryOffer | None:
    """Create the PENDING offer; None when the rider got another offer meanwhile (the partial
    unique index on the rider's pending offer)."""
    try:
        with transaction.atomic():
            return DeliveryOffer.objects.create(
                task=task,
                rider=rider,
                status=OfferStatus.PENDING,
                offered_at=now,
                expires_at=now + timedelta(seconds=settings.OFFER_TIMEOUT_SECONDS),
            )
    except IntegrityError:
        return None


def _announce_offer(offer: DeliveryOffer, order: Order, task: DeliveryTask) -> None:
    from apps.delivery.services.presenters import offer_body

    body = offer_body(offer, order, task)
    user = offer.rider.user
    rider_id = offer.rider_id
    # `offer_id` keys the push (one per offer, so a later round's offer is pushed again).
    push = {**body, "offer_id": offer.pk}

    def send() -> None:
        hooks.send_push(user, "rider.offer_new", push)
        hooks.publish_offer(rider_id, body)

    transaction.on_commit(send)


def expire_offer(offer_id: int, now=None) -> str:
    """06 §5 `expire_offer`: a PENDING offer past `expires_at` becomes EXPIRED (a timeout counts
    as a rejection) and the next rider is tried. Early or repeated calls change nothing."""
    now = now or timezone.now()
    probe = DeliveryOffer.objects.filter(pk=offer_id).values("task__order_id").first()
    if probe is None:
        return "skipped"
    with transaction.atomic():
        order = _locked_order(probe["task__order_id"])
        task = _locked_task(order)
        offer = DeliveryOffer.objects.select_for_update().get(pk=offer_id)
        if offer.status != OfferStatus.PENDING:
            return "skipped"
        if now < offer.expires_at:
            from apps.delivery.tasks import expire_offer as expire_task

            _later(expire_task, (offer_id,), (offer.expires_at - now).total_seconds())
            return "not_due"
        offer.status = OfferStatus.EXPIRED
        offer.save(update_fields=["status"])
        if task.status == TS.OFFERED:
            task.status = TS.SEARCHING
            task.save(update_fields=["status", "updated_at"])
            _soon(order.pk)
        hooks.offer_closed(offer, order, "EXPIRED")
    return "expired"


def dispatch_sweep(now=None) -> dict:
    """Beat backbone (every 15 s): expire due offers, run due searches, resume UNASSIGNED."""
    now = now or timezone.now()
    result = {"expired": 0, "dispatched": 0}
    due_offers = DeliveryOffer.objects.filter(
        status=OfferStatus.PENDING, expires_at__lte=now
    ).values_list("pk", flat=True)[:200]
    for offer_id in list(due_offers):
        if expire_offer(offer_id, now=now) == "expired":
            result["expired"] += 1
    due_tasks = (
        DeliveryTask.objects.filter(status__in=[TS.SEARCHING, TS.UNASSIGNED])
        .exclude(next_dispatch_at__gt=now)
        .exclude(Exists(DeliveryOffer.objects.filter(task=OuterRef("pk"), status="PENDING")))
        .values_list("order_id", flat=True)[:200]
    )
    for order_id in list(due_tasks):
        if dispatch_order(order_id, now=now) in ("offered", "unassigned"):
            result["dispatched"] += 1
    return result


# --------------------------------------------------------------------------- the rider's offers


def current_offer(rider: Rider, now=None) -> DeliveryOffer | None:
    now = now or timezone.now()
    return (
        DeliveryOffer.objects.select_related("task__order__store")
        .filter(rider=rider, status=OfferStatus.PENDING, expires_at__gt=now)
        .first()
    )


def _own_offer(user, offer_id: int) -> tuple[Rider, DeliveryOffer]:
    rider = require_rider(user, active=True)
    offer = DeliveryOffer.objects.filter(pk=offer_id, rider=rider).select_related("task").first()
    if offer is None:
        raise ApiError(ErrorCode.NOT_FOUND, MSG_OFFER_NOT_FOUND)
    return rider, offer


def accept_offer(user, offer_id: int, now=None) -> DeliveryTask:
    """08 §5 step 4 (`POST /rider/offers/{id}/accept/`). Under the task lock: the task becomes
    ASSIGNED to this rider. Repeating an accepted offer returns the task. Late: 409
    OFFER_EXPIRED (the offer is expired and the next rider tried); the order went elsewhere or
    was cancelled: 409 OFFER_TAKEN."""
    now = now or timezone.now()
    rider, probe = _own_offer(user, offer_id)
    error = None
    with transaction.atomic():
        order = _locked_order(probe.task.order_id)
        task = _locked_task(order)
        offer = DeliveryOffer.objects.select_for_update().get(pk=offer_id)
        rider = Rider.objects.select_for_update().get(pk=rider.pk)
        if offer.status == OfferStatus.ACCEPTED and task.rider_id == rider.pk:
            return task
        if offer.status == OfferStatus.WITHDRAWN or task.status != TS.OFFERED:
            raise ApiError(ErrorCode.OFFER_TAKEN)
        if offer.status != OfferStatus.PENDING:
            raise ApiError(ErrorCode.OFFER_EXPIRED)
        if not rider.is_online:
            raise ApiError(ErrorCode.RIDER_OFFLINE)
        busy = (
            DeliveryTask.objects.filter(rider=rider, status__in=RIDER_BUSY_STATUSES)
            .exclude(pk=task.pk)
            .exists()
        )
        if busy:
            # Ops assigned this rider another order meanwhile (manual dispatch): the offer is
            # withdrawn and the order goes to someone else.
            offer.status = OfferStatus.WITHDRAWN
            offer.save(update_fields=["status"])
            task.status = TS.SEARCHING
            task.save(update_fields=["status", "updated_at"])
            _soon(order.pk)
            error = ApiError(ErrorCode.OFFER_TAKEN)
        elif now >= offer.expires_at:
            offer.status = OfferStatus.EXPIRED
            offer.save(update_fields=["status"])
            task.status = TS.SEARCHING
            task.save(update_fields=["status", "updated_at"])
            _soon(order.pk)
            error = ApiError(ErrorCode.OFFER_EXPIRED)
        else:
            offer.status = OfferStatus.ACCEPTED
            offer.responded_at = now
            offer.save(update_fields=["status", "responded_at"])
            _assign(task, rider, AssignmentMode.AUTO, now)
    if error is not None:
        raise error  # after commit: the expiry is kept
    logger.info("Rider %s accepted task %s", rider.pk, task.pk)
    return task


def _assign(task: DeliveryTask, rider: Rider, mode: str, now) -> None:
    task.status = TS.ASSIGNED
    task.rider = rider
    task.assignment_mode = mode
    task.assigned_at = now
    task.next_dispatch_at = None
    task.pickup_attempts = 0
    task.pickup_locked_at = None
    task.save()


def reject_offer(user, offer_id: int, reason: str | None, now=None) -> None:
    """08 §5 step 5: the offer closes and the next rider is tried. Rejecting an offer that is
    no longer pending changes nothing; an offer this rider accepted: 409."""
    now = now or timezone.now()
    _rider, probe = _own_offer(user, offer_id)
    with transaction.atomic():
        order = _locked_order(probe.task.order_id)
        task = _locked_task(order)
        offer = DeliveryOffer.objects.select_for_update().get(pk=offer_id)
        if offer.status == OfferStatus.ACCEPTED:
            raise ApiError(
                ErrorCode.INVALID_STATE_TRANSITION,
                "You already accepted this offer.",
                details={"status": OfferStatus.ACCEPTED},
            )
        if offer.status != OfferStatus.PENDING:
            return
        offer.status = OfferStatus.REJECTED
        offer.responded_at = now
        offer.reject_reason = reason or ""
        offer.save(update_fields=["status", "responded_at", "reject_reason"])
        if task.status == TS.OFFERED:
            task.status = TS.SEARCHING
            task.save(update_fields=["status", "updated_at"])
            _soon(order.pk)


def withdraw_rider_offers(rider_id: int, reason: str = "RIDER_OFFLINE") -> int:
    """The rider went offline (or was suspended), or ops assigned them another order
    (`reason` REASSIGNED): their pending offers are withdrawn (`offer.withdrawn`) and each task
    goes back to the search. Runs in its own transactions, in the normal lock order."""
    count = 0
    for offer_id, order_id in DeliveryOffer.objects.filter(
        rider_id=rider_id, status=OfferStatus.PENDING
    ).values_list("pk", "task__order_id"):
        with transaction.atomic():
            order = _locked_order(order_id)
            task = _locked_task(order)
            offer = DeliveryOffer.objects.select_for_update().get(pk=offer_id)
            if offer.status != OfferStatus.PENDING:
                continue
            offer.status = OfferStatus.WITHDRAWN
            offer.save(update_fields=["status"])
            if task.status == TS.OFFERED:
                task.status = TS.SEARCHING
                task.save(update_fields=["status", "updated_at"])
                _soon(order.pk)
            hooks.offer_closed(offer, order, reason)
            count += 1
    return count


# --------------------------------------------------------------------------- order events


def withdraw_for_order(order: Order, now=None) -> None:
    """08 T11/T12 ("withdraw the pending offer / free the assigned rider"): called by
    `orders.services.cancel_active` with the order locked. The task is CANCELLED (the rider
    sees it as `recent_task`), a pending offer WITHDRAWN, and the rider is told."""
    now = now or timezone.now()
    task = _locked_task(order)
    if task is None or task.status not in CANCELLABLE_TASK_STATUSES:
        return
    offer = _pending_offer(task)
    if offer is not None:
        offer.status = OfferStatus.WITHDRAWN
        offer.save(update_fields=["status"])
        hooks.offer_closed(offer, order, "ORDER_CANCELLED")
    task.status = TS.CANCELLED
    task.cancelled_at = now
    task.ended_at = now
    task.next_dispatch_at = None
    task.save()
    if task.rider_id:
        data = {"task_id": task.pk, "order_number": order.order_number}
        hooks.task_updated(
            task, order, "ORDER_CANCELLED", push_event="rider.task_cancelled", push_data=data
        )


def order_packed(order_id: int) -> None:
    """08 T8 ("notify the assigned rider 'Order ready'; if no rider yet, raise dispatch
    priority"): runs after commit from the `order.packed` event."""
    task = (
        DeliveryTask.objects.select_related("rider__user", "order")
        .filter(order_id=order_id)
        .first()
    )
    if task is None:
        return
    if task.status in (TS.ASSIGNED, TS.AT_STORE) and task.rider_id:
        hooks.task_updated(
            task,
            task.order,
            "ORDER_PACKED",
            push_event="rider.order_ready",
            push_data={
                "task_id": task.pk,
                "order_number": task.order.order_number,
                "store_name": task.store.name,
            },
        )
    elif task.status in (TS.SEARCHING, TS.UNASSIGNED):
        DeliveryTask.objects.filter(pk=task.pk).update(next_dispatch_at=None)
        dispatch_order(order_id)


def cod_amount_changed(order: Order, old_amount: Decimal) -> None:
    """08 T8a for COD: the amount due dropped. The task keeps the previous amount
    (`cod_amount_previous`, "collect ₹X, was ₹Y") and the assigned rider is told. The caller
    holds the order lock."""
    task = _locked_task(order)
    if task is None or task.status not in CANCELLABLE_TASK_STATUSES:
        return
    task.cod_amount_previous = old_amount
    task.save(update_fields=["cod_amount_previous", "updated_at"])
    if task.rider_id:
        data = {
            "task_id": task.pk,
            "order_number": order.order_number,
            "cod_amount": str(order.grand_total),
            "cod_amount_due": str(order.grand_total),
            "cod_amount_previous": str(old_amount),
            "ref": f"{task.pk}:{order.grand_total}",  # one push per new amount
        }
        hooks.task_updated(
            task, order, "AMOUNT_CHANGED", push_event="rider.cod_amount_changed", push_data=data
        )


# --------------------------------------------------------------------------- ops (05 §1.4)


def can_dispatch(user) -> bool:
    """05 §3 "Manual dispatch": Super Admin, Ops, Store Manager (own stores)."""
    return bool(user and user.is_active and user.is_staff and user.has_perm(DISPATCH_PERMISSION))


def _ops_order(user, order_id: int) -> Order:
    from apps.orders.store_ops import staff_orders

    if not can_dispatch(user):
        raise PermissionDenied(MSG_NO_PERMISSION)
    ids = staff_orders(user).filter(pk=order_id).values("pk")
    order = (
        Order.objects.select_for_update(of=("self",))
        .select_related("store")
        .filter(pk__in=ids)
        .first()
    )
    if order is None:
        raise ValidationError(MSG_ORDER_NOT_FOUND)
    return order


def _state(message: str, **details) -> ApiError:
    return ApiError(ErrorCode.INVALID_STATE_TRANSITION, message, details=details)


def manual_assign(order_id: int, rider_id: int, *, by, ip: str | None = None) -> DeliveryTask:
    """08 §5 step 7: ops assign a rider directly (no offer). The rider must be ACTIVE, online,
    of the order's store, free, and within the cash limit for COD (422 CASH_LIMIT_EXCEEDED).
    A pending offer is withdrawn. Audited."""
    now = timezone.now()
    with transaction.atomic():
        order = _ops_order(by, order_id)
        if order.status not in DISPATCHABLE_ORDER_STATUSES:
            raise _state("This order can no longer be assigned.", status=order.status)
        task = ensure_task(order, now)
        if task.status not in (TS.SEARCHING, TS.OFFERED, TS.UNASSIGNED):
            raise _state("The order already has a rider.", task_status=task.status)
        rider = Rider.objects.select_for_update().select_related("user").filter(pk=rider_id).first()
        if (
            rider is None
            or rider.status != RiderStatus.ACTIVE
            or rider.home_store_id != order.store_id
        ):
            raise ValidationError("Choose an active rider of this store.")
        if not rider.is_online:
            raise ValidationError("The rider is offline.")
        if DeliveryTask.objects.filter(rider=rider, status__in=RIDER_BUSY_STATUSES).exists():
            raise ValidationError("The rider is on another delivery.")
        if (
            order.payment_method == PaymentMethod.COD
            and rider.cash_in_hand + order.grand_total > rider.cash_limit
        ):
            raise ApiError(
                ErrorCode.CASH_LIMIT_EXCEEDED,
                details={
                    "cash_in_hand": str(rider.cash_in_hand),
                    "cash_limit": str(rider.cash_limit),
                    "amount": str(order.grand_total),
                },
            )
        offer = _pending_offer(task)
        if offer is not None:
            offer.status = OfferStatus.WITHDRAWN
            offer.save(update_fields=["status"])
            hooks.offer_closed(offer, order, "TAKEN")
        _assign(task, rider, AssignmentMode.MANUAL, now)
        # The rider may hold a pending offer for another order: withdraw it after commit, in
        # the normal lock order (an accept racing this one gets OFFER_TAKEN under the rider lock).
        rider_id = rider.pk
        transaction.on_commit(lambda: withdraw_rider_offers(rider_id, "REASSIGNED"))
        audit.record(by, "delivery.manual_assign", order, {"rider": rider.pk}, ip=ip)
        data = {
            "task_id": task.pk,
            "order_number": order.order_number,
            "store_name": order.store.name,
        }
        hooks.task_updated(
            task, order, "ASSIGNED", push_event="rider.task_assigned", push_data=data
        )
    return task


def unassign(order_id: int, *, by, ip: str | None = None) -> DeliveryTask:
    """08 §3 reassignment: a rider in ASSIGNED/AT_STORE is taken off (e.g. vehicle breakdown);
    the task goes back to SEARCHING and the rider is freed and told. Audited."""
    now = timezone.now()
    with transaction.atomic():
        order = _ops_order(by, order_id)
        task = _locked_task(order)
        if task is None or task.status not in (TS.ASSIGNED, TS.AT_STORE):
            raise _state(
                "Only a rider heading to or at the store can be taken off.",
                task_status=task.status if task else None,
            )
        previous = task.rider
        task.rider = None
        task.assignment_mode = ""
        task.assigned_at = None
        task.arrived_store_at = None
        task.pickup_attempts = 0
        task.pickup_locked_at = None
        _new_round(task, now)
        task.save()
        audit.record(by, "delivery.unassign", order, {"rider": previous.pk}, ip=ip)
        data = {"task_id": task.pk, "order_number": order.order_number}
        hooks.task_updated(
            task,
            order,
            "REASSIGNED",
            rider=previous,
            push_event="rider.task_cancelled",
            push_data=data,
        )
        _soon(order.pk)
    return task


def retry_dispatch(order_id: int, *, by, ip: str | None = None) -> DeliveryTask:
    """08 §5 step 6 / §3: ops restart auto-dispatch of an UNASSIGNED task now. Audited."""
    now = timezone.now()
    with transaction.atomic():
        order = _ops_order(by, order_id)
        task = _locked_task(order)
        if task is None or task.status != TS.UNASSIGNED:
            raise _state(
                "Only an unassigned order can be re-dispatched.",
                task_status=task.status if task else None,
            )
        _new_round(task, now)
        task.save()
        audit.record(by, "delivery.retry_dispatch", order, {}, ip=ip)
        _soon(order.pk)
    return task
