"""Outbound HTTP to third-party APIs (T-814, L2).

`open_no_redirect()` never follows a 3xx: a request carrying credentials (basic auth, API keys)
only ever goes to the URL it was built for. urllib raises the 3xx as an `HTTPError` instead.
"""

import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_OPENER = urllib.request.build_opener(NoRedirect)


def open_no_redirect(request: urllib.request.Request, timeout: float):
    return _OPENER.open(request, timeout=timeout)
