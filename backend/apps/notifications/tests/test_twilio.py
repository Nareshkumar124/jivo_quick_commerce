"""TwilioSmsBackend (D-02). No internet: `sms._open` is patched, except in the redirect test,
which talks to a throwaway server on 127.0.0.1."""

import base64
import http.client
import http.server
import io
import json
import logging
import socket
import threading
import urllib.error
import urllib.parse
import urllib.request

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from rest_framework.test import APIClient

from apps.accounts.models import OTPRequest
from apps.accounts.tasks import send_otp_sms
from apps.notifications import sms

PHONE = "+919876543210"
SID = "AC00000000000000000000000000000000"
TOKEN = "fake-auth-token-not-real"
SERVICE = "MG00000000000000000000000000000000"
FROM = "+15005550006"
OTP_BODY = "<#> 482913 is your Jivo verification code."


@pytest.fixture
def twilio(settings):
    settings.SMS_BACKEND = sms.TWILIO_BACKEND
    settings.TWILIO_ACCOUNT_SID = SID
    settings.TWILIO_AUTH_TOKEN = TOKEN
    settings.TWILIO_MESSAGING_SERVICE_SID = ""
    settings.TWILIO_FROM_NUMBER = FROM
    return settings


class _Response(io.BytesIO):
    status = 201

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def _http_error(status: int, body: dict) -> urllib.error.HTTPError:
    return urllib.error.HTTPError(
        "https://api.twilio.com/x", status, "error", {}, io.BytesIO(json.dumps(body).encode())
    )


@pytest.fixture
def urlopen(monkeypatch):
    """Records each request; `outcome` is the JSON to return or the exception to raise."""
    calls = []
    state = {"outcome": {"sid": "SM123", "status": "queued"}}

    def fake(request, timeout):
        calls.append((request, timeout))
        outcome = state["outcome"]
        if isinstance(outcome, BaseException):
            raise outcome
        return _Response(json.dumps(outcome).encode())

    monkeypatch.setattr(sms, "_open", fake)
    fake.calls = calls
    fake.state = state
    return fake


def _fields(request) -> dict:
    return dict(urllib.parse.parse_qsl(request.data.decode()))


def _send():
    sms.send_sms(PHONE, OTP_BODY, "1007")


def _assert_no_secrets(text: str):
    assert TOKEN not in text
    assert "482913" not in text
    assert OTP_BODY not in text
    assert PHONE not in text


def test_success_posts_form_with_basic_auth_and_from(twilio, urlopen, caplog):
    with caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"):
        _send()
    ((request, timeout),) = urlopen.calls
    assert request.get_method() == "POST"
    assert request.full_url == (f"https://api.twilio.com/2010-04-01/Accounts/{SID}/Messages.json")
    assert request.get_header("Authorization") == (
        "Basic " + base64.b64encode(f"{SID}:{TOKEN}".encode()).decode()
    )
    assert request.get_header("Content-type") == "application/x-www-form-urlencoded"
    assert _fields(request) == {"To": PHONE, "Body": OTP_BODY, "From": FROM}
    assert 0 < timeout <= 10
    assert "SM123" in caplog.text
    assert "+91******3210" in caplog.text
    _assert_no_secrets(caplog.text)


def test_messaging_service_takes_precedence_over_from(twilio, urlopen):
    twilio.TWILIO_MESSAGING_SERVICE_SID = SERVICE
    _send()
    fields = _fields(urlopen.calls[0][0])
    assert fields["MessagingServiceSid"] == SERVICE
    assert "From" not in fields


def test_messaging_service_alone(twilio, urlopen):
    twilio.TWILIO_MESSAGING_SERVICE_SID = SERVICE
    twilio.TWILIO_FROM_NUMBER = ""
    _send()
    assert _fields(urlopen.calls[0][0])["MessagingServiceSid"] == SERVICE


@pytest.mark.parametrize("missing", ["TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "sender"])
def test_missing_settings_fail_loudly_without_calling_twilio(twilio, urlopen, missing):
    if missing == "sender":
        twilio.TWILIO_FROM_NUMBER = ""
    else:
        setattr(twilio, missing, "")
    with pytest.raises(ImproperlyConfigured) as exc:
        _send()
    assert urlopen.calls == []
    _assert_no_secrets(str(exc.value))


@pytest.mark.parametrize(("code", "twilio_code"), [(400, 21608), (400, 21211), (401, 20003)])
def test_4xx_is_rejected_without_retry(twilio, urlopen, caplog, code, twilio_code):
    urlopen.state["outcome"] = _http_error(
        code, {"code": twilio_code, "message": f"The number {PHONE} is unverified.", "status": code}
    )
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected) as exc,
    ):
        _send()
    assert not isinstance(exc.value, sms.SmsError)
    assert str(twilio_code) in caplog.text
    assert f"HTTP {code}" in caplog.text
    _assert_no_secrets(caplog.text)
    _assert_no_secrets(str(exc.value))


@pytest.mark.parametrize("code", [429, 500, 503])
def test_429_and_5xx_raise_retryable_error(twilio, urlopen, caplog, code):
    urlopen.state["outcome"] = _http_error(code, {"code": 20429, "message": "busy"})
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsError),
    ):
        _send()
    assert f"HTTP {code}" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize(
    "error",
    [
        urllib.error.URLError(socket.gaierror("dns")),
        urllib.error.URLError(ConnectionRefusedError()),
        urllib.error.URLError(TimeoutError("connect timed out")),
    ],
)
def test_errors_before_the_request_is_sent_are_retried(twilio, urlopen, caplog, error):
    """urllib wraps connect/send failures in URLError: nothing reached Twilio, so retry."""
    urlopen.state["outcome"] = error
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsError),
    ):
        _send()
    assert "will retry" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize(
    "error",
    [
        TimeoutError("timed out"),
        ConnectionResetError(),
        http.client.RemoteDisconnected("closed"),
        http.client.IncompleteRead(b""),
    ],
)
def test_errors_after_the_request_is_sent_are_not_retried(twilio, urlopen, caplog, error):
    """A read timeout or dropped connection after sending: Twilio may have sent the SMS and has
    no idempotency key, so a retry could send a duplicate OTP."""
    urlopen.state["outcome"] = error
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsOutcomeUnknown) as exc,
    ):
        _send()
    assert not isinstance(exc.value, sms.SmsError)
    assert "outcome unknown, not retried" in caplog.text
    assert "+91******3210" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize("code", [301, 302, 307, 308])
def test_3xx_is_rejected(twilio, urlopen, caplog, code):
    urlopen.state["outcome"] = _http_error(code, {})
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected),
    ):
        _send()
    assert f"HTTP {code}" in caplog.text


def test_opener_never_follows_a_redirect():
    """The real opener against a local server answering 307: the 3xx surfaces as an HTTPError and
    the POST body is never sent to the Location."""
    hits = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            hits.append(self.path)
            self.rfile.read(int(self.headers["Content-Length"]))
            self.send_response(307)
            self.send_header("Location", "/elsewhere")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        request = urllib.request.Request(
            f"http://127.0.0.1:{server.server_port}/Messages.json", data=b"To=x", method="POST"
        )
        with pytest.raises(urllib.error.HTTPError) as exc:
            sms._open(request, 5)
        assert exc.value.code == 307
    finally:
        server.shutdown()
        server.server_close()
    assert hits == ["/Messages.json"]


def test_unparseable_error_body_is_handled(twilio, urlopen):
    urlopen.state["outcome"] = urllib.error.HTTPError(
        "https://api.twilio.com/x", 502, "bad gateway", {}, io.BytesIO(b"<html>")
    )
    with pytest.raises(sms.SmsError):
        _send()
    assert sms._json(b"[1]") == {}


# --------------------------------------------------------------------------- the OTP task


@pytest.mark.django_db
class TestOtpTaskWithTwilio:
    def _otp_request(self, phone=PHONE):
        from datetime import timedelta

        from django.utils import timezone

        return OTPRequest.objects.create(
            phone=phone,
            app="customer",
            code_hash="x",
            expires_at=timezone.now() + timedelta(minutes=5),
        )

    def test_sends_and_marks_sent(self, twilio, urlopen, caplog):
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms(otp.pk, "482913") == "sent"
        otp.refresh_from_db()
        assert otp.sms_sent_at is not None
        assert "482913" in _fields(urlopen.calls[0][0])["Body"]
        _assert_no_secrets(caplog.text)

    def test_rejected_number_is_not_retried(self, twilio, urlopen, caplog):
        urlopen.state["outcome"] = _http_error(400, {"code": 21608, "message": "unverified"})
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms.apply(args=(otp.pk, "482913")).get() == "rejected"
        assert len(urlopen.calls) == 1  # no retry
        otp.refresh_from_db()
        assert otp.sms_sent_at is None
        _assert_no_secrets(caplog.text)

    def test_unknown_outcome_is_not_retried(self, twilio, urlopen, caplog):
        urlopen.state["outcome"] = TimeoutError("read timed out")
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms.apply(args=(otp.pk, "482913")).get() == "unknown"
        assert len(urlopen.calls) == 1  # no retry
        otp.refresh_from_db()
        assert otp.sms_sent_at is None
        assert "outcome unknown, not retried" in caplog.text
        _assert_no_secrets(caplog.text)

    def test_transient_error_uses_the_task_retry_policy(self, twilio, urlopen):
        assert sms.SmsError in send_otp_sms.autoretry_for
        urlopen.state["outcome"] = _http_error(503, {})
        otp = self._otp_request()
        with pytest.raises(sms.SmsError):
            send_otp_sms(otp.pk, "482913")
        otp.refresh_from_db()
        assert otp.sms_sent_at is None

    def test_fixed_otp_test_numbers_never_reach_twilio(
        self, twilio, urlopen, django_capture_on_commit_callbacks
    ):
        for phone in ("+919000000001", "+919000000002", "+919000000003"):
            with django_capture_on_commit_callbacks(execute=True):
                response = APIClient().post(
                    "/api/v1/auth/otp/request/", {"phone": phone, "app": "customer"}, format="json"
                )
            assert response.status_code == 200
        assert urlopen.calls == []
        assert OTPRequest.objects.filter(sms_sent_at__isnull=False).count() == 0

    def test_real_number_goes_through_twilio(
        self, twilio, urlopen, django_capture_on_commit_callbacks
    ):
        with django_capture_on_commit_callbacks(execute=True):
            APIClient().post(
                "/api/v1/auth/otp/request/", {"phone": PHONE, "app": "customer"}, format="json"
            )
        assert len(urlopen.calls) == 1
        assert _fields(urlopen.calls[0][0])["To"] == PHONE


# --------------------------------------------------------------------------- system check


def _twilio_errors():
    return [e for e in run_checks() if e.id == "accounts.E004"]


def test_check_ignores_other_backends(settings):
    settings.TWILIO_ACCOUNT_SID = ""
    assert _twilio_errors() == []


def test_check_passes_when_configured(twilio):
    assert _twilio_errors() == []
    twilio.TWILIO_FROM_NUMBER = ""
    twilio.TWILIO_MESSAGING_SERVICE_SID = SERVICE
    assert _twilio_errors() == []


def test_check_requires_credentials_and_a_sender(twilio):
    twilio.TWILIO_AUTH_TOKEN = ""
    twilio.TWILIO_FROM_NUMBER = ""
    (error,) = _twilio_errors()
    assert "TWILIO_AUTH_TOKEN" in error.msg
    assert "TWILIO_MESSAGING_SERVICE_SID or TWILIO_FROM_NUMBER" in error.msg
    assert "TWILIO_ACCOUNT_SID" not in error.msg


def test_twilio_is_a_delivering_backend_in_deployed_environments(twilio):
    twilio.APP_ENVIRONMENT = "production"
    assert sms.TWILIO_BACKEND not in sms.NON_DELIVERING_BACKENDS
    assert [e for e in run_checks() if e.id == "accounts.E003"] == []
