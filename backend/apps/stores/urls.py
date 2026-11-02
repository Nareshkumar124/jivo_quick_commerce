from django.urls import path

from apps.stores import views

urlpatterns = [
    path("serviceability/", views.ServiceabilityView.as_view(), name="serviceability"),
    path(
        "serviceability/notify-me/",
        views.NotifyMeView.as_view(),
        name="serviceability-notify-me",
    ),
]
