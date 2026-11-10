"""Ops dashboard metrics (05 §1.1, Phase 7) for the Ops Console. Store-scoped like the reports
(`reports.view_reports`, `stores_for`, optional `store_id`); `PermissionDenied` otherwise.

- `kpis(user, *, store_id=None, day=None, now=None) -> dict`: for one IST day (default today):
  orders, gmv, aov, delivered, cancelled, cancelled_pct, avg_delivery_minutes,
  avg_acceptance_seconds, sla_breaches {late_deliveries, late_acceptances, total},
  online_riders, active_orders, stock_outs, low_stock.
- `charts(user, *, store_id=None, day=None, trend_days=7, top=10) -> dict`: orders_per_hour
  (24 IST hours), gmv_trend (last `trend_days` days to `day`), top_products, payment_split.
- `alerts(user, *, store_id=None, now=None, limit=20) -> dict`: awaiting_acceptance (PLACED for
  more than DASHBOARD_ACCEPT_WAIT_ALERT_MINUTES), no_rider (task searching / unassigned for more
  than DASHBOARD_NO_RIDER_ALERT_MINUTES), low_stock, riders_over_cash_limit, failed_deliveries.
  Each is `{count, items[]}`.

Definitions follow `apps.reports.registry` (orders count on the IST day of `placed_at`; GMV
excludes CANCELLED). A **late delivery** is DELIVERED after `eta_at`; a **late acceptance** is
accepted more than `STORE_ACCEPTANCE_SLA_SECONDS` after placement (or still PLACED past it).
Money in the result is a 2-decimal string.
"""

from datetime import date, datetime, timedelta

from django.conf import settings
from django.core.exceptions import PermissionDenied
from django.db.models import (
    Avg,
    Count,
    DecimalField,
    DurationField,
    ExpressionWrapper,
    F,
    Q,
    Sum,
)
from django.db.models.functions import Coalesce, ExtractHour, TruncDate
from django.utils import timezone

from apps.core.money import money_str, round_money
from apps.reports.registry import VIEW_REPORTS, ZERO, day_start, ist
from apps.reports.services import MSG_NO_PERMISSION, scoped_stores


def _stores(user, store_id):
    if not (user and user.is_authenticated and user.is_active and user.is_staff):
        raise PermissionDenied(MSG_NO_PERMISSION)
    if not user.has_perm(VIEW_REPORTS):
        raise PermissionDenied(MSG_NO_PERMISSION)
    return scoped_stores(user, store_id)


def _today(now=None) -> date:
    return timezone.localtime(now or timezone.now(), ist()).date()


def _seconds(value: timedelta | None) -> float | None:
    return round(value.total_seconds(), 1) if value is not None else None


def kpis(user, *, store_id: int | None = None, day: date | None = None, now=None) -> dict:
    from apps.delivery.models import Rider
    from apps.inventory.models import StoreInventory
    from apps.orders.choices import ACTIVE_STATUSES, OrderStatus
    from apps.orders.models import Order

    stores = _stores(user, store_id)
    now = now or timezone.now()
    day = day or _today(now)
    since, until = day_start(day), day_start(day + timedelta(days=1))
    sla = timedelta(seconds=settings.STORE_ACCEPTANCE_SLA_SECONDS)
    orders = Order.objects.filter(store__in=stores, placed_at__gte=since, placed_at__lt=until)
    live = ~Q(status=OrderStatus.CANCELLED)
    stats = orders.aggregate(
        orders=Count("id"),
        delivered=Count("id", filter=Q(status=OrderStatus.DELIVERED)),
        cancelled=Count("id", filter=Q(status=OrderStatus.CANCELLED)),
        gmv=Coalesce(Sum("grand_total", filter=live), ZERO),
        avg_accept=Avg(
            ExpressionWrapper(F("accepted_at") - F("placed_at"), output_field=DurationField()),
            filter=Q(accepted_at__isnull=False),
        ),
        late_accept=Count(
            "id",
            filter=Q(accepted_at__gt=F("placed_at") + sla)
            | Q(status=OrderStatus.PLACED, placed_at__lt=now - sla),
        ),
    )
    delivered = Order.objects.filter(
        store__in=stores,
        status=OrderStatus.DELIVERED,
        delivered_at__gte=since,
        delivered_at__lt=until,
    ).aggregate(
        avg=Avg(
            ExpressionWrapper(F("delivered_at") - F("placed_at"), output_field=DurationField())
        ),
        late=Count("id", filter=Q(eta_at__isnull=False, delivered_at__gt=F("eta_at"))),
    )
    live_orders = stats["orders"] - stats["cancelled"]
    stock = StoreInventory.objects.filter(store__in=stores, variant__is_active=True)
    available = F("on_hand") - F("reserved")
    stock_stats = stock.aggregate(
        outs=Count("id", filter=Q(on_hand__lte=F("reserved")) | Q(is_available=False)),
        low=Count(
            "id",
            filter=Q(on_hand__gt=F("reserved"), is_available=True)
            & Q(low_stock_threshold__gt=available),
        ),
    )
    avg_delivery = delivered["avg"]
    return {
        "day": day,
        "orders": stats["orders"],
        "gmv": money_str(stats["gmv"]),
        "aov": money_str(round_money(stats["gmv"] / live_orders) if live_orders else ZERO),
        "delivered": stats["delivered"],
        "cancelled": stats["cancelled"],
        "cancelled_pct": round(100 * stats["cancelled"] / stats["orders"], 1)
        if stats["orders"]
        else 0.0,
        "avg_delivery_minutes": round(avg_delivery.total_seconds() / 60, 1)
        if avg_delivery is not None
        else None,
        "avg_acceptance_seconds": _seconds(stats["avg_accept"]),
        "sla_breaches": {
            "late_deliveries": delivered["late"],
            "late_acceptances": stats["late_accept"],
            "total": delivered["late"] + stats["late_accept"],
        },
        "online_riders": Rider.objects.filter(is_online=True, home_store__in=stores).count(),
        "active_orders": Order.objects.filter(store__in=stores, status__in=ACTIVE_STATUSES)
        .exclude(status=OrderStatus.PAYMENT_PENDING)
        .count(),
        "stock_outs": stock_stats["outs"],
        "low_stock": stock_stats["low"],
    }


def charts(
    user,
    *,
    store_id: int | None = None,
    day: date | None = None,
    trend_days: int = 7,
    top: int = 10,
    now=None,
) -> dict:
    from apps.orders.choices import OrderStatus
    from apps.orders.models import Order, OrderItem

    stores = _stores(user, store_id)
    day = day or _today(now)
    since, until = day_start(day), day_start(day + timedelta(days=1))
    today = Order.objects.filter(store__in=stores, placed_at__gte=since, placed_at__lt=until)
    per_hour = dict(
        today.annotate(hour=ExtractHour("placed_at", tzinfo=ist()))
        .values("hour")
        .annotate(n=Count("id"))
        .values_list("hour", "n")
    )
    trend_since = day_start(day - timedelta(days=trend_days - 1))
    live = ~Q(status=OrderStatus.CANCELLED)
    trend = {
        row["d"]: row
        for row in Order.objects.filter(
            store__in=stores, placed_at__gte=trend_since, placed_at__lt=until
        )
        .annotate(d=TruncDate("placed_at", tzinfo=ist()))
        .values("d")
        .annotate(orders=Count("id"), gmv=Coalesce(Sum("grand_total", filter=live), ZERO))
    }
    units = F("quantity") - F("quantity_unavailable")
    top_rows = (
        OrderItem.objects.filter(order__in=today.filter(live))
        .values("sku", "product_name", "variant_name")
        .annotate(
            units=Sum(units),
            revenue=Coalesce(
                Sum(
                    ExpressionWrapper(
                        F("selling_price") * units,
                        output_field=DecimalField(max_digits=14, decimal_places=2),
                    )
                ),
                ZERO,
            ),
        )
        .filter(units__gt=0)
        .order_by("-units", "sku")[:top]
    )
    split = {
        row["payment_method"]: row
        for row in today.filter(live)
        .values("payment_method")
        .annotate(orders=Count("id"), gmv=Coalesce(Sum("grand_total"), ZERO))
    }
    days = [day - timedelta(days=offset) for offset in range(trend_days - 1, -1, -1)]
    return {
        "orders_per_hour": [{"hour": h, "orders": per_hour.get(h, 0)} for h in range(24)],
        "gmv_trend": [
            {
                "day": d,
                "orders": trend[d]["orders"] if d in trend else 0,
                "gmv": money_str(trend[d]["gmv"] if d in trend else ZERO),
            }
            for d in days
        ],
        "top_products": [
            {
                "sku": row["sku"],
                "name": f"{row['product_name']} {row['variant_name']}".strip(),
                "units": row["units"],
                "revenue": money_str(round_money(row["revenue"])),
            }
            for row in top_rows
        ],
        "payment_split": [
            {
                "payment_method": method,
                "orders": split[method]["orders"] if method in split else 0,
                "gmv": money_str(split[method]["gmv"] if method in split else ZERO),
            }
            for method in ("ONLINE", "COD")
        ],
    }


def _age_minutes(start: datetime | None, now: datetime) -> float | None:
    return round((now - start).total_seconds() / 60, 1) if start else None


def alerts(user, *, store_id: int | None = None, now=None, limit: int = 20) -> dict:
    from apps.delivery.choices import DeliveryTaskStatus
    from apps.delivery.models import DeliveryTask, Rider
    from apps.inventory.models import StoreInventory
    from apps.orders.choices import OrderStatus
    from apps.orders.models import Order

    stores = _stores(user, store_id)
    now = now or timezone.now()

    def block(queryset, render):
        return {"count": queryset.count(), "items": [render(obj) for obj in queryset[:limit]]}

    waiting = (
        Order.objects.filter(
            store__in=stores,
            status=OrderStatus.PLACED,
            placed_at__lt=now - timedelta(minutes=settings.DASHBOARD_ACCEPT_WAIT_ALERT_MINUTES),
        )
        .select_related("store")
        .order_by("placed_at")
    )
    no_rider = (
        DeliveryTask.objects.filter(
            store__in=stores,
            status__in=[
                DeliveryTaskStatus.SEARCHING,
                DeliveryTaskStatus.OFFERED,
                DeliveryTaskStatus.UNASSIGNED,
            ],
            search_started_at__lt=now
            - timedelta(minutes=settings.DASHBOARD_NO_RIDER_ALERT_MINUTES),
        )
        .select_related("order", "store")
        .order_by("search_started_at")
    )
    low = (
        StoreInventory.objects.filter(store__in=stores, variant__is_active=True, is_available=True)
        .filter(low_stock_threshold__gt=F("on_hand") - F("reserved"))
        .select_related("store", "variant", "variant__product")
        .order_by("store__code", "variant__sku")
    )
    over_cash = (
        Rider.objects.filter(home_store__in=stores, cash_in_hand__gt=F("cash_limit"))
        .select_related("home_store")
        .order_by("-cash_in_hand")
    )
    failed = (
        Order.objects.filter(store__in=stores, status=OrderStatus.DELIVERY_FAILED)
        .select_related("store")
        .order_by("delivery_failed_at")
    )
    return {
        "awaiting_acceptance": block(
            waiting,
            lambda o: {
                "order_id": o.pk,
                "order_number": o.order_number,
                "store": o.store.code,
                "minutes": _age_minutes(o.placed_at, now),
            },
        ),
        "no_rider": block(
            no_rider,
            lambda t: {
                "order_id": t.order_id,
                "order_number": t.order.order_number,
                "store": t.store.code,
                "task_status": t.status,
                "minutes": _age_minutes(t.search_started_at, now),
            },
        ),
        "low_stock": block(
            low,
            lambda s: {
                "store": s.store.code,
                "sku": s.variant.sku,
                "name": f"{s.variant.product.name} {s.variant.name}",
                "available": s.on_hand - s.reserved,
                "threshold": s.low_stock_threshold,
            },
        ),
        "riders_over_cash_limit": block(
            over_cash,
            lambda r: {
                "rider_id": r.pk,
                "name": r.full_name,
                "store": r.home_store.code if r.home_store_id else "",
                "cash_in_hand": money_str(r.cash_in_hand),
                "cash_limit": money_str(r.cash_limit),
            },
        ),
        "failed_deliveries": block(
            failed,
            lambda o: {
                "order_id": o.pk,
                "order_number": o.order_number,
                "store": o.store.code,
                "minutes": _age_minutes(o.delivery_failed_at, now),
            },
        ),
    }
