"""Client IP for rate limits and lockouts.

Behind nginx / a load balancer, set NUM_PROXIES (env) to the number of trusted proxies so the
client address is read from X-Forwarded-For; otherwise REMOTE_ADDR is used. Mirrors DRF's
throttle identification so every limiter agrees on who the client is.
"""

import ipaddress

from django.conf import settings


def client_ip(request) -> str | None:
    num_proxies = settings.NUM_PROXIES
    remote = request.META.get("REMOTE_ADDR")
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR")
    candidate = remote
    if num_proxies and forwarded:
        hops = [hop.strip() for hop in forwarded.split(",") if hop.strip()]
        if hops:
            candidate = hops[-min(num_proxies, len(hops))]
    try:
        return str(ipaddress.ip_address((candidate or "").strip()))
    except ValueError:
        return None
