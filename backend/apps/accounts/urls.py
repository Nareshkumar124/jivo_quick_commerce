from django.urls import path

from apps.accounts import views

urlpatterns = [
    path("auth/otp/request/", views.OtpRequestView.as_view(), name="auth-otp-request"),
    path("auth/otp/verify/", views.OtpVerifyView.as_view(), name="auth-otp-verify"),
    path("auth/methods/", views.LoginMethodsView.as_view(), name="auth-methods"),
    path(
        "auth/email-otp/request/",
        views.EmailOtpRequestView.as_view(),
        name="auth-email-otp-request",
    ),
    path(
        "auth/email-otp/verify/", views.EmailOtpVerifyView.as_view(), name="auth-email-otp-verify"
    ),
    path("auth/token/refresh/", views.TokenRefreshView.as_view(), name="auth-token-refresh"),
    path("auth/logout/", views.LogoutView.as_view(), name="auth-logout"),
    path("me/", views.MeView.as_view(), name="me"),
    path(
        "me/profile-prompt/skip/",
        views.ProfilePromptSkipView.as_view(),
        name="me-profile-prompt-skip",
    ),
    path(
        "business-categories/",
        views.BusinessCategoryListView.as_view(),
        name="business-category-list",
    ),
    path("me/phone/otp/", views.MePhoneOtpView.as_view(), name="me-phone-otp"),
    path("me/phone/verify/", views.MePhoneVerifyView.as_view(), name="me-phone-verify"),
    path("me/email/otp/", views.MeEmailOtpView.as_view(), name="me-email-otp"),
    path("me/email/verify/", views.MeEmailVerifyView.as_view(), name="me-email-verify"),
    path("me/delete/", views.AccountDeleteView.as_view(), name="me-delete"),
    path("me/devices/", views.DeviceRegisterView.as_view(), name="me-devices"),
    path("addresses/", views.AddressListCreateView.as_view(), name="address-list"),
    path("addresses/<int:id>/", views.AddressDetailView.as_view(), name="address-detail"),
    path(
        "addresses/<int:id>/set-default/",
        views.AddressSetDefaultView.as_view(),
        name="address-set-default",
    ),
]
