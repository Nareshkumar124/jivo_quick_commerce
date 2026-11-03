"""Payment gateway behind one small interface (DL-21, D-01): Razorpay by default, Cashfree as the
named alternative. `PAYMENT_GATEWAY` (a dotted path) picks the implementation.

- `RazorpayGateway`: the real gateway. Keys come only from the environment
  (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`). The signature checks
  are implemented; the HTTP calls (create order, list payments, refund) arrive in Phase 3 R2b.
  Missing keys fail loudly when it is used, never silently.
- `FakeRazorpayGateway`: local development and tests only. No network, no keys. It uses
  Razorpay's own signature algorithms with **published, dev-only** constants, so a dev build of
  the customer app can produce a payment that `POST /payments/razorpay/verify/` accepts without
  real keys (scheme in `docs/06-backend-modules-and-api.md` §2.6). Deployed environments refuse
  it twice: the system check `payments.E001` and this class's constructor.

The server decides payment success (08 §4): a valid signature on verify, or a signed webhook.
The amount always comes from the server-side order, never from the client.
"""

import hashlib
import hmac
import secrets
import string
from abc import ABC, abstractmethod
from dataclasses import dataclass, field

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.module_loading import import_string

DEPLOYED_ENVIRONMENTS = frozenset({"staging", "production"})
_ID_ALPHABET = string.ascii_letters + string.digits


class PaymentGatewayError(Exception):
    """The gateway could not be reached or answered with an error. Transient: the caller
    answers 503 `SERVICE_UNAVAILABLE` (API) or retries (Celery)."""


@dataclass(frozen=True)
class GatewayOrder:
    """An order created at the gateway; the app's checkout pays it."""

    id: str  # e.g. "order_Nq3uVxY7kL9pQe"
    amount_paise: int
    currency: str
    receipt: str  # our order number


@dataclass(frozen=True)
class GatewayPayment:
    """A payment attempt on a gateway order, as the gateway reports it."""

    id: str  # e.g. "pay_Nq3vA1bC2dE3fG"
    order_id: str
    amount_paise: int
    status: str  # Razorpay: created / authorized / captured / failed / refunded
    method: str = ""  # upi / card / netbanking / wallet
    raw: dict = field(default_factory=dict)


@dataclass(frozen=True)
class GatewayRefund:
    id: str  # e.g. "rfnd_..."
    payment_id: str
    amount_paise: int
    status: str  # pending / processed / failed


def razorpay_payment_signature(secret: str, order_id: str, payment_id: str) -> str:
    """Razorpay's checkout signature: hex HMAC-SHA256 of `"<order_id>|<payment_id>"`, keyed
    with the key secret."""
    message = f"{order_id}|{payment_id}".encode()
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def razorpay_webhook_signature(secret: str, body: bytes) -> str:
    """Razorpay's webhook signature (`X-Razorpay-Signature`): hex HMAC-SHA256 of the raw request
    body bytes, keyed with the webhook secret."""
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def _matches(expected: str, given: str | None) -> bool:
    """Constant-time comparison of hex signatures. Anything that is not ASCII is refused first:
    `hmac.compare_digest` raises `TypeError` on non-ASCII `str`, which would turn a forged
    header into a 500 instead of a 400 (code review of R1)."""
    if not given or not given.isascii():
        return False
    return hmac.compare_digest(expected.encode("ascii"), given.strip().lower().encode("ascii"))


class PaymentGateway(ABC):
    """What the order and payment services need from a gateway."""

    #: `Payment.gateway` value (07 §2.7).
    code = "RAZORPAY"

    @property
    @abstractmethod
    def key_id(self) -> str:
        """The public key the app's checkout is opened with."""

    @abstractmethod
    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        """Create a gateway order for exactly `amount_paise` (from the server-side order)."""

    @abstractmethod
    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        """Every payment attempt on a gateway order. `expire_unpaid_orders` calls it before
        failing an order, in case a capture webhook was missed (08 §4 rule 3)."""

    @abstractmethod
    def refund(self, *, payment_id: str, amount_paise: int, notes: dict) -> GatewayRefund:
        """Refund to the original payment (08 §4 rule 4; T3a late captures)."""

    @abstractmethod
    def _key_secret(self) -> str: ...

    @abstractmethod
    def _webhook_secret(self) -> str: ...

    def verify_payment_signature(self, *, order_id: str, payment_id: str, signature: str) -> bool:
        """True when the checkout's `razorpay_signature` matches this order and payment."""
        expected = razorpay_payment_signature(self._key_secret(), order_id, payment_id)
        return _matches(expected, signature)

    def verify_webhook_signature(self, body: bytes, signature: str | None) -> bool:
        """True when `X-Razorpay-Signature` matches the raw body."""
        expected = razorpay_webhook_signature(self._webhook_secret(), body)
        return _matches(expected, signature)


class RazorpayGateway(PaymentGateway):
    """The real Razorpay gateway (test keys on staging, live keys in production)."""

    def _setting(self, name: str) -> str:
        value = getattr(settings, name, "")
        if not value:
            # Fails loudly (a 500 and Sentry), never a silent success: no checkout works
            # without keys (D-01). Deployed environments set them per environment.
            raise ImproperlyConfigured(f"{name} is not set: Razorpay payments cannot work.")
        return value

    @property
    def key_id(self) -> str:
        return self._setting("RAZORPAY_KEY_ID")

    def _key_secret(self) -> str:
        return self._setting("RAZORPAY_KEY_SECRET")

    def _webhook_secret(self) -> str:
        return self._setting("RAZORPAY_WEBHOOK_SECRET")

    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        raise NotImplementedError("Razorpay API calls arrive in Phase 3 R2b.")

    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        raise NotImplementedError("Razorpay API calls arrive in Phase 3 R2b.")

    def refund(self, *, payment_id: str, amount_paise: int, notes: dict) -> GatewayRefund:
        raise NotImplementedError("Razorpay API calls arrive in Phase 3 R2b.")


# --------------------------------------------------------------------------- fake (local/test)
# Published on purpose (06 §2.6, "Fake payment gateway"): these are not secrets. They only work
# with FakeRazorpayGateway, which deployed environments refuse (payments.E001 + constructor).
FAKE_KEY_ID = "rzp_fake_jivo_local"
FAKE_KEY_SECRET = "jivo-fake-razorpay-key-secret-local-only"  # noqa: S105 - published fake
FAKE_WEBHOOK_SECRET = "jivo-fake-razorpay-webhook-secret-local-only"  # noqa: S105 - published


def _fake_id(prefix: str) -> str:
    return prefix + "".join(secrets.choice(_ID_ALPHABET) for _ in range(14))


class FakeRazorpayGateway(PaymentGateway):
    """Razorpay without the network, for local development and tests. Never deployed."""

    def __init__(self) -> None:
        if settings.APP_ENVIRONMENT in DEPLOYED_ENVIRONMENTS:
            raise ImproperlyConfigured(
                f"FakeRazorpayGateway is not allowed in {settings.APP_ENVIRONMENT} "
                "(payments.E001). Set PAYMENT_GATEWAY to the Razorpay gateway."
            )

    @property
    def key_id(self) -> str:
        return FAKE_KEY_ID

    def _key_secret(self) -> str:
        return FAKE_KEY_SECRET

    def _webhook_secret(self) -> str:
        return FAKE_WEBHOOK_SECRET

    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        return GatewayOrder(
            id=_fake_id("order_"), amount_paise=amount_paise, currency="INR", receipt=receipt
        )

    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        # R2b: answered from the captures the server learnt through verify or a signed webhook.
        raise NotImplementedError("The fake gateway's payment lookup arrives in Phase 3 R2b.")

    def refund(self, *, payment_id: str, amount_paise: int, notes: dict) -> GatewayRefund:
        return GatewayRefund(
            id=_fake_id("rfnd_"),
            payment_id=payment_id,
            amount_paise=amount_paise,
            status="processed",
        )


# Gateways that move no money. Refused in deployed environments (payments.E001).
FAKE_GATEWAYS = frozenset({"apps.payments.gateways.FakeRazorpayGateway"})


def get_gateway() -> PaymentGateway:
    return import_string(settings.PAYMENT_GATEWAY)()
