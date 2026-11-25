from django.urls import path

from apps.promotions import views

urlpatterns = [
    path("account/rewards/", views.RewardsView.as_view(), name="account-rewards"),
]
