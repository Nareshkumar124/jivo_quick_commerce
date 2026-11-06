"""The WebSocket contract (06 §4): sockets, close codes, every message type, its JSON schema and
an example.

OpenAPI does not describe sockets, so `apps.realtime.schema.add_websocket_components` publishes
each message as a `Ws...` component in `openapi/schema.yaml` (with its example): the apps build
against them. Doc 06 §4 shows the same examples. Tests check that every example validates
against its schema and that the payloads the server really sends do too.

Every server message is `{"type": "<type>", "data": {...}, "sent_at": "<UTC ISO 8601>"}`.
Messages carry the current state (not a diff), so a duplicate or a missed message is harmless:
apply the newest `sent_at`, and on reconnect re-read the REST endpoint.
"""

from typing import Any

# --------------------------------------------------------------------------- sockets & auth
ORDER_SOCKET = "/ws/v1/orders/{order_id}/"
RIDER_SOCKET = "/ws/v1/rider/"
OPS_SOCKET = "/ws/ops/live/"

# Sec-WebSocket-Protocol: the app offers both values; the server selects SUBPROTOCOL (never the
# token). Without the token value the app authenticates with the first message instead.
SUBPROTOCOL = "jivo.v1"
TOKEN_SUBPROTOCOL_PREFIX = "jivo.auth."  # noqa: S105 - a prefix, not a secret

# Close codes (4000-4999 are application codes, RFC 6455 §7.4.2), modelled on HTTP statuses.
CLOSE_BAD_MESSAGE = 4400  # first message not auth, or more than WS_MAX_BAD_MESSAGES bad ones
CLOSE_UNAUTHENTICATED = 4401  # missing / invalid / expired token, or no staff session
CLOSE_FORBIDDEN = 4403  # authenticated, but not allowed (no role, not an active rider)
CLOSE_NOT_FOUND = 4404  # the order does not exist or is another user's (IDOR: same code)
CLOSE_AUTH_TIMEOUT = 4408  # no auth message within WS_AUTH_TIMEOUT_SECONDS
CLOSE_TOO_MANY_SOCKETS = 4429  # the user already has WS_MAX_SOCKETS_PER_USER sockets open
CLOSE_MESSAGE_TOO_BIG = 1009  # RFC 6455: an inbound message over WS_MAX_MESSAGE_BYTES
CLOSE_CODES = {
    CLOSE_BAD_MESSAGE: "The first message must be the auth message.",
    CLOSE_UNAUTHENTICATED: (
        "Not signed in: the token is missing, invalid or expired (refresh it, then reconnect), "
        "or the staff session ended."
    ),
    CLOSE_FORBIDDEN: "Signed in, but this socket is not for you (role, rider status).",
    CLOSE_NOT_FOUND: "The order does not exist or is not yours.",
    CLOSE_AUTH_TIMEOUT: "No auth message in time.",
    CLOSE_TOO_MANY_SOCKETS: "Too many open sockets for this user: close one, then reconnect.",
    CLOSE_MESSAGE_TOO_BIG: "A message was larger than the server accepts.",
}

# --------------------------------------------------------------------------- message types
ORDER_STATUS = "order.status"
ORDER_ETA = "order.eta"
ORDER_CREATED = "order.created"
RIDER_LOCATION = "rider.location"
RIDER_STATUS = "rider.status"
OFFER_NEW = "offer.new"
OFFER_WITHDRAWN = "offer.withdrawn"
OFFER_EXPIRED = "offer.expired"
TASK_UPDATED = "task.updated"
CASH_UPDATED = "cash.updated"
NOTIFICATION_NEW = "notification.new"
TASK_STATUS = "task.status"
ALERT = "alert"
# Control messages
AUTH = "auth"  # client -> server
PING = "ping"  # client -> server
AUTH_OK = "auth.ok"  # server -> client
PONG = "pong"  # server -> client
ERROR = "error"  # server -> client (non-fatal: the socket stays open)

ALERT_CODES = (
    "ACCEPTANCE_SLA_BREACHED",  # the store has not accepted within the SLA (08 §9)
    "LATE_CAPTURE",  # T3a: a capture after the order failed, auto-refunded
    "REFUND_FAILED",  # a refund failed at the gateway: retry it
    "DELIVERY_FAILED",  # T13 (Phase 5)
    "DISPATCH_UNASSIGNED",  # no rider found (Phase 5)
    "PICKUP_CODE_LOCKED",  # too many wrong pickup codes (Phase 5)
    "DELIVERY_OTP_LOCKED",  # too many wrong delivery OTPs (Phase 5)
    "STOCK_NOT_COMMITTED",  # T9 with no active stock reservation (Phase 5)
    "ARRIVAL_GEOFENCE_OVERRIDE",  # rider marked arrival outside the drop geofence (Phase 5)
    "MOCKED_LOCATION",  # the rider app reports mocked GPS (Phase 5)
    "RIDER_STALE_ON_TASK",  # a rider on a task stopped sending locations (Phase 5)
)
# EXPIRED is only sent as `offer.expired` (T-612); `offer.withdrawn` carries the others.
OFFER_WITHDRAWN_REASONS = ("EXPIRED", "TAKEN", "ORDER_CANCELLED", "REASSIGNED", "RIDER_OFFLINE")
TASK_CHANGES = (
    "ORDER_PACKED",
    "ORDER_CANCELLED",
    "AMOUNT_CHANGED",
    "REASSIGNED",
    "STATUS_CHANGED",
    "ASSIGNED",
)
CASH_REASONS = ("COD_COLLECTED", "DEPOSIT", "ADJUSTMENT", "DEPOSIT_REQUIRED")
TASK_STATUSES = (
    "SEARCHING",
    "OFFERED",
    "ASSIGNED",
    "AT_STORE",
    "PICKED_UP",
    "AT_CUSTOMER",
    "DELIVERED",
    "FAILED",
    "RETURNING",
    "RETURNED",
    "UNASSIGNED",
    "CANCELLED",
)

# --------------------------------------------------------------------------- schema helpers
DT = {"type": "string", "format": "date-time"}
DT_NULL = {**DT, "nullable": True}
INT = {"type": "integer"}
INT_NULL = {"type": "integer", "nullable": True}
STR = {"type": "string"}
NUM = {"type": "number", "format": "double"}
NUM_NULL = {**NUM, "nullable": True}
MONEY = {"type": "string", "format": "decimal", "pattern": r"^-?\d{0,10}(?:\.\d{0,2})?$"}
MONEY_NULL = {**MONEY, "nullable": True}
BOOL = {"type": "boolean"}


def _ref(name: str) -> dict:
    return {"$ref": f"#/components/schemas/{name}"}


def _enum(*values: str, nullable: bool = False) -> dict:
    schema: dict[str, Any] = {"type": "string", "enum": list(values)}
    if nullable:
        schema["nullable"] = True
        schema["enum"].append(None)
    return schema


def _object(description: str, **properties) -> dict:
    return {
        "type": "object",
        "description": description,
        "properties": properties,
        "required": list(properties),
    }


def _message(type_: str, data_component: str | None, description: str) -> dict:
    properties: dict[str, Any] = {
        "type": {**STR, "description": f'Always "{type_}".'},
    }
    if data_component:
        properties["data"] = _ref(data_component)
    properties["sent_at"] = {**DT, "description": "When the server sent it (UTC)."}
    return {
        "type": "object",
        "description": description,
        "properties": properties,
        "required": list(properties),
    }


# --------------------------------------------------------------------------- examples
SENT_AT = "2026-11-10T09:41:05.120000Z"
ORDER_STATUS_DATA = {
    "order_id": 1203,
    "order_number": "JV-261110-001203",
    "store_id": 1,
    "status": "ACCEPTED",
    "payment_status": "PAID",
    "eta_at": "2026-11-10T09:58:00Z",
    "updated_at": "2026-11-10T09:41:04.880000Z",
}
ORDER_ETA_DATA = {"order_id": 1203, "eta_at": "2026-11-10T09:56:00Z", "eta_minutes": 9}
RIDER_LOCATION_DATA = {
    "order_id": 1203,
    "lat": 28.4741,
    "lng": 77.0489,
    "heading": 72.5,
    "recorded_at": "2026-11-10T09:47:12Z",
}
OPS_RIDER_LOCATION_DATA = {
    "rider_id": 41,
    "store_id": 1,
    "order_id": 1203,
    "lat": 28.4741,
    "lng": 77.0489,
    "heading": 72.5,
    "recorded_at": "2026-11-10T09:47:12Z",
}
ORDER_CREATED_DATA = {
    "order_id": 1203,
    "order_number": "JV-261110-001203",
    "store_id": 1,
    "status": "PLACED",
    "payment_method": "COD",
    "item_count": 3,
    "grand_total": "498.00",
    "placed_at": "2026-11-10T09:40:31Z",
    "eta_at": "2026-11-10T09:58:00Z",
}
RIDER_STATUS_DATA = {
    "rider_id": 41,
    "store_id": 1,
    "is_online": True,
    "on_task": False,
    "updated_at": "2026-11-10T09:30:00Z",
}
ALERT_DATA = {
    "code": "ACCEPTANCE_SLA_BREACHED",
    "message": "Order JV-261110-001203 has not been accepted within 60 seconds.",
    "store_id": 1,
    "order_id": 1203,
    "rider_id": None,
    "at": "2026-11-10T09:41:31Z",
}
# The `RiderOffer` body of `GET /rider/offers/current/` (Phase 5 contract).
OFFER_DATA = {
    "id": 9001,
    "task_id": 7001,
    "store_name": "Jivo Sector 14",
    "drop_locality": "Sector 21, Gurugram",
    "distance_km": "2.40",
    "payment_type": "COD",
    "cod_amount": "498.00",
    "estimated_payout": "42.00",
    "item_count": 3,
    "offered_at": "2026-11-10T09:30:00Z",
    "expires_at": "2026-11-10T09:30:30Z",
}
OFFER_WITHDRAWN_DATA = {"offer_id": 9001, "task_id": 7001, "reason": "ORDER_CANCELLED"}
OFFER_EXPIRED_DATA = {"offer_id": 9001, "task_id": 7001, "reason": "EXPIRED"}
CASH_UPDATED_DATA = {
    "rider_id": 41,
    "cash_in_hand": "1498.00",
    "cash_limit": "2000.00",
    "limit_reached": False,
    "deposit_required": False,
    "reason": "COD_COLLECTED",
    "updated_at": "2026-11-10T09:58:10Z",
}
NOTIFICATION_NEW_DATA = {
    "id": 5512,
    "title": "Order confirmed",
    "body": "The store has confirmed order JV-261110-001203 and will pack it now.",
    "category": "order",
    "link": "jivo://orders/1203",
    "read": False,
    "created_at": "2026-11-10T09:41:05Z",
    "unread_count": 3,
}
OPS_TASK_STATUS_DATA = {
    "task_id": 7001,
    "order_id": 1203,
    "order_number": "JV-261110-001203",
    "store_id": 1,
    "status": "ASSIGNED",
    "previous_status": "OFFERED",
    "rider_id": 41,
    "assignment_mode": "AUTO",
    "attempt_count": 1,
    "updated_at": "2026-11-10T09:30:08Z",
}
TASK_UPDATED_DATA = {
    "task_id": 7001,
    "order_id": 1203,
    "status": "ASSIGNED",
    "order_status": "PACKED",
    "change": "ORDER_PACKED",
}
AUTH_OK_DATA = {"user_id": 812, "expires_at": "2026-11-10T09:55:00Z"}
ERROR_DATA = {"code": "VALIDATION_ERROR", "message": "Unknown message type."}


def _example(type_: str, data: dict | None) -> dict:
    message: dict[str, Any] = {"type": type_}
    if data is not None:
        message["data"] = data
    message["sent_at"] = SENT_AT
    return message


# --------------------------------------------------------------------------- components
# name -> (schema, example). Data components first, then the messages that use them.
DATA_COMPONENTS: dict[str, dict] = {
    "WsOrderStatusData": _object(
        "The order's current status (same values as `GET /orders/{id}/`).",
        order_id=INT,
        order_number=STR,
        store_id=INT,
        status=_ref("OrderStatusEnum"),
        payment_status=_ref("PaymentStatusEnum"),
        eta_at={**DT_NULL, "description": "Promised delivery time (08 §8), UTC."},
        updated_at={**DT, "description": "When the order last changed."},
    ),
    "WsOrderEtaData": _object(
        "A recomputed ETA (08 §8): on status changes and while the rider is on the way.",
        order_id=INT,
        eta_at=DT,
        eta_minutes={**INT, "description": "Minutes from `sent_at`, at least 1."},
    ),
    "WsRiderLocationData": _object(
        "The rider's newest position for this order (customer socket).",
        order_id=INT,
        lat=NUM,
        lng=NUM,
        heading={**NUM_NULL, "description": "Degrees from north, or null."},
        recorded_at={**DT, "description": "When the phone recorded the fix (UTC)."},
    ),
    "WsOpsRiderLocationData": _object(
        "A rider's newest position (ops socket, rider map).",
        rider_id=INT,
        store_id=INT,
        order_id={**INT_NULL, "description": "The order of the rider's active task, or null."},
        lat=NUM,
        lng=NUM,
        heading=NUM_NULL,
        recorded_at=DT,
    ),
    "WsOrderCreatedData": _object(
        "A new order for the store (new-order alert with sound, live board). No customer data.",
        order_id=INT,
        order_number=STR,
        store_id=INT,
        status=_ref("OrderStatusEnum"),
        payment_method=_ref("PaymentMethodEnum"),
        item_count={**INT, "description": "Units in the order."},
        grand_total=MONEY,
        placed_at=DT_NULL,
        eta_at=DT_NULL,
    ),
    "WsRiderStatusData": _object(
        "A rider went online or offline, or started or finished a task (ops).",
        rider_id=INT,
        store_id=INT,
        is_online=BOOL,
        on_task=BOOL,
        updated_at=DT,
    ),
    "WsAlertData": _object(
        "An ops alert (08 §9 **Alert** column).",
        code={
            **_enum(*ALERT_CODES),
            "description": "What happened. New codes may come: show `message` for unknown ones.",
        },
        message=STR,
        store_id=INT_NULL,
        order_id=INT_NULL,
        rider_id=INT_NULL,
        at=DT,
    ),
    "WsOfferData": {
        "type": "object",
        "description": (
            "Exactly the `RiderOffer` body of `GET /rider/offers/current/` (`offer`). Accept "
            "with `POST /rider/offers/{id}/accept/` before `expires_at`."
        ),
        "properties": {
            "id": INT,
            "task_id": INT,
            "store_name": STR,
            "drop_locality": STR,
            "distance_km": {"type": "string", "format": "decimal"},
            "payment_type": STR,
            "cod_amount": MONEY_NULL,
            "estimated_payout": MONEY,
            "item_count": INT,
            "offered_at": DT,
            "expires_at": DT,
        },
        "required": [
            "id",
            "task_id",
            "store_name",
            "drop_locality",
            "distance_km",
            "payment_type",
            "cod_amount",
            "estimated_payout",
            "item_count",
            "offered_at",
            "expires_at",
        ],
    },
    "WsOfferWithdrawnData": _object(
        "The offer is gone: close the offer screen.",
        offer_id=INT,
        task_id=INT,
        reason=_enum(*OFFER_WITHDRAWN_REASONS),
    ),
    "WsCashUpdatedData": _object(
        "The rider's cash in hand changed (COD collected, deposit, adjustment), or COD offers "
        "now need a deposit first. Same values as `GET /rider/cash/` (`cash`).",
        rider_id=INT,
        cash_in_hand=MONEY,
        cash_limit=MONEY,
        limit_reached=BOOL,
        deposit_required={
            **BOOL,
            "description": 'Show the "deposit cash" banner (08 §5, DL-61 b).',
        },
        reason=_enum(*CASH_REASONS),
        updated_at=DT,
    ),
    "WsNotificationNewData": _object(
        "A new inbox entry for this app (the `InboxNotification` of `GET /me/notifications/`) "
        "and the new unread count. Sent to every open app socket of the user.",
        id=INT,
        title=STR,
        body=STR,
        category=STR,
        link={**STR, "nullable": True},
        read=BOOL,
        created_at=DT,
        unread_count={**INT, "description": "Unread inbox entries for this app now."},
    ),
    "WsOpsTaskStatusData": _object(
        "A delivery task was created or changed state (dispatch board, 05 §1.4). No customer data.",
        task_id=INT,
        order_id=INT,
        order_number=STR,
        store_id=INT,
        status=_enum(*TASK_STATUSES),
        previous_status={
            **_enum(*TASK_STATUSES, nullable=True),
            "description": "null when the task was just created.",
        },
        rider_id=INT_NULL,
        assignment_mode={
            **_enum("AUTO", "MANUAL", nullable=True),
            "description": "null before a rider is assigned.",
        },
        attempt_count={**INT, "description": "Offers made in the current search round."},
        updated_at=DT,
    ),
    "WsTaskUpdatedData": _object(
        "The rider's task changed: re-read `GET /rider/tasks/current/`.",
        task_id=INT,
        order_id=INT,
        status={**STR, "description": "The task status (08 §3)."},
        order_status=_ref("OrderStatusEnum"),
        change=_enum(*TASK_CHANGES),
    ),
    "WsAuthOkData": _object(
        "Authenticated. Before `expires_at` send a new auth message with a fresh access token, "
        "or the socket closes with 4401.",
        user_id=INT,
        expires_at=DT_NULL,
    ),
    "WsErrorData": _object(
        "A non-fatal error about a client message (the socket stays open).",
        code=STR,
        message=STR,
    ),
}

MESSAGES: list[tuple[str, str, str | None, dict | None, str]] = [
    # (component, type, data component, example data, description)
    (
        "WsOrderStatusMessage",
        ORDER_STATUS,
        "WsOrderStatusData",
        ORDER_STATUS_DATA,
        f"`{ORDER_SOCKET}` (also sent once right after `auth.ok`) and `{OPS_SOCKET}`.",
    ),
    (
        "WsOrderEtaMessage",
        ORDER_ETA,
        "WsOrderEtaData",
        ORDER_ETA_DATA,
        f"`{ORDER_SOCKET}`.",
    ),
    (
        "WsRiderLocationMessage",
        RIDER_LOCATION,
        "WsRiderLocationData",
        RIDER_LOCATION_DATA,
        f"`{ORDER_SOCKET}`: while a rider is assigned.",
    ),
    (
        "WsOpsRiderLocationMessage",
        RIDER_LOCATION,
        "WsOpsRiderLocationData",
        OPS_RIDER_LOCATION_DATA,
        f"`{OPS_SOCKET}`: the rider map.",
    ),
    (
        "WsOrderCreatedMessage",
        ORDER_CREATED,
        "WsOrderCreatedData",
        ORDER_CREATED_DATA,
        f"`{OPS_SOCKET}`: an order reached PLACED.",
    ),
    (
        "WsRiderStatusMessage",
        RIDER_STATUS,
        "WsRiderStatusData",
        RIDER_STATUS_DATA,
        f"`{OPS_SOCKET}`.",
    ),
    ("WsAlertMessage", ALERT, "WsAlertData", ALERT_DATA, f"`{OPS_SOCKET}`."),
    ("WsOfferNewMessage", OFFER_NEW, "WsOfferData", OFFER_DATA, f"`{RIDER_SOCKET}`."),
    (
        "WsOfferWithdrawnMessage",
        OFFER_WITHDRAWN,
        "WsOfferWithdrawnData",
        OFFER_WITHDRAWN_DATA,
        f"`{RIDER_SOCKET}`.",
    ),
    (
        "WsOfferExpiredMessage",
        OFFER_EXPIRED,
        "WsOfferWithdrawnData",
        OFFER_EXPIRED_DATA,
        f"`{RIDER_SOCKET}`: the offer timed out (`reason` is EXPIRED). Close the offer screen.",
    ),
    (
        "WsCashUpdatedMessage",
        CASH_UPDATED,
        "WsCashUpdatedData",
        CASH_UPDATED_DATA,
        f"`{RIDER_SOCKET}`.",
    ),
    (
        "WsNotificationNewMessage",
        NOTIFICATION_NEW,
        "WsNotificationNewData",
        NOTIFICATION_NEW_DATA,
        f"`{ORDER_SOCKET}` and `{RIDER_SOCKET}`: a new inbox entry (api-requests #47). Without "
        "an open socket the app re-reads the inbox on the FCM message.",
    ),
    (
        "WsOpsTaskStatusMessage",
        TASK_STATUS,
        "WsOpsTaskStatusData",
        OPS_TASK_STATUS_DATA,
        f"`{OPS_SOCKET}`: the dispatch board (task created, offered, accepted, failed, ...).",
    ),
    (
        "WsTaskUpdatedMessage",
        TASK_UPDATED,
        "WsTaskUpdatedData",
        TASK_UPDATED_DATA,
        f"`{RIDER_SOCKET}`.",
    ),
    (
        "WsAuthOkMessage",
        AUTH_OK,
        "WsAuthOkData",
        AUTH_OK_DATA,
        "Every socket: the answer to a valid auth (first message or subprotocol).",
    ),
    ("WsPongMessage", PONG, None, None, 'Every socket: the answer to `{"type": "ping"}`.'),
    ("WsErrorMessage", ERROR, "WsErrorData", ERROR_DATA, "Every socket."),
]

AUTH_MESSAGE_EXAMPLE = {"type": AUTH, "token": "<access JWT>"}
CLIENT_COMPONENTS: dict[str, dict] = {
    "WsAuthRequest": {
        "type": "object",
        "description": (
            "Client -> server, the first message on `/ws/v1/` sockets (or offer the "
            f'subprotocols `["{SUBPROTOCOL}", "{TOKEN_SUBPROTOCOL_PREFIX}<access JWT>"]` instead). '
            "Never put the token in the URL. Send it again with a fresh token to extend the socket."
        ),
        "properties": {"type": {**STR, "description": '"auth"'}, "token": STR},
        "required": ["type", "token"],
    },
    "WsPingRequest": {
        "type": "object",
        "description": 'Client -> server keep-alive, answered with `{"type": "pong"}`.',
        "properties": {"type": {**STR, "description": '"ping"'}},
        "required": ["type"],
    },
}


def components() -> dict[str, dict]:
    """Every `Ws...` component (schema with its `example`), for the OpenAPI schema."""
    result: dict[str, dict] = {}
    for name, schema in DATA_COMPONENTS.items():
        result[name] = dict(schema)
    for name, type_, data_component, data, description in MESSAGES:
        result[name] = {
            **_message(type_, data_component, description),
            "example": _example(type_, data),
        }
    result["WsAuthRequest"] = {
        **CLIENT_COMPONENTS["WsAuthRequest"],
        "example": AUTH_MESSAGE_EXAMPLE,
    }
    result["WsPingRequest"] = {**CLIENT_COMPONENTS["WsPingRequest"], "example": {"type": PING}}
    return result


def examples() -> dict[str, dict]:
    """component name -> example message."""
    return {name: _example(type_, data) for name, type_, _, data, _ in MESSAGES}
