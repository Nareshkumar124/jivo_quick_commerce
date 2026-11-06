"""OpenAPI examples for the support endpoints (the apps build their fakes from these)."""

_ORDER = {"order_id": 1002, "order_number": "JV-261104-001002"}

_FIRST = {
    "id": 31,
    "body": "The oil bottle cap was broken when it arrived.",
    "from_support": False,
    "created_at": "2026-11-04T05:10:00Z",
}
_SUPPORT = {
    "id": 32,
    "body": "Sorry about that! We have started a refund for the bottle.",
    "from_support": True,
    "created_at": "2026-11-04T05:25:00Z",
}
_REPLY = {
    "id": 33,
    "body": "Thank you, I can see the refund now.",
    "from_support": False,
    "created_at": "2026-11-04T06:02:00Z",
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
