"""Phase 6 inbox endpoints (api-requests #29, 06 §2.7).

Always scoped to the caller and the app their token was issued for (`app` claim): the customer
app sees customer notifications only, the rider app rider ones. Another user's id is a 404.
"""

from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.pagination import StandardPagination
from apps.core.schema import (
    NOT_FOUND,
    PAGINATION_PARAMETERS,
    UNAUTHORIZED,
    app_responses,
    ok_response,
    paginated_responses,
)
from apps.notifications import examples as ex
from apps.notifications import services
from apps.notifications.serializers import (
    InboxNotificationSerializer,
    ReadAllResultSerializer,
    UnreadCountSerializer,
)

TAGS = ["notifications"]


class PaginatedInboxNotificationListSerializer(serializers.Serializer):
    """Standard page (02 §5): `?page=&page_size=`, default 20, max 100."""

    count = serializers.IntegerField()
    next = serializers.URLField(allow_null=True)
    previous = serializers.URLField(allow_null=True)
    results = InboxNotificationSerializer(many=True)
    unread_count = serializers.IntegerField(
        help_text="Unread entries for this app (all pages; api-requests #45)."
    )


def _app(request: Request) -> str:
    return services.app_of_token(request.auth)


class InboxListView(APIView):
    @extend_schema(
        operation_id="me_notifications_list",
        tags=TAGS,
        summary="My notification inbox",
        description=(
            "Newest first, for the app the access token was issued to (customer or rider). "
            "Entries are kept for `NOTIFICATION_RETENTION_DAYS` (90). A tap opens `link`. "
            "Unread entries have `read: false`; mark one with `POST .../{id}/read/` or all with "
            "`POST /me/notifications/read-all/`. The push data payload of the same event "
            "carries the same `link` (see the push payload in 06 §2.7)."
        ),
        parameters=PAGINATION_PARAMETERS,
        responses=paginated_responses(
            {
                200: ok_response(
                    PaginatedInboxNotificationListSerializer,
                    "One page of inbox entries.",
                    ("Inbox", ex.INBOX_PAGE),
                    ("Empty", ex.INBOX_EMPTY),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        paginator = StandardPagination()
        app = _app(request)
        page = paginator.paginate_queryset(services.inbox(request.user, app), request, view=self)
        response = paginator.get_paginated_response(
            InboxNotificationSerializer(page, many=True).data
        )
        response.data["unread_count"] = services.unread_count(request.user, app)
        return response


class InboxUnreadCountView(APIView):
    @extend_schema(
        operation_id="me_notifications_unread_count",
        tags=TAGS,
        summary="Unread inbox count (badge)",
        description=(
            "Unread inbox entries for the app the token was issued to (api-requests #45). The "
            "same number comes with every page of `GET /me/notifications/` (`unread_count`) "
            "and with `notification.new` on the app sockets."
        ),
        responses=app_responses(
            {
                200: ok_response(UnreadCountSerializer, "The count.", ("Badge", ex.UNREAD)),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        return Response({"unread": services.unread_count(request.user, _app(request))})


class InboxReadView(APIView):
    @extend_schema(
        operation_id="me_notifications_read",
        tags=TAGS,
        summary="Mark one inbox entry read",
        description="Idempotent: an entry already read stays read (its first read time is kept).",
        request=None,
        responses=app_responses(
            {
                200: ok_response(InboxNotificationSerializer, "The entry.", ("Read", ex.READ)),
                401: UNAUTHORIZED,
                404: NOT_FOUND,
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        notification = services.mark_read(request.user, _app(request), id)
        return Response(InboxNotificationSerializer(notification).data)


class InboxReadAllView(APIView):
    @extend_schema(
        operation_id="me_notifications_read_all",
        tags=TAGS,
        summary="Mark every inbox entry read",
        request=None,
        responses=app_responses(
            {
                200: ok_response(
                    ReadAllResultSerializer, "How many changed.", ("Read all", ex.READ_ALL)
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        updated = services.mark_all_read(request.user, _app(request))
        return Response({"updated": updated})
