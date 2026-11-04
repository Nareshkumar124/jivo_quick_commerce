"""Template helpers for the Ops Console and admin templates: `{% load ops %}`."""

from django import template

from apps.ops_console import pii, status

register = template.Library()


@register.filter
def phone_for(phone, user) -> str:
    """`{{ customer.phone|phone_for:request.user }}`: full or masked per the PII policy."""
    return pii.display_phone(user, phone)


@register.inclusion_tag("ops/components/status_badge.html")
def status_badge(kind: str, code: str | None, size: str = "") -> dict:
    """`{% status_badge "order" order.status %}`: label and colour from `status.BADGES`."""
    return {"badge": status.badge_for(kind, code), "size": size}


@register.filter
def inr(value) -> str:
    """`{{ order.grand_total|inr }}`: "₹1,299.00" (display only, `money.inr`)."""
    from apps.ops_console.money import inr as format_inr

    return format_inr(value)


@register.filter
def iso(moment) -> str:
    """`{{ order.placed_at|iso }}`: ISO 8601 in UTC for `data-*` attributes read by scripts."""
    if not moment:
        return ""
    from datetime import UTC

    return moment.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


@register.filter
def minutes_since(moment, now) -> int:
    """Whole minutes between `moment` and `now` (the server-rendered age; scripts tick it)."""
    if not moment or not now:
        return 0
    return max(int((now - moment).total_seconds() // 60), 0)


@register.inclusion_tag("ops/components/sla_badge.html")
def sla_badge(timer, now=None) -> dict:
    """`{% sla_badge ticket.timer console.generated_at %}`: DUE SOON / LATE badge plus the time
    text (design/system/components/ops-alert-banner-and-sla-badges.md, Part B)."""
    from apps.ops_console import sla

    return {
        "timer": timer,
        "label": sla.BADGE_LABELS.get(timer.tone, ""),
        "icon": sla.BADGE_ICONS.get(timer.tone, "timer"),
        "text": sla.time_text(timer, now),
        "aria": sla.aria_text(timer, now),
    }
