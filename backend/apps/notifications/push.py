"""Push behind a small interface, chosen by PUSH_BACKEND. FCM itself waits for D-19 (Firebase
projects), so there is no Firebase dependency yet: an `FcmPushBackend` will implement `send()`.

- DisabledPushBackend (default until D-19): sends nothing; logs the event and the number of
  devices only (never the text, which can hold a delivery OTP). The notification is SKIPPED.
- ConsolePushBackend (local): logs title and body, so developers can read them.
- LocmemPushBackend (tests): keeps messages in `outbox`. Tests never call a real service.

`send()` raises `PushError` for a transient failure (the task retries) and returns the tokens the
service reported as unregistered (their devices are deactivated).
"""

import logging
from dataclasses import dataclass, field

from django.conf import settings
from django.utils.module_loading import import_string

logger = logging.getLogger(__name__)


class PushError(Exception):
    """A transient failure; the task retries with backoff."""


class PushDisabled(Exception):
    """No push service is configured (D-19): the notification is SKIPPED, not retried."""


@dataclass(frozen=True)
class PushMessage:
    tokens: tuple[str, ...]
    title: str
    body: str
    data: dict[str, str] = field(default_factory=dict)  # FCM data values are strings
    event: str = ""
    app: str = ""


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
        logger.warning(
            "PUSH (console backend) [%s, %s device(s)] %s: %s %s",
            message.event,
            len(message.tokens),
            message.title,
            message.body,
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
