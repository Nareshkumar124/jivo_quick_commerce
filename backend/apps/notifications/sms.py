"""SMS behind a small interface (D-02). The gateway is chosen by SMS_BACKEND.

- ConsoleSmsBackend (local): logs the message, phone masked, so developers can read the OTP.
  It writes OTP codes to the log, so deployed environments refuse it (system check
  `accounts.E003`, BUG-0005); staging may opt in with SMS_CONSOLE_BACKEND_ALLOWED until D-02.
- LocmemSmsBackend (tests): keeps messages in `outbox`. Tests never call a real gateway.
- UnconfiguredSmsBackend: the deployed default until a gateway is configured. Every send fails
  loudly (an error, never a silent drop, and never the message text in the log).
- TwilioSmsBackend: Twilio Programmable Messaging (opt-in via SMS_BACKEND, settings TWILIO_*).
  Indian numbers need a DLT-registered sender and template on the Twilio account in production;
  a Twilio trial account only delivers to verified numbers (error 21608 otherwise).
- Msg91SmsBackend (T-815, D-02): the MSG91 Flow API v5 (opt-in via SMS_BACKEND, settings
  MSG91_AUTH_KEY and MSG91_FLOW_IDS). Our server still generates and verifies every OTP; MSG91
  only delivers the text (its sendotp/verifyotp API is not used). A MSG91 flow ("SMS template")
  holds the DLT-approved text with named `##variables##`, so this backend sends the message's
  `variables`, never `body`. The flow is looked up by the message's DLT template id
  (MSG91_FLOW_IDS = "dlt_id:flow_id,..."); system check accounts.E007 requires the auth key
  and the OTP flow.

Every message carries both forms: `body` (the rendered DLT text, which the console, locmem and
Twilio backends send) and `variables` (the values the text was rendered from, which MSG91 sends).
The OTP uses `otp` and `app_hash`; a notification event uses the `{{names}}` of its SMS text
(apps.notifications.catalog, or its NotificationTemplate override).
"""

import base64
import http.client
import json
import logging
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Mapping
from dataclasses import dataclass, field

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class SmsError(Exception):
    """A transient send failure; the caller (a Celery task) retries."""


class SmsRejected(Exception):
    """The gateway refused the message (4xx: bad or unverified number, bad sender...).
    Retrying cannot help, so this is deliberately not an SmsError."""


class SmsOutcomeUnknown(Exception):
    """The request reached the gateway but no answer came back (read timeout, dropped
    connection). The SMS may have been sent, and neither Twilio nor MSG91 has an idempotency key,
    so a retry could send a duplicate OTP: deliberately not an SmsError. The user can request a
    new OTP."""


@dataclass(frozen=True)
class SmsMessage:
    """`body` and `variables` can hold an OTP, so both are left out of the repr."""

    to: str
    body: str = field(repr=False)
    dlt_template_id: str
    sender_id: str
    # The template variables, for gateways that render the DLT text themselves (MSG91 flows).
    # None: the caller has only the rendered body.
    variables: Mapping[str, str] | None = field(default=None, repr=False)


def mask_phone(phone: str) -> str:
    """09 §3.3: never log full phone numbers. "+919876543210" -> "+91******3210"."""
    if len(phone) <= 7:
        return "*" * len(phone)
    return f"{phone[:3]}{'*' * (len(phone) - 7)}{phone[-4:]}"


class BaseSmsBackend:
    def send(self, message: SmsMessage) -> None:
        raise NotImplementedError


class ConsoleSmsBackend(BaseSmsBackend):
    def send(self, message: SmsMessage) -> None:
        logger.warning(
            "SMS (console backend) to %s [sender %s, DLT template %s]: %s",
            mask_phone(message.to),
            message.sender_id or "-",
            message.dlt_template_id or "-",
            message.body,
        )


class UnconfiguredSmsBackend(BaseSmsBackend):
    def send(self, message: SmsMessage) -> None:
        # Not SmsError: retrying cannot help. The task fails and is reported (Sentry).
        raise ImproperlyConfigured(
            "No SMS gateway is configured (SMS_BACKEND, D-02): an SMS to "
            f"{mask_phone(message.to)} was not sent."
        )


TWILIO_API_BASE = "https://api.twilio.com/2010-04-01"
TWILIO_TIMEOUT_SECONDS = 10  # urllib applies it to the connect and to each socket read
TWILIO_BACKEND = "apps.notifications.sms.TwilioSmsBackend"


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Never follow a 3xx: the POST (credentials and OTP) only ever goes to api.twilio.com.
    Returning None makes urllib raise the 3xx as an HTTPError."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


_OPENER = urllib.request.build_opener(_NoRedirect)


def _open(request: urllib.request.Request, timeout: float):
    return _OPENER.open(request, timeout=timeout)


class TwilioSmsBackend(BaseSmsBackend):
    """POST /Accounts/{sid}/Messages.json with basic auth (account SID : auth token).

    Sends from TWILIO_MESSAGING_SERVICE_SID when set, else from TWILIO_FROM_NUMBER. Logs only
    the masked destination, HTTP status, Twilio error code and message SID: never the token, the
    body (it holds the OTP) or Twilio's error text (it can echo the full number).

    Errors, and whether the OTP task retries them:
    - Retried (SmsError): failures before the request was sent (DNS, connection refused, a
      connect or send timeout; urllib wraps these in URLError), HTTP 429 and 5xx.
    - Not retried, outcome unknown (SmsOutcomeUnknown): a read timeout or dropped connection
      after the request was sent. Twilio may already have accepted the message and has no
      idempotency key, so a retry could deliver a duplicate OTP.
    - Not retried, rejected (SmsRejected): other 4xx, and any 3xx (never followed). Common
      Twilio codes: 21608 (trial account: the number is not verified), 21211 / 21614 (invalid
      or non-mobile number), 21606 / 21659 (the From number cannot send), 20003 (bad SID or
      token), 21408 (the destination region is not enabled in Geo Permissions).
    """

    def send(self, message: SmsMessage) -> None:
        account_sid = settings.TWILIO_ACCOUNT_SID
        auth_token = settings.TWILIO_AUTH_TOKEN
        if not account_sid or not auth_token:
            raise ImproperlyConfigured(
                "TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN are not set: an SMS to "
                f"{mask_phone(message.to)} was not sent."
            )
        fields = {"To": message.to, "Body": message.body}
        if settings.TWILIO_MESSAGING_SERVICE_SID:
            fields["MessagingServiceSid"] = settings.TWILIO_MESSAGING_SERVICE_SID
        elif settings.TWILIO_FROM_NUMBER:
            fields["From"] = settings.TWILIO_FROM_NUMBER
        else:
            raise ImproperlyConfigured(
                "Set TWILIO_MESSAGING_SERVICE_SID or TWILIO_FROM_NUMBER: an SMS to "
                f"{mask_phone(message.to)} was not sent."
            )
        token = base64.b64encode(f"{account_sid}:{auth_token}".encode()).decode()
        request = urllib.request.Request(  # noqa: S310 - fixed https base URL
            f"{TWILIO_API_BASE}/Accounts/{urllib.parse.quote(account_sid)}/Messages.json",
            data=urllib.parse.urlencode(fields).encode(),
            method="POST",
            headers={
                "Authorization": f"Basic {token}",
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
            },
        )
        to = mask_phone(message.to)
        try:
            with _open(request, TWILIO_TIMEOUT_SECONDS) as response:
                status = response.status
                data = _json(response.read())
        except urllib.error.HTTPError as exc:
            code = _json(exc.read()).get("code")
            if exc.code == 429 or exc.code >= 500:
                logger.warning(
                    "Twilio SMS to %s failed, will retry: HTTP %s, Twilio error %s",
                    to,
                    exc.code,
                    code,
                )
                raise SmsError(f"Twilio HTTP {exc.code} (error {code})") from None
            logger.warning(
                "Twilio rejected the SMS to %s, not retrying: HTTP %s, Twilio error %s",
                to,
                exc.code,
                code,
            )
            raise SmsRejected(f"Twilio HTTP {exc.code} (error {code})") from None
        except urllib.error.URLError as exc:
            # Raised before the request was sent (urllib wraps connect/send errors): safe to retry.
            reason = type(getattr(exc, "reason", exc)).__name__
            logger.warning("Twilio SMS to %s not sent, will retry: %s", to, reason)
            raise SmsError(f"Twilio unreachable: {reason}") from None
        except (TimeoutError, OSError, http.client.HTTPException) as exc:
            # The request was sent but no (complete) answer came back.
            logger.warning(
                "Twilio SMS to %s: no response after sending (%s), outcome unknown, not retried",
                to,
                type(exc).__name__,
            )
            raise SmsOutcomeUnknown(f"Twilio response lost: {type(exc).__name__}") from None
        logger.info(
            "Twilio SMS accepted for %s: HTTP %s, message %s, status %s",
            to,
            status,
            data.get("sid", "-"),
            data.get("status", "-"),
        )


MSG91_FLOW_URL = "https://control.msg91.com/api/v5/flow"
MSG91_TIMEOUT_SECONDS = 10  # urllib applies it to the connect and to each socket read
MSG91_BACKEND = "apps.notifications.sms.Msg91SmsBackend"
_E164 = re.compile(r"^\+[1-9][0-9]{7,14}$")
_MSG91_TOKEN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")  # a request id or an error code, no free text


def msg91_mobile(phone: str) -> str:
    """MSG91 wants the country code without "+": "+919876543210" -> "919876543210". Anything
    but an E.164 number is refused (a bare 10-digit number would be read as another country)."""
    if not _E164.match(phone or ""):
        raise SmsRejected(f"Not an E.164 phone number: {mask_phone(phone or '')}")
    return phone[1:]


def _msg91_token(value) -> str:
    """A request id or error code from MSG91's JSON, else "-". Free text (which can echo the
    number) is never logged."""
    value = str(value) if isinstance(value, str | int) and not isinstance(value, bool) else ""
    return value if _MSG91_TOKEN.match(value) else "-"


class Msg91SmsBackend(BaseSmsBackend):
    """POST /api/v5/flow (MSG91 Flow API; T-815, D-02) with the `authkey` header and the JSON
    `{"template_id": <flow id>, "short_url": "0", "recipients": [{"mobiles": "91...",
    <variable>: <value>, ...}]}`, plus `"sender"` when SMS_SENDER_ID is set (used only by flows
    whose sender is "FromAPI"; otherwise the flow's own sender ID applies).

    The flow id comes from MSG91_FLOW_IDS, keyed by the message's DLT template id. Each MSG91
    flow is bound to exactly one DLT template on the MSG91 panel, so the DLT id is the natural
    key, and an admin NotificationTemplate override that brings a new DLT id fails loudly until
    its own flow is mapped (instead of silently sending the old flow's text). A message without
    a mapped flow or without variables is a configuration error (ImproperlyConfigured, nothing
    sent), as with UnconfiguredSmsBackend.

    Logs only the masked destination, the HTTP status, MSG91's response type and its request id
    or error code: never the authkey, the variables (they hold the OTP) or MSG91's error text.

    Errors, and whether the OTP task retries them (the TwilioSmsBackend rules):
    - Retried (SmsError): failures before the request was sent (URLError), HTTP 429 and 5xx.
    - Not retried, outcome unknown (SmsOutcomeUnknown): a read timeout or dropped connection
      after sending, or a 2xx answer without a MSG91 `type`. MSG91 has no idempotency key.
    - Not retried, rejected (SmsRejected): a `"type": "error"` body (MSG91 also reports errors
      such as a bad authkey, an unknown template or a DLT mismatch with HTTP 200), other 4xx,
      any 3xx (never followed), and a phone number that is not E.164.
    """

    def send(self, message: SmsMessage) -> None:
        to = mask_phone(message.to)
        auth_key = settings.MSG91_AUTH_KEY
        if not auth_key:
            raise ImproperlyConfigured(f"MSG91_AUTH_KEY is not set: an SMS to {to} was not sent.")
        flow_id = settings.MSG91_FLOW_IDS.get(message.dlt_template_id or "", "")
        if not flow_id:
            raise ImproperlyConfigured(
                f"No MSG91 flow for DLT template {message.dlt_template_id or '-'} "
                f"(MSG91_FLOW_IDS): an SMS to {to} was not sent."
            )
        if message.variables is None:
            raise ImproperlyConfigured(
                f"MSG91 needs the message's template variables: an SMS to {to} was not sent."
            )
        recipient = {str(name): str(value) for name, value in message.variables.items()}
        recipient["mobiles"] = msg91_mobile(message.to)
        payload = {"template_id": flow_id, "short_url": "0", "recipients": [recipient]}
        if message.sender_id:
            payload["sender"] = message.sender_id
        request = urllib.request.Request(  # fixed https URL
            MSG91_FLOW_URL,
            data=json.dumps(payload).encode(),
            method="POST",
            headers={
                "authkey": auth_key,
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
        )
        try:
            with _open(request, MSG91_TIMEOUT_SECONDS) as response:
                status = response.status
                data = _json(response.read())
        except urllib.error.HTTPError as exc:
            code = _msg91_token(_json(exc.read()).get("code"))
            if exc.code == 429 or exc.code >= 500:
                logger.warning(
                    "MSG91 SMS to %s failed, will retry: HTTP %s, MSG91 code %s",
                    to,
                    exc.code,
                    code,
                )
                raise SmsError(f"MSG91 HTTP {exc.code} (code {code})") from None
            logger.warning(
                "MSG91 rejected the SMS to %s, not retrying: HTTP %s, MSG91 code %s",
                to,
                exc.code,
                code,
            )
            raise SmsRejected(f"MSG91 HTTP {exc.code} (code {code})") from None
        except urllib.error.URLError as exc:
            # Raised before the request was sent (urllib wraps connect/send errors): safe to retry.
            reason = type(getattr(exc, "reason", exc)).__name__
            logger.warning("MSG91 SMS to %s not sent, will retry: %s", to, reason)
            raise SmsError(f"MSG91 unreachable: {reason}") from None
        except (TimeoutError, OSError, http.client.HTTPException) as exc:
            # The request was sent but no (complete) answer came back.
            logger.warning(
                "MSG91 SMS to %s: no response after sending (%s), outcome unknown, not retried",
                to,
                type(exc).__name__,
            )
            raise SmsOutcomeUnknown(f"MSG91 response lost: {type(exc).__name__}") from None
        kind = data.get("type")
        if kind == "error":
            code = _msg91_token(data.get("code"))
            logger.warning(
                "MSG91 rejected the SMS to %s, not retrying: HTTP %s, type error, MSG91 code %s",
                to,
                status,
                code,
            )
            raise SmsRejected(f"MSG91 type error (HTTP {status}, code {code})")
        if kind != "success":
            logger.warning(
                "MSG91 SMS to %s: unexpected answer (HTTP %s), outcome unknown, not retried",
                to,
                status,
            )
            raise SmsOutcomeUnknown(f"MSG91 answered HTTP {status} without a type")
        logger.info(
            "MSG91 SMS accepted for %s: HTTP %s, type success, request %s",
            to,
            status,
            _msg91_token(data.get("message")),
        )


def _json(raw: bytes) -> dict:
    """The gateway's JSON body, or {} when it is missing or not an object."""
    try:
        data = json.loads(raw or b"{}")
    except ValueError:
        return {}
    return data if isinstance(data, dict) else {}


# Backends that never deliver an SMS. Refused in deployed environments (accounts.E003).
NON_DELIVERING_BACKENDS = frozenset(
    {
        "apps.notifications.sms.ConsoleSmsBackend",
        "apps.notifications.sms.LocmemSmsBackend",
    }
)

outbox: list[SmsMessage] = []


class LocmemSmsBackend(BaseSmsBackend):
    def send(self, message: SmsMessage) -> None:
        outbox.append(message)


def get_backend() -> BaseSmsBackend:
    return import_string(settings.SMS_BACKEND)()


def send_sms(
    to: str, body: str, dlt_template_id: str, variables: Mapping[str, str] | None = None
) -> None:
    """`body` is the rendered DLT text; `variables` are the values it was rendered from (MSG91)."""
    get_backend().send(
        SmsMessage(
            to=to,
            body=body,
            dlt_template_id=dlt_template_id,
            sender_id=settings.SMS_SENDER_ID,
            variables=variables,
        )
    )
