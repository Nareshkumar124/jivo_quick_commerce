from django.urls import path

from apps.referrals import views

urlpatterns = [
    path("account/referral/", views.ReferralView.as_view(), name="account-referral"),
    path(
        "account/referral/apply/",
        views.ReferralApplyView.as_view(),
        name="account-referral-apply",
    ),
]
