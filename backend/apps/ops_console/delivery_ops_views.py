"""SLICE 5.4 Ops screens and buttons (see `delivery_ops` for the services and signatures).

- Task buttons on `/ops/dispatch/tasks/<id>/` (05 §1.4, DL-61 a): unlock pickup code, unlock
  delivery OTP, mark the delivery failed (T13 by ops). Capability `dispatch`.
- Force a rider offline from the dispatch board (05 §1.4). Capability `dispatch`.
- Cash deposits `/ops/cash/` (05 §1.5): riders with cash in hand, record a deposit, day-end
  report per store. Capability `cash_deposit` (Super Admin, Ops, Store Manager own, Finance;
  DL-61 a). Riders come from `cash.staff_cash_riders`, which scopes to the user's stores.
- Payouts `/ops/payouts/` (05 §2 "Rider earnings & payouts", §3 "Payouts": Super Admin,
  Finance): create a batch for a period, mark a payout paid with the bank reference, void a
  pending one. Capability `payouts`.

Before the 5.4 merge the `cash_deposit` / `payouts` capabilities are False for everyone (403)
and the task buttons render disabled (a crafted POST gets 501). Every lookup starts from the
user's stores: another store's task or rider is a 404 and no service is called.
"""

import uuid

from django.apps import apps
from django.core.paginator import Paginator
from django.http import Http404
from django.shortcuts import render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_POST

from apps.core.net import client_ip
from apps.delivery.choices import DeliveryTaskStatus as TS
from apps.delivery.models import Rider
from apps.ops_console import capabilities, delivery_ops, order_actions
from apps.ops_console import dispatch as dispatch_data
from apps.ops_console.access import ops_view
from apps.ops_console.delivery_ops_forms import (
    CashDepositForm,
    CreatePayoutsForm,
    DayReportForm,
    FailDeliveryForm,
    MarkPaidForm,
)
from apps.ops_console.order_views import _form_message, _refused, _run, poll_seconds
from apps.ops_console.views import ops_context
from apps.orders.choices import OrderStatus
from apps.stores.services import stores_for

UNLOCK_PICKUP_STATES = frozenset({TS.AT_STORE})
UNLOCK_OTP_STATES = frozenset({TS.AT_CUSTOMER})
FAIL_STATES = frozenset({TS.PICKED_UP, TS.AT_CUSTOMER})
CASH_LIMIT = 100  # riders per page on /ops/cash/
PAYOUTS_PER_PAGE = 50
MSG_DEPOSIT_STORE = "Record the deposit at the rider's home store."


# --------------------------------------------------------------------------- task buttons


def task_actions(task) -> dict:
    """What the task page offers (state only; the service re-checks everything)."""
    return {
        "unlock_pickup": task.status in UNLOCK_PICKUP_STATES
        and (task.pickup_locked_at is not None or task.pickup_attempts > 0),
        "unlock_otp": task.status in UNLOCK_OTP_STATES
        and (task.otp_locked_at is not None or task.otp_attempts > 0),
        "fail": task.status in FAIL_STATES and task.order.status == OrderStatus.OUT_FOR_DELIVERY,
    }


def task_context() -> dict:
    """Extra context for the task panel (merged into dispatch_views._detail_context)."""
    return {
        "ops54": delivery_ops.availability(),
        "fail_form": FailDeliveryForm(reasons=delivery_ops.fail_reasons()),
    }


def _task(request, task_id: int):
    task = dispatch_data.task_for(request.user, task_id)
    if task is None:
        raise Http404("No such task.")
    return task


def _back(task) -> str:
    return reverse("ops:dispatch-task", args=[task.pk])


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_unlock_pickup(request, task_id: int):
    task = _task(request, task_id)
    return _run(
        request,
        _back(task),
        lambda: delivery_ops.unlock_pickup(
            task.order_id, actor=request.user, ip=client_ip(request)
        ),
        f"Pickup code unlocked for {task.order.order_number}; the rider can try again.",
    )


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_unlock_otp(request, task_id: int):
    task = _task(request, task_id)
    return _run(
        request,
        _back(task),
        lambda: delivery_ops.unlock_otp(task.order_id, actor=request.user, ip=client_ip(request)),
        f"Delivery OTP unlocked for {task.order.order_number}; the rider can try again.",
    )


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_fail(request, task_id: int):
    task = _task(request, task_id)
    form = FailDeliveryForm(request.POST, reasons=delivery_ops.fail_reasons())
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, _back(task))
    return _run(
        request,
        _back(task),
        lambda: delivery_ops.fail_delivery(
            task.order_id,
            reason=form.cleaned_data["reason"],
            note=form.cleaned_data["note"],
            actor=request.user,
            ip=client_ip(request),
        ),
        f"Delivery of {task.order.order_number} marked failed; the rider brings the items back.",
    )


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def rider_force_offline(request, rider_id: int):
    rider = (
        Rider.objects.filter(home_store__in=stores_for(request.user), pk=rider_id)
        .only("pk", "full_name")
        .first()
    )
    if rider is None:
        raise Http404("No such rider.")
    return _run(
        request,
        reverse("ops:dispatch"),
        lambda: delivery_ops.force_offline(rider.pk, actor=request.user, ip=client_ip(request)),
        f"{rider.full_name} is offline now.",
    )


# --------------------------------------------------------------------------- cash (05 §1.5)


def _store_id(request) -> int | None:
    value = request.GET.get("store") or request.POST.get("store") or ""
    if not value.isdigit():
        return None
    return int(value) if stores_for(request.user).filter(pk=int(value)).exists() else None


def _can_record(user) -> bool:
    return user.has_perm("delivery.record_cash_deposit")


def _cash_context(request) -> dict:
    store_id = _store_id(request)
    riders = list(delivery_ops.cash_riders(request.user, store_id)[: CASH_LIMIT + 1])
    stores = list(stores_for(request.user).only("pk", "code", "name").order_by("code"))
    if store_id is None and len(stores) == 1:
        store_id = stores[0].pk
    report = report_error = None
    day_form = DayReportForm(request.GET or None)
    day = day_form.cleaned_data["day"] if day_form.is_valid() else timezone.localdate()
    if store_id is not None:
        try:
            report = delivery_ops.day_report(request.user, store_id, day)
        except order_actions.ActionRefused as refusal:
            report_error = refusal.message
    return {
        "riders": riders[:CASH_LIMIT],
        "truncated": len(riders) > CASH_LIMIT,
        "stores": stores,
        "store_id": store_id,
        "day": day,
        "report": report,
        "report_error": report_error,
        "can_record": _can_record(request.user),
        # One key per render: resending the same form records one deposit.
        "deposit_key": uuid.uuid4().hex,
        "poll_seconds": poll_seconds(),
    }


@ops_view(capability=capabilities.CASH_DEPOSIT)
def cash_index(request):
    context = ops_context(request, title="Cash deposits")
    context.update(_cash_context(request))
    return render(request, "ops/cash/index.html", context)


@ops_view(capability=capabilities.CASH_DEPOSIT)
def cash_partial(request):
    context = {"request": request, **_cash_context(request)}
    return render(request, "ops/partials/cash_riders.html", context)


@ops_view("delivery.record_cash_deposit", capability=capabilities.CASH_DEPOSIT)
@require_POST
def cash_deposit(request, rider_id: int):
    rider = delivery_ops.cash_riders(request.user).filter(pk=rider_id).first()
    if rider is None:
        raise Http404("No such rider.")
    back = reverse("ops:cash")
    form = CashDepositForm(request.POST)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    # The cash is received at the rider's home store (code review). `cash.record_deposit` only
    # checks that the store is one of the user's, so a different posted store is refused here.
    posted = request.POST.get("store", "")
    if posted and posted != str(rider.home_store_id):
        return _refused(request, MSG_DEPOSIT_STORE, 400, back)
    amount = form.cleaned_data["amount"]
    return _run(
        request,
        back,
        lambda: delivery_ops.record_deposit(
            rider.pk,
            f"{amount:.2f}",
            actor=request.user,
            store_id=rider.home_store_id,
            note=form.cleaned_data["note"],
            key=form.cleaned_data["key"],
            ip=client_ip(request),
        ),
        f"Deposit of ₹{amount:.2f} from {rider.full_name} recorded.",
    )


# --------------------------------------------------------------------------- payouts


def _payout_model():
    return apps.get_model("delivery", "Payout")


def _payouts_context(request) -> dict:
    Payout = _payout_model()
    status = request.GET.get("status", "")
    queryset = Payout.objects.select_related("rider").order_by("-period_end", "-pk")
    if status in {choice for choice, _ in Payout._meta.get_field("status").choices}:
        queryset = queryset.filter(status=status)
    page = Paginator(queryset, PAYOUTS_PER_PAGE).get_page(request.GET.get("page"))
    return {
        "page": page,
        "status": status,
        "status_choices": Payout._meta.get_field("status").choices,
        "create_form": CreatePayoutsForm(),
        "poll_seconds": poll_seconds(),
    }


@ops_view(capability=capabilities.PAYOUTS)
def payouts_index(request):
    context = ops_context(request, title="Rider payouts")
    context.update(_payouts_context(request))
    return render(request, "ops/payouts/index.html", context)


@ops_view(capability=capabilities.PAYOUTS)
def payouts_partial(request):
    context = {"request": request, **_payouts_context(request)}
    return render(request, "ops/partials/payouts_list.html", context)


@ops_view(capability=capabilities.PAYOUTS)
@require_POST
def payouts_create(request):
    back = reverse("ops:payouts")
    form = CreatePayoutsForm(request.POST)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    data = form.cleaned_data

    def done(payouts) -> str:
        count = len(payouts)
        if not count:
            return "Nothing to pay for this period."
        return f"{count} payout{'s' if count != 1 else ''} created."

    return _run(
        request,
        back,
        lambda: delivery_ops.create_payouts(
            data["period_start"], data["period_end"], actor=request.user, ip=client_ip(request)
        ),
        done,
    )


def _payout(payout_id: int):
    payout = _payout_model().objects.select_related("rider").filter(pk=payout_id).first()
    if payout is None:
        raise Http404("No such payout.")
    return payout


@ops_view(capability=capabilities.PAYOUTS)
@require_POST
def payout_mark_paid(request, payout_id: int):
    payout = _payout(payout_id)
    back = reverse("ops:payouts")
    form = MarkPaidForm(request.POST)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    return _run(
        request,
        back,
        lambda: delivery_ops.mark_paid(
            payout.pk,
            reference=form.cleaned_data["reference"],
            actor=request.user,
            ip=client_ip(request),
        ),
        f"Payout to {payout.rider.full_name} marked paid.",
    )


@ops_view(capability=capabilities.PAYOUTS)
@require_POST
def payout_void(request, payout_id: int):
    payout = _payout(payout_id)
    return _run(
        request,
        reverse("ops:payouts"),
        lambda: delivery_ops.void_payout(payout.pk, actor=request.user, ip=client_ip(request)),
        f"Payout to {payout.rider.full_name} voided; its earnings are unpaid again.",
    )
