from django.urls import path

from apps.payments import views

urlpatterns = [
    path(
        "payments/razorpay/verify/",
        views.RazorpayVerifyView.as_view(),
        name="payments-razorpay-verify",
    ),
    path(
        "payments/razorpay/webhook/",
        views.RazorpayWebhookView.as_view(),
        name="payments-razorpay-webhook",
    ),
]
