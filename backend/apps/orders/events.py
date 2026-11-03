"""Order domain events (06 §1.2). Services call `emit()` inside their transaction; the handler
runs after commit as an idempotent Celery task, so a rolled-back change never notifies anyone.

Phase 3 only records the event (log line). Phase 4 (store new-order alert, live board) and
Phase 6 (push, SMS, WebSocket) hang their notifications on these same events (08 §9).
"""

from django.db import transaction

PLACED = "order.placed"  # T2/T3: the store should start
PAYMENT_PENDING = "order.payment_pending"  # T1
PAYMENT_FAILED = "order.payment_failed"  # T4
CANCELLED = "order.cancelled"  # T5
LATE_CAPTURE = "payment.late_capture"  # T3a: ops alert


def emit(event: str, order_id: int) -> None:
    def send() -> None:
        from apps.orders.tasks import order_event

        order_event.delay(event, order_id)

    transaction.on_commit(send)
