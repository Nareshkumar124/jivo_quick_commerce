"""Dashboard order section (05 §1.1, P7): KPI cards, charts and the alerts panel, filtered by
IST day and store. Capability `reports` (05 §3 "Reports" row). The store filter lists only the
user's stores, so another store's id is an invalid choice (a field error), never a way to read
its numbers.

The numbers come from the backend's `apps.reports.dashboard` (`kpis`, `charts`, `alerts`),
which re-checks `reports.view_reports` and the store scope. Money arrives as 2-decimal strings
and is only formatted here, never recomputed.
"""

from datetime import timedelta

from django import forms
from django.urls import NoReverseMatch, reverse
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldAdminTextInputWidget

from apps.ops_console import capabilities
from apps.ops_console.dates import local_day_start, local_today
from apps.ops_console.money import inr
from apps.ops_console.sla import duration_text
from apps.orders.ratings import LOW_RATING_MAX_STARS, staff_ratings
from apps.reports import dashboard
from apps.stores.services import stores_for

MAX_DAYS_BACK = 366
ALERT_ITEMS_SHOWN = 5
METHOD_LABELS = {"ONLINE": "Pay online", "COD": "Cash on delivery"}


class DashboardFilterForm(forms.Form):
    day = forms.DateField(
        label="Day", required=False, widget=UnfoldAdminTextInputWidget(attrs={"type": "date"})
    )
    store = forms.TypedChoiceField(
        label="Store", required=False, coerce=int, empty_value=None, widget=UnfoldAdminSelectWidget
    )

    def __init__(self, data, *, stores, **kwargs):
        super().__init__(data, **kwargs)
        self.fields["store"].choices = [("", "All my stores")] + [
            (store.pk, f"{store.code} · {store.name}")
            for store in stores.only("pk", "code", "name").order_by("code")
        ]

    def clean_day(self):
        day = self.cleaned_data.get("day")
        today = local_today()
        if day is None:
            return today
        if day > today:
            raise forms.ValidationError("Choose today or an earlier day.")
        if day < today - timedelta(days=MAX_DAYS_BACK):
            raise forms.ValidationError("Choose a day in the last year.")
        return day


def _url(name: str, query: str = "") -> str:
    try:
        base = reverse(name)
    except NoReverseMatch:
        return ""
    return f"{base}?{query}" if query else base


def _seconds(value) -> str:
    return duration_text(value) if value is not None else "-"


# A link only when the user may open its target (hiding is not the check: every target enforces
# its own rule; this only avoids offering a 403).
ALERT_TARGETS = {
    "acceptance": (capabilities.LIVE_BOARD, "ops:live-board", "breached=on"),
    "no_rider": (capabilities.DISPATCH, "ops:dispatch", ""),
    "cash_limit": (capabilities.CASH_DEPOSIT, "ops:cash", ""),
    "failed": (capabilities.LIVE_BOARD, "ops:live-board", ""),
    "low_stock": (None, "admin:inventory_storeinventory_changelist", "stock=low&on_sale=1"),
    "low_ratings": (None, "admin:orders_rating_changelist", "low=1"),
}
VIEW_RATING = "orders.view_rating"
PERMISSION_TARGETS = {"low_stock": "inventory.view_storeinventory", "low_ratings": VIEW_RATING}


def _alert_link(user, key: str) -> str:
    capability, name, query = ALERT_TARGETS[key]
    if capability is None:
        allowed = user.has_perm(PERMISSION_TARGETS[key])
    else:
        allowed = capabilities.allowed(user, capability)
    return _url(name, query) if allowed else ""


def _alert(user, key, label, count, tone="danger", items=()) -> dict:
    return {
        "key": key,
        "label": label,
        "count": count,
        "tone": tone,
        "href": _alert_link(user, key),
        "items": list(items)[:ALERT_ITEMS_SHOWN],
    }


def _chart(kind, labels, label, data, rows) -> dict:
    return {
        "type": kind,
        "labels": labels,
        "datasets": [{"label": label, "data": data}],
        "rows": rows,
    }


def build(request) -> dict:
    """Context for `ops/partials/order_dashboard.html`."""
    user = request.user
    stores = stores_for(user)  # once per request
    form = DashboardFilterForm(request.GET or {}, stores=stores)
    form.is_valid()
    if form.errors:
        return {"order_form": form, "order_errors": True}
    day = form.cleaned_data["day"]
    store_id = form.cleaned_data.get("store")
    section = _section(user, day, store_id)
    return {
        "order_form": form,
        "order_day": day,
        "is_today": day == local_today(),
        "alerts_total": sum(alert["count"] for alert in section["alert_rows"]),
        **section,
    }


# --------------------------------------------------------------------------- section


def _items(block, render) -> list[str]:
    return [render(item) for item in block["items"]]


def _order_item(item) -> str:
    minutes = item.get("minutes")
    tail = f" · {minutes} min" if minutes is not None else ""
    return f"{item['order_number']} · {item['store']}{tail}"


def _low_ratings(user, day, store_id) -> dict | None:
    """Low ratings (`staff_ratings(low_only=True)`, the backend's LOW_RATING_MAX_STARS) given on
    the chosen IST day, for roles with `orders.view_rating` only (05 §2 Ratings). None hides it."""
    if not user.has_perm(VIEW_RATING):
        return None
    rows = staff_ratings(user, store_id=store_id, low_only=True).filter(
        created_at__gte=local_day_start(day),
        created_at__lt=local_day_start(day + timedelta(days=1)),
    )
    shown = list(rows[:ALERT_ITEMS_SHOWN])  # one query; count only when there may be more
    count = len(shown) if len(shown) < ALERT_ITEMS_SHOWN else rows.count()
    items = [
        f"{row.order.order_number} · {row.order.store.code} · {row.get_target_display()} "
        f"{row.stars}★"
        for row in shown
    ]
    return _alert(
        user,
        "low_ratings",
        f"Low ratings ({LOW_RATING_MAX_STARS}★ or fewer) on this day",
        count,
        tone="warning",
        items=items,
    )


def _section(user, day, store_id) -> dict:
    kpis = dashboard.kpis(user, store_id=store_id, day=day)
    charts = dashboard.charts(user, store_id=store_id, day=day)
    alerts = dashboard.alerts(user, store_id=store_id)
    minutes = kpis["avg_delivery_minutes"]
    breaches = kpis["sla_breaches"]
    hours = [(f"{row['hour']:02d}:00", row["orders"]) for row in charts["orders_per_hour"]]
    trend = charts["gmv_trend"]
    top = charts["top_products"]
    split = [
        (METHOD_LABELS.get(row["payment_method"], row["payment_method"]), row["orders"])
        for row in charts["payment_split"]
    ]
    return {
        "kpis": kpis,
        "kpi_cards": [
            ("Orders", kpis["orders"], "receipt", ""),
            ("GMV", inr(kpis["gmv"]), "currency_rupee", "Excludes cancelled orders"),
            ("AOV", inr(kpis["aov"]), "shopping_bag", ""),
            ("Delivered", kpis["delivered"], "task_alt", ""),
            ("Cancelled", f"{kpis['cancelled']} ({kpis['cancelled_pct']}%)", "cancel", ""),
            (
                "Avg delivery time",
                _seconds(minutes * 60) if minutes is not None else "-",
                "timer",
                "Placed to delivered",
            ),
            (
                "Avg acceptance time",
                _seconds(kpis["avg_acceptance_seconds"]),
                "schedule",
                "Placed to accepted",
            ),
            (
                "SLA breaches",
                breaches["total"],
                "alarm",
                f"{breaches['late_acceptances']} late acceptances, "
                f"{breaches['late_deliveries']} late deliveries",
            ),
            ("Online riders", kpis["online_riders"], "two_wheeler", "Right now"),
            ("Active orders", kpis["active_orders"], "pending_actions", "Right now"),
            ("Out of stock", kpis["stock_outs"], "remove_shopping_cart", "Right now"),
            ("Low stock", kpis["low_stock"], "warning", "Right now"),
        ],
        "hour_chart": _chart("bar", [h for h, _ in hours], "Orders", [n for _, n in hours], hours),
        "gmv_chart": _chart(
            "line",
            [row["day"].strftime("%d %b") for row in trend],
            "GMV (₹)",
            [float(row["gmv"]) for row in trend],  # chart drawing only; the table shows strings
            [(row["day"], inr(row["gmv"])) for row in trend],
        ),
        "top_chart": _chart(
            "bar",
            [row["name"] for row in top],
            "Units",
            [row["units"] for row in top],
            [(row["name"], f"{row['units']} units, {inr(row['revenue'])}") for row in top],
        ),
        "split_chart": _chart("bar", [m for m, _ in split], "Orders", [n for _, n in split], split),
        "alert_rows": [
            _alert(
                user,
                "acceptance",
                "Waiting too long for store acceptance",
                alerts["awaiting_acceptance"]["count"],
                items=_items(alerts["awaiting_acceptance"], _order_item),
            ),
            _alert(
                user,
                "no_rider",
                "Orders without a rider",
                alerts["no_rider"]["count"],
                items=_items(alerts["no_rider"], _order_item),
            ),
            _alert(
                user,
                "low_stock",
                "Low-stock SKUs",
                alerts["low_stock"]["count"],
                tone="warning",
                items=_items(
                    alerts["low_stock"],
                    lambda i: f"{i['sku']} · {i['store']} · {i['available']} left",
                ),
            ),
            _alert(
                user,
                "cash_limit",
                "Riders over their cash limit",
                alerts["riders_over_cash_limit"]["count"],
                tone="warning",
                items=_items(
                    alerts["riders_over_cash_limit"],
                    lambda i: f"{i['store']} · {inr(i['cash_in_hand'])} of {inr(i['cash_limit'])}",
                ),
            ),
            _alert(
                user,
                "failed",
                "Failed deliveries awaiting return",
                alerts["failed_deliveries"]["count"],
                items=_items(alerts["failed_deliveries"], _order_item),
            ),
            *[row for row in [_low_ratings(user, day, store_id)] if row is not None],
        ],
    }
