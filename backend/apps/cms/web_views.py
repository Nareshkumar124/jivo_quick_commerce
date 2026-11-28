"""Public web view of the CMS pages: `/legal/` and `/legal/<slug>/` (launch, 2026-11-28).

Standalone HTML (no login, no JavaScript, inline CSS only) for the Play Store / Razorpay policy
links and the app's `policy_urls`. Same content as `GET /api/v1/pages/<slug>/`: published pages
only, body sanitised (`apps.cms.html`), unknown or unpublished slugs answer 404.
"""

from django.http import Http404, HttpRequest, HttpResponse
from django.shortcuts import render
from django.views.decorators.http import require_safe

from apps.cms.legal_pages import LEGAL_PAGES
from apps.cms.models import Page
from apps.cms.services import page_body

# No scripts, no remote anything: only the inline <style>; no framing, no forms.
LEGAL_CSP = (
    "default-src 'none'; style-src 'unsafe-inline'; img-src 'self'; base-uri 'none'; "
    "form-action 'none'; frame-ancestors 'none'"
)
CACHE_CONTROL = "public, max-age=60"


def _finish(response: HttpResponse) -> HttpResponse:
    response["Content-Security-Policy"] = LEGAL_CSP
    response["Cache-Control"] = CACHE_CONTROL
    return response


@require_safe
def legal_index(request: HttpRequest) -> HttpResponse:
    """The launch policy pages (LEGAL_PAGES) that are published, in LEGAL_PAGES order."""
    order = {slug: index for index, slug in enumerate(LEGAL_PAGES)}
    pages = sorted(
        Page.objects.filter(is_published=True, slug__in=list(LEGAL_PAGES)).values("slug", "title"),
        key=lambda page: order[page["slug"]],
    )
    return _finish(render(request, "cms/legal_index.html", {"pages": pages}))


@require_safe
def legal_page(request: HttpRequest, slug: str) -> HttpResponse:
    body = page_body(slug)
    if body is None:
        raise Http404("Page not found.")
    return _finish(render(request, "cms/legal_page.html", {"page": body}))
