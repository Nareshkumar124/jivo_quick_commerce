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
