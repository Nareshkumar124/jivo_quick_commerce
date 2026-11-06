"""Example payloads for the Phase 6 inbox contract (checked by tests/test_schema_examples.py)."""

ORDER_PLACED = {
    "id": 5102,
    "title": "Order placed",
    "body": "We have received order JV-261110-001203. We will tell you when the store confirms it.",
    "category": "order",
    "link": "jivo://orders/1203",
    "read": False,
    "created_at": "2026-11-10T09:40:32Z",
}
ORDER_CONFIRMED_READ = {
    "id": 5101,
    "title": "Order confirmed",
    "body": "The store has confirmed order JV-261109-001188 and is packing it.",
    "category": "order",
    "link": "jivo://orders/1188",
    "read": True,
    "created_at": "2026-11-09T18:02:10Z",
}
INBOX_PAGE = {
    "count": 2,
    "next": None,
    "previous": None,
    "results": [ORDER_PLACED, ORDER_CONFIRMED_READ],
    "unread_count": 1,
}
INBOX_EMPTY = {"count": 0, "next": None, "previous": None, "results": [], "unread_count": 0}
READ = {**ORDER_PLACED, "read": True}
READ_ALL = {"updated": 3}
UNREAD = {"unread": 2}
