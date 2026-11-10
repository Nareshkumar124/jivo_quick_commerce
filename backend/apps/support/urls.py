from django.urls import path

from apps.support import views

urlpatterns = [
    path("support/tickets/", views.TicketListCreateView.as_view(), name="support-ticket-list"),
    path(
        "support/tickets/<int:id>/",
        views.TicketDetailView.as_view(),
        name="support-ticket-detail",
    ),
    path(
        "support/tickets/<int:id>/messages/",
        views.TicketMessageCreateView.as_view(),
        name="support-ticket-messages",
    ),
    path(
        "support/tickets/<int:id>/attachments/",
        views.TicketAttachmentCreateView.as_view(),
        name="support-ticket-attachments",
    ),
]
