"""Report builders (05 §4, Phase 7). Each report is a `ReportSpec`: a key, a title, the permission
it needs, its columns and a builder that yields rows for a `ReportQuery` (the caller's stores,
already scoped with `stores_for`, and an IST date range).

Cells are plain values: money as `Decimal`, dates and times in IST, counts as `int`. The
service layer formats them (2-decimal strings, CSV with formula escaping). No report carries a
customer's name, phone or address (09 PII); riders appear by id and name (payouts need them).

Definitions (⚠ PM defaults, documented in docs/05 §4):
- An order **counts** on the IST day of `placed_at` (orders that never reached PLACED are left
  out). **Live** orders are the counted orders that are not CANCELLED.
- **GMV** = sum of `grand_total` of live orders (the current bill: after a T8a partial
  unavailability it is already the reduced one). **AOV** = GMV / live orders.
- **Tips** = tips of live orders except DELIVERY_FAILED / RETURNED (a tip is passed to the
  rider on delivery; a failed delivery's tip is refunded to an online customer inside the
  failed-delivery refund, 08 §6.4, so it is not subtracted twice).
- **Refunded** = processed refunds (`amount_refunded`) of live orders, minus their processed
  T8a (`item_unavailable`) refunds, which the reduced `grand_total` already reflects.
  **Unavailable refunds** (those T8a refunds) are shown for reconciliation only.
- **Net revenue** = GMV - tips - refunded.
- **Cancelled refunds** = processed refunds of CANCELLED orders: shown on their own, never
  part of GMV or net revenue (those orders are not in GMV).
- **Product sales** count DELIVERED orders on the IST day of `delivered_at`: units delivered
  (ordered - unavailable) and their value at the order price (before the coupon share).
- **GST** follows the invoice maths (`orders.invoices.tax_lines`), grouped per invoice, HSN/SAC
  and rate; CGST is half the tax rounded half up, SGST the rest (intra-state), else IGST.
"""

from collections.abc import Callable, Iterable, Iterator
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db.models import Count, DecimalField, ExpressionWrapper, F, Q, Sum
from django.db.models.functions import Coalesce, TruncDate
from django.utils import timezone

from apps.core.money import round_money

ZERO = Decimal("0.00")
VIEW_REPORTS = "reports.view_reports"
VIEW_CATALOG = "reports.view_catalog_reports"
VIEW_FINANCE = "reports.view_finance_reports"


def ist() -> ZoneInfo:
    return ZoneInfo(settings.STORE_TIME_ZONE)


def day_start(day: date) -> datetime:
    return datetime(day.year, day.month, day.day, tzinfo=ist())


def local(value: datetime | None) -> str:
    return timezone.localtime(value, ist()).strftime("%Y-%m-%d %H:%M") if value else ""


@dataclass(frozen=True)
class ReportQuery:
    stores: object  # QuerySet[DarkStore], already scoped to the user (and to store_id)
    start: date
    end: date  # inclusive
    all_stores: bool = False  # every store, unfiltered (a global role, no store_id)

    @property
    def since(self) -> datetime:
        return day_start(self.start)

    @property
    def until(self) -> datetime:
        return day_start(self.end + timedelta(days=1))


@dataclass(frozen=True)
class ReportSpec:
    key: str
    title: str
    permission: str
    columns: tuple[str, ...]
    build: Callable[[ReportQuery], Iterable[tuple]]
    description: str = ""
    dated: bool = True  # False: a snapshot (current stock); the date range is ignored


def _money_sum(field: str) -> Coalesce:
    return Coalesce(Sum(field), ZERO, output_field=DecimalField(max_digits=14, decimal_places=2))


# --------------------------------------------------------------------------- sales and orders


def _counted_orders(query: ReportQuery):
    from apps.orders.models import Order

    return Order.objects.filter(
        store__in=query.stores,
        placed_at__gte=query.since,
        placed_at__lt=query.until,
    )


def sales_summary(query: ReportQuery) -> Iterator[tuple]:
    """See the module doc for GMV, tips, refunded, net revenue and cancelled refunds."""
    from apps.orders.choices import OrderStatus
    from apps.payments.models import Refund, RefundStatus
    from apps.payments.order_refunds import ITEM_UNAVAILABLE

    cancelled = Q(status=OrderStatus.CANCELLED)
    live = ~cancelled
    tipped = live & ~Q(status__in=(OrderStatus.DELIVERY_FAILED, OrderStatus.RETURNED))
    rows = (
        _counted_orders(query)
        .annotate(day=TruncDate("placed_at", tzinfo=ist()))
        .values("day", "store__code")
        .annotate(
            orders=Count("id"),
            delivered=Count("id", filter=Q(status=OrderStatus.DELIVERED)),
            cancelled=Count("id", filter=cancelled),
            gmv=Coalesce(Sum("grand_total", filter=live), ZERO),
            item_total=Coalesce(Sum("item_total", filter=live), ZERO),
            product_discount=Coalesce(Sum("product_discount", filter=live), ZERO),
            coupon_discount=Coalesce(Sum("coupon_discount", filter=live), ZERO),
            fees=Coalesce(
                Sum(F("delivery_fee") + F("small_cart_fee") + F("handling_fee"), filter=live),
                ZERO,
            ),
            tips=Coalesce(Sum("tip", filter=tipped), ZERO),
            live_refunded=Coalesce(Sum("amount_refunded", filter=live), ZERO),
            cancelled_refunds=Coalesce(Sum("amount_refunded", filter=cancelled), ZERO),
        )
        .order_by("day", "store__code")
    )
    # T8a refunds of live orders, by the same (order day, store) key.
    unavailable = {
        (row["day"], row["order__store__code"]): row["amount"]
        for row in Refund.objects.filter(
            order__in=_counted_orders(query).filter(live),
            reason=ITEM_UNAVAILABLE,
            status=RefundStatus.PROCESSED,
        )
        .annotate(day=TruncDate("order__placed_at", tzinfo=ist()))
        .values("day", "order__store__code")
        .annotate(amount=_money_sum("amount"))
    }
    for row in rows:
        live_orders = row["orders"] - row["cancelled"]
        aov = round_money(row["gmv"] / live_orders) if live_orders else ZERO
        unavailable_refunds = unavailable.get((row["day"], row["store__code"]), ZERO)
        refunded = max(row["live_refunded"] - unavailable_refunds, ZERO)
        yield (
            row["day"],
            row["store__code"],
            row["orders"],
            row["delivered"],
            row["cancelled"],
            row["item_total"],
            row["product_discount"],
            row["coupon_discount"],
            row["fees"],
            row["tips"],
            row["gmv"],
            refunded,
            row["gmv"] - row["tips"] - refunded,
            aov,
            unavailable_refunds,
            row["cancelled_refunds"],
        )


def orders_report(query: ReportQuery) -> Iterator[tuple]:
    rows = (
        _counted_orders(query)
        .select_related("store")
        .order_by("placed_at", "id")
        .only(
            "order_number",
            "placed_at",
            "store__code",
            "status",
            "payment_method",
            "payment_status",
            "item_total",
            "coupon_discount",
            "coupon_code",
            "delivery_fee",
            "small_cart_fee",
            "handling_fee",
            "tip",
            "grand_total",
            "amount_refunded",
            "accepted_at",
            "delivered_at",
            "cancel_reason",
            "cancelled_by_type",
        )
    )
    for order in rows.iterator(chunk_size=2000):
        minutes = (
            round((order.delivered_at - order.placed_at).total_seconds() / 60, 1)
            if order.delivered_at
            else ""
        )
        yield (
            order.order_number,
            local(order.placed_at),
            order.store.code,
            order.status,
            order.payment_method,
            order.payment_status,
            order.item_total,
            order.coupon_code,
            order.coupon_discount,
            order.delivery_fee + order.small_cart_fee + order.handling_fee,
            order.tip,
            order.grand_total,
            order.amount_refunded,
            local(order.accepted_at),
            local(order.delivered_at),
            minutes,
            order.cancel_reason,
            order.cancelled_by_type,
        )


def cancellations(query: ReportQuery) -> Iterator[tuple]:
    from apps.orders.models import Order

    rows = (
        Order.objects.filter(
            store__in=query.stores, cancelled_at__gte=query.since, cancelled_at__lt=query.until
        )
        .values("store__code", "cancel_reason", "cancelled_by_type")
        .annotate(orders=Count("id"), value=_money_sum("grand_total"))
        .order_by("store__code", "-orders", "cancel_reason")
    )
    for row in rows:
        yield (
            row["store__code"],
            row["cancel_reason"] or "",
            row["cancelled_by_type"] or "",
            row["orders"],
            row["value"],
        )


def refunds(query: ReportQuery) -> Iterator[tuple]:
    from apps.payments.models import Refund

    rows = (
        Refund.objects.filter(
            order__store__in=query.stores,
            created_at__gte=query.since,
            created_at__lt=query.until,
        )
        .select_related("order", "order__store")
        .order_by("created_at", "id")
    )
    for refund in rows.iterator(chunk_size=2000):
        yield (
            refund.pk,
            local(refund.created_at),
            refund.order.order_number,
            refund.order.store.code,
            refund.amount,
            refund.status,
            refund.reason,
            "staff" if refund.initiated_by_id else "system",
            refund.initiated_by_id or "",
            refund.gateway_refund_id,
            local(refund.processed_at),
        )


def cod_reconciliation(query: ReportQuery) -> Iterator[tuple]:
    """COD collected vs deposited per rider, store and IST day (05 §1.5, §4)."""
    from apps.delivery.choices import CashEntryType
    from apps.delivery.models import RiderCashLedger

    rows = (
        RiderCashLedger.objects.filter(
            store__in=query.stores,
            recorded_at__gte=query.since,
            recorded_at__lt=query.until,
        )
        .annotate(day=TruncDate("recorded_at", tzinfo=ist()))
        .values("day", "store__code", "rider_id", "rider__full_name")
        .annotate(
            collected=Coalesce(
                Sum("amount", filter=Q(entry_type=CashEntryType.COD_COLLECTED)), ZERO
            ),
            deposited=Coalesce(Sum("amount", filter=Q(entry_type=CashEntryType.DEPOSIT)), ZERO),
            adjusted=Coalesce(Sum("amount", filter=Q(entry_type=CashEntryType.ADJUSTMENT)), ZERO),
        )
        .order_by("day", "store__code", "rider_id")
    )
    for row in rows:
        deposited = -row["deposited"]
        yield (
            row["day"],
            row["store__code"],
            row["rider_id"],
            row["rider__full_name"],
            row["collected"],
            deposited,
            row["adjusted"],
            row["collected"] - deposited + row["adjusted"],
        )


# --------------------------------------------------------------------------- catalog


def product_sales(query: ReportQuery) -> Iterator[tuple]:
    from apps.orders.choices import OrderStatus
    from apps.orders.models import OrderItem

    units = F("quantity") - F("quantity_unavailable")
    rows = (
        OrderItem.objects.filter(
            order__store__in=query.stores,
            order__status=OrderStatus.DELIVERED,
            order__delivered_at__gte=query.since,
            order__delivered_at__lt=query.until,
        )
        .values("order__store__code", "sku", "product_name", "variant_name")
        .annotate(
            units=Sum(units),
            orders=Count("order_id", distinct=True),
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
        .order_by("order__store__code", "-revenue", "sku")
    )
    for row in rows:
        yield (
            row["order__store__code"],
            row["sku"],
            row["product_name"],
            row["variant_name"],
            row["orders"],
            row["units"],
            round_money(row["revenue"]),
        )


def inventory_stock(query: ReportQuery) -> Iterator[tuple]:
    from apps.inventory.models import StoreInventory

    rows = (
        StoreInventory.objects.filter(store__in=query.stores)
        .select_related("store", "variant", "variant__product")
        .order_by("store__code", "variant__sku")
    )
    for row in rows.iterator(chunk_size=2000):
        available = row.on_hand - row.reserved
        yield (
            row.store.code,
            row.variant.sku,
            row.variant.product.name,
            row.variant.name,
            row.on_hand,
            row.reserved,
            available,
            row.low_stock_threshold,
            "yes" if available < row.low_stock_threshold else "no",
            "yes" if row.is_available else "no",
        )


def inventory_movements(query: ReportQuery) -> Iterator[tuple]:
    from apps.inventory.models import StockMovement

    rows = (
        StockMovement.objects.filter(
            store__in=query.stores,
            created_at__gte=query.since,
            created_at__lt=query.until,
        )
        .select_related("store", "variant", "order")
        .order_by("created_at", "id")
    )
    for row in rows.iterator(chunk_size=2000):
        yield (
            local(row.created_at),
            row.store.code,
            row.variant.sku,
            row.type,
            row.delta,
            row.on_hand_after,
            row.order.order_number if row.order_id else "",
            row.reason,
            row.created_by_id or "",
        )


# --------------------------------------------------------------------------- finance


def gst_invoices(query: ReportQuery) -> Iterator[tuple]:
    """Invoice-wise taxable value and CGST/SGST/IGST per HSN/SAC and rate (GSTR-1 prep)."""
    from apps.orders.invoices import is_intra_state, tax_lines
    from apps.orders.models import Invoice

    invoices = (
        Invoice.objects.filter(
            order__store__in=query.stores,
            issued_at__gte=query.since,
            issued_at__lt=query.until,
        )
        .select_related("order", "order__store")
        .prefetch_related("order__items")
        .order_by("issued_at", "id")
    )
    for invoice in invoices.iterator(chunk_size=500):
        order = invoice.order
        intra = is_intra_state(order)
        groups: dict[tuple[str, Decimal], list] = {}
        for line in tax_lines(order):
            group = groups.setdefault((line.code, line.rate), [0, ZERO, ZERO])
            group[0] += line.quantity
            group[1] += line.taxable
            group[2] += line.tax
        for (code, rate), (quantity, taxable, tax) in sorted(groups.items()):
            cgst = round_money(tax / 2) if intra else ZERO
            sgst = tax - cgst if intra else ZERO
            igst = ZERO if intra else tax
            yield (
                invoice.invoice_number,
                local(invoice.issued_at)[:10],
                order.store.code,
                invoice.seller_gstin,
                (order.address_snapshot or {}).get("state", ""),
                code,
                rate,
                quantity,
                taxable,
                cgst,
                sgst,
                igst,
                taxable + tax,
                "yes" if invoice.is_placeholder else "no",
            )


def gst_hsn_summary(query: ReportQuery) -> Iterator[tuple]:
    """HSN/SAC-wise summary of the invoice rows (GSTR-1 table 12)."""
    totals: dict[tuple[str, Decimal], list] = {}
    for row in gst_invoices(query):
        code, rate = row[5], row[6]
        group = totals.setdefault((code, rate), [0, ZERO, ZERO, ZERO, ZERO, ZERO])
        for index, value in enumerate(row[7:13]):
            group[index] += value
    for (code, rate), values in sorted(totals.items()):
        yield (code, rate, *values)


def _rider_store_q(query: ReportQuery) -> Q:
    """Riders of the query's stores (home store, else the store they applied for). Not
    filtered at all for an all-store query, so no rider is ever hidden from global roles."""
    if query.all_stores:
        return Q()
    return Q(rider__home_store__in=query.stores) | Q(
        rider__home_store__isnull=True, rider__preferred_store__in=query.stores
    )


def rider_earnings(query: ReportQuery) -> Iterator[tuple]:
    from apps.delivery.choices import EarningType, PayoutStatus
    from apps.delivery.models import RiderEarning

    def of(kind):
        return Coalesce(Sum("amount", filter=Q(type=kind)), ZERO)

    rows = (
        RiderEarning.objects.filter(
            _rider_store_q(query), earned_at__gte=query.since, earned_at__lt=query.until
        )
        .values("rider_id", "rider__full_name", "rider__home_store__code")
        .annotate(
            deliveries=Count("task_id", distinct=True, filter=Q(type=EarningType.BASE)),
            base=of(EarningType.BASE),
            distance=of(EarningType.DISTANCE),
            tips=of(EarningType.TIP),
            incentives=of(EarningType.INCENTIVE),
            penalties=of(EarningType.PENALTY),
            total=_money_sum("amount"),
            paid=Coalesce(Sum("amount", filter=Q(payout__status=PayoutStatus.PAID)), ZERO),
        )
        .order_by("rider__home_store__code", "rider_id")
    )
    for row in rows:
        yield (
            row["rider_id"],
            row["rider__full_name"],
            row["rider__home_store__code"] or "",
            row["deliveries"],
            row["base"],
            row["distance"],
            row["tips"],
            row["incentives"],
            row["penalties"],
            row["total"],
            row["paid"],
            row["total"] - row["paid"],
        )


def payouts(query: ReportQuery) -> Iterator[tuple]:
    from apps.delivery.models import Payout

    rows = (
        Payout.objects.filter(
            _rider_store_q(query),
            period_end__gte=query.start,
            period_start__lte=query.end,
        )
        .select_related("rider", "rider__home_store")
        .order_by("period_start", "rider_id", "id")
    )
    for payout in rows:
        yield (
            payout.pk,
            payout.rider_id,
            payout.rider.full_name,
            payout.rider.home_store.code if payout.rider.home_store_id else "",
            payout.period_start,
            payout.period_end,
            payout.amount,
            payout.status,
            payout.reference,
            local(payout.paid_at),
        )


REPORTS: dict[str, ReportSpec] = {
    spec.key: spec
    for spec in [
        ReportSpec(
            "sales_summary",
            "Sales summary",
            VIEW_REPORTS,
            (
                "day",
                "store",
                "orders",
                "delivered",
                "cancelled",
                "item_total",
                "product_discount",
                "coupon_discount",
                "fees",
                "tips",
                "gmv",
                "refunded",
                "net_revenue",
                "aov",
                "unavailable_refunds",
                "cancelled_refunds",
            ),
            sales_summary,
            "Orders, GMV, discounts, fees, net revenue and AOV per IST day and store "
            "(refunds of cancelled orders shown apart).",
        ),
        ReportSpec(
            "orders",
            "Orders",
            VIEW_REPORTS,
            (
                "order_number",
                "placed_at",
                "store",
                "status",
                "payment_method",
                "payment_status",
                "item_total",
                "coupon_code",
                "coupon_discount",
                "fees",
                "tip",
                "grand_total",
                "refunded",
                "accepted_at",
                "delivered_at",
                "delivery_minutes",
                "cancel_reason",
                "cancelled_by",
            ),
            orders_report,
            "One row per order placed in the range (no customer details).",
        ),
        ReportSpec(
            "cancellations",
            "Cancellations",
            VIEW_REPORTS,
            ("store", "reason", "cancelled_by", "orders", "order_value"),
            cancellations,
            "Cancelled orders by store, reason and actor.",
        ),
        ReportSpec(
            "refunds",
            "Refunds",
            VIEW_REPORTS,
            (
                "refund_id",
                "created_at",
                "order_number",
                "store",
                "amount",
                "status",
                "reason",
                "initiated_by",
                "staff_user_id",
                "gateway_refund_id",
                "processed_at",
            ),
            refunds,
            "Refunds created in the range.",
        ),
        ReportSpec(
            "cod_reconciliation",
            "COD reconciliation",
            VIEW_REPORTS,
            (
                "day",
                "store",
                "rider_id",
                "rider",
                "collected",
                "deposited",
                "adjusted",
                "difference",
            ),
            cod_reconciliation,
            "Cash collected vs deposited per rider, store and IST day.",
        ),
        ReportSpec(
            "product_sales",
            "Product sales",
            VIEW_CATALOG,
            ("store", "sku", "product", "variant", "orders", "units", "revenue"),
            product_sales,
            "Units and revenue per SKU and store (delivered orders).",
        ),
        ReportSpec(
            "inventory_stock",
            "Current stock",
            VIEW_CATALOG,
            (
                "store",
                "sku",
                "product",
                "variant",
                "on_hand",
                "reserved",
                "available",
                "low_stock_threshold",
                "low_stock",
                "sellable",
            ),
            inventory_stock,
            "Stock per store and SKU now (the date range is ignored).",
            dated=False,
        ),
        ReportSpec(
            "inventory_movements",
            "Stock movements",
            VIEW_CATALOG,
            (
                "created_at",
                "store",
                "sku",
                "type",
                "delta",
                "on_hand_after",
                "order_number",
                "reason",
                "staff_user_id",
            ),
            inventory_movements,
            "The stock ledger (every on-hand change).",
        ),
        ReportSpec(
            "gst_invoices",
            "GST by invoice",
            VIEW_FINANCE,
            (
                "invoice_number",
                "invoice_date",
                "store",
                "seller_gstin",
                "place_of_supply",
                "hsn_sac",
                "gst_rate",
                "quantity",
                "taxable_value",
                "cgst",
                "sgst",
                "igst",
                "invoice_value",
                "placeholder",
            ),
            gst_invoices,
            "Invoice-wise taxable value and CGST/SGST/IGST per HSN/SAC and rate (GSTR-1).",
        ),
        ReportSpec(
            "gst_hsn_summary",
            "GST HSN summary",
            VIEW_FINANCE,
            (
                "hsn_sac",
                "gst_rate",
                "quantity",
                "taxable_value",
                "cgst",
                "sgst",
                "igst",
                "total_value",
            ),
            gst_hsn_summary,
            "HSN/SAC-wise totals of the invoices in the range.",
        ),
        ReportSpec(
            "rider_earnings",
            "Rider earnings",
            VIEW_FINANCE,
            (
                "rider_id",
                "rider",
                "home_store",
                "deliveries",
                "base",
                "distance",
                "tips",
                "incentives",
                "penalties",
                "total",
                "paid",
                "unpaid",
            ),
            rider_earnings,
            "Earnings per rider for the range (by delivery time).",
        ),
        ReportSpec(
            "payouts",
            "Rider payouts",
            VIEW_FINANCE,
            (
                "payout_id",
                "rider_id",
                "rider",
                "home_store",
                "period_start",
                "period_end",
                "amount",
                "status",
                "reference",
                "paid_at",
            ),
            payouts,
            "Payouts whose period overlaps the range.",
        ),
    ]
}
