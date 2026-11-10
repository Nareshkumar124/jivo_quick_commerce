"""Report filters (05 §4): a date range (IST days) and one of the user's stores.

The store choices are only `stores_for(user)`, so another store's id is an invalid choice (a
field error), never a way to read its numbers. The backend's reports service validates the
range again (`REPORT_MAX_RANGE_DAYS`) and re-checks the store scope.
"""

from dataclasses import dataclass
from datetime import date, timedelta

from django import forms
from django.conf import settings
from unfold.widgets import UnfoldAdminSelectWidget, UnfoldAdminTextInputWidget

from apps.ops_console.dates import local_today
from apps.stores.services import stores_for

DEFAULT_DAYS = 7


def max_range_days() -> int:
    return int(settings.REPORT_MAX_RANGE_DAYS)


class ReportFilterForm(forms.Form):
    date_from = forms.DateField(
        label="From",
        widget=UnfoldAdminTextInputWidget(attrs={"type": "date"}),
    )
    date_to = forms.DateField(
        label="To",
        widget=UnfoldAdminTextInputWidget(attrs={"type": "date"}),
    )
    store = forms.TypedChoiceField(
        label="Store", required=False, coerce=int, empty_value=None, widget=UnfoldAdminSelectWidget
    )

    def __init__(self, data, *, user, **kwargs):
        today = local_today()
        initial = {"date_from": today - timedelta(days=DEFAULT_DAYS - 1), "date_to": today}
        if not data or not any(key in data for key in ("date_from", "date_to", "store")):
            data = {key: value.isoformat() for key, value in initial.items()}
        super().__init__(data, **kwargs)
        stores = stores_for(user).only("pk", "code", "name").order_by("code")
        self.fields["store"].choices = [("", "All my stores")] + [
            (store.pk, f"{store.code} · {store.name}") for store in stores
        ]

    def clean(self):
        data = super().clean()
        start, end = data.get("date_from"), data.get("date_to")
        if start and end:
            if start > end:
                self.add_error("date_to", "The end date is before the start date.")
            elif (end - start).days + 1 > max_range_days():
                self.add_error("date_to", f"Choose at most {max_range_days()} days.")
            if end > local_today():
                self.add_error("date_to", "The end date is in the future.")
        return data


@dataclass(frozen=True)
class Params:
    start: date
    end: date
    store_id: int | None
