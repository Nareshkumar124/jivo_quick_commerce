"""BUG-0020, P6-TC-50: daphne (`manage.py runserver`, local dev and the QA instance) can send the
close code 1009. Without `apps.realtime.daphne_compat`, autobahn refused it ("invalid close code
1009 (must be 1000 or from [3000, 4999])"), daphne logged an ERROR traceback and sent 1011.

These drive daphne's real `WebSocketProtocol.serverClose` (what daphne calls for an application's
`websocket.close`) on a protocol in the OPEN state whose outgoing frames are recorded.
"""

import struct

import pytest
from daphne.ws_protocol import WebSocketProtocol

from apps.realtime import contract, daphne_compat

APP_CODES = sorted(code for code in contract.CLOSE_CODES if code != contract.CLOSE_MESSAGE_TOO_BIG)


def open_protocol() -> WebSocketProtocol:
    protocol = WebSocketProtocol.__new__(WebSocketProtocol)  # no connection, no reactor
    protocol.state = WebSocketProtocol.STATE_OPEN
    protocol.closeHandshakeTimeout = 0
    protocol.frames = []
    protocol.sendFrame = lambda opcode, payload=b"", **kw: protocol.frames.append((opcode, payload))
    return protocol


def close_codes(protocol) -> list[int]:
    assert all(opcode == 8 for opcode, _ in protocol.frames)  # 8: close frame
    return [struct.unpack("!H", payload[:2])[0] for _, payload in protocol.frames]


def test_the_patch_is_installed_at_startup():
    """`RealtimeConfig.ready()` installs it: daphne is in INSTALLED_APPS."""
    assert daphne_compat.installed()


def test_install_is_idempotent():
    patched = WebSocketProtocol.serverClose
    assert daphne_compat.install()
    assert WebSocketProtocol.serverClose is patched
    assert patched.__wrapped__.__module__ == "daphne.ws_protocol"  # wrapped once, not twice


def test_daphne_sends_1009():
    protocol = open_protocol()
    protocol.serverClose(code=contract.CLOSE_MESSAGE_TOO_BIG)
    assert close_codes(protocol) == [1009]
    assert protocol.state == WebSocketProtocol.STATE_CLOSING
    assert protocol.closedByMe
    protocol.serverClose(code=contract.CLOSE_MESSAGE_TOO_BIG)  # already closing: no 2nd frame
    assert close_codes(protocol) == [1009]


def test_without_the_patch_daphne_refuses_1009():
    """The bug, reproduced on daphne's own method."""
    protocol = open_protocol()
    with pytest.raises(Exception, match=r"invalid close code 1009"):
        WebSocketProtocol.serverClose.__wrapped__(protocol, code=1009)
    assert protocol.frames == []


@pytest.mark.parametrize("code", [None, 1000, *APP_CODES])
def test_every_other_code_still_goes_through_daphne(code):
    protocol = open_protocol()
    protocol.serverClose(code=code)
    assert close_codes(protocol) == [code or 1000]


def test_codes_outside_the_contract_are_still_refused():
    """Only the contract's RFC code is let through; autobahn's rule holds for the rest."""
    protocol = open_protocol()
    with pytest.raises(Exception, match=r"invalid close code 1011"):
        protocol.serverClose(code=1011)
    assert protocol.frames == []
