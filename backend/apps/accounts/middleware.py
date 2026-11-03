"""Staff session policy (05 §5, 09 §3.1, BUG-0006).

Staff sign in to the admin and the Ops Console with a Django session (Jivo Auth later, D-04).
05 §5: "Session timeout 8 hours (store staff) / 2 hours idle (admin roles)". Implemented as:

- **Every staff session** ends `STAFF_SESSION_MAX_AGE_SECONDS` (8 h) after login, however
  active it is. The login time is stamped in the session (`user_logged_in`), because Django's
  own cookie age (`SESSION_COOKIE_AGE`, also 8 h by default) restarts whenever the session is
  saved and is therefore not an absolute limit.
- **Admin roles** (everyone except staff whose only roles are Store Manager / Store Staff:
  superusers, global roles, mixed roles, staff with no role) also end after
  `STAFF_SESSION_IDLE_SECONDS` (2 h) without a request. Interpretation recorded in 05 §5.

The session cookie's expiry follows the same limits, so the browser drops it too. Activity is
written to the session at most once a minute. Expired sessions are flushed (`logout`) before the
view runs, so the admin and the Ops Console send the user to the login page.
"""

import time
from datetime import UTC, datetime

from django.conf import settings
from django.contrib.auth import logout

from apps.accounts import roles

LOGIN_AT_KEY = "_staff_login_at"
LAST_SEEN_KEY = "_staff_last_seen"
TOUCH_INTERVAL_SECONDS = 60


def stamp_staff_login(sender, request, user, **kwargs) -> None:
    """`user_logged_in` receiver: start the absolute and idle clocks of a staff session."""
    if request is None or not getattr(user, "is_staff", False) or not hasattr(request, "session"):
        return
    now = time.time()
    request.session[LOGIN_AT_KEY] = now
    request.session[LAST_SEEN_KEY] = now
    _set_cookie_expiry(request, _deadline(now, now, idle=has_idle_timeout(user)))


def has_idle_timeout(user) -> bool:
    """Admin roles get the 2-hour idle timeout; store-only staff do not."""
    return not roles.is_store_staff_only(user)


def _deadline(login_at: float, last_seen: float, *, idle: bool) -> float:
    deadline = login_at + settings.STAFF_SESSION_MAX_AGE_SECONDS
    if idle:
        deadline = min(deadline, last_seen + settings.STAFF_SESSION_IDLE_SECONDS)
    return deadline


def _set_cookie_expiry(request, deadline: float) -> None:
    # A datetime (not seconds) so later saves of the session never push the expiry out.
    request.session.set_expiry(datetime.fromtimestamp(deadline, tz=UTC))


def staff_session_policy_middleware(get_response):
    def middleware(request):
        user = getattr(request, "user", None)
        if user is not None and user.is_authenticated and user.is_staff:
            _enforce(request, user)
        return get_response(request)

    return middleware


def _enforce(request, user) -> None:
    session = request.session
    now = time.time()
    idle = has_idle_timeout(user)
    login_at = session.get(LOGIN_AT_KEY)
    if login_at is None:  # signed in before this policy existed: the clocks start now
        session[LOGIN_AT_KEY] = session[LAST_SEEN_KEY] = login_at = now
        _set_cookie_expiry(request, _deadline(login_at, now, idle=idle))
        return
    last_seen = session.get(LAST_SEEN_KEY, login_at)
    if now >= _deadline(login_at, last_seen, idle=idle):
        logout(request)
        return
    if idle and now - last_seen >= TOUCH_INTERVAL_SECONDS:
        session[LAST_SEEN_KEY] = now
        _set_cookie_expiry(request, _deadline(login_at, now, idle=idle))
