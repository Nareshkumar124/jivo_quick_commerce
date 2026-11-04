"""Phase 3 endpoints: place an order, list orders, retry a payment, cancel an unpaid order
(06 §2.6, 08 §2 T1-T5).

Orders are always looked up in the caller's own orders: another user's order id is a 404.
State changes go only through `orders.services.transition()` (Phase 3 R2).

Views are thin: validate, call `apps.orders.services`, render with `apps.orders.presenters`.
"""

from django.db.models import Case, IntegerField, Value, When
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.cart import services as cart_services
from apps.core.errors import ErrorCode
from apps.core.idempotency import (
    IDEMPOTENCY_KEY_INVALID,
    IDEMPOTENCY_KEY_MISSING,
    IDEMPOTENCY_KEY_PARAMETER,
    IDEMPOTENCY_KEY_REUSED,
    idempotency_key_from_header,
)
from apps.core.pagination import StandardPagination
from apps.core.schema import (
    MAINTENANCE,
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
from apps.core.throttling import RATE_LIMITED, OrderPlacementThrottle, PaymentThrottle
from apps.orders import examples as ex
from apps.orders import presenters, services
from apps.orders.choices import ACTIVE_STATUSES, TERMINAL_STATUSES, OrderListStatus
from apps.orders.serializers import (
    OrderCancelSerializer,
    OrderCreateSerializer,
    OrderInvoiceSerializer,
    OrderListQuerySerializer,
    OrderPlacementSerializer,
    OrderSerializer,
    PaginatedOrderSummaryListSerializer,
    ReorderResultSerializer,
)
from apps.stores.context import get_store
from apps.stores.schema import STORE_ID_PARAMETER, store_responses

TAGS = ["orders"]

ORDER_ID = OpenApiParameter("id", int, OpenApiParameter.PATH, description="`Order.id`.")
ORDER_NOT_FOUND = error_response(
    "The order does not exist or is not the caller's.",
    error_example(ErrorCode.NOT_FOUND, "Order not found."),
)
GATEWAY_UNAVAILABLE = error_example(
    ErrorCode.SERVICE_UNAVAILABLE,
    "Online payment is temporarily unavailable. Try again, or choose cash on delivery.",
    name="PAYMENT_GATEWAY_UNAVAILABLE",
)
PAYMENT_UNAVAILABLE = error_response(
    "Maintenance mode (`MAINTENANCE`), or the payment gateway could not be reached "
    "(`SERVICE_UNAVAILABLE`; nothing was created and no stock is held: retry with the same "
    "`Idempotency-Key`, or offer COD).",
    *MAINTENANCE.examples,
    GATEWAY_UNAVAILABLE,
)
COUPON_ERRORS = (
    error_example(
        ErrorCode.COUPON_NOT_ELIGIBLE,
        "Add items worth ₹74 more to use JIVO50, or remove the coupon.",
        {
            "code": "JIVO50",
            "reason": "MIN_ORDER_VALUE",
            "min_order_value": "299.00",
            "amount_to_unlock": "74.00",
        },
    ),
    error_example(ErrorCode.COUPON_EXPIRED, "This coupon has expired.", {"code": "JIVO50"}),
    error_example(
        ErrorCode.COUPON_USAGE_EXCEEDED,
        "You have already used this coupon.",
        {"code": "JIVO50", "scope": "per_user"},
    ),
)


class OrderListCreateView(APIView):
    def get_throttles(self):
        # Placing orders is rate limited per user; reading the list is not.
        return [OrderPlacementThrottle()] if self.request.method == "POST" else []

    @extend_schema(
        operation_id="orders_list",
        tags=TAGS,
        summary="My orders",
        description=(
            "The caller's orders, newest first; without `status`, active orders come first. "
            "On app launch, `?status=active` finds an order still in PAYMENT_PENDING (the app "
            "was closed during payment): show its server status and offer Retry while "
            "`can_retry_payment` is true (03 §2.9)."
        ),
        parameters=[OrderListQuerySerializer, *PAGINATION_PARAMETERS],
        responses=paginated_responses(
            {
                200: ok_response(
                    PaginatedOrderSummaryListSerializer,
                    "One page of orders.",
                    ("Active orders", ex.ORDERS_ACTIVE),
                    ("Past orders", ex.ORDERS_PAST),
                    ("No orders", ex.ORDERS_EMPTY),
                ),
                400: error_response(
                    "Invalid `status`.",
                    validation_error(
                        {"status": ['"open" is not a valid choice.']}, name="Invalid status"
                    ),
                ),
                401: UNAUTHORIZED,
            }
        ),
    )
    def get(self, request: Request) -> Response:
        query = OrderListQuerySerializer(data=request.query_params)
        query.is_valid(raise_exception=True)
        orders = presenters.with_api_relations(services.own_orders(request.user))
        status = query.validated_data.get("status")
        if status == OrderListStatus.ACTIVE:
            orders = orders.filter(status__in=sorted(ACTIVE_STATUSES)).order_by(
                "-created_at", "-id"
            )
        elif status == OrderListStatus.PAST:
            orders = orders.filter(status__in=sorted(TERMINAL_STATUSES)).order_by(
                "-created_at", "-id"
            )
        else:
            orders = orders.annotate(
                finished=Case(
                    When(status__in=sorted(TERMINAL_STATUSES), then=Value(1)),
                    default=Value(0),
                    output_field=IntegerField(),
                )
            ).order_by("finished", "-created_at", "-id")
        paginator = StandardPagination()
        page = paginator.paginate_queryset(orders, request, view=self)
        return paginator.get_paginated_response([presenters.summary_body(o) for o in page])

    @extend_schema(
        operation_id="orders_create",
        tags=TAGS,
        summary="Place an order from the cart",
        description=(
            "Places the cart as an order at the store in `X-Store-Id` (08 T1/T2). Stock is "
            "reserved now, never earlier (08 §6.1). The server re-checks everything: the "
            "address is served by the store, the store is open, every line is available (else "
            "409 `STOCK_UNAVAILABLE`), the minimum order, the coupon, and that its bill equals "
            "`expected_grand_total` (else 409 `PRICE_CHANGED`: reload the cart).\n\n"
            "**COD:** the order is PLACED at once (`razorpay` is null) and the cart is emptied. "
            "COD needs the store to offer it and `grand_total` within its limit.\n\n"
            "**ONLINE:** the order is PAYMENT_PENDING for the payment window (15 minutes); the "
            "stock and the coupon are held. Open Razorpay checkout with `razorpay`, then call "
            "`POST /payments/razorpay/verify/`. The cart is emptied only when the payment is "
            "confirmed; if it never is, the order fails, the stock is released and the cart is "
            "still there to try again.\n\n"
            "Send the same `Idempotency-Key` when retrying a request whose response was lost: "
            "the first order is returned (200) and nothing is placed twice. Disable the button "
            "while a request is in flight."
        ),
        parameters=[IDEMPOTENCY_KEY_PARAMETER, STORE_ID_PARAMETER],
        request=OrderCreateSerializer,
        examples=request_examples(
            ("Pay online", ex.ORDER_CREATE_ONLINE_REQUEST),
            ("Cash on delivery", ex.ORDER_CREATE_COD_REQUEST),
        ),
        responses=store_responses(
            {
                201: ok_response(
                    OrderPlacementSerializer,
                    "Placed.",
                    ("Online: open checkout", ex.PLACEMENT_ONLINE),
                    ("Online, local fake gateway (dev only)", ex.PLACEMENT_ONLINE_FAKE),
                    ("Cash on delivery", ex.PLACEMENT_COD),
                ),
                200: ok_response(
                    OrderPlacementSerializer,
                    "A repeat with the same `Idempotency-Key`: the order placed by the first "
                    "request, in its current state (`razorpay` only while it awaits payment).",
                    ("Replay: still awaiting payment", ex.PLACEMENT_ONLINE),
                    ("Replay: already paid", ex.PLACEMENT_REPLAY_PAID),
                ),
                401: UNAUTHORIZED,
                409: error_response(
                    "`PRICE_CHANGED`: the bill is not the one the customer saw; reload the cart "
                    "and show it. `STOCK_UNAVAILABLE`: some lines cannot be supplied "
                    "(`details.items` with the `orderable_quantity` now); reload the cart, "
                    "whose lines show the fix. `INVALID_STATE_TRANSITION` with "
                    "`details.pending_order_id`: another of the customer's orders is still "
                    "awaiting payment; offer to complete it (retry-payment) or cancel it first "
                    "(PM decision, Phase 3: one unpaid order at a time, so stock is never held "
                    "twice).",
                    error_example(ErrorCode.PRICE_CHANGED, details=ex.PRICE_CHANGED_DETAILS),
                    error_example(
                        ErrorCode.STOCK_UNAVAILABLE, details=ex.STOCK_UNAVAILABLE_DETAILS
                    ),
                    error_example(
                        ErrorCode.INVALID_STATE_TRANSITION,
                        "You have an order awaiting payment. Complete or cancel it first.",
                        {"pending_order_id": 5012},
                        name="PAYMENT_PENDING_ORDER_EXISTS",
                    ),
                ),
                422: error_response(
                    "The cart cannot be ordered as it is (the cart's `checkout.blockers` show "
                    "the same problems in advance).",
                    error_example(
                        ErrorCode.NOT_SERVICEABLE,
                        "We do not deliver to this address from this store.",
                        {"address_id": 13},
                    ),
                    error_example(
                        ErrorCode.STORE_CLOSED,
                        "The store is closed now. It opens at 7:00 AM.",
                        ex.STORE_CLOSED_DETAILS,
                    ),
                    error_example(
                        ErrorCode.MIN_ORDER_NOT_MET,
                        "Add items worth ₹20 more to place your order (minimum ₹99).",
                        ex.MIN_ORDER_DETAILS,
                    ),
                    error_example(
                        ErrorCode.COD_NOT_AVAILABLE,
                        "Cash on delivery is available on orders up to ₹2,000.",
                        ex.COD_ABOVE_LIMIT_DETAILS,
                    ),
                    *COUPON_ERRORS,
                ),
                429: RATE_LIMITED,
                503: PAYMENT_UNAVAILABLE,
            },
            bad_request=(
                IDEMPOTENCY_KEY_MISSING,
                IDEMPOTENCY_KEY_INVALID,
                IDEMPOTENCY_KEY_REUSED,
                validation_error({"address_id": ["Address not found."]}, name="Unknown address"),
                validation_error(
                    {"expected_grand_total": ["This field is required."]},
                    name="Missing expected_grand_total",
                ),
                validation_error({"non_field_errors": ["Your cart is empty."]}, name="Empty cart"),
            ),
        ),
    )
    def post(self, request: Request) -> Response:
        key = idempotency_key_from_header(request)
        store = get_store(request)
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        info = getattr(request, "client_info", None)
        placement = services.place_order(
            request.user,
            store,
            address_id=data["address_id"],
            payment_method=data["payment_method"],
            expected_grand_total=data["expected_grand_total"],
            idempotency_key=key,
            client_app_version=getattr(info, "app_version", "") or "",
            client_platform=getattr(info, "platform", "") or "",
        )
        order = services.get_own_order(request.user, placement.order.pk)
        return Response(presenters.placement_body(order), status=201 if placement.created else 200)


class OrderDetailView(APIView):
    @extend_schema(
        operation_id="orders_retrieve",
        tags=TAGS,
        summary="One of my orders",
        description=(
            "The order with its bill, items and state (added to Phase 3, PM decision): poll it "
            "after checkout while the payment is being confirmed (e.g. verify's response was "
            "lost), and for the success screen. Another user's order id is a 404.\n\n"
            "**Phase 4** adds `timeline` (every state reached), `cancellation`, "
            "`amount_refunded`, `refunds` and `can_download_invoice`, and per line "
            "`quantity_unavailable`: when the store cannot supply some units (08 T8a) they are "
            "removed, `bill` becomes the recomputed bill (never more than before) and, for an "
            "online payment, the difference is refunded. Show the bill as it is: the app never "
            "computes money."
        ),
        parameters=[ORDER_ID],
        responses=app_responses(
            {
                200: ok_response(
                    OrderSerializer,
                    "The order.",
                    ("Awaiting payment", ex.ORDER_ONLINE_PENDING),
                    ("Paid online", ex.ORDER_ONLINE_PLACED),
                    ("Cash on delivery", ex.ORDER_COD_PLACED),
                    ("Cancelled before paying", ex.ORDER_PAYMENT_CANCELLED),
                    ("Accepted by the store", ex.ORDER_ACCEPTED),
                    ("Packing, an item unavailable (refund pending)", ex.ORDER_ITEM_UNAVAILABLE),
                    ("Cancelled by the customer, refunded", ex.ORDER_CANCELLED_REFUNDED),
                    ("Cancelled by the store (COD)", ex.ORDER_CANCELLED_BY_STORE),
                    ("Delivered, invoice available", ex.ORDER_DELIVERED),
                ),
                401: UNAUTHORIZED,
                404: ORDER_NOT_FOUND,
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        return Response(presenters.order_body(services.get_own_order(request.user, id)))


class OrderRetryPaymentView(APIView):
    throttle_classes = [PaymentThrottle]

    @extend_schema(
        operation_id="orders_retry_payment",
        tags=TAGS,
        summary="Retry the online payment",
        description=(
            "For an ONLINE order in PAYMENT_PENDING before `payment_expires_at` (the 'Payment "
            "failed' screen's Retry, 03 §2.9): creates a new Razorpay order for the same amount "
            "and returns new checkout options. The payment window is **not** extended. To pay "
            "another way, cancel the order (`POST /orders/{id}/cancel/`) and place a new one: "
            "the cart is still there."
        ),
        parameters=[ORDER_ID, IDEMPOTENCY_KEY_PARAMETER],
        request=None,
        responses=app_responses(
            {
                200: ok_response(
                    OrderPlacementSerializer,
                    "New checkout options.",
                    ("Retry", ex.PLACEMENT_RETRY),
                ),
                400: error_response(
                    "The `Idempotency-Key` header is missing or malformed.",
                    IDEMPOTENCY_KEY_MISSING,
                    IDEMPOTENCY_KEY_INVALID,
                ),
                401: UNAUTHORIZED,
                404: ORDER_NOT_FOUND,
                409: error_response(
                    "`INVALID_STATE_TRANSITION`: the order is not awaiting payment any more "
                    "(paid, failed or cancelled; `details.status`), or the window has ended.",
                    error_example(
                        ErrorCode.INVALID_STATE_TRANSITION,
                        "The payment window has ended. Place the order again.",
                        {"status": "PAYMENT_FAILED"},
                        name="PAYMENT_WINDOW_ENDED",
                    ),
                    error_example(
                        ErrorCode.INVALID_STATE_TRANSITION,
                        "This order is already paid.",
                        {"status": "PLACED"},
                        name="ALREADY_PAID",
                    ),
                ),
                429: RATE_LIMITED,
                503: PAYMENT_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        key = idempotency_key_from_header(request)
        order, payment = services.retry_payment(request.user, id, key)
        order = services.get_own_order(request.user, order.pk)
        return Response(presenters.placement_body(order, payment))


class OrderCancelView(APIView):
    @extend_schema(
        operation_id="orders_cancel",
        tags=TAGS,
        summary="Cancel my order",
        description=(
            "08 §7: allowed in PAYMENT_PENDING, PLACED and ACCEPTED; use `can_cancel` to show "
            "the button (from PACKING on, show 'Contact support').\n\n"
            "- **PAYMENT_PENDING (T5):** the customer gives up on paying or wants to pay another "
            "way: the stock and the coupon hold are released; the cart is still there.\n"
            "- **PLACED / ACCEPTED (T11, Phase 4):** the stock is released and the coupon can be "
            "used again. Paid online: the full amount is refunded to the original payment "
            "(`refunds[]`, `payment_status` REFUND_PENDING, then REFUNDED; 08 §6.4). COD: "
            "nothing is due.\n\n"
            "Repeating the call on an order already cancelled returns 409."
        ),
        parameters=[ORDER_ID],
        request=OrderCancelSerializer,
        examples=request_examples(
            ("Pay another way", ex.ORDER_CANCEL_REQUEST),
            ("Changed my mind", ex.ORDER_CANCEL_CHANGED_MIND_REQUEST),
            ("Other, with a note", ex.ORDER_CANCEL_OTHER_REQUEST),
        ),
        responses=app_responses(
            {
                200: ok_response(
                    OrderSerializer,
                    "Cancelled.",
                    ("Cancelled before paying (T5)", ex.ORDER_PAYMENT_CANCELLED),
                    ("Cancelled after paying: refunded (T11)", ex.ORDER_CANCELLED_REFUNDED),
                ),
                400: error_response(
                    "Invalid reason or note.",
                    validation_error(
                        {"reason": ['"BORED" is not a valid choice.']}, name="Invalid reason"
                    ),
                ),
                401: UNAUTHORIZED,
                404: ORDER_NOT_FOUND,
                409: error_response(
                    "`INVALID_STATE_TRANSITION`: the order can no longer be cancelled in the "
                    "app (`details.status`). Show 'Contact support'.",
                    error_example(
                        ErrorCode.INVALID_STATE_TRANSITION,
                        "This order can no longer be cancelled. Contact support for help.",
                        {"status": "PACKING"},
                    ),
                ),
            }
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        serializer = OrderCancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        services.cancel_order(request.user, id, reason=data["reason"], note=data.get("note", ""))
        return Response(presenters.order_body(services.get_own_order(request.user, id)))


INVOICE_NOT_READY = error_example(
    ErrorCode.INVALID_STATE_TRANSITION,
    "The invoice is available once the order is delivered.",
    {"status": "PACKING"},
    name="INVOICE_NOT_READY",
)
INVOICE_UNAVAILABLE = error_example(
    ErrorCode.SERVICE_UNAVAILABLE,
    "The invoice cannot be created right now. Try again in a few minutes.",
    name="INVOICE_RENDERING_UNAVAILABLE",
)


class OrderInvoiceView(APIView):
    @extend_schema(
        operation_id="orders_invoice",
        tags=TAGS,
        summary="Download the GST invoice",
        description=(
            "A short-lived signed link to the order's GST tax invoice (PDF), made on the first "
            "request. Only for DELIVERED orders (`can_download_invoice`). Open or download the "
            "link before `expires_at`; call again for a fresh link.\n\n"
            "Until Jivo's GST details are configured (D-12), invoices carry placeholder GST data "
            "and a 'not a valid tax invoice' banner."
        ),
        parameters=[ORDER_ID],
        responses=app_responses(
            {
                200: ok_response(
                    OrderInvoiceSerializer, "The invoice link.", ("Invoice", ex.INVOICE)
                ),
                401: UNAUTHORIZED,
                404: ORDER_NOT_FOUND,
                409: error_response(
                    "`INVALID_STATE_TRANSITION`: the order is not delivered (`details.status`).",
                    INVOICE_NOT_READY,
                ),
                503: error_response(
                    "Maintenance mode, or the PDF cannot be made right now (retry later).",
                    *MAINTENANCE.examples,
                    INVOICE_UNAVAILABLE,
                ),
            }
        ),
    )
    def get(self, request: Request, id: int) -> Response:
        return Response(services.invoice_link(request.user, id))


class OrderReorderView(APIView):
    @extend_schema(
        operation_id="orders_reorder",
        tags=TAGS,
        summary="Order again",
        description=(
            "Puts the order's items back in the cart, priced at the store in `X-Store-Id`, as "
            "far as they can be ordered now (03 §2.10). Each line is raised to the units of the "
            "past order, capped by what can be ordered (`orderable_quantity`); it is never "
            "added on top, so repeating the call changes nothing. Lines already in the cart "
            "with more units are left as they are. Returns the whole cart and the lines that "
            "could not be added in full (`unavailable`): show them, then open the cart."
        ),
        parameters=[ORDER_ID, STORE_ID_PARAMETER],
        request=None,
        responses=store_responses(
            {
                200: ok_response(
                    ReorderResultSerializer,
                    "The cart after adding the items.",
                    ("Everything added", ex.REORDER_ALL_ADDED),
                    ("Some items unavailable", ex.REORDER_SOME_UNAVAILABLE),
                ),
                401: UNAUTHORIZED,
            },
            not_found=(
                error_example(ErrorCode.NOT_FOUND, "Order not found.", name="ORDER_NOT_FOUND"),
            ),
        ),
    )
    def post(self, request: Request, id: int) -> Response:
        store = get_store(request)
        unavailable, added_count = services.reorder(request.user, store, id)
        cart = cart_services.read_cart(request.user, store)
        return Response(
            {
                "cart": cart_services.cart_body(cart, store, request.user),
                "added_count": added_count,
                "unavailable": unavailable,
            }
        )
