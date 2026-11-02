from django.urls import path

from apps.ops_console import views

app_name = "ops"

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("dashboard/customer-kpis/", views.dashboard_customer_kpis, name="dashboard-kpis"),
    path("dashboard/signups/", views.dashboard_signups, name="dashboard-signups"),
]
