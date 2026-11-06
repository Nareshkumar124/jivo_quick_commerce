"""Ops Console dispatch screens (05 §1.4, slice 5.3) and the store's returns page (05 §1.3
"Returns", 08 T14).

- Dispatch board `/ops/dispatch/`: tasks waiting for a rider (searching, offered, unassigned),
  offers in flight, tasks on the road, online riders with distance to their store and ping age.
  Polls itself (HTMX) every `OPS_POLL_SECONDS`; live pushes arrive in Phase 6.
- Task detail `/ops/dispatch/tasks/<id>/`: timeline, offers, pickup-code / delivery-OTP lock
  state (never the codes) and the manual assign / unassign / retry buttons.
- Returns `/ops/store/<code>/returns/`: failed deliveries back at the store; damaged units per
  line, then `store_ops.receive_return`.

Access: dispatch screens need the `dispatch` capability (05 §3 "Manual dispatch": Super Admin,
Ops, Store Manager own stores); returns need `receive_return` (DL-61: the same roles; Store
Staff and Support never). Every lookup is inside the user's stores first, so another store's
task, order or store is a 404. Buttons call `order_actions` only (the backend services lock,
re-check the role and scope, transition and audit).
"""

from django.http import Http404
from django.shortcuts import get_object_or_404, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from apps.core.net import client_ip
from apps.ops_console import capabilities, delivery_ops, delivery_ops_views, order_actions, packing
from apps.ops_console import dispatch as data
from apps.ops_console.access import ops_view
from apps.ops_console.forms import AssignRiderForm, ReceiveReturnForm
from apps.ops_console.order_views import _form_message, _refused, _run, poll_seconds
from apps.ops_console.scoping import visible_stores
from apps.ops_console.views import ops_context
from apps.stores.services import stores_for

DISPATCH_ACTIONS = (
    order_actions.MANUAL_ASSIGN,
    order_actions.UNASSIGN,
    order_actions.RETRY_DISPATCH,
)


def _store_id(request) -> int | None:
    """The `store` filter, only if it is one of the user's stores (else no filter)."""
    value = request.GET.get("store", "")
    if not value.isdigit():
        return None
    return int(value) if stores_for(request.user).filter(pk=int(value)).exists() else None


def _board_context(request) -> dict:
    store_id = _store_id(request)
    return {
        "board": data.board(request.user, store_id),
        "can_force_offline": delivery_ops.available(delivery_ops.FORCE_OFFLINE),
        "stores": list(visible_stores(request.user).only("pk", "code", "name").order_by("code")),
        "store_id": store_id,
        "poll_seconds": poll_seconds(),
    }


@ops_view(capability=capabilities.DISPATCH)
def dispatch_board(request):
    context = ops_context(request, title="Dispatch", **_board_context(request))
    return render(request, "ops/dispatch/board.html", context)


@ops_view(capability=capabilities.DISPATCH)
def dispatch_board_partial(request):
    context = {"request": request, **_board_context(request)}
    return render(request, "ops/partials/dispatch_board.html", context)


# --------------------------------------------------------------------------- task detail


def _task(request, task_id: int):
    task = data.task_for(request.user, task_id)
    if task is None:
        raise Http404("No such task.")
    return task


def _detail_context(request, task) -> dict:
    return {
        "detail": data.task_detail(task),
        "actions": {action: order_actions.available(action) for action in DISPATCH_ACTIONS},
        # Slice 5.4 (DL-61 a): unlock pickup code / delivery OTP and ops-marked T13
        # (delivery_ops_views); disabled until their services are on the branch.
        "ops54_state": delivery_ops_views.task_actions(task),
        **delivery_ops_views.task_context(),
        "poll_seconds": poll_seconds(),
    }


@ops_view(capability=capabilities.DISPATCH)
def task_detail(request, task_id: int):
    task = _task(request, task_id)
    context = ops_context(request, title=f"Delivery of {task.order.order_number}")
    context.update(_detail_context(request, task))
    return render(request, "ops/dispatch/task.html", context)


@ops_view(capability=capabilities.DISPATCH)
def task_detail_partial(request, task_id: int):
    task = _task(request, task_id)
    context = {"request": request, **_detail_context(request, task)}
    return render(request, "ops/partials/dispatch_task.html", context)


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_assign(request, task_id: int):
    task = _task(request, task_id)
    back = reverse("ops:dispatch-task", args=[task.pk])
    form = AssignRiderForm(request.POST)
    if not form.is_valid():
        return _refused(request, "Choose a rider.", 400, back)
    return _run(
        request,
        back,
        lambda: order_actions.manual_assign(
            task.order_id, form.cleaned_data["rider"], actor=request.user, ip=client_ip(request)
        ),
        f"Rider assigned to {task.order.order_number}.",
    )


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_unassign(request, task_id: int):
    task = _task(request, task_id)
    back = reverse("ops:dispatch-task", args=[task.pk])
    return _run(
        request,
        back,
        lambda: order_actions.unassign(task.order_id, actor=request.user, ip=client_ip(request)),
        f"Rider taken off {task.order.order_number}; searching again.",
    )


@ops_view(capability=capabilities.DISPATCH)
@require_POST
def task_retry(request, task_id: int):
    task = _task(request, task_id)
    back = reverse("ops:dispatch-task", args=[task.pk])
    return _run(
        request,
        back,
        lambda: order_actions.retry_dispatch(
            task.order_id, actor=request.user, ip=client_ip(request)
        ),
        f"Searching for a rider again for {task.order.order_number}.",
    )


# --------------------------------------------------------------------------- returns (T14)


def _returns_context(request, store) -> dict:
    return {
        "store": store,
        "rows": data.returns(store),
        "can_receive": order_actions.available(order_actions.RECEIVE_RETURN),
        "poll_seconds": poll_seconds(),
    }


@ops_view(capability=capabilities.RECEIVE_RETURN)
def store_returns(request, code: str):
    store = packing.store_for(request.user, code)
    context = ops_context(request, title=f"Returns: {store.code} {store.name}")
    context.update(_returns_context(request, store))
    return render(request, "ops/store/returns.html", context)


@ops_view(capability=capabilities.RECEIVE_RETURN)
def store_returns_partial(request, code: str):
    store = packing.store_for(request.user, code)
    context = {"request": request, **_returns_context(request, store)}
    return render(request, "ops/partials/returns_list.html", context)


@ops_view(capability=capabilities.RECEIVE_RETURN)
@require_POST
def store_receive_return(request, code: str, order_id: int):
    store = packing.store_for(request.user, code)
    order = get_object_or_404(data.returnable_orders(store), pk=order_id)
    back = reverse("ops:store-returns", args=[store.code])
    rows = data.returns(store, order_id=order.pk)
    form = ReceiveReturnForm(request.POST, lines=rows[0].lines if rows else [])
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    damaged = form.damaged()
    bad = sum(damaged.values())
    return _run(
        request,
        back,
        lambda: order_actions.receive_return(
            order, damaged, actor=request.user, ip=client_ip(request)
        ),
        f"Return of {order.order_number} received"
        + (f"; {bad} damaged unit{'s' if bad != 1 else ''} recorded." if bad else "."),
    )
