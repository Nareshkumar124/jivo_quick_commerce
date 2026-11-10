"""OpenAPI examples for the support endpoints (the apps build their fakes from these)."""

_ORDER = {
    "order_id": 1002,
    "order_number": "JV-261104-001002",
    "task_id": None,
    "payout_id": None,
}

_FIRST = {
    "id": 31,
    "body": "The oil bottle cap was broken when it arrived.",
    "from_support": False,
    "created_at": "2026-11-04T05:10:00Z",
    "attachments": [],
}
_SUPPORT = {
    "id": 32,
    "body": "Sorry about that! We have started a refund for the bottle.",
    "from_support": True,
    "created_at": "2026-11-04T05:25:00Z",
    "attachments": [],
}
ATTACHMENT = {
    "key": "9f1c2b7e4d5a4c3b8a7f6e5d4c3b2a19",
    "url": "https://storage.example.com/private/support/12/9f1c2b7e4d5a4c3b8a7f6e5d4c3b2a19.webp"
    "?X-Amz-Expires=600&X-Amz-Signature=abc123",
}
_REPLY = {
    "id": 33,
    "body": "Here is a photo of the bottle.",
    "from_support": False,
    "created_at": "2026-11-04T06:02:00Z",
    "attachments": [ATTACHMENT],
}


def _ticket(status, messages, **extra):
    last = messages[-1]
    return {
        "id": 12,
        "number": "TK-000012",
        "category": "DAMAGED_ITEMS",
        "status": status,
        **_ORDER,
        "last_message": last["body"],
        "created_at": "2026-11-04T05:10:00Z",
        "updated_at": last["created_at"],
        "can_reply": status != "CLOSED",
        "messages": messages,
        **extra,
    }


def _summary(ticket):
    return {k: v for k, v in ticket.items() if k not in ("messages", "can_reply")}


TICKET_NEW = _ticket("OPEN", [_FIRST])
TICKET_ANSWERED = _ticket("IN_PROGRESS", [_FIRST, _SUPPORT])
TICKET_REPLIED = _ticket("OPEN", [_FIRST, _SUPPORT, _REPLY])
TICKET_CLOSED = _ticket("CLOSED", [_FIRST, _SUPPORT])

TICKETS_PAGE = {
    "count": 2,
    "next": None,
    "previous": None,
    "results": [
        _summary(TICKET_ANSWERED),
        {
            "id": 9,
            "number": "TK-000009",
            "category": "ACCOUNT",
            "status": "RESOLVED",
            "order_id": None,
            "order_number": None,
            "task_id": None,
            "payout_id": None,
            "last_message": "Your phone number is updated. Anything else we can help with?",
            "created_at": "2026-11-01T09:00:00Z",
            "updated_at": "2026-11-01T10:30:00Z",
        },
    ],
}
TICKETS_EMPTY = {"count": 0, "next": None, "previous": None, "results": []}

CREATE_WITH_ORDER = {
    "category": "DAMAGED_ITEMS",
    "message": "The oil bottle cap was broken when it arrived.",
    "order_id": 1002,
}
CREATE_WITHOUT_ORDER = {
    "category": "ACCOUNT",
    "message": "How do I change the phone number on my account?",
}
REPLY = {"message": "Thank you, I can see the refund now."}
REPLY_WITH_PHOTO = {
    "message": "Here is a photo of the bottle.",
    "attachment_keys": ["9f1c2b7e4d5a4c3b8a7f6e5d4c3b2a19"],
}
RIDER_TICKET = {
    "id": 14,
    "number": "TK-000014",
    "category": "TASK",
    "status": "OPEN",
    "order_id": None,
    "order_number": "JV-261104-001010",
    "task_id": 310,
    "payout_id": None,
    "last_message": "The customer's gate was locked and nobody answered.",
    "created_at": "2026-11-04T08:00:00Z",
    "updated_at": "2026-11-04T08:00:00Z",
    "can_reply": True,
    "messages": [
        {
            "id": 40,
            "body": "The customer's gate was locked and nobody answered.",
            "from_support": False,
            "created_at": "2026-11-04T08:00:00Z",
            "attachments": [],
        }
    ],
}
CREATE_RIDER_TASK = {
    "category": "TASK",
    "message": "The customer's gate was locked and nobody answered.",
    "task_id": 310,
}
