"""Store management pages (ADR 0004 §4): bottle prices, offers, delivery locations.

Super Admin only: each page and each button needs its permission (`store_management`), checked
by `ops_view` on GET and POST alike; every other role gets the 403 page. Objects are looked up
inside what the user may manage (sellable sizes, public coupons, the user's stores' pincodes),
so anything else is a 404 and no service is called.

Every change goes through a backend service (`store_management`), behind a confirm dialog:
- buttons and inline forms post with HTMX and answer 204 + a toast (`HX-Trigger`) and
  `ops:refresh`, which reloads the page region; a refusal is 400 / 403 / 404 / 501 with the
  plain message in `X-Ops-Message` (ops.js shows it as a toast);
- the add / edit pages are plain forms: on success a redirect with a message, on a refusal the
  form again (400) with each message next to its field.
Without JavaScript the HTMX forms post normally and come back with a message.
"""

import json

from django.contrib import messages
from django.core.paginator import Paginator
from django.http import Http404, HttpResponse
from django.shortcuts import redirect, render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.http import require_http_methods, require_POST

from apps.ops_console import store_management as sm
from apps.ops_console.access import is_htmx, ops_view
from apps.ops_console.order_actions import MSG_UNAVAILABLE, ActionUnavailable
from apps.ops_console.order_views import _form_message, _refused
from apps.ops_console.params import has_nul
from apps.ops_console.store_management_forms import (
    CouponForm,
    PincodeEditForm,
    PincodeForm,
    PriceForm,
    RewardsForm,
    VolumeOfferForm,
    apply_service_errors,
)
from apps.ops_console.views import ops_context
from apps.stores.services import stores_for

PRICES_PER_PAGE = 50
COUPONS_PER_PAGE = 25
MAX_QUERY = 60
MSG_NEEDS_FREE_SIZE = (
    "The buy-N-get-1 settings can be changed here after the free-carton update is installed."
)
MSG_BAD_SWITCH = "Choose on or off."
FORM_METHODS = ["GET", "POST"]

TONE_LEVEL = {
    "success": messages.SUCCESS,
    "info": messages.INFO,
    "warning": messages.WARNING,
}


def _done(request, message: str, back: str, tone: str = "success") -> HttpResponse:
    if is_htmx(request):
        response = HttpResponse(status=204)
        response["HX-Trigger"] = json.dumps(
            {"ops:toast": {"message": message, "tone": tone}, "ops:refresh": True}
        )
        return response
    messages.add_message(request, TONE_LEVEL[tone], message)
    return redirect(back)


def _attempt(request, back: str, call):
    """Run a service call: `(result, None)`, or `(None, refusal response)`."""
    try:
        return call(), None
    except ActionUnavailable:
        return None, _refused(request, MSG_UNAVAILABLE, 501, back)
    except sm.Refused as refusal:
        return None, _refused(request, refusal.message, refusal.status, back)


def _switch(request) -> bool | None:
    """The posted on/off value ("1" / "0"), or None for anything else."""
    return {"1": True, "0": False}.get(request.POST.get("active", ""))


def _form_page(request, context: dict, status: int = 200) -> HttpResponse:
    response = render(request, "ops/store_management/form_page.html", context)
    response.status_code = status
    return response


# --------------------------------------------------------------------------- bottle prices


@ops_view(sm.MANAGE_PRICES)
def prices(request):
    query = request.GET.get("q", "").strip()[:MAX_QUERY]
    if has_nul(query):
        query = ""
    page = Paginator(sm.price_rows(query), PRICES_PER_PAGE).get_page(request.GET.get("page"))
    for variant in page.object_list:
        variant.label = sm.variant_label(variant)
        variant.confirm_template = sm.price_confirm_template(variant)
    context = ops_context(
        request,
        title="Bottle prices",
        page=page,
        query=query,
        can_save=sm.available(sm.SET_PRICE),
    )
    return render(request, "ops/store_management/prices.html", context)


@ops_view(sm.MANAGE_PRICES)
@require_POST
def price_set(request, variant_id: int):
    variant = sm.sellable_variants().select_related("product").filter(pk=variant_id).first()
    if variant is None:
        raise Http404("No such size.")
    back = reverse("ops:prices")
    form = PriceForm(request.POST)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    label, old = sm.variant_label(variant), sm.short_inr(variant.selling_price)
    changed, refused = _attempt(
        request,
        back,
        lambda: sm.set_price(variant, form.cleaned_data["price"], actor=request.user),
    )
    if refused:
        return refused
    if not changed:
        return _done(request, f"No change: {label} already costs {old}.", back, "info")
    new = sm.short_inr(variant.selling_price)
    return _done(
        request,
        f"{label} now costs {new} (was {old}). Customers see the new price at once.",
        back,
    )


# --------------------------------------------------------------------------- offers


def _offers_context(request, rewards_form=None) -> dict:
    user = request.user
    quantities = sm.has_reward_quantities()
    settings_row = sm.referral_settings()
    if rewards_form is None:
        initial = {"referral_enabled": settings_row.is_enabled}
        if quantities:
            initial["welcome"] = settings_row.welcome_reward_quantity
            initial["referral"] = settings_row.reward_quantity
        rewards_form = RewardsForm(initial=initial, quantities=quantities)
    page = Paginator(sm.coupon_list(), COUPONS_PER_PAGE).get_page(request.GET.get("page"))
    now = timezone.now()
    for coupon in page.object_list:
        coupon.state = sm.coupon_state(coupon, now)
        coupon.value_text = sm.coupon_value(coupon)
        coupon.confirm_toggle = sm.coupon_toggle_confirm(coupon)
    volume = []
    free_size = sm.has_free_size()
    for row in sm.volume_rows(stores_for(user)):
        form = VolumeOfferForm(
            initial={"enabled": row.on, "every": row.every or None, "free_variant": row.variant_id},
            sizes=row.sizes,
            auto_id=f"vol{row.store.pk}_%s",
        )
        volume.append({"row": row, "form": form})
    return {
        "volume": volume,
        "free_size": free_size,
        "rewards": settings_row,
        "rewards_form": rewards_form,
        "quantities": quantities,
        "page": page,
        "actions": {action: sm.available(action) for action in sm.SERVICES},
    }


@ops_view(sm.MANAGE_OFFERS)
def offers(request):
    context = ops_context(request, title="Offers")
    context.update(_offers_context(request))
    return render(request, "ops/store_management/offers.html", context)


@ops_view(sm.MANAGE_OFFERS)
@require_POST
def offer_volume(request, store_id: int):
    store = stores_for(request.user).filter(pk=store_id).first()
    if store is None:
        raise Http404("No such store.")
    back = reverse("ops:offers")
    if not sm.has_free_size():
        return _refused(request, MSG_NEEDS_FREE_SIZE, 501, back)
    form = VolumeOfferForm(request.POST, sizes=sm.store_sizes([store.pk]).get(store.pk, []))
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    data = form.cleaned_data
    every = data["every"] if data["enabled"] else 0
    changed, refused = _attempt(
        request,
        back,
        lambda: sm.set_volume_offer(store, every, data["free_variant"], actor=request.user),
    )
    if refused:
        return refused
    if not changed:
        return _done(request, f"Nothing changed at {store.code}.", back, "info")
    if every:
        return _done(
            request, f"Buy {every} get 1 free is on at {store.code}. Carts show it at once.", back
        )
    return _done(request, f"Buy-N-get-1 is off at {store.code}.", back)


@ops_view(sm.MANAGE_OFFERS)
@require_POST
def offer_rewards(request):
    back = reverse("ops:offers")
    quantities = sm.has_reward_quantities()
    form = RewardsForm(request.POST, quantities=quantities)
    if not form.is_valid():
        return _refused(request, _form_message(form), 400, back)
    data = form.cleaned_data
    changed, refused = _attempt(
        request,
        back,
        lambda: sm.set_rewards(
            actor=request.user,
            referral_enabled=data["referral_enabled"],
            welcome=data.get("welcome"),
            referral=data.get("referral"),
        ),
    )
    if refused:
        return refused
    if not changed:
        return _done(request, "Nothing changed in the rewards.", back, "info")
    return _done(
        request,
        "Rewards saved. New rewards use these numbers; rewards already given keep theirs.",
        back,
    )


# Public coupons ---------------------------------------------------------------


def _coupon(coupon_id: int):
    coupon = sm.public_coupons().filter(pk=coupon_id).first()
    if coupon is None:
        raise Http404("No such coupon.")
    return coupon


def _coupon_page(request, form, *, coupon=None, status: int = 200) -> HttpResponse:
    editing = coupon is not None
    context = ops_context(
        request,
        title=f"Edit coupon {coupon.code}" if editing else "Add a coupon",
        form=form,
        action=reverse("ops:coupon-edit", args=[coupon.pk])
        if editing
        else reverse("ops:coupon-add"),
        back_url=reverse("ops:offers"),
        back_label="Back to offers",
        intro=[
            "A coupon gives money off an order. Customers see it in the app's coupon list "
            "and type its code at checkout.",
            "A percent coupon needs a maximum discount in rupees.",
        ],
        submit_label="Save changes" if editing else "Add coupon",
        confirm_title="Save the coupon?" if editing else "Add the coupon?",
        confirm_message=(
            f"Save the changes to {coupon.code}? Customers see them at once. Orders already "
            "placed keep their discount."
            if editing
            else "Add this coupon? Customers can see and use it in the app from its start date."
        ),
        confirm_label="Save" if editing else "Add coupon",
        testid="coupon-form",
    )
    return _form_page(request, context, status)


@ops_view(sm.MANAGE_OFFERS)
@require_http_methods(FORM_METHODS)
def coupon_add(request):
    if request.method != "POST":
        return _coupon_page(request, CouponForm())
    form = CouponForm(request.POST)
    if not form.is_valid():
        return _coupon_page(request, form, status=400)
    try:
        coupon = sm.create_coupon(form.data_for_service(), actor=request.user)
    except ActionUnavailable:
        form.add_error(None, MSG_UNAVAILABLE)
        return _coupon_page(request, form, status=501)
    except sm.Refused as refusal:
        apply_service_errors(form, refusal)
        return _coupon_page(request, form, status=refusal.status)
    messages.success(request, f"Coupon {coupon.code} added. Customers can use it from its start.")
    return redirect("ops:offers")


@ops_view(sm.MANAGE_OFFERS)
@require_http_methods(FORM_METHODS)
def coupon_edit(request, coupon_id: int):
    coupon = _coupon(coupon_id)
    if request.method != "POST":
        return _coupon_page(
            request, CouponForm(initial=CouponForm.initial_for(coupon)), coupon=coupon
        )
    form = CouponForm(request.POST)
    if not form.is_valid():
        return _coupon_page(request, form, coupon=coupon, status=400)
    try:
        changed = sm.update_coupon(coupon, form.data_for_service(), actor=request.user)
    except ActionUnavailable:
        form.add_error(None, MSG_UNAVAILABLE)
        return _coupon_page(request, form, coupon=coupon, status=501)
    except sm.Refused as refusal:
        apply_service_errors(form, refusal)
        return _coupon_page(request, form, coupon=coupon, status=refusal.status)
    if changed:
        coupon.refresh_from_db(fields=["code"])
        messages.success(request, f"Coupon {coupon.code} saved. Customers see the change at once.")
    else:
        messages.info(request, f"Nothing changed in coupon {coupon.code}.")
    return redirect("ops:offers")


@ops_view(sm.MANAGE_OFFERS)
@require_POST
def coupon_active(request, coupon_id: int):
    coupon = _coupon(coupon_id)
    back = reverse("ops:offers")
    active = _switch(request)
    if active is None:
        return _refused(request, MSG_BAD_SWITCH, 400, back)
    changed, refused = _attempt(
        request, back, lambda: sm.set_coupon_active(coupon, active, actor=request.user)
    )
    if refused:
        return refused
    if not changed:
        state = "on" if active else "off"
        return _done(request, f"Coupon {coupon.code} was already {state}.", back, "info")
    if active:
        return _done(request, f"Coupon {coupon.code} is on. Customers can use it now.", back)
    return _done(
        request, f"Coupon {coupon.code} is off. Customers can no longer see or use it.", back
    )


# --------------------------------------------------------------------------- delivery locations


@ops_view(sm.MANAGE_PINCODES)
def delivery(request):
    context = ops_context(
        request,
        title="Delivery locations",
        groups=sm.pincode_stores(request.user),
        no_outline=sm.MSG_NO_OUTLINE,
        actions={action: sm.available(action) for action in sm.SERVICES},
    )
    return render(request, "ops/store_management/delivery.html", context)


def _pincode(request, pincode_id: int):
    row = sm.pincodes_for(request.user).filter(pk=pincode_id).first()
    if row is None:
        raise Http404("No such pincode.")
    return row


PINCODE_INTRO = [
    "Customers can order only from active pincodes. The app checks the pincode of the "
    "delivery address.",
    "If this is the store's first pincode, the store then delivers only to its active "
    "pincodes, not to its whole map area.",
]


def _pincode_page(request, form, *, row=None, status: int = 200) -> HttpResponse:
    editing = row is not None
    context = ops_context(
        request,
        title=f"Edit pincode {row.pincode} ({row.store.code})" if editing else "Add a pincode",
        form=form,
        action=(
            reverse("ops:pincode-edit", args=[row.pk]) if editing else reverse("ops:pincode-add")
        ),
        back_url=reverse("ops:delivery"),
        back_label="Back to delivery locations",
        intro=PINCODE_INTRO[:1] if editing else PINCODE_INTRO,
        submit_label="Save changes" if editing else "Add pincode",
        confirm_title="Save the pincode?" if editing else "Add the pincode?",
        confirm_message=(
            "Save the changes? Customers are checked against the new pincode and area name "
            "at once. Orders already placed are still delivered."
            if editing
            else "Add this pincode? If it is active, customers with this pincode can order "
            "from this store at once."
        ),
        confirm_label="Save" if editing else "Add pincode",
        testid="pincode-form",
    )
    return _form_page(request, context, status)


@ops_view(sm.MANAGE_PINCODES)
@require_http_methods(FORM_METHODS)
def pincode_add(request):
    stores = list(stores_for(request.user).order_by("code"))
    if request.method != "POST":
        initial = {"is_active": True}
        chosen = request.GET.get("store", "")
        if any(str(store.pk) == chosen for store in stores):
            initial["store"] = chosen
        return _pincode_page(request, PincodeForm(initial=initial, stores=stores))
    form = PincodeForm(request.POST, stores=stores)
    if not form.is_valid():
        return _pincode_page(request, form, status=400)
    data = form.cleaned_data
    store = next(store for store in stores if store.pk == data["store"])
    try:
        row = sm.add_pincode(
            store,
            data["pincode"],
            area_name=data["area_name"],
            is_active=data["is_active"],
            actor=request.user,
        )
    except ActionUnavailable:
        form.add_error(None, MSG_UNAVAILABLE)
        return _pincode_page(request, form, status=501)
    except sm.Refused as refusal:
        apply_service_errors(form, refusal)
        return _pincode_page(request, form, status=refusal.status)
    if row.is_active:
        messages.success(
            request,
            f"Pincode {sm.place(row)} added to {store.code}. Customers there can order now.",
        )
    else:
        messages.success(
            request,
            f"Pincode {sm.place(row)} added to {store.code} as inactive. Customers there can't "
            "order until you activate it.",
        )
    if not sm.pincodes_for(request.user).filter(pk=row.pk, has_outline=True).exists():
        messages.warning(request, f"{row.pincode}: {sm.MSG_NO_OUTLINE}")
    return redirect("ops:delivery")


@ops_view(sm.MANAGE_PINCODES)
@require_http_methods(FORM_METHODS)
def pincode_edit(request, pincode_id: int):
    row = _pincode(request, pincode_id)
    if request.method != "POST":
        initial = {"pincode": row.pincode, "area_name": row.area_name}
        return _pincode_page(request, PincodeEditForm(initial=initial), row=row)
    form = PincodeEditForm(request.POST)
    if not form.is_valid():
        return _pincode_page(request, form, row=row, status=400)
    try:
        changed = sm.update_pincode(
            row,
            pincode=form.cleaned_data["pincode"],
            area_name=form.cleaned_data["area_name"],
            actor=request.user,
        )
    except ActionUnavailable:
        form.add_error(None, MSG_UNAVAILABLE)
        return _pincode_page(request, form, row=row, status=501)
    except sm.Refused as refusal:
        apply_service_errors(form, refusal)
        return _pincode_page(request, form, row=row, status=refusal.status)
    if changed:
        messages.success(request, f"Pincode {sm.place(row)} of {row.store.code} saved.")
    else:
        messages.info(request, f"Nothing changed in pincode {row.pincode}.")
    return redirect("ops:delivery")


@ops_view(sm.MANAGE_PINCODES)
@require_POST
def pincode_active(request, pincode_id: int):
    row = _pincode(request, pincode_id)
    back = reverse("ops:delivery")
    active = _switch(request)
    if active is None:
        return _refused(request, MSG_BAD_SWITCH, 400, back)
    changed, refused = _attempt(
        request, back, lambda: sm.set_pincode_active(row, active, actor=request.user)
    )
    if refused:
        return refused
    where = f"{sm.place(row)} ({row.store.code})"
    if not changed:
        state = "active" if active else "inactive"
        return _done(request, f"Pincode {where} was already {state}.", back, "info")
    if active:
        return _done(request, f"Delivery to {where} is on. Customers there can order now.", back)
    return _done(
        request,
        f"Delivery to {where} is off. Customers there can't place new orders.",
        back,
    )
