"""SLICE 5.4 forms: ops-marked failed delivery, cash deposit, payouts (see `delivery_ops`).

They validate the shape of the input only; the services decide (amount <= cash in hand, period
not in the future, reference unique per payout, ...). No money is computed here.
"""

from decimal import Decimal

from django import forms
from unfold.widgets import (
    UnfoldAdminDecimalFieldWidget,
    UnfoldAdminSelectWidget,
    UnfoldAdminTextareaWidget,
    UnfoldAdminTextInputWidget,
)

MAX_FAIL_NOTE = 300  # delivery.services.ops.fail_delivery keeps 300 characters
MAX_CASH_NOTE = 200  # RiderCashLedger.note
MAX_KEY = 64  # RiderCashLedger.idempotency_key
MAX_REFERENCE = 64  # Payout.reference (bank UTR)

DATE_CLASSES = (
    "bg-white border border-base-200 px-3 py-2 rounded-default w-full "
    "dark:bg-base-900 dark:border-base-700"
)


def date_input() -> forms.DateInput:
    return forms.DateInput(attrs={"type": "date", "class": DATE_CLASSES}, format="%Y-%m-%d")


class FailDeliveryForm(forms.Form):
    """T13 marked by ops (DL-61 a): a reason from the backend's enum and a required note."""

    reason = forms.ChoiceField(label="Reason", widget=UnfoldAdminSelectWidget)
    note = forms.CharField(
        label="What happened",
        max_length=MAX_FAIL_NOTE,
        widget=UnfoldAdminTextareaWidget(attrs={"rows": 2}),
    )

    def __init__(self, *args, reasons=(), **kwargs):
        super().__init__(*args, **kwargs)
        self.fields["reason"].choices = [("", "Choose a reason"), *reasons]


class CashDepositForm(forms.Form):
    """05 §1.5: the amount the store received from the rider, in rupees."""

    amount = forms.DecimalField(
        label="Amount received (₹)",
        min_value=Decimal("0.01"),
        max_digits=10,
        decimal_places=2,
        widget=UnfoldAdminDecimalFieldWidget(attrs={"step": "0.01", "min": "0.01"}),
    )
    note = forms.CharField(
        label="Note", required=False, max_length=MAX_CASH_NOTE, widget=UnfoldAdminTextInputWidget
    )
    # A fresh key per rendered form: a double submit or a resend records one deposit.
    # Required (code review): without it a resend would record the deposit twice.
    key = forms.CharField(max_length=MAX_KEY, widget=forms.HiddenInput)


class DayReportForm(forms.Form):
    day = forms.DateField(label="Day (IST)", widget=date_input())


class CreatePayoutsForm(forms.Form):
    """A payout batch for an IST period (D-16: weekly, paid offline by Finance)."""

    period_start = forms.DateField(label="From (IST)", widget=date_input())
    period_end = forms.DateField(label="To (IST, inclusive)", widget=date_input())

    def clean(self):
        data = super().clean()
        start, end = data.get("period_start"), data.get("period_end")
        if start and end and end < start:
            raise forms.ValidationError("The period must end on or after its start.")
        return data


class MarkPaidForm(forms.Form):
    reference = forms.CharField(
        label="Bank transfer reference (UTR)",
        max_length=MAX_REFERENCE,
        widget=UnfoldAdminTextInputWidget,
    )
