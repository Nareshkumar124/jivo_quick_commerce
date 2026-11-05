"""Content-Security-Policy for the staff panel (OWASP review L7), **report-only** first.

`Content-Security-Policy-Report-Only` goes on every `/admin/` and `/ops/` response; violations
are POSTed to `/ops/csp-report/` and logged (directive, blocked URI and page path only). After a
week of clean reports, set `CSP_REPORT_ONLY = False` to send the enforcing header instead.

Policy notes:
- Scripts come only from our own origin (htmx, Alpine, Chart.js, qrcode-generator are vendored,
  docs/admin-panel-architecture.md §6). `'unsafe-eval'` stays: Alpine's standard build (ours and
  the copy unfold ships for /admin/) and htmx trigger filters evaluate expressions. Dropping it
  needs Alpine's CSP build plus rewriting every inline Alpine expression, unfold's included; the
  reports will show whether anything else needs it.
- A per-request nonce is in `script-src` (`request.csp_nonce`), so any inline script that must
  stay can carry `nonce="{{ request.csp_nonce }}"` instead of needing `'unsafe-inline'`.
- Styles allow `'unsafe-inline'` (unfold and the theme colours use inline `<style>` / `style=`).
- Images: our origin, `data:` / `blob:` (charts, QR), and the OpenStreetMap tiles of the store
  maps (until the Mappls switch, DL-29).
- No framing (`frame-ancestors 'none'`), no plugins, forms post only to our origin.
"""

import json
import logging
import re
import secrets

from django.conf import settings
from django.core.cache import cache
from django.http import HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

logger = logging.getLogger("apps.ops_console.csp")

PANEL_PREFIXES = ("/admin/", "/ops/")
REPORT_PATH = "/ops/csp-report/"
MAX_REPORT_BYTES = 16_384
HEADER_ENFORCE = "Content-Security-Policy"
HEADER_REPORT_ONLY = "Content-Security-Policy-Report-Only"


def policy(nonce: str) -> str:
    directives = [
        "default-src 'self'",
        f"script-src 'self' 'unsafe-eval' 'nonce-{nonce}'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob: https://tile.openstreetmap.org",
        "font-src 'self' data:",
        "connect-src 'self'",
        "frame-src 'self'",
        "frame-ancestors 'none'",
        "object-src 'none'",
        "base-uri 'self'",
        "form-action 'self'",
        f"report-uri {REPORT_PATH}",
    ]
    return "; ".join(directives)


def report_only() -> bool:
    return bool(getattr(settings, "CSP_REPORT_ONLY", True))


def report_only_csp_middleware(get_response):
    def middleware(request):
        request.csp_nonce = secrets.token_urlsafe(16)
        response = get_response(request)
        if request.path.startswith(PANEL_PREFIXES):
            header = HEADER_REPORT_ONLY if report_only() else HEADER_ENFORCE
            if header not in response:
                response[header] = policy(request.csp_nonce)
        return response

    return middleware


REPORTS_PER_MINUTE = 30  # per client IP; more are dropped silently
_CONTROL = re.compile(r"[\x00-\x1f\x7f]")


def _clean(value, limit: int) -> str:
    """One log-safe token: no control characters (no CR/LF log injection), no query string or
    fragment (they may carry search terms), at most `limit` characters."""
    text = _CONTROL.sub("", str(value or ""))
    text = text.split("?", 1)[0].split("#", 1)[0]
    return text[:limit]


def _flooding(request) -> bool:
    from apps.core.net import client_ip

    key = f"ops-csp-report:{client_ip(request) or 'unknown'}"
    cache.add(key, 0, timeout=60)
    try:
        count = cache.incr(key)
    except ValueError:  # expired between add and incr
        cache.set(key, 1, timeout=60)
        count = 1
    return count > REPORTS_PER_MINUTE


@csrf_exempt
@require_POST
def csp_report(request):
    """Browsers POST violation reports here (`application/csp-report`). Logged at INFO in short,
    sanitised form; never echoed back. Oversized bodies are refused before they are read (413),
    malformed ones and floods (more than 30 a minute from one IP) are dropped silently."""
    try:
        length = int(request.META.get("CONTENT_LENGTH") or 0)
    except ValueError:
        length = MAX_REPORT_BYTES + 1
    if length > MAX_REPORT_BYTES:
        return HttpResponse(status=413)
    if _flooding(request):
        return HttpResponse(status=204)
    try:
        data = json.loads(request.body or b"{}")
    except ValueError:
        return HttpResponse(status=204)
    report = data.get("csp-report", data) if isinstance(data, dict) else {}
    if isinstance(report, dict):
        directive = report.get("violated-directive") or report.get("effective-directive")
        logger.info(
            "CSP violation: %s blocked %s on %s",
            _clean(directive, 100),
            _clean(report.get("blocked-uri"), 200),
            _clean(report.get("document-uri"), 200),
        )
    return HttpResponse(status=204)
