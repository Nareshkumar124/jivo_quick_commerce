"""GST invoices (06 §5 `generate_invoice`, 07 §2.6, 09 §4): made on demand for a delivered order
(Phase 4) and on DELIVERED (T10, Phase 5), rendered to PDF with WeasyPrint and kept in the
private bucket; the customer gets a short-lived signed link.

**D-12 is not decided.** The seller's GSTIN comes from the store (`DarkStore.gstin`); a store
without one, a product without an HSN code and the fees' SAC use the clearly marked placeholders
of settings (`INVOICE_PLACEHOLDER_GSTIN`, `INVOICE_PLACEHOLDER_HSN`, `INVOICE_FEE_SAC`). Any
placeholder makes the invoice `is_placeholder`, and its PDF says "PLACEHOLDER - NOT A VALID TAX
INVOICE". Nothing here invents a real-looking GSTIN, HSN or SAC.

Amounts (prices are GST-inclusive, 08 §6.2): for each line the units delivered (ordered minus
unavailable) at the order's price, less its share of the coupon discount (pro rata to line
value; the last line takes the rounding remainder), split into taxable value and GST at the
product's rate. Delivery, small-cart and handling fees are taxed at `INVOICE_FEE_GST_RATE`
(placeholder). The tip is passed to the rider and is not part of the tax invoice. Intra-state
supply (store state = delivery state): CGST + SGST halves; otherwise IGST.

WeasyPrint needs native Pango/GTK libraries. Where they are missing (e.g. a Windows dev host),
`render_pdf` raises `InvoiceRenderingUnavailable` and the API answers 503; the invoice row and
its numbers are still made.
"""

import logging
from dataclasses import dataclass
from datetime import timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.db import transaction
from django.template.loader import render_to_string
from django.utils import timezone

from apps.core.money import money_str, round_money
from apps.orders.choices import OrderStatus
from apps.orders.models import Invoice, InvoiceSequence, Order

logger = logging.getLogger(__name__)

ZERO = Decimal("0.00")
HUNDRED = Decimal("100")


class InvoiceRenderingUnavailable(Exception):
    """WeasyPrint (or its native libraries) is not available on this host."""


@dataclass
class TaxLine:
    description: str
    code: str  # HSN (goods) or SAC (fees)
    quantity: int
    gross: Decimal  # GST-inclusive value after the coupon share
    rate: Decimal
    taxable: Decimal = ZERO
    tax: Decimal = ZERO
    placeholder: bool = False

    def split(self) -> None:
        self.taxable = round_money(self.gross * HUNDRED / (HUNDRED + self.rate))
        self.tax = self.gross - self.taxable


def financial_year(at) -> str:
    """Indian financial year (April-March) in IST, e.g. "26-27"."""
    local = at.astimezone(ZoneInfo(settings.STORE_TIME_ZONE))
    start = local.year if local.month >= 4 else local.year - 1
    return f"{start % 100:02d}-{(start + 1) % 100:02d}"


def tax_lines(order: Order) -> list[TaxLine]:
    items = [i for i in order.items.all() if i.quantity > i.quantity_unavailable]
    values = [i.selling_price * (i.quantity - i.quantity_unavailable) for i in items]
    total = sum(values, ZERO)
    discount, left = order.coupon_discount, order.coupon_discount
    lines = []
    for index, (item, value) in enumerate(zip(items, values, strict=True)):
        last = index == len(items) - 1
        share = left if last else (round_money(discount * value / total) if total else ZERO)
        left -= share
        lines.append(
            TaxLine(
                description=f"{item.product_name} {item.variant_name}",
                code=item.hsn_code or settings.INVOICE_PLACEHOLDER_HSN,
                quantity=item.quantity - item.quantity_unavailable,
                gross=value - share,
                rate=item.gst_rate or ZERO,
                placeholder=not item.hsn_code,
            )
        )
    for label, amount in (
        ("Delivery fee", order.delivery_fee),
        ("Small cart fee", order.small_cart_fee),
        ("Handling fee", order.handling_fee),
    ):
        if amount > ZERO:
            lines.append(
                TaxLine(
                    description=label,
                    code=settings.INVOICE_FEE_SAC,
                    quantity=1,
                    gross=amount,
                    rate=settings.INVOICE_FEE_GST_RATE,
                    placeholder=settings.INVOICE_FEE_SAC.endswith("TBD"),
                )
            )
    for line in lines:
        line.split()
    return lines


def is_intra_state(order: Order) -> bool:
    """True when the place of supply (the delivery address's state) is the store's state:
    CGST + SGST; otherwise IGST. Shared by the invoice and the GST reports."""
    state = (order.address_snapshot or {}).get("state", "")
    return state.strip().lower() == (order.store.state or "").strip().lower()


def ensure_invoice(order_id: int) -> Invoice:
    """The order's invoice, made once (numbered per store and financial year). Idempotent."""
    existing = Invoice.objects.filter(order_id=order_id).first()
    if existing is not None:
        return existing
    with transaction.atomic():
        order = (
            Order.objects.select_for_update(of=("self",)).select_related("store").get(pk=order_id)
        )
        existing = Invoice.objects.filter(order=order).first()
        if existing is not None:
            return existing
        now = order.delivered_at or timezone.now()
        year = financial_year(now)
        sequence, _ = InvoiceSequence.objects.select_for_update().get_or_create(
            store=order.store, financial_year=year
        )
        sequence.last_number += 1
        sequence.save(update_fields=["last_number"])
        lines = tax_lines(order)
        taxable = sum((line.taxable for line in lines), ZERO)
        tax = sum((line.tax for line in lines), ZERO)
        if is_intra_state(order):
            cgst = round_money(tax / 2)
            sgst, igst = tax - cgst, ZERO
        else:
            cgst = sgst = ZERO
            igst = tax
        prefix = order.store.invoice_prefix or order.store.code
        gstin = order.store.gstin or settings.INVOICE_PLACEHOLDER_GSTIN
        return Invoice.objects.create(
            order=order,
            invoice_number=f"{prefix}/{year}/{sequence.last_number:06d}",
            issued_at=now,
            seller_gstin=gstin,
            is_placeholder=not order.store.gstin or any(line.placeholder for line in lines),
            taxable_value=taxable,
            cgst=cgst,
            sgst=sgst,
            igst=igst,
            total=taxable + cgst + sgst + igst,
        )


def invoice_html(invoice: Invoice) -> str:
    order = invoice.order
    lines = tax_lines(order)
    return render_to_string(
        "orders/invoice.html",
        {
            "invoice": invoice,
            "order": order,
            "store": order.store,
            "seller_name": settings.INVOICE_SELLER_NAME,
            "address": order.address_snapshot or {},
            "lines": [
                {
                    "description": line.description,
                    "code": line.code,
                    "quantity": line.quantity,
                    "rate": money_str(line.rate),
                    "taxable": money_str(line.taxable),
                    "tax": money_str(line.tax),
                    "gross": money_str(line.gross),
                }
                for line in lines
            ],
            "totals": {
                "taxable": money_str(invoice.taxable_value),
                "cgst": money_str(invoice.cgst),
                "sgst": money_str(invoice.sgst),
                "igst": money_str(invoice.igst),
                "total": money_str(invoice.total),
                "tip": money_str(order.tip),
                "grand_total": money_str(order.grand_total),
            },
            "issued_at": invoice.issued_at.astimezone(ZoneInfo(settings.STORE_TIME_ZONE)),
        },
    )


def render_pdf(invoice: Invoice) -> bytes:
    try:
        from weasyprint import HTML
    except (ImportError, OSError) as exc:  # missing Pango/GTK raises OSError on import
        raise InvoiceRenderingUnavailable(str(exc)) from exc
    return HTML(string=invoice_html(invoice)).write_pdf()


def ensure_pdf(invoice: Invoice) -> Invoice:
    """Render and store the PDF once. Raises `InvoiceRenderingUnavailable`."""
    if invoice.pdf:
        return invoice
    content = render_pdf(invoice)
    with transaction.atomic():
        invoice = Invoice.objects.select_for_update().get(pk=invoice.pk)
        if not invoice.pdf:
            invoice.pdf.save("invoice.pdf", ContentFile(content), save=False)
            invoice.save(update_fields=["pdf", "updated_at"])
    return invoice


def signed_link(invoice: Invoice, now=None) -> dict:
    """`OrderInvoice`: a signed URL to the private PDF, valid `INVOICE_URL_EXPIRY_SECONDS`."""
    now = now or timezone.now()
    seconds = settings.INVOICE_URL_EXPIRY_SECONDS
    try:
        url = default_storage.url(invoice.pdf.name, expire=seconds)
    except TypeError:  # storages without signed URLs (tests: in-memory)
        url = default_storage.url(invoice.pdf.name)
    return {
        "invoice_number": invoice.invoice_number,
        "issued_at": invoice.issued_at,
        "url": url,
        "expires_at": now + timedelta(seconds=seconds),
    }


def is_invoiceable(order: Order) -> bool:
    return order.status == OrderStatus.DELIVERED
