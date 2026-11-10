from django.urls import path

from apps.cms.views import AppConfigView, FaqListView, PageView

urlpatterns = [
    path("config/app/", AppConfigView.as_view(), name="config-app"),
    path("pages/<slug:slug>/", PageView.as_view(), name="cms-page"),  # P7
    path("faqs/", FaqListView.as_view(), name="cms-faqs"),  # P7
]
