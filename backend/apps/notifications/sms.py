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
"""

import base64
import http.client
import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass

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
    connection). The SMS may have been sent, and Twilio has no idempotency key, so a retry could
    send a duplicate OTP: deliberately not an SmsError. The user can request a new OTP."""


@dataclass(frozen=True)
class SmsMessage:
    to: str
    body: str
    dlt_template_id: str
    sender_id: str


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


def _json(raw: bytes) -> dict:
    """Twilio's JSON body, or {} when it is missing or not an object."""
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


def send_sms(to: str, body: str, dlt_template_id: str) -> None:
    get_backend().send(
        SmsMessage(
            to=to, body=body, dlt_template_id=dlt_template_id, sender_id=settings.SMS_SENDER_ID
        )
    )
