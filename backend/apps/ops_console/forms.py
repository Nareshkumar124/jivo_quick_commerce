"""Ops Console forms for the order buttons. They validate input only; the services decide."""

from decimal import Decimal

from django import forms
from unfold.widgets import (
    UnfoldAdminDecimalFieldWidget,
    UnfoldAdminIntegerFieldWidget,
    UnfoldAdminSelectWidget,
    UnfoldAdminTextareaWidget,
)

MAX_NOTE = 250  # Order.cancel_note


class CancelOrderForm(forms.Form):
    """T12: a reason is required (from the backend's staff reasons), the note is optional."""

    reason = forms.ChoiceField(label="Reason", widget=UnfoldAdminSelectWidget)
    note = forms.CharField(
        label="Note for the record",
        required=False,
        max_length=MAX_NOTE,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 2}),
        help_text="Internal; never shown to the customer.",
    )

    def __init__(self, *args, reasons=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["reason"].choices = [("", "Choose a reason"), *reasons]


class UnavailableForm(forms.Form):
    """T8a for one line: the line's new **total** of units that cannot be supplied. It can only
    grow: the minimum is the line's current count (the same value again is a no-op in the
    service, so a resend after a lost response is safe)."""

    item = forms.IntegerField(min_value=1)
    quantity_unavailable = forms.IntegerField(
        label="Units unavailable", min_value=0, widget=UnfoldAdminIntegerFieldWidget
    )

    def __init__(self, *args, order=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.order = order
        self.line = None

    def clean(self):
        cleaned = super().clean()
        item_id = cleaned.get("item")
        quantity = cleaned.get("quantity_unavailable")
        if item_id is None or quantity is None:
            return cleaned
        # Scoped to the order (itself scoped to the store): another order's line does not exist.
        self.line = self.order.items.filter(pk=item_id).first() if self.order else None
        if self.line is None:
            raise forms.ValidationError("This item is not in the order.", code="not_found")
        if quantity < self.line.quantity_unavailable:
            self.add_error(
                "quantity_unavailable",
                f"Already {self.line.quantity_unavailable} marked unavailable; "
                "that can't be undone.",
            )
        elif quantity > self.line.quantity:
            self.add_error(
                "quantity_unavailable",
                f"At most {self.line.quantity}: the customer ordered {self.line.quantity}.",
            )
        return cleaned


class AcceptingForm(forms.Form):
    accepting = forms.TypedChoiceField(
        choices=[("1", "Accepting"), ("0", "Paused")], coerce=lambda value: value == "1"
    )


class ManualRefundForm(forms.Form):
    """05 §2 Orders "refund (full/partial, within role limit)" (BUG-0010). Input checks only:
    above zero, two decimals, at most what the server says is refundable. The service
    (`order_refunds.manual_refund`) decides: role, Support limit, cap, ONLINE only."""

    amount = forms.DecimalField(
        label="Amount to refund (₹)",
        max_digits=12,
        decimal_places=2,
        min_value=Decimal("0.01"),
        widget=UnfoldAdminDecimalFieldWidget(attrs={"step": "0.01", "min": "0.01"}),
    )
    note = forms.CharField(
        label="Note for the record",
        required=False,
        max_length=MAX_NOTE,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 2}),
        help_text="Why the customer is refunded. Internal; only its length is audited.",
    )
    once = forms.CharField(required=False, widget=forms.HiddenInput)

    def __init__(self, *args, refundable=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.refundable = refundable

    def clean_amount(self):
        amount = self.cleaned_data["amount"]
        if self.refundable is not None and amount > self.refundable:
            raise forms.ValidationError(
                f"At most ₹{self.refundable:.2f} can still be refunded on this order."
            )
        return amount


class AssignRiderForm(forms.Form):
    """08 §5 step 7: the rider to assign. Which riders are allowed is the service's decision."""

    rider = forms.IntegerField(min_value=1)


class ReceiveReturnForm(forms.Form):
    """08 T14: damaged units per order line (`damaged_<line id>`, 0..units sent out). Lines of
    other orders do not exist here; the service re-checks the ranges."""

    def __init__(self, *args, lines=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.lines = list(lines)
        for line in self.lines:
            self.fields[f"damaged_{line.item.pk}"] = forms.IntegerField(
                label=f"{line.item.product_name} {line.item.variant_name}".strip(),
                min_value=0,
                max_value=line.units,
                initial=0,
                required=False,
                widget=UnfoldAdminIntegerFieldWidget(attrs={"min": 0, "max": line.units}),
            )

    def damaged(self) -> dict[int, int]:
        return {
            line.item.pk: self.cleaned_data.get(f"damaged_{line.item.pk}") or 0
            for line in self.lines
        }
