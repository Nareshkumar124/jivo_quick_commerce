from django.urls import path

from apps.cms.views import AppConfigView

urlpatterns = [
    path("config/app/", AppConfigView.as_view(), name="config-app"),
]
