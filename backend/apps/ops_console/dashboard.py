"""Dashboard building blocks (05 §1.1). Phase 1 shows only data that exists: customers, staff
roles and app configuration. Order, revenue, rider and store cards arrive with their phases."""

from django.template.loader import render_to_string
from django.urls import reverse
from django.utils import timezone
from django.utils.html import format_html

from apps.ops_console import selectors, status
from apps.ops_console.dates import DISPLAY_TZ
from apps.ops_console.pii import display_phone
from apps.ops_console.tables import Column, DataTable, Filter

SIGNUP_CHART_DAYS = 14


def signups_chart(now=None) -> dict:
    """Spec read by ops.js (`data-ops-chart`): a bar chart of sign-ups per IST day."""
    series = selectors.signups_per_day(SIGNUP_CHART_DAYS, now)
    return {
        "type": "bar",
        "labels": [day.strftime("%d %b") for day, _ in series],
        "datasets": [{"label": "Sign-ups", "data": [count for _, count in series]}],
        "total": sum(count for _, count in series),
        "rows": [(day, count) for day, count in series],
    }


def _status_cell(customer):
    badge = status.badge_for(status.CUSTOMER, status.customer_status(customer))
    return render_to_string("ops/components/status_badge.html", {"badge": badge})


def _name_cell(customer):
    url = reverse("admin:accounts_customer_change", args=[customer.pk])
    return format_html(
        '<a class="text-primary-600 dark:text-primary-500" href="{}">{}</a>',
        url,
        customer.name or f"Customer {customer.pk}",
    )


def signups_table(request) -> dict:
    user = request.user
    statuses = status.BADGES[status.CUSTOMER]
    return DataTable(
        request,
        selectors.customers_for_table(),
        table_id="recent-signups",
        url=reverse("ops:dashboard-signups"),
        columns=[
            Column("Name", _name_cell),
            Column("Phone", lambda customer: display_phone(user, customer.phone)),
            Column("Status", _status_cell),
            Column(
                "Joined (IST)",
                lambda customer: timezone.localtime(customer.created_at, DISPLAY_TZ).strftime(
                    "%d %b %Y, %H:%M"
                ),
                css="whitespace-nowrap",
            ),
        ],
        search_fields=("name", "phone", "email"),
        search_placeholder="Name, phone or email",
        filters=[
            Filter(
                "status",
                "Status",
                [(code, badge.label) for code, badge in statuses.items()],
                lambda queryset, value: queryset.filter(selectors.CUSTOMER_STATUS_FILTERS[value]),
            )
        ],
        per_page=10,
        empty_title="No customers found",
        empty_message="Try another search or clear the status filter.",
    ).context()
