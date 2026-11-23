"""Live delivery monitoring (05 §1.4 "Dispatch & rider map", T-821): `/ops/riders/map/`.

- Page: split layout (map left, live list right; stacked on narrow screens), stats bar, rider /
  drop / store markers, a details drawer per delivery. The page itself carries no delivery
  data: `live_map.js` loads it from the JSON endpoint, then follows the ops socket
  (`rider.location`, `rider.status`, `task.status`, `delivery.progress`) and polls as the
  fallback.
- JSON `/ops/riders/map/data/?store=<id>`: `apps.delivery.services.live_ops.snapshot()` for the
  user's stores, as is. The service decides which fields a role sees (customer name, drop point
  and area only for roles that may see them), so the page treats them as optional.
- JSON `/ops/riders/map/orders/<id>/route/`: the rider's current road leg for one delivery
  (`live_tracking.rider_route`, cached and throttled in `apps.maps`), only when the snapshot
  would show this role the drop point (a route ends there).

Access (05 §3 "Live order board": Super Admin, Ops, Store Manager own stores, Support view;
Finance, Store Staff and Catalog Manager none): the `live_board` capability, then the service's
own check (`PermissionDenied` -> 403). MFA and the session idle rules come from the panel
middleware; automatic refreshes send `X-Ops-Background` so they never extend an idle session.

Nothing here writes. The drawer's actions reuse existing screens and endpoints: the dispatch
task panel (assign / reassign / retry / unlock / mark failed, `dispatch` capability), the
board's cancel endpoint (`cancel_order` capability, 08 T12, the service re-checks the state and
the store), and the admin order and rider pages.
"""

from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.core.serializers.json import DjangoJSONEncoder
from django.http import Http404, JsonResponse
from django.shortcuts import render
from django.urls import reverse

from apps.ops_console import capabilities, order_actions
from apps.ops_console.access import forbidden, ops_view
from apps.ops_console.forms import CancelOrderForm
from apps.ops_console.order_views import poll_seconds
from apps.ops_console.params import parse_ascii_id
from apps.ops_console.scoping import scope_to_stores, visible_stores
from apps.ops_console.status import BADGES, ORDER, TASK
from apps.ops_console.views import ops_context
from apps.stores.services import stores_for

# Map providers (static/ops/js/map_provider_<name>.js registers `window.OpsMapProviders[name]`).
# Only OpenLayers + OpenStreetMap tiles today; a Google Maps JS provider can be added later as
# another entry and chosen with the `OPS_MAP_PROVIDER` setting.
MAP_PROVIDERS = {
    "openlayers": {
        "css": ("ops/vendor/ol-7.2.2.css",),
        "js": ("ops/vendor/ol-7.2.2.min.js", "ops/js/map_provider_ol.js"),
    },
}
DEFAULT_MAP_PROVIDER = "openlayers"
# Order states in which the cancel button is offered (08 T12: before pickup). The service
# re-checks the state, the role ("before pickup" for Store Manager / Support) and the store.
CANCELLABLE = ("PLACED", "ACCEPTED", "PACKING", "PACKED")
STATS = (
    ("active_orders", "Active orders"),
    ("riders_online", "Riders online"),
    ("riders_delivering", "Riders delivering"),
    ("awaiting_assignment", "Awaiting rider"),
    ("picked_up", "Picked up"),
    ("in_transit", "In transit"),
    ("delayed", "Delayed"),
    ("completed_today", "Completed today"),
)


def map_provider() -> tuple[str, dict]:
    name = getattr(settings, "OPS_MAP_PROVIDER", DEFAULT_MAP_PROVIDER)
    if name not in MAP_PROVIDERS:
        name = DEFAULT_MAP_PROVIDER
    return name, MAP_PROVIDERS[name]


def drop_visible(user) -> bool:
    """The snapshot's own rule for `drop` / `area` (and the customer name): a route ends at the
    drop point, so the route endpoint answers only where the snapshot shows it."""
    return _snapshot_module().shows_customer_name(user)


def _snapshot_module():
    from apps.delivery.services import live_ops

    return live_ops


def _store_id(request) -> int | None:
    """The `store` filter, only if it is one of the user's stores (else no filter)."""
    store_id = parse_ascii_id(request.GET.get("store", ""))
    if store_id is None:
        return None
    return store_id if stores_for(request.user).filter(pk=store_id).exists() else None


def _url_template(name: str) -> str:
    """A URL for id 0; live_map.js puts the real (integer) id in place of `/0/`."""
    return reverse(name, args=[0])


def _labels() -> dict:
    return {
        kind: {code: {"label": b.label, "tone": b.tone} for code, b in BADGES[kind].items()}
        for kind in (ORDER, TASK)
    }


@ops_view(capability=capabilities.LIVE_BOARD)
def live_map(request):
    user = request.user
    if not _snapshot_module().can_view(user):
        return forbidden(request)
    provider, assets = map_provider()
    caps = capabilities.capability_flags(user)
    config = {
        "dataUrl": reverse("ops:live-map-data"),
        "routeUrl": _url_template("ops:live-map-route"),
        "orderUrl": _url_template("admin:orders_order_change"),
        "riderUrl": (
            _url_template("admin:delivery_rider_change")
            if user.has_perm("delivery.view_rider")
            else ""
        ),
        "taskUrl": _url_template("ops:dispatch-task") if caps["dispatch"] else "",
        "taskPanelUrl": _url_template("ops:dispatch-task-panel") if caps["dispatch"] else "",
        "cancelUrl": (
            _url_template("ops:board-cancel")
            if caps["cancel_order"] and order_actions.available(order_actions.CANCEL)
            else ""
        ),
        "cancellable": list(CANCELLABLE),
        "pollSeconds": poll_seconds(),
        "labels": _labels(),
        "stats": [{"key": key, "label": label} for key, label in STATS],
    }
    context = ops_context(
        request,
        title="Live deliveries",
        stores=list(visible_stores(user).only("pk", "code", "name").order_by("code")),
        store_id=_store_id(request),
        map_provider=provider,
        map_assets=assets,
        live_map_config=config,
        stats=STATS,
        cancel_form=CancelOrderForm(reasons=order_actions.cancel_reasons() or ()),
        caps=caps,
    )
    return render(request, "ops/riders/live_map.html", context)


@ops_view(capability=capabilities.LIVE_BOARD)
def live_map_data(request):
    try:
        data = _snapshot_module().snapshot(request.user, store_id=_store_id(request))
    except PermissionDenied:
        return forbidden(request)
    return JsonResponse(data, encoder=DjangoJSONEncoder)


@ops_view(capability=capabilities.LIVE_BOARD)
def live_map_route(request, order_id: int):
    """The rider's current leg for one delivery in the user's stores (another store's order
    is a 404). `route` is null without a rider position, outside ASSIGNED .. AT_CUSTOMER, or
    for a role that may not see the drop point."""
    from apps.delivery.models import DeliveryTask
    from apps.delivery.services import live_tracking
    from apps.delivery.services.shifts import latest_location
    from apps.orders.models import Order

    live_ops = _snapshot_module()
    if not live_ops.can_view(request.user):
        return forbidden(request)
    order = scope_to_stores(Order.objects.all(), request.user).filter(pk=order_id).first()
    if order is None:
        raise Http404("No such order.")
    route = None
    if drop_visible(request.user):
        task = (
            DeliveryTask.objects.filter(order=order)
            .defer(*live_ops.TASK_SECRETS)
            .select_related("rider")
            .first()
        )
        if task is not None and task.rider_id:
            location = latest_location(task.rider)
            point = (location["lat"], location["lng"]) if location else None
            tracked = live_tracking.rider_route(task, order, point)
            route = live_tracking.route_body(task, tracked)
    return JsonResponse({"order_id": order.pk, "route": route}, encoder=DjangoJSONEncoder)
