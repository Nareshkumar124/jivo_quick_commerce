"""Let daphne send the RFC 6455 close code 1009 (BUG-0020).

06 §4.1: a socket that sends a message over WS_MAX_MESSAGE_BYTES is closed with 1009 ("message
too big", RFC 6455 §7.4.1). uvicorn (staging and production) sends the code it is given. daphne,
the server behind `manage.py runserver` (local dev :8001 and the QA instance :8004), hands the
application's code to autobahn's `sendClose()`, which accepts only 1000 and 3000-4999 from an
application. So `close(code=1009)` raised inside daphne: it logged "Exception inside application"
at ERROR and closed the socket with 1011.

A size limit on daphne itself does not help: autobahn drops the TCP connection when a message is
too big (`failByDrop`), so the client would see 1006, not 1009.

`install()` wraps daphne's `WebSocketProtocol.serverClose`: the codes in `PROTOCOL_CLOSE_CODES`
go straight to `sendCloseFrame()`, which is what `sendClose()` calls after its range check (and
what daphne itself uses for 1011). Every other code still goes through daphne unchanged.
`RealtimeConfig.ready()` installs it when daphne is in INSTALLED_APPS. It changes nothing under
uvicorn, where daphne's protocol class is never used.
"""

import logging

from apps.realtime import contract

logger = logging.getLogger(__name__)

# RFC 6455 codes the consumers send that autobahn refuses from an application.
PROTOCOL_CLOSE_CODES = frozenset({contract.CLOSE_MESSAGE_TOO_BIG})

_MARKER = "jqc_protocol_close_codes"


def install() -> bool:
    """Patch daphne once. False when daphne is not installed or its internals changed (the
    realtime tests then fail, so a daphne upgrade cannot silently bring 1011 back)."""
    try:
        from daphne.ws_protocol import WebSocketProtocol
    except ImportError:
        return False
    original = WebSocketProtocol.serverClose
    if getattr(original, _MARKER, False):
        return True
    if not callable(getattr(WebSocketProtocol, "sendCloseFrame", None)):
        logger.warning("daphne_compat: daphne has no sendCloseFrame; 1009 closes stay 1011")
        return False

    def serverClose(self, code=None):
        if code in PROTOCOL_CLOSE_CODES:
            # Same as autobahn's sendClose() after its range check: send the close frame when
            # open, ignore when already closing or closed.
            self.sendCloseFrame(code=code, isReply=False)
            return
        original(self, code=code)

    setattr(serverClose, _MARKER, True)
    serverClose.__wrapped__ = original
    WebSocketProtocol.serverClose = serverClose
    return True


def installed() -> bool:
    try:
        from daphne.ws_protocol import WebSocketProtocol
    except ImportError:
        return False
    return bool(getattr(WebSocketProtocol.serverClose, _MARKER, False))
