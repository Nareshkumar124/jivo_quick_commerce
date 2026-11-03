"""SMS behind a small interface (D-02). The gateway (e.g. MSG91) is chosen by SMS_BACKEND.

- ConsoleSmsBackend (local): logs the message, phone masked, so developers can read the OTP.
  It writes OTP codes to the log, so deployed environments refuse it (system check
  `accounts.E003`, BUG-0005); staging may opt in with SMS_CONSOLE_BACKEND_ALLOWED until D-02.
- LocmemSmsBackend (tests): keeps messages in `outbox`. Tests never call a real gateway.
- UnconfiguredSmsBackend: the deployed default until a gateway is configured. Every send fails
  loudly (an error, never a silent drop, and never the message text in the log).
A real DLT-registered gateway backend is added when Jivo picks the provider.
"""

import logging
from dataclasses import dataclass

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class SmsError(Exception):
    """A transient send failure; the caller (a Celery task) retries."""


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
