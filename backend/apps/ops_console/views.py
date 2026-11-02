"""Ops Console views (05 §1). Thin: access checks in `access.ops_view`, reads in `selectors`,
state changes only through the owning app's services (none in Phase 1)."""

from django.contrib import admin
from django.shortcuts import render

from apps.ops_console import dashboard as dashboard_blocks
from apps.ops_console import selectors
from apps.ops_console.access import ops_view
from apps.ops_console.navigation import visible_sections

VIEW_CUSTOMERS = "accounts.view_customer"
VIEW_STAFF = "accounts.view_user"
VIEW_APP_CONFIG = "cms.view_appconfig"


def ops_context(request, **extra) -> dict:
    """Layout context: the admin site's theme (colours, titles, environment badge) so both
    layers look the same, plus the Ops sidebar and the user's roles."""
    context = admin.site.each_context(request)
    context.update(
        ops_nav=visible_sections(request.user),
        user_roles=selectors.role_names(request.user),
        **extra,
    )
    return context


@ops_view()
def dashboard(request):
    """Every staff member may open the dashboard; each card needs its own permission. Roles
    with none of them get an empty state, never placeholder numbers."""
    user = request.user
    context = ops_context(request, title="Dashboard")
    if user.has_perm(VIEW_CUSTOMERS):
        context["customers"] = selectors.customer_stats()
        context["signups_chart"] = dashboard_blocks.signups_chart()
        context["signups_table"] = dashboard_blocks.signups_table(request)
    if user.has_perm(VIEW_STAFF):
        context["staff_roles"] = selectors.staff_per_role()
    if user.has_perm(VIEW_APP_CONFIG):
        context["app_config"] = selectors.app_config_status()
    return render(request, "ops/dashboard.html", context)


@ops_view(VIEW_CUSTOMERS)
def dashboard_customer_kpis(request):
    """HTMX partial: the customer KPI cards (polled every 60 s)."""
    return render(
        request, "ops/partials/customer_kpis.html", {"customers": selectors.customer_stats()}
    )


@ops_view(VIEW_CUSTOMERS)
def dashboard_signups(request):
    """HTMX partial: the results region of the recent sign-ups table."""
    return render(
        request,
        "ops/components/data_table_results.html",
        {"table": dashboard_blocks.signups_table(request)},
    )
