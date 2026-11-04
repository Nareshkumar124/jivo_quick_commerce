from django.urls import path

from apps.orders import views

urlpatterns = [
    path("orders/", views.OrderListCreateView.as_view(), name="order-list"),
    path("orders/<int:id>/", views.OrderDetailView.as_view(), name="order-detail"),
    path(
        "orders/<int:id>/retry-payment/",
        views.OrderRetryPaymentView.as_view(),
        name="order-retry-payment",
    ),
    path("orders/<int:id>/cancel/", views.OrderCancelView.as_view(), name="order-cancel"),
]
