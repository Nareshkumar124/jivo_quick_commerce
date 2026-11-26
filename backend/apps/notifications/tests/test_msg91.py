"""Msg91SmsBackend (T-815, D-02): the MSG91 Flow API v5. No internet: `sms._open` is patched
everywhere, so no test can reach control.msg91.com.

Covers the request shape (authkey header, flow template_id, recipients with `mobiles` and the
template variables), phone normalisation, the error classes and how the OTP task and the
notification SMS task treat each one, MSG91's `type: error` answers on HTTP 200, the variable
mapping for the OTP and for notification events, the system checks accounts.E007 / W001, and
that no authkey, OTP or full phone number reaches the log.
"""

import http.client
import io
import json
import logging
import socket
import urllib.error

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from rest_framework.test import APIClient

from apps.accounts.models import OTPRequest
from apps.accounts.services import otp as otp_service
from apps.accounts.tasks import send_otp_sms
from apps.notifications import services, sms
from apps.notifications.choices import Channel, DeliveryStatus
from apps.notifications.models import Notification, NotificationTemplate
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory

MSG91_URL = "https://control.msg91.com/api/v5/flow"
PHONE = "+919876543210"
MOBILE = "919876543210"
AUTH_KEY = "fake-msg91-authkey-not-real"
OTP_DLT = "1007000000000000001"  # test settings' SMS_OTP_DLT_TEMPLATE_ID
OTP_FLOW = "65f0aaaaaaaaaaaaaaaaaaaa"
PLACED_DLT = "1007000000000000101"  # test settings' SMS_DLT_TEMPLATE_IDS["order.placed"]
PLACED_FLOW = "65f0bbbbbbbbbbbbbbbbbbbb"
OFD_DLT = "1007000000000000103"  # order.out_for_delivery
OFD_FLOW = "65f0cccccccccccccccccccc"
REQUEST_ID = "3567686a6f73303435363831"
CODE = "482913"
APP_HASH = "FA+9qCX9VSu"


@pytest.fixture
def msg91(settings):
    settings.SMS_BACKEND = sms.MSG91_BACKEND
    settings.MSG91_AUTH_KEY = AUTH_KEY
    settings.MSG91_FLOW_IDS = {OTP_DLT: OTP_FLOW, PLACED_DLT: PLACED_FLOW, OFD_DLT: OFD_FLOW}
    settings.SMS_SENDER_ID = ""
    settings.SMS_RETRIEVER_APP_HASHES = {"customer": APP_HASH, "rider": ""}
    return settings


class _Response(io.BytesIO):
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def _http_error(status: int, body) -> urllib.error.HTTPError:
    raw = body if isinstance(body, bytes) else json.dumps(body).encode()
    return urllib.error.HTTPError(MSG91_URL, status, "error", {}, io.BytesIO(raw))


@pytest.fixture
def urlopen(monkeypatch):
    """Records each request; `outcome` is the JSON (or raw bytes) to return, or the exception
    to raise."""
    calls = []
    state = {"outcome": {"type": "success", "message": REQUEST_ID}}

    def fake(request, timeout):
        calls.append((request, timeout))
        outcome = state["outcome"]
        if isinstance(outcome, BaseException):
            raise outcome
        raw = outcome if isinstance(outcome, bytes) else json.dumps(outcome).encode()
        return _Response(raw)

    monkeypatch.setattr(sms, "_open", fake)
    fake.calls = calls
    fake.state = state
    return fake


def _payload(request) -> dict:
    return json.loads(request.data.decode())


def _send(variables=None, dlt=OTP_DLT, to=PHONE):
    if variables is None:
        variables = {"otp": CODE, "app_hash": APP_HASH}
    sms.send_sms(to, f"<#> {CODE} is your Jivo verification code. {APP_HASH}", dlt, variables)


def _assert_no_secrets(text: str):
    assert AUTH_KEY not in text
    assert CODE not in text
    assert PHONE not in text
    assert MOBILE not in text


# --------------------------------------------------------------------------- the request


def test_success_posts_the_flow_with_authkey_and_variables(msg91, urlopen, caplog):
    """T-815: POST /api/v5/flow, authkey header, template_id = the flow mapped to the DLT id,
    recipients[0] = {mobiles without "+", the template variables}."""
    with caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"):
        _send()
    ((request, timeout),) = urlopen.calls
    assert request.get_method() == "POST"
    assert request.full_url == MSG91_URL
    assert request.full_url.startswith("https://")
    assert request.get_header("Authkey") == AUTH_KEY
    assert request.get_header("Content-type") == "application/json"
    assert _payload(request) == {
        "template_id": OTP_FLOW,
        "short_url": "0",
        "recipients": [{"otp": CODE, "app_hash": APP_HASH, "mobiles": MOBILE}],
    }
    assert 0 < timeout <= 10
    assert REQUEST_ID in caplog.text
    assert "+91******3210" in caplog.text
    _assert_no_secrets(caplog.text)


def test_sender_is_sent_only_when_configured(msg91, urlopen):
    msg91.SMS_SENDER_ID = "JIVOWL"
    _send()
    assert _payload(urlopen.calls[0][0])["sender"] == "JIVOWL"


def test_a_variable_cannot_override_the_destination(msg91, urlopen):
    _send(variables={"otp": CODE, "mobiles": "910000000000"})
    assert _payload(urlopen.calls[0][0])["recipients"] == [{"otp": CODE, "mobiles": MOBILE}]


def test_variable_values_are_sent_as_strings(msg91, urlopen):
    _send(variables={"amount": 249})
    assert _payload(urlopen.calls[0][0])["recipients"][0]["amount"] == "249"


@pytest.mark.parametrize(
    ("phone", "mobile"),
    [("+919876543210", "919876543210"), ("+14155550100", "14155550100")],
)
def test_phone_is_sent_with_country_code_without_plus(phone, mobile):
    assert sms.msg91_mobile(phone) == mobile


@pytest.mark.parametrize("phone", ["9876543210", "919876543210", "+91 98765 43210", "+0912", ""])
def test_a_phone_that_is_not_e164_is_rejected_without_calling_msg91(msg91, urlopen, phone):
    with pytest.raises(sms.SmsRejected) as exc:
        _send(to=phone)
    assert urlopen.calls == []
    assert not isinstance(exc.value, sms.SmsError)
    if phone:
        assert phone not in str(exc.value)


@pytest.mark.parametrize("missing", ["auth_key", "flow", "dlt", "variables"])
def test_missing_configuration_fails_loudly_without_calling_msg91(msg91, urlopen, missing):
    """Like UnconfiguredSmsBackend: ImproperlyConfigured, nothing sent, nothing secret in the
    message."""
    if missing == "auth_key":
        msg91.MSG91_AUTH_KEY = ""
    elif missing == "flow":
        msg91.MSG91_FLOW_IDS = {}
    message = sms.SmsMessage(
        to=PHONE,
        body=CODE,
        dlt_template_id="" if missing == "dlt" else OTP_DLT,
        sender_id="",
        variables=None if missing == "variables" else {"otp": CODE},
    )
    with pytest.raises(ImproperlyConfigured) as exc:
        sms.get_backend().send(message)
    assert urlopen.calls == []
    _assert_no_secrets(str(exc.value))


def test_message_repr_never_shows_the_body_or_variables():
    message = sms.SmsMessage(
        to=PHONE, body=f"{CODE} is your code", dlt_template_id="1", sender_id="", variables={}
    )
    assert CODE not in repr(message)


# --------------------------------------------------------------------------- answers and errors


@pytest.mark.parametrize(
    "body",
    [
        {"type": "error", "message": f"Invalid mobile number {MOBILE}", "code": "418"},
        {"type": "error", "message": "Authentication failure"},
        {"type": "error", "message": "template id missing", "code": {"nested": "x"}},
    ],
)
def test_type_error_on_http_200_is_rejected_without_logging_msg91_text(
    msg91, urlopen, caplog, body
):
    """MSG91 reports a bad authkey, unknown flow or DLT mismatch with HTTP 200 + type error."""
    urlopen.state["outcome"] = body
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected) as exc,
    ):
        _send()
    assert not isinstance(exc.value, sms.SmsError)
    assert "HTTP 200, type error" in caplog.text
    assert body["message"] not in caplog.text
    _assert_no_secrets(caplog.text)
    _assert_no_secrets(str(exc.value))


@pytest.mark.parametrize("raw", [b"<html>ok</html>", b"", b"[1]", b'{"message": "x"}'])
def test_2xx_without_a_msg91_type_is_an_unknown_outcome(msg91, urlopen, caplog, raw):
    urlopen.state["outcome"] = raw
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsOutcomeUnknown),
    ):
        _send()
    assert "outcome unknown, not retried" in caplog.text


def test_a_free_text_success_message_is_not_logged(msg91, urlopen, caplog):
    urlopen.state["outcome"] = {"type": "success", "message": f"sent to {MOBILE}"}
    with caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"):
        _send()
    assert "request -" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize("code", [400, 401, 403, 404, 422])
def test_4xx_is_rejected_without_retry(msg91, urlopen, caplog, code):
    urlopen.state["outcome"] = _http_error(
        code, {"type": "error", "message": f"bad number {MOBILE}", "code": "311"}
    )
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected) as exc,
    ):
        _send()
    assert not isinstance(exc.value, sms.SmsError)
    assert f"HTTP {code}" in caplog.text
    assert "MSG91 code 311" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize("code", [301, 302, 307, 308])
def test_3xx_is_rejected(msg91, urlopen, code):
    urlopen.state["outcome"] = _http_error(code, b"")
    with pytest.raises(sms.SmsRejected):
        _send()


@pytest.mark.parametrize("code", [429, 500, 502, 503])
def test_429_and_5xx_raise_retryable_error(msg91, urlopen, caplog, code):
    urlopen.state["outcome"] = _http_error(code, b"<html>busy</html>")
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsError),
    ):
        _send()
    assert f"HTTP {code}" in caplog.text
    assert "will retry" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize(
    "error",
    [
        urllib.error.URLError(socket.gaierror("dns")),
        urllib.error.URLError(ConnectionRefusedError()),
        urllib.error.URLError(TimeoutError("connect timed out")),
    ],
)
def test_errors_before_the_request_is_sent_are_retried(msg91, urlopen, caplog, error):
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
def test_errors_after_the_request_is_sent_are_not_retried(msg91, urlopen, caplog, error):
    """MSG91 may already have sent the SMS and has no idempotency key: no retry."""
    urlopen.state["outcome"] = error
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsOutcomeUnknown) as exc,
    ):
        _send()
    assert not isinstance(exc.value, sms.SmsError)
    assert "outcome unknown, not retried" in caplog.text
    _assert_no_secrets(caplog.text)


# --------------------------------------------------------------------------- the OTP task


@pytest.mark.django_db
class TestOtpTaskWithMsg91:
    def _otp_request(self, phone=PHONE, app="customer"):
        from datetime import timedelta

        from django.utils import timezone

        return OTPRequest.objects.create(
            phone=phone,
            app=app,
            code_hash="x",
            expires_at=timezone.now() + timedelta(minutes=5),
        )

    def test_sends_otp_and_app_hash_as_flow_variables(self, msg91, urlopen, caplog):
        """T-815: the OTP flow gets ##otp## and ##app_hash## (SMS Retriever), not the text."""
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms(otp.pk, CODE) == "sent"
        otp.refresh_from_db()
        assert otp.sms_sent_at is not None
        payload = _payload(urlopen.calls[0][0])
        assert payload["template_id"] == OTP_FLOW
        assert payload["recipients"] == [{"otp": CODE, "app_hash": APP_HASH, "mobiles": MOBILE}]
        _assert_no_secrets(caplog.text)

    def test_app_hash_is_blank_when_unset(self, msg91, urlopen):
        otp = self._otp_request(app="rider")
        send_otp_sms(otp.pk, CODE)
        assert _payload(urlopen.calls[0][0])["recipients"][0]["app_hash"] == ""

    def test_variables_match_the_rendered_text(self, msg91):
        msg91.SMS_OTP_TEMPLATE = "<#> {otp} is your Jivo code. {app_hash}"
        variables = otp_service.otp_sms_variables(CODE, "customer")
        assert variables == {"otp": CODE, "app_hash": APP_HASH}
        text = otp_service.render_otp_sms(CODE, "customer")
        assert CODE in text
        assert text.endswith(APP_HASH)

    def test_type_error_is_rejected_and_not_retried(self, msg91, urlopen, caplog):
        urlopen.state["outcome"] = {"type": "error", "message": "DLT template mismatch"}
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms.apply(args=(otp.pk, CODE)).get() == "rejected"
        assert len(urlopen.calls) == 1
        otp.refresh_from_db()
        assert otp.sms_sent_at is None
        _assert_no_secrets(caplog.text)

    def test_4xx_is_rejected_and_not_retried(self, msg91, urlopen):
        urlopen.state["outcome"] = _http_error(401, {"type": "error", "message": "auth"})
        otp = self._otp_request()
        assert send_otp_sms.apply(args=(otp.pk, CODE)).get() == "rejected"
        assert len(urlopen.calls) == 1

    def test_unknown_outcome_is_not_retried(self, msg91, urlopen, caplog):
        urlopen.state["outcome"] = TimeoutError("read timed out")
        otp = self._otp_request()
        with caplog.at_level(logging.DEBUG):
            assert send_otp_sms.apply(args=(otp.pk, CODE)).get() == "unknown"
        assert len(urlopen.calls) == 1
        otp.refresh_from_db()
        assert otp.sms_sent_at is None
        _assert_no_secrets(caplog.text)

    @pytest.mark.parametrize(
        "outcome",
        [_http_error(503, b""), _http_error(429, b""), urllib.error.URLError(socket.gaierror())],
    )
    def test_transient_errors_use_the_task_retry_policy(self, msg91, urlopen, outcome):
        assert sms.SmsError in send_otp_sms.autoretry_for
        urlopen.state["outcome"] = outcome
        otp = self._otp_request()
        with pytest.raises(sms.SmsError):
            send_otp_sms(otp.pk, CODE)
        otp.refresh_from_db()
        assert otp.sms_sent_at is None

    def test_a_transient_error_schedules_a_retry_that_then_sends(self, msg91, urlopen):
        """503: the task asks Celery for a retry (autoretry_for SmsError), nothing is marked
        sent; the retried run sends once and marks the OTP sent."""
        from celery.exceptions import Retry

        urlopen.state["outcome"] = _http_error(503, b"")
        otp = self._otp_request()
        with pytest.raises(Retry):
            send_otp_sms.apply(args=(otp.pk, CODE))
        otp.refresh_from_db()
        assert otp.sms_sent_at is None
        urlopen.state["outcome"] = {"type": "success", "message": REQUEST_ID}
        assert send_otp_sms.apply(args=(otp.pk, CODE)).get() == "sent"
        assert len(urlopen.calls) == 2
        otp.refresh_from_db()
        assert otp.sms_sent_at is not None
        assert send_otp_sms(otp.pk, CODE) == "skipped"  # a duplicate retry never re-sends

    def test_missing_flow_fails_the_task_loudly(self, msg91, urlopen):
        msg91.MSG91_FLOW_IDS = {}
        otp = self._otp_request()
        with pytest.raises(ImproperlyConfigured):
            send_otp_sms(otp.pk, CODE)
        assert urlopen.calls == []

    def test_fixed_otp_test_numbers_never_reach_msg91(
        self, msg91, urlopen, django_capture_on_commit_callbacks
    ):
        """D-15: the fixed-OTP test numbers send nothing, whatever the gateway."""
        for phone in ("+919000000001", "+919000000002", "+919000000003"):
            with django_capture_on_commit_callbacks(execute=True):
                response = APIClient().post(
                    "/api/v1/auth/otp/request/", {"phone": phone, "app": "customer"}, format="json"
                )
            assert response.status_code == 200
        assert urlopen.calls == []
        assert OTPRequest.objects.filter(sms_sent_at__isnull=False).count() == 0

    def test_real_number_goes_through_msg91(
        self, msg91, urlopen, django_capture_on_commit_callbacks
    ):
        with django_capture_on_commit_callbacks(execute=True):
            APIClient().post(
                "/api/v1/auth/otp/request/", {"phone": PHONE, "app": "customer"}, format="json"
            )
        assert len(urlopen.calls) == 1
        recipient = _payload(urlopen.calls[0][0])["recipients"][0]
        assert recipient["mobiles"] == MOBILE
        assert set(recipient) == {"mobiles", "otp", "app_hash"}
        assert len(recipient["otp"]) == 6


# --------------------------------------------------------------------------- notification SMS


@pytest.fixture
def run_on_commit(django_capture_on_commit_callbacks):
    def run(fn, *args, **kwargs):
        with django_capture_on_commit_callbacks(execute=True):
            return fn(*args, **kwargs)

    return run


@pytest.mark.django_db
class TestNotificationSmsWithMsg91:
    def test_order_placed_sends_its_placeholders_as_variables(self, msg91, urlopen, run_on_commit):
        """08 §9 order.placed SMS: ##order_number## and ##grand_total## (catalog `{{names}}`)."""
        order = OrderFactory()
        notification = run_on_commit(services.notify_order_event, "order.placed", order.pk)
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.SENT
        ((request, _),) = urlopen.calls
        payload = _payload(request)
        assert payload["template_id"] == PLACED_FLOW
        context = services.order_context(order)
        assert payload["recipients"] == [
            {
                "order_number": order.order_number,
                "grand_total": context["grand_total"],
                "mobiles": order.user.phone[1:],
            }
        ]
        assert notification.sms_variables == {}  # blanked with sms_body once final

    def test_out_for_delivery_otp_is_a_variable_and_never_logged(
        self, msg91, urlopen, run_on_commit, caplog
    ):
        order = OrderFactory()
        order.status = OrderStatus.OUT_FOR_DELIVERY
        with caplog.at_level(logging.DEBUG):
            notification = run_on_commit(
                services.notify_order,
                order,
                "order.out_for_delivery",
                rider_name="Ravi",
                otp="4821",
            )
        recipient = _payload(urlopen.calls[0][0])["recipients"][0]
        assert recipient["otp"] == "4821"
        assert recipient["order_number"] == order.order_number
        assert _payload(urlopen.calls[0][0])["template_id"] == OFD_FLOW
        assert "4821" not in caplog.text
        assert AUTH_KEY not in caplog.text
        notification.refresh_from_db()
        assert notification.sms_variables == {}
        assert notification.sms_body == ""

    def test_variables_are_stored_until_the_send(self, msg91, monkeypatch):
        monkeypatch.setattr(services, "_queue", lambda notification: None)
        order = OrderFactory()
        notification = services.notify_order_event("order.placed", order.pk)
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.PENDING
        assert set(notification.sms_variables) == {"order_number", "grand_total"}

    def test_template_override_variables_follow_the_override_text(
        self, msg91, urlopen, run_on_commit
    ):
        """An admin NotificationTemplate with its own DLT id: its `{{names}}` become the
        variables, and its DLT id selects the flow."""
        NotificationTemplate.objects.create(
            event="order.placed",
            channel=Channel.SMS,
            app="customer",
            body="Jivo order {{order_number}} placed from {{store_name}}.",
            dlt_template_id="1007000000000000999",
        )
        msg91.MSG91_FLOW_IDS = {**msg91.MSG91_FLOW_IDS, "1007000000000000999": "65f0dddd"}
        order = OrderFactory()
        run_on_commit(services.notify_order_event, "order.placed", order.pk)
        payload = _payload(urlopen.calls[0][0])
        assert payload["template_id"] == "65f0dddd"
        recipient = payload["recipients"][0]
        assert recipient["order_number"] == order.order_number
        assert recipient["store_name"] == order.store.name
        assert "grand_total" not in recipient

    def test_event_without_a_flow_fails_without_calling_msg91(
        self, msg91, urlopen, run_on_commit, caplog
    ):
        msg91.MSG91_FLOW_IDS = {OTP_DLT: OTP_FLOW}
        order = OrderFactory()
        notification = run_on_commit(services.notify_order_event, "order.placed", order.pk)
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.FAILED
        assert urlopen.calls == []
        assert "ImproperlyConfigured" in caplog.text

    def test_type_error_marks_the_sms_failed_not_retried(self, msg91, urlopen, run_on_commit):
        urlopen.state["outcome"] = {"type": "error", "message": "DLT mismatch"}
        order = OrderFactory()
        notification = run_on_commit(services.notify_order_event, "order.placed", order.pk)
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.FAILED
        assert len(urlopen.calls) == 1

    def test_transient_error_puts_the_sms_back_to_pending(self, msg91, urlopen, monkeypatch):
        monkeypatch.setattr(services, "_queue", lambda notification: None)
        urlopen.state["outcome"] = _http_error(503, b"")
        order = OrderFactory()
        notification = services.notify_order_event("order.placed", order.pk)
        with pytest.raises(sms.SmsError):
            services.deliver_sms(notification.pk)
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.PENDING
        assert notification.sms_variables  # kept for the retry
        urlopen.state["outcome"] = {"type": "success", "message": REQUEST_ID}
        assert services.deliver_sms(notification.pk) == "sent"

    def test_a_legacy_row_without_variables_fails_loudly_and_sends_nothing(
        self, msg91, urlopen, monkeypatch, caplog
    ):
        """Review of T-815: a PENDING SMS created before migration 0003 (sms_variables = {})
        must never reach a MSG91 flow with blank variables: ImproperlyConfigured -> FAILED, texts
        blanked, zero gateway calls."""
        monkeypatch.setattr(services, "_queue", lambda notification: None)
        order = OrderFactory()
        notification = services.notify_order_event("order.placed", order.pk)
        Notification.objects.filter(pk=notification.pk).update(sms_variables={})
        assert services.deliver_sms(notification.pk) == "failed"
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.FAILED
        assert notification.sms_body == ""
        assert notification.sms_variables == {}
        assert urlopen.calls == []
        assert "ImproperlyConfigured" in caplog.text

    def test_body_backends_still_send_a_row_without_variables(self, monkeypatch):
        """Locmem (like console and Twilio) sends the body, so `variables=None` is fine there."""
        monkeypatch.setattr(services, "_queue", lambda notification: None)
        order = OrderFactory()
        notification = services.notify_order_event("order.placed", order.pk)
        Notification.objects.filter(pk=notification.pk).update(sms_variables={})
        assert services.deliver_sms(notification.pk) == "sent"
        assert sms.outbox[-1].variables is None
        assert order.order_number in sms.outbox[-1].body

    def test_sweeper_blanks_stuck_variables(self, msg91, monkeypatch):
        from datetime import timedelta

        from django.utils import timezone

        monkeypatch.setattr(services, "_queue", lambda notification: None)
        order = OrderFactory()
        notification = services.notify_order_event("order.placed", order.pk)
        Notification.objects.filter(pk=notification.pk).update(sms_status=DeliveryStatus.SENDING)
        services.sweep_stuck_sends(now=timezone.now() + timedelta(hours=1))
        notification.refresh_from_db()
        assert notification.sms_status == DeliveryStatus.FAILED
        assert notification.sms_variables == {}


def test_render_variables_lists_each_placeholder_once():
    variables = services.render_variables(
        "A {{ order_number }} {{grand_total}} {{order_number}} {{missing}}",
        {"order_number": "  JV-1  ", "grand_total": 249},
    )
    assert variables == {"order_number": "JV-1", "grand_total": "249", "missing": ""}


# --------------------------------------------------------------------------- system checks


def _checks(check_id):
    return [e for e in run_checks() if e.id == check_id]


def test_check_ignores_other_backends(settings):
    settings.MSG91_AUTH_KEY = ""
    assert _checks("accounts.E007") == []
    assert _checks("accounts.W001") == []


def test_check_passes_when_configured(msg91):
    assert _checks("accounts.E007") == []


@pytest.mark.parametrize(
    ("change", "expected"),
    [
        ({"MSG91_AUTH_KEY": ""}, "MSG91_AUTH_KEY"),
        ({"SMS_OTP_DLT_TEMPLATE_ID": ""}, "SMS_OTP_DLT_TEMPLATE_ID"),
        ({"MSG91_FLOW_IDS": {PLACED_DLT: PLACED_FLOW}}, "MSG91_FLOW_IDS entry"),
    ],
)
def test_check_requires_the_auth_key_and_the_otp_flow(msg91, change, expected):
    for name, value in change.items():
        setattr(msg91, name, value)
    (error,) = _checks("accounts.E007")
    assert expected in error.msg
    assert AUTH_KEY not in error.msg


def test_check_warns_about_events_without_a_flow(msg91):
    (warning,) = _checks("accounts.W001")
    # test settings map 5 events; the fixture maps order.placed and order.out_for_delivery only
    assert "order.cancelled" in warning.msg
    assert "order.placed" not in warning.msg


def test_msg91_is_a_delivering_backend_in_deployed_environments(msg91):
    msg91.APP_ENVIRONMENT = "production"
    assert sms.MSG91_BACKEND not in sms.NON_DELIVERING_BACKENDS
    assert _checks("accounts.E003") == []


@pytest.mark.django_db
def test_inbox_never_exposes_sms_texts_or_variables(monkeypatch):
    """Review of T-815: `sms_variables` and `sms_body` (they can hold an OTP) are never part of
    the inbox API output."""
    from apps.notifications.serializers import InboxNotificationSerializer

    monkeypatch.setattr(services, "_queue", lambda notification: None)
    order = OrderFactory()
    notification = services.notify_order(
        order, "order.out_for_delivery", rider_name="Ravi", otp="4821"
    )
    notification.refresh_from_db()
    assert notification.sms_variables["otp"] == "4821"  # still pending: stored
    data = InboxNotificationSerializer(notification).data
    assert "sms_variables" not in data
    assert "sms_body" not in data
    assert "4821" not in json.dumps(data, default=str)
