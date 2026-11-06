"""Per-user limits on the support endpoints that write (fail open, apps.core.throttling)."""

from apps.core.throttling import FailOpenUserThrottle


class TicketCreateThrottle(FailOpenUserThrottle):
    scope = "support_tickets_create"


class TicketMessageThrottle(FailOpenUserThrottle):
    scope = "support_messages"
