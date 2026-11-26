"""BhashSmsBackend (D-02, the chosen gateway since 2026-11-26): the BhashSMS HTTP API
(sendmsg.php). No internet: `sms._open` is patched everywhere, so no test can reach bhashsms.com
and no real SMS is ever sent.

Covers the request shape (default http GET query, optional POST form: user, pass, sender,
10-digit phone, rendered DLT text, priority/stype, optional DLT template/entity fields), the
answers (message id, HTTP 200 error texts, empty answer), the error classes and how the OTP task
treats them, the DLT OTP template text, the system checks accounts.E008/E009/W002, the
send_test_sms command, and that no password, URL, OTP, text or full phone number reaches the log.
"""

import http.client
import io
import logging
import re
import socket
import urllib.error
import urllib.parse
from datetime import timedelta

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings
from django.utils import timezone

from apps.accounts.models import OTPRequest
from apps.accounts.services import otp as otp_service
from apps.accounts.tasks import send_otp_sms
from apps.notifications import sms
from config.settings import base

URL = "http://bhashsms.com/api/sendmsg.php"  # the endpoint proven with real sends (2026-11-26)
HTTPS_URL = "https://bhashsms.com/api/sendmsg.php"
PHONE = "+919876543210"
MOBILE = "9876543210"
USER = "jivo-test-user"
PASSWORD = "fake-bhashsms-password-not-real"
SENDER = "JIVOJI"
OTP_DLT = "1007000000000000001"  # test settings' SMS_OTP_DLT_TEMPLATE_ID
MESSAGE_ID = "S.583291"
CODE = "482913"
APP_HASH = "FA+9qCX9VSu"
# The approved DLT template (Jio TrueConnect, header JIVOJI, OTP01, id 1207172050323409701), as
# shown in the BhashSMS panel: one variable, the code. No app hash (no SMS Retriever autofill).
DLT_TEMPLATE = (
    "Dear Customer, your OTP for login is {#var#}. Please do not share the OTP with anyone. "
    "Team Jivo."
)
BODY = DLT_TEMPLATE.replace("{#var#}", CODE)
EXPECTED_FIELDS = {
    "user": USER,
    "pass": PASSWORD,
    "sender": SENDER,
    "phone": MOBILE,
    "text": BODY,
    "priority": "ndnd",
    "stype": "normal",
}


@pytest.fixture
def bhash(settings):
    settings.SMS_BACKEND = sms.BHASHSMS_BACKEND
    settings.BHASHSMS_USER = USER
    settings.BHASHSMS_PASSWORD = PASSWORD
    settings.BHASHSMS_API_URL = URL
    settings.BHASHSMS_HTTP_METHOD = "GET"
    settings.BHASHSMS_TEMPLATE_ID_PARAM = ""
    settings.BHASHSMS_ENTITY_ID = ""
    settings.BHASHSMS_ENTITY_ID_PARAM = ""
    settings.SMS_SENDER_ID = SENDER
    settings.SMS_RETRIEVER_APP_HASHES = {"customer": APP_HASH, "rider": ""}
    return settings


class _Response(io.BytesIO):
    status = 200

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


@pytest.fixture
def urlopen(monkeypatch):
    """Records each request; `outcome` is the raw answer to return, or the exception to raise."""
    calls = []
    state = {"outcome": MESSAGE_ID.encode()}

    def fake(request, timeout):
        calls.append((request, timeout))
        outcome = state["outcome"]
        if isinstance(outcome, BaseException):
            raise outcome
        return _Response(outcome)

    monkeypatch.setattr(sms, "_open", fake)
    fake.calls = calls
    fake.state = state
    return fake


def _fields(request) -> dict:
    """The sent fields: the query string of a GET, the form body of a POST."""
    if request.get_method() == "GET":
        raw = urllib.parse.urlsplit(request.full_url).query
    else:
        raw = request.data.decode()
    return dict(urllib.parse.parse_qsl(raw, keep_blank_values=True))


def _send(to=PHONE, body=BODY, dlt=OTP_DLT):
    return sms.send_sms(to, body, dlt, {"otp": CODE, "app_hash": APP_HASH})


def _http_error(status: int, raw: bytes = b"") -> urllib.error.HTTPError:
    return urllib.error.HTTPError(URL, status, "error", {}, io.BytesIO(raw))


def _assert_no_secrets(text: str):
    assert PASSWORD not in text
    assert CODE not in text
    assert PHONE not in text
    assert MOBILE not in text
    assert "your OTP for login" not in text
    assert "pass=" not in text  # the GET URL (it holds the password) is never logged
    assert "bhashsms.com" not in text


# --------------------------------------------------------------------------- the request


def test_success_sends_a_get_to_the_proven_endpoint(bhash, urlopen, caplog):
    """Default: GET http://bhashsms.com/api/sendmsg.php with login, sender, 10-digit phone, the
    rendered DLT text verbatim, priority=ndnd (transactional route), stype=normal. Returns
    BhashSMS's message id; the URL (it holds the password) never reaches the log."""
    with caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"):
        assert _send() == MESSAGE_ID
    ((request, timeout),) = urlopen.calls
    assert request.get_method() == "GET"
    assert request.data is None
    assert request.full_url.split("?")[0] == URL
    assert _fields(request) == EXPECTED_FIELDS
    assert 0 < timeout <= 10
    assert MESSAGE_ID in caplog.text
    assert "+91******3210" in caplog.text
    _assert_no_secrets(caplog.text)


def test_post_over_https_when_configured(bhash, urlopen):
    """BHASHSMS_HTTP_METHOD=POST (+ an https URL) keeps the password out of the URL."""
    bhash.BHASHSMS_API_URL = HTTPS_URL
    bhash.BHASHSMS_HTTP_METHOD = "post"
    assert _send() == MESSAGE_ID
    ((request, _),) = urlopen.calls
    assert request.get_method() == "POST"
    assert request.full_url == HTTPS_URL
    assert request.get_header("Content-type") == "application/x-www-form-urlencoded"
    assert _fields(request) == EXPECTED_FIELDS


def test_blank_method_means_get(bhash, urlopen):
    bhash.BHASHSMS_HTTP_METHOD = ""
    _send()
    assert urlopen.calls[0][0].get_method() == "GET"


def test_dlt_template_and_entity_fields_are_sent_when_configured(bhash, urlopen):
    bhash.BHASHSMS_TEMPLATE_ID_PARAM = "tempid"
    bhash.BHASHSMS_ENTITY_ID_PARAM = "entityid"
    bhash.BHASHSMS_ENTITY_ID = "1201000000000000001"
    _send()
    fields = _fields(urlopen.calls[0][0])
    assert fields["tempid"] == OTP_DLT
    assert fields["entityid"] == "1201000000000000001"


def test_entity_param_without_an_entity_id_is_not_sent(bhash, urlopen):
    bhash.BHASHSMS_ENTITY_ID_PARAM = "entityid"
    _send()
    assert "entityid" not in _fields(urlopen.calls[0][0])


def test_default_url_when_the_setting_is_blank(bhash, urlopen):
    bhash.BHASHSMS_API_URL = ""
    _send()
    assert urlopen.calls[0][0].full_url.split("?")[0] == sms.BHASHSMS_DEFAULT_API_URL == URL


@pytest.mark.parametrize(
    "phone",
    ["+14155550100", "9876543210", "+91987654321", "+915876543210", "", "+91 9876543210"],
)
def test_only_indian_mobile_numbers_are_sent(bhash, urlopen, phone):
    with pytest.raises(sms.SmsRejected):
        _send(to=phone)
    assert urlopen.calls == []


@pytest.mark.parametrize(
    ("change", "message"),
    [
        ({"BHASHSMS_USER": ""}, "BHASHSMS_USER"),
        ({"BHASHSMS_PASSWORD": ""}, "BHASHSMS_PASSWORD"),
        ({"SMS_SENDER_ID": ""}, "SMS_SENDER_ID"),
        ({"BHASHSMS_API_URL": "ftp://bhashsms.com/api/sendmsg.php"}, "http"),
        ({"BHASHSMS_API_URL": URL + "?user=x"}, "query"),
        ({"BHASHSMS_HTTP_METHOD": "PUT"}, "GET or POST"),
    ],
)
def test_misconfiguration_sends_nothing(bhash, urlopen, change, message):
    for name, value in change.items():
        setattr(bhash, name, value)
    with pytest.raises(ImproperlyConfigured, match=message) as exc_info:
        _send()
    assert urlopen.calls == []
    _assert_no_secrets(str(exc_info.value))


# --------------------------------------------------------------------------- the answers


@pytest.mark.parametrize(
    ("answer", "message_id"),
    [
        (b"S.876282", "S.876282"),
        (b"S.876282\n", "S.876282"),
        (b"S.876282 extra words", "S.876282"),
        (b"S.", "S.?"),
    ],
)
def test_any_answer_starting_with_s_dot_is_accepted(bhash, urlopen, answer, message_id):
    urlopen.state["outcome"] = answer
    assert _send() == message_id


@pytest.mark.parametrize(
    ("answer", "kind"),
    [
        (b"<br>Username/Password Incorrect or Account Deactivated  ", "auth"),
        (b"Sender ID Does not Exist", "sender"),
        (b"Insufficient Credits", "credits"),
        (b"DLT Template not matched", "dlt"),
        (b"Invalid Number 9876543210", "number"),
        (b"Something else went wrong", "other"),
    ],
)
def test_error_text_on_http_200_is_rejected(bhash, urlopen, caplog, answer, kind):
    """BhashSMS reports errors as free text on HTTP 200 (seen live: "<br>Username/Password
    Incorrect or Account Deactivated"). Logged as a fixed label plus the text with digits and
    credentials redacted; the exception carries only the label."""
    urlopen.state["outcome"] = answer
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected, match=kind) as exc_info,
    ):
        _send()
    assert f"error {kind}" in caplog.text
    assert "Incorrect" not in str(exc_info.value)
    _assert_no_secrets(caplog.text)
    _assert_no_secrets(str(exc_info.value))


def test_error_text_is_redacted_and_shortened(bhash, urlopen, caplog):
    urlopen.state["outcome"] = (
        f"Error for {USER} / {PASSWORD}: {MOBILE} code {CODE} ".encode() + b"x" * 200
    )
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsRejected),
    ):
        _send()
    assert "Error for *** / ***: # code #" in caplog.text
    assert USER not in caplog.text
    assert "x" * 81 not in caplog.text
    _assert_no_secrets(caplog.text)


def test_empty_answer_is_outcome_unknown(bhash, urlopen):
    urlopen.state["outcome"] = b"  <br> "
    with pytest.raises(sms.SmsOutcomeUnknown):
        _send()


@pytest.mark.parametrize("status", [429, 500, 503])
def test_429_and_5xx_are_retried(bhash, urlopen, caplog, status):
    urlopen.state["outcome"] = _http_error(status, b"busy")
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsError),
    ):
        _send()
    assert f"HTTP {status}" in caplog.text
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize("status", [301, 400, 403, 404])
def test_other_http_errors_are_rejected(bhash, urlopen, status):
    urlopen.state["outcome"] = _http_error(status)
    with pytest.raises(sms.SmsRejected):
        _send()


def test_connect_failure_is_retried(bhash, urlopen, caplog):
    urlopen.state["outcome"] = urllib.error.URLError(socket.gaierror("no dns"))
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsError, match="gaierror"),
    ):
        _send()
    _assert_no_secrets(caplog.text)


@pytest.mark.parametrize(
    "error",
    [TimeoutError("read timed out"), ConnectionResetError(), http.client.IncompleteRead(b"")],
)
def test_lost_answer_after_sending_is_not_retried(bhash, urlopen, caplog, error):
    """BhashSMS may already have sent the SMS and has no idempotency key: no retry."""
    urlopen.state["outcome"] = error
    with (
        caplog.at_level(logging.DEBUG, logger="apps.notifications.sms"),
        pytest.raises(sms.SmsOutcomeUnknown),
    ):
        _send()
    assert "outcome unknown" in caplog.text
    _assert_no_secrets(caplog.text)


# --------------------------------------------------------------------------- the OTP task


def _otp_request(phone=PHONE):
    return OTPRequest.objects.create(
        phone=phone,
        app="customer",
        code_hash="x",
        expires_at=timezone.now() + timedelta(minutes=5),
    )


@pytest.mark.django_db
def test_otp_task_sends_the_rendered_dlt_text(bhash, urlopen):
    request = _otp_request()
    assert send_otp_sms(request.pk, CODE) == "sent"
    assert _fields(urlopen.calls[0][0])["text"] == BODY
    request.refresh_from_db()
    assert request.sms_sent_at is not None


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("outcome", "result"),
    [
        (b"Username/Password Incorrect", "rejected"),
        (TimeoutError("read timed out"), "unknown"),
    ],
)
def test_otp_task_does_not_retry_rejected_or_unknown(bhash, urlopen, outcome, result):
    urlopen.state["outcome"] = outcome
    request = _otp_request()
    assert send_otp_sms(request.pk, CODE) == result
    request.refresh_from_db()
    assert request.sms_sent_at is None


@pytest.mark.django_db
def test_otp_task_retries_a_transient_failure(bhash, urlopen):
    urlopen.state["outcome"] = _http_error(503)
    request = _otp_request()
    with pytest.raises(sms.SmsError):
        send_otp_sms.run(request.pk, CODE)


# --------------------------------------------------------------------------- the DLT template


def _matches_dlt_template(text: str) -> bool:
    """TRAI DLT scrubbing: the fixed parts match exactly, each {#var#} holds up to 30 chars."""
    parts = [re.escape(part) for part in DLT_TEMPLATE.split("{#var#}")]
    return re.fullmatch(r"(.{0,30})".join(parts), text) is not None


@pytest.mark.parametrize("app_hash", [APP_HASH, ""])
def test_default_otp_template_is_the_approved_dlt_template(app_hash):
    """The default OTP template (base settings, not only test settings) renders the approved
    OTP01 text exactly: one space before "Team Jivo." (no newline), and no app hash whatever
    SMS_RETRIEVER_APP_HASHES holds, so SMS Retriever autofill does not apply."""
    with override_settings(
        SMS_OTP_TEMPLATE=base.SMS_OTP_DEFAULT_TEMPLATE,
        SMS_RETRIEVER_APP_HASHES={"customer": app_hash},
    ):
        text = otp_service.render_otp_sms(CODE, "customer")
    assert text == BODY
    assert "\n" not in text
    assert _matches_dlt_template(text)


def test_otp_template_is_env_overridable(settings):
    settings.SMS_OTP_TEMPLATE = "Your Jivo OTP is {otp}. {app_hash}"
    settings.SMS_RETRIEVER_APP_HASHES = {"customer": APP_HASH}
    assert otp_service.render_otp_sms(CODE, "customer") == f"Your Jivo OTP is {CODE}. {APP_HASH}"


def test_msg91_backup_still_gets_otp_and_app_hash_variables(settings):
    """The MSG91 flow keeps its ##otp## / ##app_hash## variables with the new default text."""
    settings.SMS_RETRIEVER_APP_HASHES = {"customer": APP_HASH}
    assert otp_service.otp_sms_variables(CODE, "customer") == {"otp": CODE, "app_hash": APP_HASH}


# --------------------------------------------------------------------------- system checks


def _checks(check_id):
    return [e for e in run_checks() if e.id == check_id]


def test_check_ignores_other_backends(settings):
    settings.BHASHSMS_USER = ""
    settings.BHASHSMS_API_URL = "ftp://nowhere"
    settings.BHASHSMS_HTTP_METHOD = "PUT"
    assert _checks("accounts.E008") == []
    assert _checks("accounts.E009") == []


def test_check_passes_when_configured(bhash):
    assert _checks("accounts.E008") == []
    assert _checks("accounts.E009") == []
    assert _checks("accounts.W002") == []  # plain http is fine outside production


@pytest.mark.parametrize(
    "name", ["BHASHSMS_USER", "BHASHSMS_PASSWORD", "SMS_SENDER_ID", "SMS_OTP_DLT_TEMPLATE_ID"]
)
def test_check_requires_login_sender_and_otp_template(bhash, name):
    setattr(bhash, name, "")
    (error,) = _checks("accounts.E008")
    assert name in error.msg
    assert PASSWORD not in error.msg


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("BHASHSMS_API_URL", "ftp://bhashsms.com/api/sendmsg.php"),
        ("BHASHSMS_API_URL", URL + "?user=x"),
        ("BHASHSMS_HTTP_METHOD", "PUT"),
    ],
)
def test_check_refuses_a_bad_url_or_method(bhash, name, value):
    setattr(bhash, name, value)
    (error,) = _checks("accounts.E009")
    assert name in error.msg


def test_check_warns_about_plain_http_in_production(bhash):
    bhash.APP_ENVIRONMENT = "production"
    (warning,) = _checks("accounts.W002")
    assert "http" in warning.msg
    bhash.BHASHSMS_API_URL = HTTPS_URL
    assert _checks("accounts.W002") == []


def test_bhashsms_is_a_delivering_backend_in_deployed_environments(bhash):
    bhash.APP_ENVIRONMENT = "production"
    assert sms.BHASHSMS_BACKEND not in sms.NON_DELIVERING_BACKENDS
    assert _checks("accounts.E003") == []


def test_msg91_backend_stays_available(settings):
    """MSG91 is kept as the backup: switching back is only the SMS_BACKEND setting."""
    settings.SMS_BACKEND = sms.MSG91_BACKEND
    assert isinstance(sms.get_backend(), sms.Msg91SmsBackend)


# --------------------------------------------------------------------------- send_test_sms


@pytest.mark.parametrize("to", ["9876543210", "+919876543210", "919876543210", "98765-43210"])
def test_send_test_sms_sends_one_otp_format_sms(bhash, urlopen, to):
    out = io.StringIO()
    call_command("send_test_sms", "--to", to, stdout=out)
    ((request, _),) = urlopen.calls
    fields = _fields(request)
    assert fields["phone"] == MOBILE
    assert _matches_dlt_template(fields["text"])
    assert fields["text"].startswith("Dear Customer, your OTP for login is ")
    output = out.getvalue()
    assert MESSAGE_ID in output
    assert "+91******3210" in output
    assert PASSWORD not in output
    assert MOBILE not in output
    assert fields["text"] not in output


@pytest.mark.django_db
def test_send_test_sms_stores_no_otp(bhash, urlopen):
    call_command("send_test_sms", "--to", MOBILE, stdout=io.StringIO())
    assert not OTPRequest.objects.exists()


def test_send_test_sms_reports_a_gateway_error(bhash, urlopen):
    urlopen.state["outcome"] = b"<br>Username/Password Incorrect or Account Deactivated"
    with pytest.raises(CommandError, match=r"SmsRejected.*auth") as exc_info:
        call_command("send_test_sms", "--to", MOBILE, stdout=io.StringIO())
    assert PASSWORD not in str(exc_info.value)


def test_send_test_sms_reports_missing_settings(bhash, urlopen):
    bhash.BHASHSMS_PASSWORD = ""
    with pytest.raises(CommandError, match="ImproperlyConfigured"):
        call_command("send_test_sms", "--to", MOBILE, stdout=io.StringIO())
    assert urlopen.calls == []


@pytest.mark.parametrize("to", ["12345", "+14155550100", "5876543210"])
def test_send_test_sms_refuses_bad_numbers(bhash, urlopen, to):
    with pytest.raises(CommandError, match="Indian mobile"):
        call_command("send_test_sms", "--to", to, stdout=io.StringIO())
    assert urlopen.calls == []


def test_send_test_sms_refused_in_production_without_force(bhash, urlopen):
    bhash.APP_ENVIRONMENT = "production"
    with pytest.raises(CommandError, match="production"):
        call_command("send_test_sms", "--to", MOBILE, stdout=io.StringIO())
    assert urlopen.calls == []
    call_command("send_test_sms", "--to", MOBILE, "--force", stdout=io.StringIO())
    assert len(urlopen.calls) == 1
