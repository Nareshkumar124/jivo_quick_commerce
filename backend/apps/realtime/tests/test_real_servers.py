"""BUG-0020, P6-TC-50 through the real ASGI servers. Channels' WebsocketCommunicator accepts any
close code, which is how the daphne refusal of 1009 went unnoticed. These start each server in a
subprocess with `config.asgi:application` and talk to it over TCP with the `websockets` client:

- daphne: what `manage.py runserver` runs (local dev :8001, the QA instance :8004);
- uvicorn: what gunicorn's uvicorn worker runs in staging and production.

The message is sent before auth, so the server never needs the database. The subprocess gets a
database port that refuses connections anyway, so it can never reach the shared DB.
"""

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest
from websockets.exceptions import ConnectionClosed
from websockets.sync.client import connect

BACKEND = Path(__file__).resolve().parents[3]
START_TIMEOUT = 90  # seconds: Django + Twisted start slowly on Windows


def daphne(port: int) -> list[str]:
    return [
        sys.executable, "-m", "daphne", "-b", "127.0.0.1", "-p", str(port),
        "config.asgi:application",
    ]  # fmt: skip


def uvicorn(port: int) -> list[str]:
    return [
        sys.executable, "-m", "uvicorn", "config.asgi:application", "--host", "127.0.0.1",
        "--port", str(port), "--lifespan", "off", "--ws-max-size", "65536", "--no-access-log",
    ]  # fmt: skip


def free_port() -> int:
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def wait_until_listening(process, port: int, log: Path) -> None:
    deadline = time.monotonic() + START_TIMEOUT
    while time.monotonic() < deadline:
        if process.poll() is not None:
            pytest.fail(f"the server exited ({process.returncode}):\n{log_text(log)}")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.5):
                return
        except OSError:
            time.sleep(0.2)
    pytest.fail(f"the server did not listen within {START_TIMEOUT} s:\n{log_text(log)}")


def log_text(log: Path) -> str:
    return log.read_text(encoding="utf-8", errors="replace")


@pytest.fixture(params=[daphne, uvicorn], ids=["daphne", "uvicorn"])
def server(request, tmp_path):
    port = free_port()
    log = tmp_path / "server.log"
    env = {k: v for k, v in os.environ.items() if not k.startswith("COV_CORE_")}
    env.update(
        DJANGO_SETTINGS_MODULE="config.settings.test",
        PYTHONUNBUFFERED="1",
        POSTGRES_HOST="127.0.0.1",
        POSTGRES_PORT="9",  # refused at once: the server never touches a real database
    )
    with log.open("wb") as output:
        process = subprocess.Popen(  # noqa: S603 - fixed argv, no shell
            request.param(port), cwd=BACKEND, env=env, stdout=output, stderr=subprocess.STDOUT
        )
        try:
            wait_until_listening(process, port, log)
            yield port, log
        finally:
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def test_oversized_message_closes_with_1009_on_the_real_server(server):
    """BUG-0020, P6-TC-50: about 5,000 bytes on the customer order socket, before auth (QA's
    `before_auth` case). Was 1011 plus an ERROR traceback on daphne."""
    port, log = server
    message = json.dumps({"type": "ping", "pad": "x" * 5000})
    with connect(f"ws://127.0.0.1:{port}/ws/v1/orders/1/", open_timeout=20) as client:
        client.send(message)
        with pytest.raises(ConnectionClosed) as closed:
            client.recv(timeout=20)
    assert closed.value.rcvd is not None, "no close frame: the connection was dropped"
    assert closed.value.rcvd.code == 1009, closed.value
    time.sleep(0.5)  # let the server write any late log line
    output = log_text(log)
    assert "Exception inside application" not in output, output
    assert "invalid close code" not in output, output
    assert " ERROR " not in output, output
    assert "over WS_MAX_MESSAGE_BYTES (4096); closing with 1009" in output, output
