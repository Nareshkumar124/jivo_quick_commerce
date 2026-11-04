"""Phase 3 endpoints: payment verification and the Razorpay webhook (06 §2.6, 08 §4).

The server decides payment success: a valid checkout signature on verify, or a signed
`payment.captured` webhook, whichever arrives first (the second is a no-op). The app's callback
alone is never trusted, and the amount always comes from the server-side order.

Views are thin: validate, then `apps.payments.services` (which ends in
`orders.services.capture_payment()`).
"""

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.core.schema import (
    UNAUTHORIZED,
    app_responses,
    error_example,
    error_response,
    ok_response,
    request_examples,
    validation_error,
)
from apps.core.throttling import RATE_LIMITED, PaymentThrottle
from apps.orders import examples as order_ex
from apps.orders import presenters
from apps.orders.serializers import OrderSerializer
from apps.payments import examples as ex
from apps.payments import services
from apps.payments.gateways import get_gateway
from apps.payments.serializers import (
    PaymentVerifySerializer,
    RazorpayWebhookEventSerializer,
    WebhookAckSerializer,
)

TAGS = ["payments"]
SIGNATURE_HEADER = "X-Razorpay-Signature"
EVENT_ID_HEADER = "X-Razorpay-Event-Id"
HEADER_REQUIRED = "This header is required."
INVALID_WEBHOOK_SIGNATURE = "The webhook signature is invalid."


# Local development only: the fake gateway's FAKE_GATEWAY_DOWN switch (P3-TC-63).
VERIFY_UNAVAILABLE = error_response(
    "Maintenance mode (`MAINTENANCE`), or the payment gateway could not be reached "
    "(`SERVICE_UNAVAILABLE`): nothing changed; call verify again.",
    *app_responses({})[503].examples,
    error_example(
        ErrorCode.SERVICE_UNAVAILABLE,
        "Online payment is temporarily unavailable. Try again, or choose cash on delivery.",
        name="PAYMENT_GATEWAY_UNAVAILABLE",
    ),
)


class RazorpayVerifyView(APIView):
    throttle_classes = [PaymentThrottle]

    @extend_schema(
        operation_id="payments_razorpay_verify",
        tags=TAGS,
        summary="Confirm an online payment",
        description=(
            "Call it with the fields of Razorpay checkout's success callback. The server checks "
            "the signature (and that the Razorpay order is this order's) and moves the order "
            "from PAYMENT_PENDING to PLACED (08 T3): the stock stays reserved, the coupon is "
            "used and the cart is emptied. Then show the success screen with the returned "
            "order.\n\n"
            "Idempotent (no `Idempotency-Key` needed): calling again, or after the webhook "
            "already confirmed the payment, returns the PLACED order. If the response is lost, "
            "call it again. On a checkout failure or dismissal do **not** call it: show "
            "'Payment failed' with Retry (`POST /orders/{id}/retry-payment/`).\n\n"
            "If the order already failed or was cancelled (`INVALID_STATE_TRANSITION`), it is "
            "not revived: a payment captured anyway is refunded in full automatically (08 T3a)."
        ),
        request=PaymentVerifySerializer,
        examples=request_examples(("Checkout success callback", ex.VERIFY_REQUEST)),
        responses=app_responses(
            {
                200: ok_response(
                    OrderSerializer,
                    "Paid: the order is PLACED.",
                    ("Paid", order_ex.ORDER_ONLINE_PLACED),
                ),
                400: error_response(
                    "`PAYMENT_VERIFICATION_FAILED`: the signature does not match, or the "
                    "Razorpay order is not this order's. Treat it as a failed payment (Retry). "
                    "`VALIDATION_ERROR`: malformed fields.",
                    error_example(ErrorCode.PAYMENT_VERIFICATION_FAILED),
                    validation_error(
                        {"razorpay_signature": ["This value does not match the required pattern."]},
                        name="Malformed signature",
                    ),
                ),
                401: UNAUTHORIZED,
                404: error_response(
                    "`order_id` is not one of the caller's orders.",
                    error_example(ErrorCode.NOT_FOUND, "Order not found."),
                ),
                409: error_response(
                    "`INVALID_STATE_TRANSITION`: the order is no longer awaiting payment "
                    "(`details.status` PAYMENT_FAILED or CANCELLED).",
                    error_example(
                        ErrorCode.INVALID_STATE_TRANSITION,
                        "This order is no longer awaiting payment. Any amount debited will be "
                        "refunded automatically.",
                        {"status": "PAYMENT_FAILED"},
                    ),
                ),
                429: RATE_LIMITED,
                503: VERIFY_UNAVAILABLE,
            }
        ),
    )
    def post(self, request: Request) -> Response:
        serializer = PaymentVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        order = services.verify_payment(
            request.user,
            order_id=data["order_id"],
            razorpay_order_id=data["razorpay_order_id"],
            razorpay_payment_id=data["razorpay_payment_id"],
            signature=data["razorpay_signature"],
        )
        return Response(presenters.order_body(order))


class RazorpayWebhookView(APIView):
    """Called by Razorpay, never by the apps. Authenticated by the `X-Razorpay-Signature` HMAC of
    the raw body (no JWT). Exempt from the 426/503 app guards, so maintenance never loses a
    payment event."""

    authentication_classes: list = []
    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="payments_razorpay_webhook",
        tags=TAGS,
        summary="Razorpay webhook (server to server)",
        description=(
            "Configured in the Razorpay dashboard for `payment.captured`, `payment.failed`, "
            "`refund.processed` and `refund.failed`. **Not for the apps.**\n\n"
            "`X-Razorpay-Signature` must be the hex HMAC-SHA256 of the exact raw body bytes, "
            "keyed with the webhook secret; anything else is a 400 and nothing is stored. "
            "Events are processed once per `X-Razorpay-Event-Id` (a repeat answers "
            "`duplicate`) and in any order relative to verify (08 §4). Unhandled event types "
            "answer `ignored`. A 2xx tells Razorpay not to retry; a 503 asks it to."
        ),
        auth=[],
        parameters=[
            OpenApiParameter(
                SIGNATURE_HEADER,
                OpenApiTypes.STR,
                OpenApiParameter.HEADER,
                required=True,
                description="Hex HMAC-SHA256 of the raw body, keyed with the webhook secret.",
            ),
            OpenApiParameter(
                EVENT_ID_HEADER,
                OpenApiTypes.STR,
                OpenApiParameter.HEADER,
                required=True,
                description="Unique per event: the idempotency key.",
            ),
        ],
        request=RazorpayWebhookEventSerializer,
        examples=request_examples(
            ("payment.captured", ex.WEBHOOK_PAYMENT_CAPTURED),
            ("payment.failed", ex.WEBHOOK_PAYMENT_FAILED),
        ),
        responses={
            200: ok_response(
                WebhookAckSerializer,
                "Accepted.",
                ("Processed", ex.ACK_PROCESSED),
                ("Duplicate event id", ex.ACK_DUPLICATE),
                ("Event type not handled", ex.ACK_IGNORED),
            ),
            400: error_response(
                "`PAYMENT_VERIFICATION_FAILED`: missing or wrong signature (nothing stored). "
                "`VALIDATION_ERROR`: no event id header, or not a Razorpay event.",
                error_example(ErrorCode.PAYMENT_VERIFICATION_FAILED, INVALID_WEBHOOK_SIGNATURE),
                validation_error({EVENT_ID_HEADER: [HEADER_REQUIRED]}, name="No event id"),
            ),
            503: error_response(
                "`SERVICE_UNAVAILABLE`: the event cannot be applied yet (a refund whose gateway "
                "id is still being recorded). Nothing is stored; Razorpay retries it.",
                error_example(ErrorCode.SERVICE_UNAVAILABLE),
            ),
        },
    )
    def post(self, request: Request) -> Response:
        # The HMAC covers the raw bytes: read them before anything parses the body.
        body = request.body
        if not get_gateway().verify_webhook_signature(body, request.headers.get(SIGNATURE_HEADER)):
            raise ApiError(ErrorCode.PAYMENT_VERIFICATION_FAILED, INVALID_WEBHOOK_SIGNATURE)
        event_id = (request.headers.get(EVENT_ID_HEADER) or "").strip()
        if not event_id or len(event_id) > 64:
            raise ValidationError({EVENT_ID_HEADER: [HEADER_REQUIRED]})
        RazorpayWebhookEventSerializer(data=request.data).is_valid(raise_exception=True)
        try:
            result = services.handle_webhook(event_id, request.data)
        except services.WebhookRetryLater:
            # Nothing stored: the gateway retries the event (refund id not recorded yet).
            raise ApiError(ErrorCode.SERVICE_UNAVAILABLE) from None
        return Response({"status": result})
