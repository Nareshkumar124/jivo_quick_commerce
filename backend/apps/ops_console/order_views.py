"""Ops Console order screens (Phase 4): the live order board (05 §1.2) and the store packing
console (05 §1.3, returns excepted).

Thin views: access in `ops_view(capability=...)` (05 §3 rows, `capabilities`), reads in `board`
/ `packing`, state changes only through `order_actions` (the backend services). Objects are
looked up inside the user's stores first, so another store's order or store is a 404.

Buttons answer HTMX with 204 + `HX-Trigger` (a toast, and `ops:refresh` so the polled region
reloads at once). Refusals: 400 / 403 / 404 / 409 from the service and 501 (the service is not
on this branch yet), each with the message in `X-Ops-Message` for the
toast. A plain (non-HTMX) POST is redirected back with a Django message. Service refusals map
to 403 (role), 404 (order or line not in scope), 400 (bad input) or 409 (wrong state), see
`order_actions.ActionRefused`.
"""

import json
from urllib.parse import quote

from django.conf import settings
from django.contrib import messages
from django.core.exceptions import NON_FIELD_ERRORS
from django.http import HttpResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse
from django.views.decorators.http import require_POST

from apps.ops_console import board as board_data
from apps.ops_console import capabilities, order_actions, packing
from apps.ops_console.access import is_htmx, ops_view
from apps.ops_console.forms import AcceptingForm, CancelOrderForm, UnavailableForm
from apps.ops_console.scoping import scope_to_stores
from apps.ops_console.views import ops_context
from apps.orders.models import Order

DEFAULT_POLL_SECONDS = 10  # 05 §1.2 "falls back to HTMX polling every 10 s"
MESSAGE_HEADER = "X-Ops-Message"


def poll_seconds() -> int:
    return max(int(getattr(settings, "OPS_POLL_SECONDS", DEFAULT_POLL_SECONDS)), 2)


def _common(request) -> dict:
    return {
        "caps": capabilities.capability_flags(request.user),
        "actions": order_actions.availability(),
        "poll_seconds": poll_seconds(),
    }


def _done(request, message: str, back: str) -> HttpResponse:
    if is_htmx(request):
        response = HttpResponse(status=204)
        response["HX-Trigger"] = json.dumps(
            {"ops:toast": {"message": message, "tone": "success"}, "ops:refresh": True}
        )
        return response
    messages.success(request, message)
    return redirect(back)


def _refused(request, message: str, status: int, back: str) -> HttpResponse:
    if is_htmx(request):
        response = HttpResponse(message, status=status, content_type="text/plain")
        # Header values must be latin-1: percent-encode, ops.js decodes.
        response[MESSAGE_HEADER] = quote(message)
        return response
    messages.error(request, message)
    return redirect(back)


def _form_message(form) -> str:
    return " ".join(str(error) for errors in form.errors.values() for error in errors)


def _run(request, back: str, call, success: str) -> HttpResponse:
    try:
        call()
    except order_actions.ActionUnavailable:
        return _refused(request, order_actions.MSG_UNAVAILABLE, 501, back)
    except order_actions.ActionRefused as refusal:
        return _refused(request, refusal.message, refusal.status, back)
    return _done(request, success, back)


# --------------------------------------------------------------------------- live board


@ops_view(capability=capabilities.LIVE_BOARD)
def live_board(request):
    form, queryset = board_data.filtered(request.user, request.GET)
    context = ops_context(
        request,
        title="Live order board",
        form=form,
        board=board_data.build(request.user, queryset),
        cancel_form=CancelOrderForm(reasons=order_actions.cancel_reasons() or ()),
        **_common(request),
    )
    return render(request, "ops/orders/live_board.html", context)


@ops_view(capability=capabilities.LIVE_BOARD)
def live_board_columns(request):
    form, queryset = board_data.filtered(request.user, request.GET)
    context = {
        "request": request,
        "form": form,
        "board": board_data.build(request.user, queryset),
        **_common(request),
    }
    return render(request, "ops/partials/live_board_columns.html", context)


def _cancel(request, order: Order, back: str) -> HttpResponse:
    reasons = order_actions.cancel_reasons()
    if reasons is None or not order_actions.available(order_actions.CANCEL):
        return _refused(request, order_actions.MSG_UNAVAILABLE, 501, back)
    form = CancelOrderForm(request.POST, reasons=reasons)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    return _run(
        request,
        back,
        lambda: order_actions.cancel(
            order,
            actor=request.user,
            reason=form.cleaned_data["reason"],
            note=form.cleaned_data["note"],
        ),
        f"Order {order.order_number} cancelled.",
    )


@ops_view(capability=capabilities.CANCEL_ORDER)
@require_POST
def board_cancel(request, order_id: int):
    order = get_object_or_404(scope_to_stores(Order.objects.all(), request.user), pk=order_id)
    return _cancel(request, order, reverse("ops:live-board"))


# --------------------------------------------------------------------------- packing console


@ops_view(capability=capabilities.PACKING)
def store_index(request):
    from apps.ops_console.scoping import visible_stores

    stores = list(visible_stores(request.user).filter(is_active=True).order_by("code"))
    if len(stores) == 1:
        return redirect("ops:packing", code=stores[0].code)
    context = ops_context(request, title="Packing console", stores=stores)
    return render(request, "ops/store/index.html", context)


def _console_context(request, store) -> dict:
    return {
        "store": store,
        "console": packing.build(store),
        "low_stock": packing.low_stock_count(store),
        "cancel_form": CancelOrderForm(reasons=order_actions.cancel_reasons() or ()),
        **_common(request),
    }


@ops_view(capability=capabilities.PACKING)
def packing_console(request, code: str):
    store = packing.store_for(request.user, code)
    context = ops_context(request, title=f"Packing: {store.code} {store.name}")
    context.update(_console_context(request, store))
    return render(request, "ops/store/console.html", context)


@ops_view(capability=capabilities.PACKING)
def packing_queue(request, code: str):
    store = packing.store_for(request.user, code)
    context = {"request": request, **_console_context(request, store)}
    return render(request, "ops/partials/packing_queues.html", context)


def _store_order(request, code: str, order_id: int):
    store = packing.store_for(request.user, code)
    order = get_object_or_404(packing.store_orders(store), pk=order_id)
    return store, order, reverse("ops:packing", args=[store.code])


STEP_ACTIONS = {
    "accept": (order_actions.accept, "Order {number} accepted."),
    "start-packing": (order_actions.start_packing, "Packing started for {number}."),
    "mark-packed": (order_actions.mark_packed, "Order {number} packed."),
}


@ops_view(capability=capabilities.PACKING)
@require_POST
def packing_step(request, code: str, order_id: int, step: str):
    if step not in STEP_ACTIONS:
        return HttpResponse(status=404)
    _store, order, back = _store_order(request, code, order_id)
    action, success = STEP_ACTIONS[step]
    return _run(
        request,
        back,
        lambda: action(order, actor=request.user),
        success.format(number=order.order_number),
    )


@ops_view(capability=capabilities.PACKING)
@require_POST
def packing_unavailable(request, code: str, order_id: int):
    _store, order, back = _store_order(request, code, order_id)
    form = UnavailableForm(request.POST, order=order)
    if not form.is_valid():
        if form.has_error(NON_FIELD_ERRORS, "not_found"):
            return HttpResponse(status=404)  # another order's line: as if it did not exist
        return _refused(request, _form_message(form), 400, back)
    quantity = form.cleaned_data["quantity_unavailable"]
    return _run(
        request,
        back,
        lambda: order_actions.mark_unavailable(order, form.line.pk, quantity, actor=request.user),
        f"{form.line.product_name}: {quantity} unit(s) marked unavailable. "
        "The bill and refund are updated by the system.",
    )


@ops_view(capability=capabilities.CANCEL_ORDER)
@require_POST
def packing_cancel(request, code: str, order_id: int):
    _store, order, back = _store_order(request, code, order_id)
    return _cancel(request, order, back)


@ops_view(capability=capabilities.TOGGLE_STORE)
@require_POST
def packing_accepting(request, code: str):
    store = packing.store_for(request.user, code)
    back = reverse("ops:packing", args=[store.code])
    form = AcceptingForm(request.POST)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    accepting = form.cleaned_data["accepting"]
    message = "Store is taking orders again." if accepting else "Store paused: no new orders."
    return _run(
        request,
        back,
        lambda: order_actions.set_accepting(store, accepting, actor=request.user),
        message,
    )


@ops_view(capability=capabilities.PACKING)
def packing_slip(request, code: str, order_id: int):
    store = packing.store_for(request.user, code)
    order = packing.slip(store, order_id)
    if order is None:
        return HttpResponse("Only orders being packed or packed have a slip.", status=404)
    return render(request, "ops/store/slip.html", {"store": store, "order": order})
