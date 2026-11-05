"""Phase 7 support endpoints for the apps (06 §2.7): my tickets, open a ticket, one ticket with
its thread, reply.

Tickets are always looked up in the caller's own tickets: another user's ticket id is a 404.
Views are thin: validate, call `apps.support.services`, render with the serializers.
"""

from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.pagination import StandardPagination
from apps.core.schema import (
    PAGINATION_PARAMETERS,
    UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    ok_response,
    paginated_responses,
    request_examples,
    validation_error,
)
from apps.core.throttling import RATE_LIMITED
from apps.support import examples as ex
from apps.support import services
from apps.support.serializers import (
    PaginatedTicketSummaryListSerializer,
    TicketCreateSerializer,
    TicketReplySerializer,
    TicketSerializer,
    TicketSummarySerializer,
)
from apps.support.throttling import TicketCreateThrottle, TicketMessageThrottle

TAGS = ["support"]

TICKET_ID = OpenApiParameter(
    "id", int, OpenApiParameter.PATH, description="`SupportTicket.id` (not the TK- number)."
)
TICKET_NOT_FOUND = error_response(
    "The ticket does not exist or is not the caller's.",
    error_example(ErrorCode.NOT_FOUND, services.MSG_TICKET_NOT_FOUND),
)


def _session_app(request: Request) -> str | None:
    """The app the access token was issued for (the `app` claim, 02 §6)."""
    token = request.auth
    try:
        return token.get("app") if token is not None else None
    except AttributeError:  # pragma: no cover - only JWTs authenticate the app API
        return None


def _ticket_body(user, ticket_id: int) -> dict:
    return TicketSerializer(services.get_own_ticket(user, ticket_id)).data


class TicketListCreateView(APIView):
    def get_throttles(self):
        # Opening tickets is rate limited per user; reading the list is not.
        return [TicketCreateThrottle()] if self.request.method == "POST" else []

    @extend_schema(
        operation_id="support_tickets_list",
        tags=TAGS,
        summary="My support tickets",
        description=(
            "The caller's tickets, newest activity first (a new message or a status change "
            "moves a ticket to the top)."
        ),
        parameters=PAGINATION_PARAMETERS,
        responses=paginated_responses(
            {
                200: ok_response(
                    PaginatedTicketSummaryListSerializer,
                    "One page of tickets.",
                    ("Tickets", ex.TICKETS_PAGE),
                    ("No tickets", ex.TICKETS_EMPTY),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        tickets = services.with_list_relations(services.own_tickets(request.user)).order_by(
            "-last_activity_at", "-id"
        )
        paginator = StandardPagination()
        page = paginator.paginate_queryset(tickets, request, view=self)
        return paginator.get_paginated_response(TicketSummarySerializer(page, many=True).data)

    @extend_schema(
        operation_id="support_tickets_create",
        tags=TAGS,
        summary="Open a support ticket",
        description=(
            "Creates an OPEN ticket whose first message is `message`. MISSING_ITEMS, "
            "DAMAGED_ITEMS, WRONG_ITEMS and LATE_DELIVERY are about an order and need "
            "`order_id`; the other categories may name one. The order must be the caller's own. "
            "Attachments are not accepted yet (planned contract: 06 §2.7). Rate limited per "
            "user (`SUPPORT_TICKETS_CREATE_RATE`, default 10 per hour)."
        ),
        request=TicketCreateSerializer,
        examples=request_examples(
            ("About an order", ex.CREATE_WITH_ORDER),
            ("General question", ex.CREATE_WITHOUT_ORDER),
        ),
        responses=app_responses(
            {
                201: ok_response(TicketSerializer, "The new ticket.", ("Created", ex.TICKET_NEW)),
                400: error_response(
                    "Invalid input: unknown category, message shorter than 10 or longer than "
                    "1000 characters, an order category without `order_id`, or an `order_id` "
                    "that is not one of the caller's orders.",
                    validation_error(
                        {"order_id": [services.MSG_ORDER_REQUIRED]}, name="Order required"
                    ),
                    validation_error(
                        {"order_id": [services.MSG_ORDER_NOT_FOUND]}, name="Not my order"
                    ),
                    validation_error(
                        {"message": ["Ensure this field has at least 10 characters."]},
                        name="Message too short",
                    ),
                ),
                401: UNAUTHORIZED,
                429: RATE_LIMITED,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        data = TicketCreateSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        ticket = services.create_ticket(
            request.user,
            category=data.validated_data["category"],
            message=data.validated_data["message"],
            order_id=data.validated_data.get("order_id"),
            app=_session_app(request),
        )
        return Response(_ticket_body(request.user, ticket.pk), status=201)


class TicketDetailView(APIView):
    @extend_schema(
        operation_id="support_tickets_retrieve",
        tags=TAGS,
        summary="One of my tickets with its messages",
        description="Messages oldest first. Another user's ticket id is a 404.",
        parameters=[TICKET_ID],
        responses=app_responses(
            {
                200: ok_response(
                    TicketSerializer,
                    "The ticket.",
                    ("Answered by support", ex.TICKET_ANSWERED),
                    ("Closed", ex.TICKET_CLOSED),
                ),
                401: UNAUTHORIZED,
                404: TICKET_NOT_FOUND,
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        return Response(_ticket_body(request.user, id))


class TicketMessageCreateView(APIView):
    throttle_classes = [TicketMessageThrottle]

    @extend_schema(
        operation_id="support_tickets_messages_create",
        tags=TAGS,
        summary="Reply on my ticket",
        description=(
            "Adds the caller's message and returns the whole ticket. A RESOLVED ticket is "
            "reopened (OPEN). A CLOSED ticket refuses replies with 400 `VALIDATION_ERROR` "
            "(`details.ticket`): offer a new ticket instead. Rate limited per user "
            "(`SUPPORT_MESSAGES_RATE`, default 60 per hour)."
        ),
        parameters=[TICKET_ID],
        request=TicketReplySerializer,
        examples=request_examples(("Reply", ex.REPLY)),
        responses=app_responses(
            {
                201: ok_response(
                    TicketSerializer,
                    "The ticket with the new message.",
                    ("Replied", ex.TICKET_REPLIED),
                ),
                400: error_response(
                    "Empty or too long message (1 to 1000 characters), or the ticket is CLOSED.",
                    error_example(
                        ErrorCode.VALIDATION_ERROR,
                        services.MSG_TICKET_CLOSED,
                        {"ticket": [services.MSG_TICKET_CLOSED]},
                        name="Ticket closed",
                    ),
                    validation_error(
                        {"message": ["This field may not be blank."]}, name="Empty message"
                    ),
                ),
                401: UNAUTHORIZED,
                404: TICKET_NOT_FOUND,
                429: RATE_LIMITED,
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        data = TicketReplySerializer(data=request.data)
        data.is_valid(raise_exception=True)
        services.add_customer_message(request.user, id, data.validated_data["message"])
        return Response(_ticket_body(request.user, id), status=201)
