from django.urls import path

from apps.delivery import views

urlpatterns = [
    path("rider/stores/", views.RiderStoresView.as_view(), name="rider-stores"),
    path("rider/register/", views.RiderRegisterView.as_view(), name="rider-register"),
    path("rider/me/", views.RiderMeView.as_view(), name="rider-me"),
    path("rider/documents/", views.RiderDocumentsView.as_view(), name="rider-documents"),
    path("rider/bank-account/", views.RiderBankAccountView.as_view(), name="rider-bank-account"),
    path("rider/shift/start/", views.ShiftStartView.as_view(), name="rider-shift-start"),
    path("rider/shift/end/", views.ShiftEndView.as_view(), name="rider-shift-end"),
    path("rider/locations/", views.LocationsView.as_view(), name="rider-locations"),
    path("rider/heartbeat/", views.HeartbeatView.as_view(), name="rider-heartbeat"),
    path("rider/offers/current/", views.CurrentOfferView.as_view(), name="rider-offer-current"),
    path(
        "rider/offers/<int:id>/accept/", views.OfferAcceptView.as_view(), name="rider-offer-accept"
    ),
    path(
        "rider/offers/<int:id>/reject/", views.OfferRejectView.as_view(), name="rider-offer-reject"
    ),
    path("rider/tasks/current/", views.CurrentTaskView.as_view(), name="rider-task-current"),
    path("rider/tasks/history/", views.TaskHistoryView.as_view(), name="rider-task-history"),
    path(
        "rider/tasks/history/<int:id>/",
        views.TaskHistoryDetailView.as_view(),
        name="rider-task-history-detail",
    ),
    path(
        "rider/tasks/<int:id>/arrived-store/",
        views.ArrivedStoreView.as_view(),
        name="rider-task-arrived-store",
    ),
    path("rider/tasks/<int:id>/pickup/", views.PickupView.as_view(), name="rider-task-pickup"),
    path(
        "rider/tasks/<int:id>/arrived-customer/",
        views.ArrivedCustomerView.as_view(),
        name="rider-task-arrived-customer",
    ),
    path("rider/tasks/<int:id>/cod-qr/", views.CodQrView.as_view(), name="rider-task-cod-qr"),
    path("rider/tasks/<int:id>/deliver/", views.DeliverView.as_view(), name="rider-task-deliver"),
    path("rider/tasks/<int:id>/fail/", views.FailView.as_view(), name="rider-task-fail"),
    path("rider/earnings/", views.EarningsView.as_view(), name="rider-earnings"),
    path("rider/cash/ledger/", views.CashLedgerView.as_view(), name="rider-cash-ledger"),
    path("rider/payouts/", views.PayoutsView.as_view(), name="rider-payouts"),
]
