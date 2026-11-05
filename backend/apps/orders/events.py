"""Order domain events (06 §1.2). Services call `emit()` inside their transaction; the handler
runs after commit as an idempotent Celery task, so a rolled-back change never notifies anyone.

Phase 3 only records the event (log line). Phase 4 (store new-order alert, live board) and
Phase 6 (push, SMS, WebSocket) hang their notifications on these same events (08 §9).
"""

from django.db import transaction

PLACED = "order.placed"  # T2/T3: the store should start
PAYMENT_PENDING = "order.payment_pending"  # T1
PAYMENT_FAILED = "order.payment_failed"  # T4
CANCELLED = "order.cancelled"  # T5, T11, T12
# Phase 4 (08 §9)
ACCEPTED = "order.accepted"  # T6: customer "Order confirmed"; dispatch if DISPATCH_TRIGGER
PACKING = "order.packing"  # T7: customer label only
PACKED = "order.packed"  # T8: rider "Order ready" (Phase 5), board
ITEMS_ADJUSTED = "order.items_adjusted"  # T8a: customer push + SMS with the refund / new amount
ACCEPTANCE_SLA_BREACHED = "order.acceptance_sla_breached"  # ops alert, store re-alert
# Phase 5 (08 §9). Push/WebSocket for T9 and "rider arrived" go through apps.delivery.hooks.
DELIVERED = "order.delivered"  # T10: customer push + rating prompt, board, invoice
DELIVERY_FAILED = "order.delivery_failed"  # T13: customer push, store "expect return", ops alert
RETURNED = "order.returned"  # T14: board
LATE_CAPTURE = "payment.late_capture"  # T3a: ops alert
REFUND_FAILED = "payment.refund_failed"  # ops alert: retry with order_refunds.retry_refund()
OPS_ALERTS = frozenset({LATE_CAPTURE, REFUND_FAILED, ACCEPTANCE_SLA_BREACHED, DELIVERY_FAILED})


def emit(event: str, order_id: int) -> None:
    def send() -> None:
        from apps.orders.tasks import order_event

        order_event.delay(event, order_id)

    transaction.on_commit(send)
