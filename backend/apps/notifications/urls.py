from django.urls import path

from apps.notifications import views

urlpatterns = [
    path("me/notifications/", views.InboxListView.as_view(), name="me-notifications"),
    path(
        "me/notifications/unread-count/",
        views.InboxUnreadCountView.as_view(),
        name="me-notifications-unread-count",
    ),
    path(
        "me/notifications/read-all/",
        views.InboxReadAllView.as_view(),
        name="me-notifications-read-all",
    ),
    path(
        "me/notifications/<int:id>/read/",
        views.InboxReadView.as_view(),
        name="me-notification-read",
    ),
]
