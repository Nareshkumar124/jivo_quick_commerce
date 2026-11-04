"""Ops Console forms for the order buttons. They validate input only; the services decide."""

from django import forms
from unfold.widgets import (
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
