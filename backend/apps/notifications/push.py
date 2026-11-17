"""Push behind a small interface, chosen by PUSH_BACKEND (D-19).

- FcmPushBackend (staging, production, and local when FCM_CREDENTIALS_FILE is set): Firebase
  Cloud Messaging HTTP v1, OAuth2 token from the service-account key file. Every environment uses
  this same backend; only the key file (Firebase project) differs.
- DisabledPushBackend (default without a key file): sends nothing; logs the event and the number
  of devices only (never the text, which can hold a delivery OTP). The notification is SKIPPED.
- ConsolePushBackend (local without a key file): logs the title and data (the body is redacted:
  it can hold a delivery OTP).
- LocmemPushBackend (tests): keeps messages in `outbox`. Tests never call a real service.
Deployed environments refuse the console and locmem backends (system check notifications.E001);
the FCM backend needs a readable key file (notifications.E002).

`send()` returns the tokens the service reported as unregistered (their devices are
deactivated), raises `PushError` for a transient failure (the task retries with backoff) and
`PushRejected` when FCM refused the message for good (the notification is FAILED, not retried).
"""

import json
import logging
import threading
import time
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta

import urllib3
from django.conf import settings
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class PushError(Exception):
    """A transient failure; the task retries with backoff. `invalid_tokens` are still
    deactivated."""

    def __init__(self, message: str = "", invalid_tokens: tuple[str, ...] = ()):
        super().__init__(message)
        self.invalid_tokens = invalid_tokens


class PushDisabled(Exception):
    """No push service is configured (D-19): the notification is SKIPPED, not retried."""


class PushRejected(Exception):
    """The push service refused the message for good (bad payload, bad key, no permission): the
    notification is FAILED, not retried. `invalid_tokens` are still deactivated."""

    def __init__(self, message: str = "", invalid_tokens: tuple[str, ...] = ()):
        super().__init__(message)
        self.invalid_tokens = invalid_tokens


@dataclass(frozen=True)
class PushMessage:
    tokens: tuple[str, ...]
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)  # FCM data values are strings
    event: str = ""
    app: str = ""
    category: str = ""  # NotificationCategory: picks the Android channel, priority and TTL
    collapse_key: str = ""  # one per notification: a retried send replaces, never duplicates


@dataclass(frozen=True)
class PushResult:
    sent: int
    invalid_tokens: tuple[str, ...] = ()


class BasePushBackend:
    def send(self, message: PushMessage) -> PushResult:
        raise NotImplementedError


class DisabledPushBackend(BasePushBackend):
    def send(self, message: PushMessage) -> PushResult:
        logger.info(
            "Push disabled (PUSH_BACKEND, D-19): event %s to %s device(s) not sent",
            message.event,
            len(message.tokens),
        )
        raise PushDisabled("No push service is configured (D-19).")


class ConsolePushBackend(BasePushBackend):
    def send(self, message: PushMessage) -> PushResult:
        # The body is never logged: it can hold a delivery OTP (code review of f08c329).
        logger.warning(
            "PUSH (console backend) [%s, %s device(s)] %s: <body redacted, %s chars> %s",
            message.event,
            len(message.tokens),
            message.title,
            len(message.body),
            message.data,
        )
        return PushResult(sent=len(message.tokens))


outbox: list[PushMessage] = []
# Tests put tokens here to simulate FCM "unregistered" answers.
invalid_tokens: set[str] = set()


class LocmemPushBackend(BasePushBackend):
    def send(self, message: PushMessage) -> PushResult:
        outbox.append(message)
        bad = tuple(token for token in message.tokens if token in invalid_tokens)
        return PushResult(sent=len(message.tokens) - len(bad), invalid_tokens=bad)


def get_backend() -> BasePushBackend:
    return import_string(settings.PUSH_BACKEND)()


# =========================================================================== FCM HTTP v1

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_SEND_URL = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
# Refresh the cached OAuth2 access token this long before it expires (tokens live 1 hour).
TOKEN_REFRESH_MARGIN = timedelta(minutes=5)
HTTP_TIMEOUT = urllib3.Timeout(connect=5.0, read=10.0)
# The token refresh runs under the token lock: never wait longer than this (google-auth's own
# default is 120 s, which would stall every sending thread).
TOKEN_REFRESH_TIMEOUT_SECONDS = 10.0

# Android notification channels (06 §4.3), created by the apps at start-up; an unknown channel
# id falls back to the app's default FCM channel.
CHANNEL_ORDERS = "orders"  # customer order events + support replies; rider task events
CHANNEL_GENERAL = "general"  # everything else (promos, referral, cash, rider support, system)
ORDER_TTL_SECONDS = 60 * 60  # an order update older than an hour is stale (the app re-reads)
GENERAL_TTL_SECONDS = 24 * 60 * 60
CUSTOMER_APP = "customer"
RIDER_APP = "rider"
ORDER_CATEGORY = "order"
SUPPORT_CATEGORY = "support"
RIDER_TASK_TYPES = frozenset({"task.updated"})
RIDER_PRIVATE_TYPES = frozenset({"task.updated", "cash.updated"})
# Generic iOS alert texts for events whose text holds a secret (code review, 2026-11-17).
APNS_LOCK_SCREEN_BODIES = {
    "order.out_for_delivery": "Your order is out for delivery. Your delivery OTP is in the app.",
}


@dataclass(frozen=True)
class FcmOptions:
    data_only: bool
    channel_id: str
    high_priority: bool
    ttl_seconds: int
    private: bool = False  # lock screen hides the text (order numbers, amounts, OTP)


def fcm_options(message: PushMessage) -> FcmOptions:
    """06 §4.3 (PM, 2026-11-17, matching both apps):
    - rider offers (`offer.new`, `offer.expired`, `offer.withdrawn`): DATA-ONLY, high priority,
      TTL = the offer timeout. The rider app's background handler rings (or dismisses) its
      full-screen offer alarm; a `notification` part would bypass that handler.
    - other rider pushes: task events (`task.updated`) -> `orders`, high, 1 h; cash, support,
      system -> `general`, normal, 24 h. Task and cash pushes are PRIVATE on the lock screen.
    - customer (always a notification): order events -> `orders`, high, 1 h; support replies ->
      `orders`, high, 24 h; everything else -> `general`, normal, 24 h. Order events are
      PRIVATE on the lock screen (order numbers, amounts, the delivery OTP)."""
    kind = str(message.data.get("type", ""))
    if message.app == RIDER_APP:
        if kind.startswith("offer."):
            return FcmOptions(True, "", True, max(int(settings.OFFER_TIMEOUT_SECONDS), 1))
        if kind in RIDER_TASK_TYPES:
            return FcmOptions(False, CHANNEL_ORDERS, True, ORDER_TTL_SECONDS, private=True)
        private = kind in RIDER_PRIVATE_TYPES
        return FcmOptions(False, CHANNEL_GENERAL, False, GENERAL_TTL_SECONDS, private=private)
    if message.category == ORDER_CATEGORY:
        return FcmOptions(False, CHANNEL_ORDERS, True, ORDER_TTL_SECONDS, private=True)
    if message.category == SUPPORT_CATEGORY:
        return FcmOptions(False, CHANNEL_ORDERS, True, GENERAL_TTL_SECONDS)
    return FcmOptions(False, CHANNEL_GENERAL, False, GENERAL_TTL_SECONDS)


def build_fcm_message(message: PushMessage, token: str, *, now: float | None = None) -> dict:
    """The HTTP v1 request body for one device token. Every `data` value is a string (FCM
    rejects anything else). A notification message has a `notification` part (title, body) on
    its Android channel, tagged per notification so a retried send never shows twice. A
    data-only message (rider offers) has no `notification` part: just `data`, priority and TTL
    (the rider app re-reads the offer from the server and never trusts the push)."""
    options = fcm_options(message)
    data = {str(key): "" if value is None else str(value) for key, value in message.data.items()}
    expires = int((now if now is not None else time.time()) + options.ttl_seconds)
    android: dict = {
        "priority": "HIGH" if options.high_priority else "NORMAL",
        "ttl": f"{options.ttl_seconds}s",
    }
    if options.data_only:
        # iOS (the rider app is Android-only in v1): a silent background push.
        apns = {
            "headers": {
                "apns-expiration": str(expires),
                "apns-priority": "5",
                "apns-push-type": "background",
            },
            "payload": {"aps": {"content-available": 1}},
        }
        return {"message": {"token": token, "data": data, "android": android, "apns": apns}}
    android["notification"] = {"channel_id": options.channel_id}
    if options.private:
        android["notification"]["visibility"] = "PRIVATE"
    apns_headers = {
        "apns-expiration": str(expires),
        "apns-priority": "10" if options.high_priority else "5",
        "apns-push-type": "alert",
    }
    if message.collapse_key:
        android["collapse_key"] = message.collapse_key
        android["notification"]["tag"] = message.collapse_key
        apns_headers["apns-collapse-id"] = message.collapse_key[:64]
    aps: dict = {"sound": "default"}
    if message.event in APNS_LOCK_SCREEN_BODIES:
        # iOS has no per-notification PRIVATE visibility: the visible alert never carries the
        # delivery OTP (the app shows it on the order screen). Android keeps the full text.
        aps["alert"] = {"title": message.title, "body": APNS_LOCK_SCREEN_BODIES[message.event]}
    return {
        "message": {
            "token": token,
            "notification": {"title": message.title, "body": message.body},
            "data": data,
            "android": android,
            "apns": {"headers": apns_headers, "payload": {"aps": aps}},
        }
    }


def mask_token(token: str) -> str:
    """Enough of a device token to tell devices apart in logs, never the token."""
    return f"{token[:8]}...({len(token)})"


def read_service_account(path: str) -> dict:
    """The key file's JSON (raises OSError / ValueError). Callers never log what it holds."""
    with open(path, encoding="utf-8") as handle:
        info = json.load(handle)
    if not isinstance(info, dict):
        raise ValueError("not a JSON object")
    return info


def _refresh_request(http: urllib3.PoolManager):
    """google-auth's urllib3 transport with a short timeout on every token request."""
    from google.auth.transport.urllib3 import Request

    class ShortTimeoutRequest(Request):
        def __call__(self, url, method="GET", body=None, headers=None, timeout=None, **kwargs):
            limit = TOKEN_REFRESH_TIMEOUT_SECONDS
            timeout = limit if timeout is None else min(float(timeout), limit)
            return super().__call__(
                url, method=method, body=body, headers=headers, timeout=timeout, **kwargs
            )

    return ShortTimeoutRequest(http)


def _key_file_error(exc: Exception) -> Exception:
    """An unreadable key file (OSError: a mount not there yet) is transient: PushError, retried.
    Bad content (not JSON, not a key) is not: PushRejected. Never the file's contents."""
    if isinstance(exc, OSError):
        return PushError(f"FCM credentials file unreadable ({type(exc).__name__}).")
    return PushRejected(f"FCM credentials file invalid ({type(exc).__name__}).")


class FcmTokenSource:
    """The OAuth2 access token of one service-account key, cached until TOKEN_REFRESH_MARGIN
    before it expires. Thread-safe: the Celery worker runs the threads pool, so one lock guards
    the refresh and every thread reuses the same token."""

    def __init__(self, credentials_file: str, http: urllib3.PoolManager):
        self.credentials_file = credentials_file
        self.http = http
        self._lock = threading.Lock()
        self._credentials = None

    def _load(self):
        from google.oauth2 import service_account

        try:
            return service_account.Credentials.from_service_account_file(
                self.credentials_file, scopes=[FCM_SCOPE]
            )
        except (OSError, ValueError) as exc:
            raise _key_file_error(exc) from None

    @staticmethod
    def _fresh(credentials) -> bool:
        if not credentials.token or credentials.expiry is None:
            return False
        expiry = credentials.expiry
        if expiry.tzinfo is None:  # google-auth keeps a naive UTC datetime
            expiry = expiry.replace(tzinfo=UTC)
        return expiry - datetime.now(UTC) > TOKEN_REFRESH_MARGIN

    def token(self, *, force_refresh: bool = False, stale: str | None = None) -> str:
        """The cached token, refreshed when near expiry. `force_refresh` with `stale` (the token
        FCM answered 401 to) refreshes only if no other thread already replaced it."""
        from google.auth import exceptions as google_exceptions

        with self._lock:
            if self._credentials is None:
                self._credentials = self._load()
            credentials = self._credentials
            must_refresh = not self._fresh(credentials)
            if force_refresh and (stale is None or credentials.token == stale):
                must_refresh = True
            if must_refresh:
                try:
                    credentials.refresh(_refresh_request(self.http))
                except google_exceptions.TransportError as exc:
                    raise PushError(f"FCM token refresh failed ({type(exc).__name__}).") from None
                except google_exceptions.RefreshError as exc:
                    if getattr(exc, "retryable", False):
                        raise PushError("FCM token refresh failed (retryable).") from None
                    logger.error("FCM token refresh refused: %s", str(exc)[:200])
                    raise PushRejected("FCM token refresh refused (check the key).") from None
            return credentials.token


_http: urllib3.PoolManager | None = None
_token_sources: dict[str, FcmTokenSource] = {}
_project_ids: dict[str, str] = {}
_module_lock = threading.Lock()


def _shared_http() -> urllib3.PoolManager:
    global _http  # one pooled client per process (keep-alive to FCM)
    with _module_lock:
        if _http is None:
            _http = urllib3.PoolManager(timeout=HTTP_TIMEOUT, retries=False)
        return _http


def token_source(credentials_file: str, http: urllib3.PoolManager) -> FcmTokenSource:
    with _module_lock:
        source = _token_sources.get(credentials_file)
        if source is None:
            source = _token_sources[credentials_file] = FcmTokenSource(credentials_file, http)
        return source


def reset_fcm_state() -> None:
    """Forget the cached tokens and project ids (tests; a rotated key file needs a restart)."""
    with _module_lock:
        _token_sources.clear()
        _project_ids.clear()


def project_id(credentials_file: str) -> str:
    if settings.FCM_PROJECT_ID:
        return settings.FCM_PROJECT_ID
    with _module_lock:
        if credentials_file not in _project_ids:
            try:
                info = read_service_account(credentials_file)
            except (OSError, ValueError) as exc:
                raise _key_file_error(exc) from None
            if not info.get("project_id"):
                raise PushRejected("FCM project id unknown: set FCM_PROJECT_ID.")
            _project_ids[credentials_file] = str(info["project_id"])
        return _project_ids[credentials_file]


# Outcomes of one send.
SENT, INVALID_TOKEN, RETRY, REJECTED, UNAUTHORISED = (
    "sent",
    "invalid_token",
    "retry",
    "rejected",
    "unauthorised",
)
INVALID_TOKEN_CODES = frozenset({"UNREGISTERED", "SENDER_ID_MISMATCH"})
RETRY_CODES = frozenset({"QUOTA_EXCEEDED", "UNAVAILABLE", "INTERNAL"})


def classify(status: int, payload: bytes) -> tuple[str, str]:
    """(outcome, FCM error code) of one HTTP v1 answer. INVALID_ARGUMENT counts as a bad token
    only when FCM blames the token (field `message.token`); a bad payload is REJECTED and never
    deactivates devices."""
    if 200 <= status < 300:
        return SENT, ""
    if status == 401:
        return UNAUTHORISED, "UNAUTHENTICATED"
    try:
        error = json.loads(payload or b"{}").get("error") or {}
    except (ValueError, AttributeError):
        error = {}
    if not isinstance(error, dict):
        error = {}
    code, token_blamed = str(error.get("status", "")), False
    for detail in error.get("details") or []:
        if not isinstance(detail, dict):
            continue
        kind = str(detail.get("@type", ""))
        if kind.endswith("google.firebase.fcm.v1.FcmError") and detail.get("errorCode"):
            code = str(detail["errorCode"])
        for violation in detail.get("fieldViolations") or []:
            if isinstance(violation, dict) and violation.get("field") == "message.token":
                token_blamed = True
    if "registration token" in str(error.get("message", "")).lower():
        token_blamed = True
    if status == 429 or status >= 500 or code in RETRY_CODES:
        return RETRY, code or str(status)
    # Only FCM's own error code blames the device: a bare 404 (a wrong project id) must never
    # deactivate every device.
    if code in INVALID_TOKEN_CODES:
        return INVALID_TOKEN, code
    if code == "INVALID_ARGUMENT" and token_blamed:
        return INVALID_TOKEN, code
    return REJECTED, code or str(status)


class FcmPushBackend(BasePushBackend):
    """FCM HTTP v1, one request per device token. A 401 refreshes the access token once. Each
    device's outcome is counted; see `send` for how they combine."""

    def __init__(self, http: urllib3.PoolManager | None = None):
        self.credentials_file = settings.FCM_CREDENTIALS_FILE
        self.http = http or _shared_http()

    def send(self, message: PushMessage) -> PushResult:
        """At least one device reached: SENT (devices that failed transiently are not retried,
        so the reached ones never get a duplicate). None reached: PushError if any failure was
        transient, PushRejected if FCM refused it, else every token was invalid (SKIPPED)."""
        if not self.credentials_file:
            raise PushRejected("FCM_CREDENTIALS_FILE is not set.")
        source = token_source(self.credentials_file, self.http)
        url = FCM_SEND_URL.format(project=project_id(self.credentials_file))
        access = source.token()
        refreshed = False
        counts = {SENT: 0, RETRY: 0, REJECTED: 0}
        bad: list[str] = []
        for device_token in message.tokens:
            body = json.dumps(build_fcm_message(message, device_token)).encode("utf-8")
            outcome, code = self._post(url, access, body)
            if outcome == UNAUTHORISED and not refreshed:
                refreshed = True
                access = source.token(force_refresh=True, stale=access)
                outcome, code = self._post(url, access, body)
            if outcome == UNAUTHORISED:
                outcome = RETRY
            if outcome == INVALID_TOKEN:
                bad.append(device_token)
            else:
                counts[outcome] += 1
            if outcome != SENT:
                logger.warning(
                    "FCM %s for event %s device %s: %s",
                    outcome,
                    message.event,
                    mask_token(device_token),
                    code,
                )
        invalid = tuple(bad)
        if counts[SENT]:
            return PushResult(sent=counts[SENT], invalid_tokens=invalid)
        if counts[RETRY]:
            raise PushError("FCM unavailable; retrying.", invalid_tokens=invalid)
        if counts[REJECTED]:
            raise PushRejected("FCM rejected the message.", invalid_tokens=invalid)
        return PushResult(sent=0, invalid_tokens=invalid)

    def _post(self, url: str, access: str, body: bytes) -> tuple[str, str]:
        try:
            response = self.http.request(
                "POST",
                url,
                body=body,
                headers={
                    "Authorization": f"Bearer {access}",
                    "Content-Type": "application/json; charset=UTF-8",
                },
                timeout=HTTP_TIMEOUT,
                retries=False,
                redirect=False,
            )
        except urllib3.exceptions.HTTPError as exc:
            # Connection refused, timeouts, dropped connections: retried. A send that did go
            # through is collapsed on the device (collapse_key / tag), so no visible duplicate.
            return RETRY, type(exc).__name__
        return classify(response.status, response.data)
