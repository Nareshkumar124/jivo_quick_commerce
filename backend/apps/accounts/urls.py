from django.urls import path

from apps.accounts import views

urlpatterns = [
    path("auth/otp/request/", views.OtpRequestView.as_view(), name="auth-otp-request"),
    path("auth/otp/verify/", views.OtpVerifyView.as_view(), name="auth-otp-verify"),
    path("auth/token/refresh/", views.TokenRefreshView.as_view(), name="auth-token-refresh"),
    path("auth/logout/", views.LogoutView.as_view(), name="auth-logout"),
    path("me/", views.MeView.as_view(), name="me"),
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
