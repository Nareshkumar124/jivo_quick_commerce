"""FCM HTTP v1 push backend (D-19): message format (06 §4.3), OAuth2 token caching and refresh,
error handling (unregistered tokens, retryable errors, 401), the key-file system check and
`send_test_push`. HTTP is always faked: tests never reach Google."""

import json
import threading
from datetime import UTC, datetime, timedelta
from io import StringIO

import pytest
from django.core.management import CommandError, call_command
from django.utils import timezone

from apps.accounts.models import Device
from apps.accounts.tests.factories import UserFactory
from apps.notifications import checks, push, services
from apps.notifications.choices import DeliveryStatus
from apps.orders.tests.factories import OrderFactory

FCM = "apps.notifications.push.FcmPushBackend"
SEND_URL = "https://fcm.googleapis.com/v1/projects/jqc-test/messages:send"


# --------------------------------------------------------------------------- fakes


class FakeResponse:
    def __init__(self, status: int, payload=None):
        self.status = status
        if not isinstance(payload, bytes):
            payload = json.dumps(payload or {}).encode()
        self.data = payload
        self.headers = {"content-type": "application/json"}


def fcm_error(status: int, code: str, message: str = "", field: str | None = None) -> FakeResponse:
    details = [{"@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError", "errorCode": code}]
    if field:
        details.append(
            {
                "@type": "type.googleapis.com/google.rpc.BadRequest",
                "fieldViolations": [{"field": field, "description": "bad"}],
            }
        )
    return FakeResponse(
        status, {"error": {"code": status, "message": message, "status": code, "details": details}}
    )


class FakeHttp:
    """Answers each FCM send from `answer(token, call_number)`; token-endpoint calls (real
    google-auth refreshes) get a fresh access token."""

    def __init__(self, answer=None):
        self.answer = answer or (lambda token, n: FakeResponse(200, {"name": "projects/x/m/1"}))
        self.sends: list[dict] = []
        self.token_calls = 0
        self.token_kwargs: list[dict] = []
        self._lock = threading.Lock()

    def request(self, method, url, body=None, headers=None, **kwargs):
        with self._lock:
            if "oauth2" in url or "token" in url.rsplit("/", 1)[-1]:
                self.token_calls += 1
                self.token_kwargs.append(kwargs)
                return FakeResponse(
                    200, {"access_token": f"real-{self.token_calls}", "expires_in": 3600}
                )
            payload = json.loads(body)
            self.sends.append({"url": url, "headers": headers, "body": payload})
            return self.answer(payload["message"]["token"], len(self.sends))


class FakeCredentials:
    """Stands in for google.oauth2 service-account credentials (counts refreshes)."""

    refreshes = 0

    def __init__(self):
        self.token = None
        self.expiry = None

    def refresh(self, request):
        FakeCredentials.refreshes += 1
        self.token = f"access-{FakeCredentials.refreshes}"
        self.expiry = datetime.now(UTC).replace(tzinfo=None) + timedelta(hours=1)


def without(key: str) -> str:
    return json.dumps({k: v for k, v in SERVICE_ACCOUNT.items() if k != key})


SERVICE_ACCOUNT = {
    "type": "service_account",
    "project_id": "jqc-test",
    "private_key_id": "test",
    "private_key": "-----BEGIN PRIVATE KEY-----\nNOT-A-REAL-KEY\n-----END PRIVATE KEY-----\n",
    "client_email": "push@jqc-test.iam.gserviceaccount.com",
    "token_uri": "https://oauth2.googleapis.com/token",
}


@pytest.fixture
def key_file(tmp_path):
    path = tmp_path / "service-account.json"
    path.write_text(json.dumps(SERVICE_ACCOUNT), encoding="utf-8")
    return path


@pytest.fixture
def fcm(settings, key_file, monkeypatch):
    """FCM backend with a fake key file and fake credentials; returns the fake HTTP client."""
    settings.PUSH_BACKEND = FCM
    settings.FCM_CREDENTIALS_FILE = str(key_file)
    settings.FCM_PROJECT_ID = ""
    push.reset_fcm_state()
    FakeCredentials.refreshes = 0
    from google.oauth2 import service_account

    monkeypatch.setattr(
        service_account.Credentials,
        "from_service_account_file",
        classmethod(lambda cls, *a, **k: FakeCredentials()),
    )
    http = FakeHttp()
    monkeypatch.setattr(push, "_shared_http", lambda: http)
    yield http
    push.reset_fcm_state()


def message(**overrides) -> push.PushMessage:
    values = {
        "tokens": ("token-aaaaaaaaaaaa-1",),
        "title": "Order confirmed",
        "body": "The store has confirmed order JQ-1.",
        "data": {"type": "order", "order_id": "12"},
        "event": "order.accepted",
        "app": "customer",
        "category": "order",
        "collapse_key": "jqc-n1",
    }
    values.update(overrides)
    return push.PushMessage(**values)


def device(user, token, app="customer") -> Device:
    return Device.objects.create(
        user=user,
        app=app,
        platform="android",
        fcm_token=token,
        app_version="1.0.0",
        last_seen_at=timezone.now(),
    )


# --------------------------------------------------------------------------- message format


def test_customer_order_event_is_a_notification_on_the_orders_channel():
    """06 §4.3: notification + data, channel `orders`, high priority, one-hour TTL."""
    body = push.build_fcm_message(message(), "tok", now=1000)["message"]
    assert body["token"] == "tok"
    assert body["notification"] == {
        "title": "Order confirmed",
        "body": "The store has confirmed order JQ-1.",
    }
    assert body["data"] == {"type": "order", "order_id": "12"}
    assert body["android"] == {
        "priority": "HIGH",
        "ttl": "3600s",
        "collapse_key": "jqc-n1",
        "notification": {"channel_id": "orders", "visibility": "PRIVATE", "tag": "jqc-n1"},
    }
    assert body["apns"] == {
        "headers": {
            "apns-expiration": "4600",
            "apns-priority": "10",
            "apns-push-type": "alert",
            "apns-collapse-id": "jqc-n1",
        },
        "payload": {"aps": {"sound": "default"}},
    }


def test_ios_alert_never_shows_the_delivery_otp():
    """Code review: iOS has no PRIVATE visibility, so the APNs alert of out-for-delivery is
    generic; Android keeps the full text (PRIVATE on the lock screen)."""
    otp_message = message(
        event="order.out_for_delivery",
        title="Your order is on the way",
        body="Asha has picked up order JQ-1. Share OTP 4321 with the rider only at delivery.",
    )
    body = push.build_fcm_message(otp_message, "tok")["message"]
    alert = body["apns"]["payload"]["aps"]["alert"]
    assert alert == {
        "title": "Your order is on the way",
        "body": "Your order is out for delivery. Your delivery OTP is in the app.",
    }
    assert "4321" not in json.dumps(body["apns"])
    assert "4321" in body["notification"]["body"]
    assert body["android"]["notification"]["visibility"] == "PRIVATE"
    other = push.build_fcm_message(message(), "tok")["message"]
    assert other["apns"]["payload"] == {"aps": {"sound": "default"}}


def test_every_data_value_is_a_string():
    data = {"type": "order", "order_id": 12, "flag": True, "none": None}
    body = push.build_fcm_message(message(data=data), "tok")["message"]
    assert body["data"] == {"type": "order", "order_id": "12", "flag": "True", "none": ""}
    assert all(isinstance(value, str) for value in body["data"].values())


@pytest.mark.parametrize("kind", ["offer.new", "offer.expired", "offer.withdrawn"])
def test_rider_offers_are_data_only_high_priority_with_the_offer_ttl(settings, kind):
    """PM 2026-11-17: the rider app's background handler rings (or dismisses) its full-screen
    offer alarm from a data-only message; a notification part would bypass it."""
    settings.OFFER_TIMEOUT_SECONDS = 30
    offer = message(
        app="rider",
        event="rider.offer_new",
        category="order",
        title="New order offer",
        body="Pickup at Store, 1.2 km.",
        data={"type": kind, "offer_id": 9001, "task_id": 7001},
    )
    body = push.build_fcm_message(offer, "tok", now=1000)["message"]
    assert "notification" not in body
    assert body["data"] == {"type": kind, "offer_id": "9001", "task_id": "7001"}
    assert body["android"] == {"priority": "HIGH", "ttl": "30s"}
    assert body["apns"]["headers"]["apns-expiration"] == "1030"
    assert body["apns"]["payload"] == {"aps": {"content-available": 1}}


@pytest.mark.parametrize(
    ("app", "category", "kind", "channel", "priority", "ttl", "private"),
    [
        ("customer", "support", "ticket", "orders", "HIGH", "86400s", False),
        ("customer", "promo", "referral", "general", "NORMAL", "86400s", False),
        ("customer", "system", "", "general", "NORMAL", "86400s", False),
        ("rider", "order", "task.updated", "orders", "HIGH", "3600s", True),
        ("rider", "order", "cash.updated", "general", "NORMAL", "86400s", True),
        ("rider", "support", "ticket", "general", "NORMAL", "86400s", False),
    ],
)
def test_channel_priority_ttl_and_visibility_per_event(
    app, category, kind, channel, priority, ttl, private
):
    """PM 2026-11-17: texts with order numbers or amounts (order, task, cash) are PRIVATE on the
    lock screen."""
    data = {"type": kind} if kind else {"link": "jivo://account"}
    body = push.build_fcm_message(
        message(app=app, category=category, data=data, collapse_key=""), "tok"
    )["message"]
    assert "notification" in body
    expected = {"channel_id": channel}
    if private:
        expected["visibility"] = "PRIVATE"
    assert body["android"] == {"priority": priority, "ttl": ttl, "notification": expected}


def test_offer_new_carries_expires_at_as_iso_utc():
    """PM 2026-11-17: `expires_at` lets the rider app skip ringing for a late push."""
    from datetime import datetime as dt

    from apps.notifications.catalog import SPECS

    expires = dt(2026, 11, 17, 6, 30, 5, tzinfo=UTC)
    context = {"offer_id": 9001, "task_id": 7001, "expires_at": expires}
    payload = services.fcm_payload("rider", services.push_data(SPECS["rider.offer_new"], context))
    assert payload == {
        "type": "offer.new",
        "offer_id": "9001",
        "task_id": "7001",
        "expires_at": "2026-11-17T06:30:05Z",
    }
    ist = expires.astimezone(timezone.get_fixed_timezone(330))
    assert services.fcm_value(ist) == "2026-11-17T06:30:05Z"
    assert services.fcm_value(expires.replace(tzinfo=None)) == "2026-11-17T06:30:05Z"


# --------------------------------------------------------------------------- sending


def test_send_posts_one_request_per_token_with_the_bearer_token(fcm):
    result = push.get_backend().send(message(tokens=("token-a-123456", "token-b-123456")))
    assert result == push.PushResult(sent=2)
    assert [send["url"] for send in fcm.sends] == [SEND_URL, SEND_URL]
    assert fcm.sends[0]["headers"]["Authorization"] == "Bearer access-1"
    assert [send["body"]["message"]["token"] for send in fcm.sends] == [
        "token-a-123456",
        "token-b-123456",
    ]


def test_project_id_setting_overrides_the_key(fcm, settings):
    settings.FCM_PROJECT_ID = "other-project"
    push.get_backend().send(message())
    assert fcm.sends[0]["url"] == SEND_URL.replace("jqc-test", "other-project")


def test_access_token_is_cached_until_shortly_before_expiry(fcm):
    backend = push.get_backend()
    backend.send(message())
    push.get_backend().send(message())  # a new backend instance reuses the cached token
    assert FakeCredentials.refreshes == 1
    source = push.token_source(backend.credentials_file, fcm)
    source._credentials.expiry = datetime.now(UTC).replace(tzinfo=None) + timedelta(minutes=4)
    push.get_backend().send(message())
    assert FakeCredentials.refreshes == 2
    assert fcm.sends[-1]["headers"]["Authorization"] == "Bearer access-2"


def test_token_refresh_is_thread_safe(fcm):
    """The Celery threads pool: many sends at once still refresh the token once."""
    errors = []

    def run():
        try:
            push.get_backend().send(message())
        except Exception as exc:  # pragma: no cover - reported below
            errors.append(exc)

    threads = [threading.Thread(target=run) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert not errors
    assert FakeCredentials.refreshes == 1
    assert len(fcm.sends) == 8


def test_401_refreshes_the_token_once_and_resends(fcm):
    fcm.answer = lambda token, n: FakeResponse(401) if n == 1 else FakeResponse(200)
    result = push.get_backend().send(message())
    assert result.sent == 1
    assert FakeCredentials.refreshes == 2
    assert [s["headers"]["Authorization"] for s in fcm.sends] == [
        "Bearer access-1",
        "Bearer access-2",
    ]


def test_persistent_401_is_retryable_after_one_refresh(fcm):
    fcm.answer = lambda token, n: FakeResponse(401)
    with pytest.raises(push.PushError):
        push.get_backend().send(message(tokens=("token-a-123456", "token-b-123456")))
    assert FakeCredentials.refreshes == 2  # refreshed once, not once per device


@pytest.mark.parametrize(
    "response",
    [
        fcm_error(404, "UNREGISTERED", "Requested entity was not found."),
        fcm_error(403, "SENDER_ID_MISMATCH", "SenderId mismatch"),
        fcm_error(400, "INVALID_ARGUMENT", "Invalid registration token", field="message.token"),
        fcm_error(400, "INVALID_ARGUMENT", "The registration token is not a valid FCM token"),
    ],
)
def test_unregistered_or_invalid_tokens_are_reported(fcm, response):
    fcm.answer = lambda token, n: response if token == "token-bad-123456" else FakeResponse(200)
    result = push.get_backend().send(message(tokens=("token-bad-123456", "token-ok-1234567")))
    assert result == push.PushResult(sent=1, invalid_tokens=("token-bad-123456",))


def test_only_invalid_tokens_is_not_an_error(fcm):
    fcm.answer = lambda token, n: fcm_error(404, "UNREGISTERED")
    result = push.get_backend().send(message())
    assert result == push.PushResult(sent=0, invalid_tokens=("token-aaaaaaaaaaaa-1",))


def test_a_bare_404_wrong_project_never_deactivates_devices(fcm):
    not_found = {"error": {"code": 404, "message": "Not found", "status": "NOT_FOUND"}}
    fcm.answer = lambda token, n: FakeResponse(404, not_found)
    with pytest.raises(push.PushRejected) as raised:
        push.get_backend().send(message())
    assert raised.value.invalid_tokens == ()


def test_a_bad_payload_is_rejected_without_blaming_the_token(fcm):
    fcm.answer = lambda token, n: fcm_error(400, "INVALID_ARGUMENT", "Invalid data payload")
    with pytest.raises(push.PushRejected) as raised:
        push.get_backend().send(message())
    assert raised.value.invalid_tokens == ()


@pytest.mark.parametrize(
    "response",
    [
        fcm_error(429, "QUOTA_EXCEEDED"),
        fcm_error(503, "UNAVAILABLE"),
        fcm_error(500, "INTERNAL"),
        FakeResponse(502, b"<html>Bad gateway</html>"),
    ],
)
def test_quota_and_server_errors_are_retryable(fcm, response):
    fcm.answer = lambda token, n: response
    with pytest.raises(push.PushError):
        push.get_backend().send(message())


def test_network_errors_are_retryable(fcm):
    import urllib3

    def answer(token, n):
        raise urllib3.exceptions.NewConnectionError(None, "refused")

    fcm.answer = answer
    with pytest.raises(push.PushError):
        push.get_backend().send(message())


def test_partial_success_counts_as_sent_so_no_device_gets_a_duplicate(fcm):
    fcm.answer = lambda token, n: fcm_error(503, "UNAVAILABLE") if n == 2 else FakeResponse(200)
    result = push.get_backend().send(message(tokens=("token-a-123456", "token-b-123456")))
    assert result.sent == 1


def test_retryable_error_still_carries_invalid_tokens(fcm):
    fcm.answer = lambda token, n: (
        fcm_error(404, "UNREGISTERED") if token == "token-bad-123456" else fcm_error(503, "X")
    )
    with pytest.raises(push.PushError) as raised:
        push.get_backend().send(message(tokens=("token-bad-123456", "token-ok-1234567")))
    assert raised.value.invalid_tokens == ("token-bad-123456",)


def test_logs_never_hold_a_full_token_or_the_body(fcm, caplog):
    token = "secret-device-token-0123456789abcdef"
    fcm.answer = lambda t, n: fcm_error(404, "UNREGISTERED")
    with caplog.at_level("DEBUG"):
        push.get_backend().send(message(tokens=(token,), body="Share OTP 4321 with the rider"))
    assert token not in caplog.text
    assert "4321" not in caplog.text
    assert push.mask_token(token) in caplog.text


def test_unreadable_key_file_is_retryable(fcm, settings, tmp_path):
    """Code review: an OSError (a secret mount not there yet) is transient."""
    settings.FCM_CREDENTIALS_FILE = str(tmp_path / "missing.json")
    with pytest.raises(push.PushError, match="unreadable"):
        push.get_backend().send(message())


def test_unreadable_key_file_at_token_load_is_retryable(settings, tmp_path, monkeypatch):
    settings.FCM_CREDENTIALS_FILE = str(tmp_path / "missing.json")
    settings.FCM_PROJECT_ID = "jqc-test"
    push.reset_fcm_state()
    try:
        with pytest.raises(push.PushError, match="FileNotFoundError"):
            push.FcmPushBackend(http=FakeHttp()).send(message())
    finally:
        push.reset_fcm_state()


@pytest.mark.parametrize(
    "content", ["{not json", json.dumps({**SERVICE_ACCOUNT, "private_key": "x"})]
)
def test_invalid_key_content_is_rejected_without_contents(settings, tmp_path, content):
    path = tmp_path / "bad.json"
    path.write_text(content, encoding="utf-8")
    settings.FCM_CREDENTIALS_FILE = str(path)
    settings.FCM_PROJECT_ID = "jqc-test"
    push.reset_fcm_state()
    try:
        with pytest.raises(push.PushRejected, match="invalid") as raised:
            push.FcmPushBackend(http=FakeHttp()).send(message())
    finally:
        push.reset_fcm_state()
    assert "NOT-A-REAL-KEY" not in str(raised.value)


def test_no_key_file_setting_is_rejected(settings):
    settings.FCM_CREDENTIALS_FILE = ""
    with pytest.raises(push.PushRejected):
        push.FcmPushBackend(http=FakeHttp()).send(message())


def test_real_google_auth_refresh_through_the_urllib3_transport(settings, tmp_path, monkeypatch):
    """The real google-auth service-account flow (signed JWT -> token endpoint) over the same
    HTTP client, with a throwaway RSA key; the token endpoint and FCM are faked."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    path = tmp_path / "sa.json"
    path.write_text(json.dumps({**SERVICE_ACCOUNT, "private_key": pem}), encoding="utf-8")
    settings.FCM_CREDENTIALS_FILE = str(path)
    settings.FCM_PROJECT_ID = ""
    push.reset_fcm_state()
    http = FakeHttp()
    monkeypatch.setattr(push, "_shared_http", lambda: http)
    try:
        push.FcmPushBackend().send(message())
        push.FcmPushBackend().send(message())
    finally:
        push.reset_fcm_state()
    assert http.token_calls == 1
    assert [s["headers"]["Authorization"] for s in http.sends] == ["Bearer real-1"] * 2
    # Code review: the refresh runs under the token lock, so it has a short timeout.
    assert http.token_kwargs[0]["timeout"] == push.TOKEN_REFRESH_TIMEOUT_SECONDS <= 10


def test_refresh_request_caps_any_longer_timeout():
    http = FakeHttp()
    request = push._refresh_request(http)
    request("https://oauth2.googleapis.com/token", method="POST", body=b"", timeout=120)
    request("https://oauth2.googleapis.com/token", method="POST", body=b"", timeout=3)
    assert [kwargs["timeout"] for kwargs in http.token_kwargs] == [10.0, 3.0]


def test_refresh_transport_error_is_retryable_and_refusal_is_rejected(fcm, monkeypatch):
    from google.auth import exceptions

    def broken(self, request):
        raise exceptions.TransportError("down")

    monkeypatch.setattr(FakeCredentials, "refresh", broken)
    with pytest.raises(push.PushError):
        push.get_backend().send(message())

    def refused(self, request):
        raise exceptions.RefreshError("invalid_grant: Invalid JWT Signature.")

    monkeypatch.setattr(FakeCredentials, "refresh", refused)
    with pytest.raises(push.PushRejected):
        push.get_backend().send(message())


# --------------------------------------------------------------------------- with the pipeline


@pytest.mark.django_db
def test_deliver_push_deactivates_unregistered_devices(fcm):
    order = OrderFactory()
    stale = device(order.user, "token-stale-123456")
    fresh = device(order.user, "token-fresh-123456")
    fcm.answer = lambda token, n: (
        fcm_error(404, "UNREGISTERED") if token == stale.fcm_token else FakeResponse(200)
    )
    notification = services.notify_order_event("order.accepted", order.pk)
    assert services.deliver_push(notification.pk) == "sent"
    stale.refresh_from_db()
    fresh.refresh_from_db()
    assert not stale.is_active
    assert fresh.is_active
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.SENT
    sent = fcm.sends[0]["body"]["message"]
    assert sent["data"] == {"type": "order", "order_id": str(order.pk)}
    assert sent["android"]["notification"]["channel_id"] == "orders"
    assert sent["android"]["collapse_key"] == f"jqc-n{notification.pk}"


@pytest.mark.django_db
def test_deliver_push_retryable_error_releases_the_claim(fcm):
    order = OrderFactory()
    device(order.user, "token-a-123456")
    fcm.answer = lambda token, n: fcm_error(503, "UNAVAILABLE")
    notification = services.notify_order_event("order.accepted", order.pk)
    with pytest.raises(push.PushError):
        services.deliver_push(notification.pk)
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.PENDING


@pytest.mark.django_db
def test_payload_invalid_argument_never_deactivates_the_device(fcm):
    """Code review nit: INVALID_ARGUMENT about the payload (not the token) is FAILED and the
    device stays active."""
    order = OrderFactory()
    device(order.user, "token-a-123456")
    fcm.answer = lambda token, n: fcm_error(400, "INVALID_ARGUMENT", "Invalid JSON payload")
    notification = services.notify_order_event("order.accepted", order.pk)
    assert services.deliver_push(notification.pk) == "rejected"
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.FAILED
    assert Device.objects.get(fcm_token="token-a-123456").is_active


@pytest.mark.django_db
def test_deliver_push_rejected_is_failed_not_retried(fcm):
    order = OrderFactory()
    device(order.user, "token-a-123456")
    fcm.answer = lambda token, n: fcm_error(403, "PERMISSION_DENIED")
    notification = services.notify_order_event("order.accepted", order.pk)
    assert services.deliver_push(notification.pk) == "rejected"
    notification.refresh_from_db()
    assert notification.push_status == DeliveryStatus.FAILED
    assert notification.push_body == ""
    assert Device.objects.get(fcm_token="token-a-123456").is_active


# --------------------------------------------------------------------------- system check


def run_check():
    return checks.check_fcm_credentials(None)


def test_check_ignores_other_backends(settings):
    settings.PUSH_BACKEND = "apps.notifications.push.DisabledPushBackend"
    settings.FCM_CREDENTIALS_FILE = ""
    assert run_check() == []


def test_check_passes_with_a_valid_key(settings, key_file):
    settings.PUSH_BACKEND = FCM
    settings.FCM_CREDENTIALS_FILE = str(key_file)
    assert run_check() == []


@pytest.mark.parametrize(
    ("content", "expected"),
    [
        (None, "not set"),
        ("missing", "does not exist"),
        ("{not json", "not valid JSON"),
        (json.dumps({**SERVICE_ACCOUNT, "type": "authorized_user"}), "not a service-account"),
        (without("private_key"), "private_key"),
        (without("project_id"), "project id"),
    ],
)
def test_check_errors_without_printing_the_key(settings, tmp_path, content, expected):
    settings.PUSH_BACKEND = FCM
    settings.FCM_PROJECT_ID = ""
    path = tmp_path / "key.json"
    if content is None:
        settings.FCM_CREDENTIALS_FILE = ""
    elif content == "missing":
        settings.FCM_CREDENTIALS_FILE = str(tmp_path / "nope.json")
    else:
        path.write_text(content, encoding="utf-8")
        settings.FCM_CREDENTIALS_FILE = str(path)
    errors = run_check()
    assert [error.id for error in errors] == ["notifications.E002"]
    assert expected in errors[0].msg
    assert "NOT-A-REAL-KEY" not in errors[0].msg + (errors[0].hint or "")


def test_check_accepts_a_project_id_setting(settings, tmp_path):
    path = tmp_path / "key.json"
    info = {k: v for k, v in SERVICE_ACCOUNT.items() if k != "project_id"}
    path.write_text(json.dumps(info), encoding="utf-8")
    settings.PUSH_BACKEND = FCM
    settings.FCM_CREDENTIALS_FILE = str(path)
    settings.FCM_PROJECT_ID = "jqc-test"
    assert run_check() == []


def test_check_reports_an_unreadable_file(settings, tmp_path):
    settings.PUSH_BACKEND = FCM
    settings.FCM_CREDENTIALS_FILE = str(tmp_path)  # a directory: open() fails
    errors = run_check()
    assert [error.id for error in errors] == ["notifications.E002"]


@pytest.mark.parametrize(
    ("environment", "backend", "warned"),
    [
        ("production", "apps.notifications.push.DisabledPushBackend", True),
        ("staging", "apps.notifications.push.DisabledPushBackend", True),
        ("production", FCM, False),
        ("local", "apps.notifications.push.DisabledPushBackend", False),
    ],
)
def test_disabled_push_in_a_deployed_environment_warns(settings, environment, backend, warned):
    """Code review: notifications.W001 (a Warning, so the deploy still starts)."""
    from django.core.checks import WARNING

    settings.APP_ENVIRONMENT = environment
    settings.PUSH_BACKEND = backend
    issues = checks.check_push_disabled(None)
    assert [(i.id, i.level) for i in issues] == (
        [("notifications.W001", WARNING)] if warned else []
    )


def test_w001_is_a_deploy_check():
    from django.core.checks import registry

    assert checks.check_push_disabled in registry.registry.get_checks(
        include_deployment_checks=True
    )
    assert checks.check_push_disabled not in registry.registry.get_checks()


def test_fcm_is_allowed_in_production(settings):
    settings.APP_ENVIRONMENT = "production"
    settings.PUSH_BACKEND = FCM
    assert checks.check_push_backend(None) == []


# --------------------------------------------------------------------------- send_test_push


@pytest.mark.django_db
def test_send_test_push_sends_to_the_users_devices():
    user = UserFactory()
    device(user, "token-cmd-123456")
    out = StringIO()
    call_command("send_test_push", "--user", user.phone, stdout=out)
    assert "Sent to 1 of 1 device(s)" in out.getvalue()
    assert "token-cmd-123456" not in out.getvalue()
    [sent] = push.outbox
    assert sent.title.startswith("[Test] ")
    assert sent.event == "order.accepted"
    assert sent.tokens == ("token-cmd-123456",)


@pytest.mark.django_db
def test_send_test_push_by_id_with_an_order_and_rider_data():
    order = OrderFactory()
    device(order.user, "token-cmd-123456")
    call_command("send_test_push", "--user", str(order.user.pk), "--order-id", str(order.pk))
    assert push.outbox[-1].data == {"type": "order", "order_id": str(order.pk)}

    rider = UserFactory()
    device(rider, "token-rider-123456", app="rider")
    call_command(
        "send_test_push",
        "--user",
        rider.phone,
        "--event",
        "rider.offer_new",
        "--data",
        "offer_id=9001",
        "--data",
        "task_id=7001",
    )
    assert push.outbox[-1].data == {"type": "offer.new", "offer_id": "9001", "task_id": "7001"}


@pytest.mark.django_db
def test_send_test_push_deactivates_unregistered_devices():
    user = UserFactory()
    device(user, "token-gone-123456")
    push.invalid_tokens.add("token-gone-123456")
    out = StringIO()
    call_command("send_test_push", "--user", user.phone, stdout=out)
    assert "1 unregistered device(s) deactivated" in out.getvalue()
    assert not Device.objects.get(fcm_token="token-gone-123456").is_active


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("args", "message_part"),
    [
        (["--event", "nope"], "Unknown event"),
        (["--order-id", "999999"], "No such order"),
        (["--data", "novalue"], "KEY=VALUE"),
    ],
)
def test_send_test_push_validates_its_arguments(args, message_part):
    user = UserFactory()
    device(user, "token-cmd-123456")
    with pytest.raises(CommandError, match=message_part):
        call_command("send_test_push", "--user", user.phone, *args)


@pytest.mark.django_db
def test_send_test_push_needs_a_user_and_a_device():
    with pytest.raises(CommandError, match="No user"):
        call_command("send_test_push", "--user", "+919999999999")
    user = UserFactory()
    with pytest.raises(CommandError, match="no active customer device"):
        call_command("send_test_push", "--user", user.phone)


@pytest.mark.django_db
def test_send_test_push_refuses_production_without_force(settings):
    settings.APP_ENVIRONMENT = "production"
    with pytest.raises(CommandError, match="Refused in production"):
        call_command("send_test_push", "--user", "1")
    user = UserFactory()
    device(user, "token-cmd-123456")
    call_command("send_test_push", "--user", user.phone, "--force", stdout=StringIO())
    assert len(push.outbox) == 1


@pytest.mark.django_db
@pytest.mark.parametrize(
    ("backend", "match"),
    [
        ("apps.notifications.push.DisabledPushBackend", "disabled"),
        ("apps.notifications.push.FcmPushBackend", "PushRejected"),
    ],
)
def test_send_test_push_reports_backend_failures(settings, backend, match):
    settings.PUSH_BACKEND = backend
    settings.FCM_CREDENTIALS_FILE = ""
    user = UserFactory()
    device(user, "token-cmd-123456")
    with pytest.raises(CommandError, match=match):
        call_command("send_test_push", "--user", user.phone, stdout=StringIO())
