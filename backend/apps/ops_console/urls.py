from django.urls import path

from apps.ops_console import csp, delivery_ops_views, dispatch_views, mfa, order_views, views

app_name = "ops"

urlpatterns = [
    path("", views.dashboard, name="dashboard"),
    path("dashboard/customer-kpis/", views.dashboard_customer_kpis, name="dashboard-kpis"),
    path("dashboard/signups/", views.dashboard_signups, name="dashboard-signups"),
    path("dashboard/operations/", views.dashboard_operations, name="dashboard-operations"),
    # Staff two-step sign-in (H2) and CSP reports (L7)
    path("mfa/setup/", mfa.setup, name="mfa-setup"),
    path("mfa/verify/", mfa.verify, name="mfa-verify"),
    path("mfa/recovery/", mfa.recovery, name="mfa-recovery"),
    path("csp-report/", csp.csp_report, name="csp-report"),
    # Live order board (05 §1.2)
    path("orders/live/", order_views.live_board, name="live-board"),
    path("orders/live/columns/", order_views.live_board_columns, name="live-board-columns"),
    path("orders/<int:order_id>/cancel/", order_views.board_cancel, name="board-cancel"),
    # Dispatch (05 §1.4, slice 5.3)
    path("dispatch/", dispatch_views.dispatch_board, name="dispatch"),
    path("dispatch/board/", dispatch_views.dispatch_board_partial, name="dispatch-board"),
    path("dispatch/tasks/<int:task_id>/", dispatch_views.task_detail, name="dispatch-task"),
    path(
        "dispatch/tasks/<int:task_id>/panel/",
        dispatch_views.task_detail_partial,
        name="dispatch-task-panel",
    ),
    path(
        "dispatch/tasks/<int:task_id>/assign/", dispatch_views.task_assign, name="dispatch-assign"
    ),
    path(
        "dispatch/tasks/<int:task_id>/unassign/",
        dispatch_views.task_unassign,
        name="dispatch-unassign",
    ),
    path("dispatch/tasks/<int:task_id>/retry/", dispatch_views.task_retry, name="dispatch-retry"),
    # Slice 5.4 (DL-61 a; apps/ops_console/delivery_ops*.py)
    path(
        "dispatch/tasks/<int:task_id>/unlock-pickup/",
        delivery_ops_views.task_unlock_pickup,
        name="dispatch-unlock-pickup",
    ),
    path(
        "dispatch/tasks/<int:task_id>/unlock-otp/",
        delivery_ops_views.task_unlock_otp,
        name="dispatch-unlock-otp",
    ),
    path("dispatch/tasks/<int:task_id>/fail/", delivery_ops_views.task_fail, name="dispatch-fail"),
    path(
        "dispatch/riders/<int:rider_id>/offline/",
        delivery_ops_views.rider_force_offline,
        name="dispatch-force-offline",
    ),
    # Cash deposits (05 §1.5) and payouts (05 §2), slice 5.4
    path("cash/", delivery_ops_views.cash_index, name="cash"),
    path("cash/riders/", delivery_ops_views.cash_partial, name="cash-riders"),
    path(
        "cash/riders/<int:rider_id>/deposit/",
        delivery_ops_views.cash_deposit,
        name="cash-deposit",
    ),
    path("payouts/", delivery_ops_views.payouts_index, name="payouts"),
    path("payouts/list/", delivery_ops_views.payouts_partial, name="payouts-list"),
    path("payouts/create/", delivery_ops_views.payouts_create, name="payouts-create"),
    path(
        "payouts/<int:payout_id>/paid/",
        delivery_ops_views.payout_mark_paid,
        name="payout-paid",
    ),
    path("payouts/<int:payout_id>/void/", delivery_ops_views.payout_void, name="payout-void"),
    # Store packing console (05 §1.3)
    path("store/", order_views.store_index, name="packing-index"),
    path("store/<str:code>/", order_views.packing_console, name="packing"),
    # Returns (05 §1.3, 08 T14)
    path("store/<str:code>/returns/", dispatch_views.store_returns, name="store-returns"),
    path(
        "store/<str:code>/returns/list/",
        dispatch_views.store_returns_partial,
        name="store-returns-list",
    ),
    path(
        "store/<str:code>/orders/<int:order_id>/return/",
        dispatch_views.store_receive_return,
        name="store-receive-return",
    ),
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
