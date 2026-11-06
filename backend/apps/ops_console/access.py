"""Ops Console access control (05 §3, 09 §3.1).

Every Ops view is wrapped in `ops_view(...)`:
- Signed-in, active staff only, the same rule as the admin site (`is_active and is_staff`), so
  one login (admin login form, django-axes lockout, CSRF) serves both layers. Anyone else is
  sent to the admin login, like /admin/ does.
- Then the view's permissions (all required), checked with `user.has_perms` so roles stay data
  (`apps.accounts.roles`), and its 05 §3 capability if it names one (`capabilities.allowed`).
  A staff member without them gets a 403 page.
- HTMX requests never get a 302: htmx would swap the login page into the target. They get
  401 + `HX-Redirect` (full-page redirect to the login) or 403 (ops.js shows a toast).
- The view runs and renders in IST (times are stored in UTC).
"""

from functools import wraps
from urllib.parse import urlencode, urlsplit

from django.contrib.auth.views import redirect_to_login
from django.http import HttpResponse
from django.shortcuts import render
from django.urls import reverse
from django.utils import timezone
from django.views.decorators.cache import never_cache

from apps.ops_console.dates import DISPLAY_TZ

# Marks refusals made by the Ops Console, so ops.js can tell them from other 403s (CSRF).
REFUSAL_HEADER = "X-Ops-Refused"


def is_htmx(request) -> bool:
    return request.headers.get("HX-Request") == "true"


def is_panel_staff(user) -> bool:
    return bool(user.is_authenticated and user.is_active and user.is_staff)


def _page_path(request) -> str:
    """The page the user is on. For an HTMX request that is the browser URL, not the partial."""
    if is_htmx(request):
        current = urlsplit(request.headers.get("HX-Current-URL", ""))
        if current.path:
            return f"{current.path}?{current.query}" if current.query else current.path
        return reverse("ops:dashboard")
    return request.get_full_path()


def login_redirect(request) -> HttpResponse:
    login_url = reverse("admin:login")
    if is_htmx(request):
        response = HttpResponse(status=401)
        response["HX-Redirect"] = f"{login_url}?{urlencode({'next': _page_path(request)})}"
        return response
    return redirect_to_login(_page_path(request), login_url)


def forbidden(request, message: str | None = None) -> HttpResponse:
    message = message or "Your role does not have access to this page."
    template = "ops/errors/403_partial.html" if is_htmx(request) else "ops/errors/403.html"
    response = render(request, template, {"message": message, "title": "Access refused"})
    response.status_code = 403
    response[REFUSAL_HEADER] = "1"
    return response


def ops_view(*perms: str, capability: str | None = None):
    """Decorate an Ops Console view: staff only, then `perms` (all required) and `capability`
    (`apps.ops_console.capabilities`)."""
    from apps.ops_console.capabilities import allowed

    def decorator(view):
        @wraps(view)
        def wrapper(request, *args, **kwargs):
            user = request.user
            if not is_panel_staff(user):
                return login_redirect(request)
            refused = bool(perms) and not user.has_perms(perms)
            if refused or (capability and not allowed(user, capability)):
                with timezone.override(DISPLAY_TZ):
                    return forbidden(request)
            with timezone.override(DISPLAY_TZ):
                return view(request, *args, **kwargs)

        return never_cache(wrapper)

    return decorator
