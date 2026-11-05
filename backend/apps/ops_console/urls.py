from django.urls import path

from apps.ops_console import order_views, views

app_name = "ops"

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("dashboard/customer-kpis/", views.dashboard_customer_kpis, name="dashboard-kpis"),
    path("dashboard/signups/", views.dashboard_signups, name="dashboard-signups"),
    path("dashboard/operations/", views.dashboard_operations, name="dashboard-operations"),
    # Live order board (05 §1.2)
    path("orders/live/", order_views.live_board, name="live-board"),
    path("orders/live/columns/", order_views.live_board_columns, name="live-board-columns"),
    path("orders/<int:order_id>/cancel/", order_views.board_cancel, name="board-cancel"),
    # Store packing console (05 §1.3)
    path("store/", order_views.store_index, name="packing-index"),
    path("store/<str:code>/", order_views.packing_console, name="packing"),
    path("store/<str:code>/queues/", order_views.packing_queue, name="packing-queues"),
    path("store/<str:code>/accepting/", order_views.packing_accepting, name="packing-accepting"),
    path(
        "store/<str:code>/orders/<int:order_id>/unavailable/",
        order_views.packing_unavailable,
        name="packing-unavailable",
    ),
    path(
        "store/<str:code>/orders/<int:order_id>/cancel/",
        order_views.packing_cancel,
        name="packing-cancel",
    ),
    path(
        "store/<str:code>/orders/<int:order_id>/slip/",
        order_views.packing_slip,
        name="packing-slip",
    ),
    path(
        "store/<str:code>/orders/<int:order_id>/<slug:step>/",
        order_views.packing_step,
        name="packing-step",
    ),
]
